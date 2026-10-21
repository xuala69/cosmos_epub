import 'package:cosmos_epub/Helpers/epub_content_parser.dart';
import 'package:cosmos_epub/Helpers/html_paginator.dart';
import 'package:cosmos_epub/Helpers/html_text_builder.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:cosmos_epub/show_epub.dart' show bookProgress;
import 'package:turnable_page_plus/turnable_page_plus.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Soft hyphen — Flutter's native Text/RichText breaks lines here.
// flutter_html strips these, so we use HtmlTextBuilder (native RichText) instead.
const _shyChar = '\u00AD';
const _vowels = 'aeiouyAEIOUYаеёиоуыэюяАЕЁИОУЫЭЮЯ';

// Uzbek digraphs that must never be split
const _uzDigraphs = [
  'ch',
  'sh',
  "g'",
  "o'",
  "gʻ",
  "oʻ",
  'Ch',
  'Sh',
  "G'",
  "O'",
  "Gʻ",
  "Oʻ",
  'CH',
  'SH',
];

bool _isVowel(String c) => _vowels.contains(c);

/// Get the length of digraph starting at position i, or 1 if not a digraph.
int _charLen(String word, int i) {
  for (final dg in _uzDigraphs) {
    if (i + dg.length <= word.length &&
        word.substring(i, i + dg.length) == dg) {
      return dg.length;
    }
  }
  return 1;
}

/// Inserts soft hyphens into words for better justified text line-breaking.
/// Respects Uzbek digraphs (ch, sh, ng, g', o') — never breaks them apart.
/// Uses - as visible hyphen at break points via Unicode soft hyphen (\u00AD).
String _hyphenateWord(String word) {
  if (word.length < 5) return word;

  // First, tokenize into logical characters (digraphs count as one)
  final tokens = <String>[];
  int i = 0;
  while (i < word.length) {
    final len = _charLen(word, i);
    tokens.add(word.substring(i, i + len));
    i += len;
  }

  if (tokens.length < 4) return word;

  // Classify each token as vowel or consonant
  // For digraphs: o' is vowel, g' is consonant, ch/sh/ng are consonant
  bool tokenIsVowel(String t) {
    if (t == "o'" || t == "oʻ" || t == "O'" || t == "Oʻ") return true;
    if (t.length == 1) return _isVowel(t);
    return false; // ch, sh, ng, g' are consonants
  }

  final buf = StringBuffer();
  for (int ti = 0; ti < tokens.length; ti++) {
    // Don't insert break in first 2 or last 2 tokens
    if (ti >= 2 && ti <= tokens.length - 2) {
      final prev = tokens[ti - 1];
      final cur = tokens[ti];
      final next = ti + 1 < tokens.length ? tokens[ti + 1] : '';
      final prevIsV = tokenIsVowel(prev);
      final curIsC = !tokenIsVowel(cur);
      final nextIsV = next.isNotEmpty && tokenIsVowel(next);

      // V|CV — break before single consonant between vowels
      if (prevIsV && curIsC && nextIsV) {
        buf.write(_shyChar);
      }
      // CC|CV — break between consonant cluster before vowel
      else if (!tokenIsVowel(prev) && curIsC && nextIsV) {
        buf.write(_shyChar);
      }
    }
    buf.write(tokens[ti]);
  }
  return buf.toString();
}

/// Inserts soft hyphens into text content between HTML tags.
String _hyphenateHtml(String html) {
  return html.replaceAllMapped(RegExp(r'>([^<]+)<'), (match) {
    final text = match.group(1)!;
    if (text.trim().isEmpty) return match.group(0)!;
    final hyphenated = text.replaceAllMapped(
      RegExp(r"[a-zA-Zа-яА-Яʻ']{5,}"),
      (m) => _hyphenateWord(m.group(0)!),
    );
    return '>$hyphenated<';
  });
}

class PagingTextHandler {
  final Function paginate;

  /// Turns to the next page WITH the flip animation. Returns false when there
  /// is no next page (the caller should then move to the next chapter).
  final bool Function() nextPage;

  /// Turns to the previous page WITH the flip animation. Returns false when
  /// there is no previous page in this chapter.
  final bool Function() previousPage;

  /// Index of the page currently shown (0-based). Read it to decide whether a
  /// button press should turn the page or move to the next/previous chapter.
  final int Function() currentPage;

  PagingTextHandler({
    required this.paginate,
    bool Function()? nextPage,
    bool Function()? previousPage,
    int Function()? currentPage,
  }) : nextPage = nextPage ?? (() => false),
       previousPage = previousPage ?? (() => false),
       currentPage = currentPage ?? (() => 0);
}

class PagingWidget extends StatefulWidget {
  final String htmlContent;
  final EpubContentParser? contentParser;
  final String bookId;
  final int chapterIndex;
  final String rawFontFamily;
  final Color accentColor;
  final Color backgroundColor;
  final String chapterTitle;
  final int totalChapters;
  final int starterPageIndex;
  final TextStyle style;
  final Function handlerCallback;
  final VoidCallback onTextTap;
  final Function(int, int) onPageFlip;
  final Function(int, int) onLastPage;
  final Function(int, int)? onFirstPageBack;
  final Widget? lastWidget;
  final FlipSettings? flipSettings; // NEW — optional, defaults to null

  const PagingWidget({
    super.key,
    required this.htmlContent,
    this.contentParser,
    this.bookId = '',
    this.chapterIndex = 0,
    this.rawFontFamily = 'Segoe',
    this.accentColor = Colors.indigoAccent,
    this.backgroundColor = Colors.white,
    this.style = const TextStyle(color: Colors.black, fontSize: 30),
    required this.handlerCallback,
    required this.onTextTap,
    required this.onPageFlip,
    required this.onLastPage,
    this.onFirstPageBack,
    this.starterPageIndex = 0,
    required this.chapterTitle,
    required this.totalChapters,
    this.lastWidget,
    this.flipSettings, // NEW — optional, defaults to null
  });

  @override
  State<PagingWidget> createState() => _PagingWidgetState();
}

class _PagingWidgetState extends State<PagingWidget> {
  List<String> _pageHtmls = [];
  List<Widget> pages = [];
  Future<void> paginateFuture = Future.value();
  late RenderBox _initializedRenderBox;

  /// Text scale used when the current pages were generated.
  TextScaler _paginatedTextScaler = TextScaler.noScaling;

  /// Bumped on every request; a pass that is no longer the latest bails out.
  int _paginateToken = 0;

  /// Inputs (content + style) the current [pages] were built with. Used to
  /// ignore no-op rebuilds (theme change, tap toggling the header, …) which
  /// would otherwise re-paginate the whole chapter.
  String? _paginatedHtml;
  double? _paginatedFontSize;
  String? _paginatedFontFamily;

  /// True while pages are being generated — every change to it goes through
  /// [setState]. It is only TRUE before the very first page list exists; from
  /// then on the reader keeps showing the current pages while a new pass runs
  /// in the background, so the spinner never comes back on a font/theme/scale
  /// change (spinner → text → spinner flicker).
  bool _isPaginating = false;

  /// Page the reader is currently on. Captured before a pass replaces [pages]
  /// — [_flipController] reads through the freshly built [pages], so the old
  /// position has to be saved before they are swapped out.
  int _currentPageIndex = 0;

  /// Page the next pass must open on (position restored after regeneration).
  int _pendingStartPage = 0;

  /// Sizes/scale the current pages were built for. Used to detect a layout
  /// change (rotation, keyboard, window resize) that needs a re-pagination.
  Size? _paginatedPageSize;
  TextScaler? _pendingTextScaler;

  /// Reader size seen by the last [build]; a change means a rotation/resize.
  /// A resize pass is already queued for the end of the frame.
  /// Inputs captured when the running pass started.
  String _pendingHtml = '';
  double? _pendingFontSize;
  String _pendingFontFamily = '';

  /// True until the first non-empty page list has been applied. Only then did
  /// the reader actually build pages, so only then does a rebuild become
  /// mandatory after a pass.
  bool _isFirstBuildPending = true;

  /// Page count the last applied pass produced.
  /// Bumped whenever a pass applies a new page list. Part of the TurnablePage
  /// key so the engine is rebuilt once with the new count.
  final _pageKey = GlobalKey();
  late final PageFlipController _flipController;

  @override
  void initState() {
    _flipController = PageFlipController();
    // Pagination needs the size of the reader, which is only known after the
    // first layout. No setState here: the first frame already shows the
    // spinner, so the spinner → content transition happens exactly once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestPaginate();
    });
    var handler = PagingTextHandler(
      paginate: _requestPaginate,
      nextPage: _flipToNextPage,
      previousPage: _flipToPreviousPage,
      currentPage: () => _currentPageIndex,
    );
    widget.handlerCallback(handler);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant PagingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Text size, font or chapter content changed — the existing pages no
    // longer fit, so they have to be regenerated. Checked against the LAST
    // PAGINATED values (not the old widget), so back-to-back rebuilds that
    // only flip a colour or the header can never kick off another pass.
    if (_inputChanged()) {
      _requestPaginate();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // System / accessibility text scaling changed → regenerate pages.
    if (_inputChanged()) {
      _requestPaginate();
    }
  }

  /// True when the reader would have to paginate again: content, font size,
  /// font family, text scale or box size differ from what [pages] was built
  /// for. A null input set means no pages exist yet.
  bool _inputChanged() {
    if (_paginatedHtml == null) return true;
    if (widget.htmlContent != _paginatedHtml) return true;
    if (widget.style.fontSize != _paginatedFontSize) return true;
    if (widget.rawFontFamily != _paginatedFontFamily) return true;
    if (MediaQuery.textScalerOf(context) != _paginatedTextScaler) return true;
    // Only a MEANINGFUL size change re-paginates. The reader box moves by a
    // few pixels while the flip engine lays out (765 → 780 → 810 in the
    // device log); treating each of those as a new size re-paginated several
    // times on open, rebuilt TurnablePage each time, and left the reader
    // unable to flip. Sub-pixel/rounding wobble is ignored here.
    final size = _paginatedPageSize;
    final measured = _paginatedPageSize;
    if (size != null && measured != null) {
      if ((size.width - measured.width).abs() > 10 ||
          (size.height - measured.height).abs() > 10) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    // Drop any pass still in flight so it cannot touch the state afterwards.
    _paginateToken++;
    super.dispose();
  }

  FlipSettings _resolvedSettings() {
    final base =
        widget.flipSettings ??
        FlipSettings(
          enableInertia: true,
          enableEasing: true,
          flippingTime: 650,
          swipeDistance: 48,
          releaseCompletionThreshold: 0.38,
          cornerTriggerAreaSize: 0.25,
        );

    // `width` / `height` are the page size used by the engine's layout, NOT
    // just defaults: `calculateBoundsRect` clamps the page to them
    // (`if (pageWidth > settings.width) pageWidth = settings.width`). With the
    // built-in 350x500 a 420x765 reader drew a 420x630 page — the small
    // rectangle that could be turned — and the aspect ratio then derived the
    // height from that clamped width. Passing the real reader box makes the
    // page fill it exactly, in portrait and landscape alike.
    //
    // The ratio width/height must therefore stay equal to the reader's own
    // ratio: the rect's left edge is `(width - pageWidth) / 2`, so any
    // mismatch shifts the page sideways and `hitTestChildren` (which only
    // tests the right slot) stops matching the visible page.
    final size = _paginatedPageSize;
    return base.copyWith(
      backgroundFillColor: widget.backgroundColor,
      width: size?.width ?? base.width,
      height: size?.height ?? base.height,
    );
  }

  /// Called from external widgets (font size slider, theme/font pickers, …)
  /// after they update their state, and from [didUpdateWidget] /
  /// [didChangeDependencies] / layout changes.
  void _requestPaginate() {
    if (!mounted) return;

    // A pass is already running. It reads the CURRENT widget + MediaQuery when
    // it starts, so a request that arrives while it runs is already covered —
    // starting a second pass would only throw away the first one.
    if (_isPaginating) return;

    // Nothing the paginator cares about changed (theme colours, header
    // toggling, a rebuild from the parent, …) → keep the pages as they are.
    if (!_inputChanged()) return;

    if (pages.isEmpty) {
      // First ever pass: show the spinner until the pages exist.
      setState(_beginPaginate);
    } else {
      // Re-pagination: keep the current pages (and the reader's position) on
      // screen while the new ones are built in the background.
      _beginPaginate();
    }
  }

  /// Re-paginates after the current frame (kept for backwards compatibility).
  void rePaginate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestPaginate();
    });
  }

  /// Kicks off a new pagination pass.
  ///
  /// Never calls [setState]: the spinner is only relevant when there are no
  /// pages yet (handled by the caller), and when there are pages the pass ends
  /// with a single [setState] that swaps in the new list. Nothing is called in
  /// between, so the build phase can never start a pass (that would crash
  /// with "setState() called during build").
  void _beginPaginate() {
    _isPaginating = true;
    _pendingTextScaler = MediaQuery.textScalerOf(context);
    // Snapshot the inputs NOW, so pages are laid out with exactly the style
    // they were measured with even if the widget updates mid-pass.
    _pendingHtml = widget.htmlContent;
    _pendingFontSize = widget.style.fontSize;
    _pendingFontFamily = widget.rawFontFamily;
    _lastPassToken = _paginateToken + 1;
    final pass = _paginate();
    paginateFuture = pass;
    // Every pass ends either by applying pages or by bailing out (stale token,
    // unmounted, no size). Attach the spinner reset to the future itself so it
    // fires even in the paths that return early without a setState.
    pass.whenComplete(() => _completePaginate(_lastPassToken));
  }

  /// Token of the pass [_beginPaginate] started last.
  int _lastPassToken = 0;

  /// Ends a pagination pass — only the latest pass may apply its result, so a
  /// stale pass can never overwrite fresh content or clear the spinner early.
  void _completePaginate(int token) {
    if (!mounted || token != _paginateToken) return;
    if (!_isPaginating) return;
    setState(() {
      _isPaginating = false;
    });
  }

  /// Keeps the reader on the same spot of the chapter after pages were
  /// regenerated: maps the first two words of the current page onto the new
  /// page list, falls back to proportional page position.
  ///
  /// Must be called at the START of a pass: [pages] / [_pageHtmls] are still
  /// the previous pass' pages there, while the flip controller already points
  /// at them. Reading the controller later (mid/end of the pass) would give a
  /// position of the new page list — or throw — every time.
  int _resolvePageIndexAfterRepaginate() {
    int controllerIndex;
    try {
      controllerIndex = pages.isEmpty ? -1 : _flipController.currentPageIndex;
    } catch (_) {
      // Controller is not attached to a TurnablePage yet.
      controllerIndex = -1;
    }

    // Only remap when we have a previous pagination pass to map from.
    if (pages.isEmpty || _pageHtmls.isEmpty) {
      return widget.starterPageIndex.clamp(
        0,
        _pageHtmls.isEmpty ? 0 : _pageHtmls.length - 1,
      );
    }

    final oldIndex =
        (controllerIndex >= 0 ? controllerIndex : _currentPageIndex).clamp(
          0,
          _pageHtmls.length - 1,
        );

    final words = _pageHtmls[oldIndex]
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(_shyChar, '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.toLowerCase())
        .toList();

    if (words.isNotEmpty) {
      final needle = words.join(' ');
      // Search everything AFTER the old index first: the needles are short
      // and reappear earlier in the page text too, so a plain scan from 0
      // could jump backwards.
      for (var i = oldIndex; i < pages.length; i++) {
        if (pages[i] is _HighlightablePage) {
          final html = (pages[i] as _HighlightablePage).pageHtml;
          final text = html
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll(_shyChar, '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .toLowerCase();
          if (text.trim().startsWith(needle)) return i;
        }
      }
      for (var i = 0; i < oldIndex; i++) {
        if (pages[i] is _HighlightablePage) {
          final text = (pages[i] as _HighlightablePage).pageHtml
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll(_shyChar, '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .toLowerCase();
          if (text.trim().startsWith(needle)) return i;
        }
      }
    }

    final ratio = oldIndex / _pageHtmls.length;
    return (ratio * pages.length).floor().clamp(
      0,
      pages.isEmpty ? 0 : pages.length - 1,
    );
  }

  /// Animated page turn used by the reader's next/previous buttons.
  ///
  /// Returns false when this chapter has no next page, so the caller can move
  /// on to the next chapter instead. On success the engine runs the normal
  /// flip animation and reports the new page through [_onPageChanged], which
  /// keeps progress, callbacks and chapter boundaries in sync — a button turn
  /// is then indistinguishable from a swipe.
  bool _flipToNextPage() {
    if (pages.isEmpty) return false;
    if (_currentPageIndex >= pages.length - 1) return false;
    try {
      // `flipNext` (NOT `goToPage`): goToPage emits a 'flip' event for the
      // target immediately, so the engine reported the new index before the
      // animation even started and we counted the turn twice.
      _flipController.nextPage();
    } catch (_) {
      // Controller not attached yet (no TurnablePage laid out).
      return false;
    }
    return true;
  }

  /// Animated backward page turn (see [_flipToNextPage]).
  bool _flipToPreviousPage() {
    if (pages.isEmpty) return false;
    if (_currentPageIndex <= 0) return false;
    try {
      _flipController.previousPage();
    } catch (_) {
      return false;
    }
    return true;
  }

  void _onPageChanged(int leftIndex, int rightIndex) {
    if (pages.isEmpty) return;
    // IMPORTANT: the engine calls this as
    //   onPageChanged(left: currentIndex, right: currentIndex + 1)
    // (`rightIndex` is the page NEXT to the current one, not the current one).
    // Using rightIndex reported every turn one page too far, which desynced
    // the index from the visible page and made the next button jump pages.
    final newIndex = leftIndex;
    if (newIndex < 0 || newIndex >= pages.length) return;

    // Only a real turn crosses a chapter boundary. Without this the engine's
    // post-layout 'flip' notification for page 0 (sent whenever the book is
    // laid out / re-created) was treated as "back from the first page" and
    // went straight to the previous chapter.
    final crossed = newIndex != _currentPageIndex;
    _currentPageIndex = newIndex;
    widget.onPageFlip(newIndex, pages.length);
    bookProgress.setCurrentPageIndex(widget.bookId, newIndex);
    if (!crossed) return;

    if (newIndex == pages.length - 1) {
      widget.onLastPage(newIndex, pages.length);
    }
    if (newIndex == 0) {
      widget.onFirstPageBack?.call(0, pages.length);
    }
  }

  Future<void> _paginate() async {
    final token = ++_paginateToken;
    if (!mounted) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      _completePaginate(token);
      return;
    }
    _initializedRenderBox = renderObject;

    // Remember where the reader was so the position survives regeneration.
    final previousIndex = _resolvePageIndexAfterRepaginate();

    final pageSize = _initializedRenderBox.size;
    // Measure with the inputs captured by [_beginPaginate], so the pages are
    // consistent even if the widget is rebuilt during the pass.
    final html = _pendingHtml;
    final fontSize = _pendingFontSize ?? widget.style.fontSize ?? 17.0;
    final fontFamily = _pendingFontFamily;
    final textScaler = _pendingTextScaler ?? MediaQuery.textScalerOf(context);
    final textDirection = RTLHelper.getTextDirection(html);

    // Resolve EPUB images to inline base64 data URIs
    String resolvedHtml = html;
    if (widget.contentParser != null) {
      resolvedHtml = widget.contentParser!.resolveImagesInHtml(resolvedHtml);
    }

    // Split HTML into page-sized chunks (before hyphenation so measurement is clean)
    final paginator = HtmlPaginator(
      pageWidth: pageSize.width - 20.w,
      pageHeight: pageSize.height - 100.h,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontPackage: 'cosmos_epub',
      textDirection: textDirection,
      textScaler: textScaler,
    );

    final newPageHtmls = paginator.paginate(resolvedHtml);

    // A newer pass was requested while this one was running — drop this one.
    if (!mounted || token != _paginateToken) return;

    // Nothing actually changed while this pass ran (e.g. the slider fired a
    // second request after the value settled): keep the existing pages and
    // make sure the spinner is gone.
    final sameResult = _samePageList(newPageHtmls, _pageHtmls);

    _pageHtmls = newPageHtmls;

    // Insert soft hyphens AFTER pagination — applied to text that goes
    // directly to native RichText (not flutter_html which strips \u00AD)
    _pageHtmls = _pageHtmls.map((h) => _hyphenateHtml(h)).toList();

    pages = _pageHtmls.map((pageHtml) {
      return _HighlightablePage(
        // Key by content+style so a regenerated page never reuses the old
        // (differently sized) layout of a previous pagination pass.
        key: ValueKey(
          '${widget.chapterIndex}_${fontSize}_${fontFamily}_'
          '${pageHtml.hashCode}',
        ),
        pageHtml: pageHtml,
        chapterTitle: widget.chapterTitle,
        style: widget.style,
        rawFontFamily: fontFamily,
        bookId: widget.bookId,
        chapterIndex: widget.chapterIndex,
        accentColor: widget.accentColor,
        backgroundColor: widget.backgroundColor,
        onTextTap: widget.onTextTap,
      );
    }).toList();

    _paginatedHtml = html;
    _paginatedFontSize = fontSize;
    _paginatedFontFamily = fontFamily;
    _paginatedTextScaler = textScaler;
    _paginatedPageSize = pageSize;

    // The position is carried over through [_pendingStartPage]; the reader is
    // moved there after the new pages are laid out (see build).
    _pendingStartPage = previousIndex.clamp(
      0,
      pages.isEmpty ? 0 : pages.length - 1,
    );
    _currentPageIndex = _pendingStartPage;

    if (sameResult && !_isFirstBuildPending) {
      // Same content as before — no rebuild needed, just leave the spinner.
      _isPaginating = false;
      return;
    }
    _isFirstBuildPending = false;
    // Force build() to hand the new list (and its start page) to a fresh
    // TurnablePage.

    // Single rebuild that swaps the spinner for the pages (first pass) or the
    // old pages for the new ones (re-pagination).
    setState(() {
      _isPaginating = false;
    });
  }

  /// True when [a] and [b] contain the same page markup in the same order.
  bool _samePageList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // The reader only exists once the first page list was built. While that
    // first pass runs the spinner is shown; afterwards the pages stay on
    // screen through every further pass, so the spinner never comes back.
    if (pages.isEmpty) {
      return Center(
        child: CupertinoActivityIndicator(
          color: Theme.of(context).primaryColor,
          radius: 30.r,
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: SizedBox.expand(
                key: _pageKey,
                child: _TapDetector(
                  onTap: widget.onTextTap,
                  child: TurnablePage(
                    key: ValueKey('reader_${pages.length}_$_pendingStartPage'),
                    controller: _flipController,
                    pageCount: pages.length,
                    pageViewMode: PageViewMode.single,
                    pagesBoundaryIsEnabled: false,
                    autoResponseSize: true,
                    aspectRatio:
                        _paginatedPageSize?.aspectRatio ?? 2 / 3,
                    settings: _resolvedSettings().copyWith(
                      startPage: _pendingStartPage.clamp(
                        0,
                        pages.length - 1,
                      ),
                      usePortrait: true,
                    ),
                    onPageChanged: _onPageChanged,
                    builder: (context, index, constraints) => pages[index],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Detects a short tap (pointer down + up with minimal movement) without
/// registering a GestureRecognizer that would compete with TurnablePage's
/// flip gesture. Uses raw pointer events so the flip engine still wins drags.
class _TapDetector extends StatefulWidget {
  const _TapDetector({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_TapDetector> createState() => _TapDetectorState();
}

class _TapDetectorState extends State<_TapDetector> {
  Offset? _downPos;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _downPos = e.position,
      onPointerUp: (e) {
        if (_downPos != null && (e.position - _downPos!).distance < 10) {
          widget.onTap();
        }
        _downPos = null;
      },
      onPointerCancel: (_) => _downPos = null,
      child: widget.child,
    );
  }
}

class _HighlightablePage extends StatefulWidget {
  final String pageHtml;
  final String chapterTitle;
  final TextStyle style;
  final String rawFontFamily;
  final String bookId;
  final int chapterIndex;
  final Color accentColor;
  final Color backgroundColor;
  final VoidCallback onTextTap;

  const _HighlightablePage({
    super.key,
    required this.pageHtml,
    this.chapterTitle = '',
    required this.style,
    this.rawFontFamily = 'Segoe',
    required this.bookId,
    required this.chapterIndex,
    this.accentColor = Colors.indigoAccent,
    this.backgroundColor = Colors.white,
    required this.onTextTap,
  });

  @override
  State<_HighlightablePage> createState() => _HighlightablePageState();
}

class _HighlightablePageState extends State<_HighlightablePage> {
  HtmlTextBuilder? _lastBuilder;

  List<Widget> _buildContent() {
    // Build once to get the page key from accumulated block text
    final tempBuilder = HtmlTextBuilder(
      fontSize: widget.style.fontSize ?? 17.0,
      fontFamily: widget.rawFontFamily,
      fontPackage: 'cosmos_epub',
      textColor: widget.style.color ?? Colors.black,
      accentColor: widget.accentColor,
      onTextTap: widget.onTextTap,
    );
    tempBuilder.build(widget.pageHtml);
    final pageKey = HighlightModel.makeParagraphKey(
      tempBuilder.lastBuiltCleanText,
    );

    // Now build with highlights loaded using that key
    final pageHighlights = widget.bookId.isNotEmpty
        ? HighlightStorage.getParagraphHighlights(
            widget.bookId,
            widget.chapterIndex,
            pageKey,
          )
        : <HighlightModel>[];

    _lastBuilder = HtmlTextBuilder(
      fontSize: widget.style.fontSize ?? 17.0,
      fontFamily: widget.rawFontFamily,
      fontPackage: 'cosmos_epub',
      textColor: widget.style.color ?? Colors.black,
      accentColor: widget.accentColor,
      onTextTap: widget.onTextTap,
      highlights: pageHighlights,
      onParagraphTapped: (start, end) {},
      onHighlightChanged: () {
        if (mounted) setState(() {});
      },
    );

    return _lastBuilder!.build(widget.pageHtml);
  }

  @override
  Widget build(BuildContext context) {
    // Section title page — centered title, no content
    if (widget.pageHtml.isEmpty && widget.chapterTitle.isNotEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTextTap,
        child: Container(
          color: widget.backgroundColor,
          child: Center(
            child: Text(
              widget.chapterTitle,
              textAlign: TextAlign.center,
              style: (widget.style).copyWith(
                fontSize: (widget.style.fontSize ?? 17) * 1.8,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
    }

    final pageTextDirection = RTLHelper.getTextDirection(widget.pageHtml);
    final contentWidgets = _buildContent();

    // SelectionArea is kept for text highlighting but without a scroll wrapper
    // so that TurnablePage's render object can claim horizontal drag gestures.
    return Container(
      color: widget.backgroundColor,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 40.h,
          top: 15.h,
          left: 15.w,
          right: 15.w,
        ),
        child: DefaultTextStyle(
          style: widget.style.copyWith(height: 1.4),
          child: Directionality(
            textDirection: pageTextDirection,
            // Measurement is an estimate, so a page can come out a line or two
            // too tall. Giving the Column unbounded height (and clipping the
            // overflow) keeps that from raising a RenderFlex error over the
            // book: content that does not fit is simply cut at the page edge.
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: contentWidgets,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
