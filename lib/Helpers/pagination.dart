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
  Offset? _singlePageSwipeStart;

  void _handleSinglePagePointerDown(PointerDownEvent event) {
    if (pages.length == 1) _singlePageSwipeStart = event.position;
  }

  void _handleSinglePagePointerUp(PointerUpEvent event) {
    final start = _singlePageSwipeStart;
    _singlePageSwipeStart = null;
    if (start == null || pages.length != 1) return;

    final dx = event.position.dx - start.dx;
    // Follow the reader's next-button direction: LTR advances with a
    // right-to-left swipe, while RTL advances with a left-to-right swipe.
    final forward = Directionality.of(context) == TextDirection.rtl
        ? dx > 48
        : dx < -48;
    if (forward) widget.onLastPage(0, pages.length);
  }

  @override
  void initState() {
    debugPrint('[PAGINATE] PagingWidget initState() called');
    debugPrint('[PAGINATE] Initial fontSize: ${widget.style.fontSize}');
    debugPrint(
      '[PAGINATE] Initial htmlContent length: ${widget.htmlContent.length}',
    );
    _flipController = PageFlipController();
    // Pagination needs the size of the reader, which is only known after the
    // first layout. No setState here: the first frame already shows the
    // spinner, so the spinner → content transition happens exactly once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[PAGINATE] Post-frame callback: requesting pagination');
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

    // If chapter content has changed, clear pages to show spinner during re-pagination
    if (oldWidget.htmlContent != widget.htmlContent) {
      debugPrint(
        '[PAGINATE] Chapter content changed, clearing pages for re-pagination',
      );
      // Set pages to empty to trigger spinner
      setState(() {
        pages = [];
      });
    }

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
        // FlipSettings(
        //   enableInertia: false,  // Disable inertia-based flipping to prevent page skipping
        //   enableEasing: true,
        //   flippingTime: 650,
        //   swipeDistance: 48,
        //   releaseCompletionThreshold: 0.5,
        //   cornerTriggerAreaSize: 0.5,
        //   inertiaVelocityThreshold: 0,  // Disable velocity-based completion
        //   inertiaProgressBoost: 0,  // Disable progress boost
        //   bottomCornerReleaseCompletionThreshold: 0.5,  // Same as main threshold
        //   usePortrait: true,  // Explicitly set for single page mode
        // );
        //The above works but no inertia so cant turn page on simulator
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
    debugPrint(
      '[PAGINATE] _resolvedSettings: size=$size, base.width=${base.width}, base.height=${base.height}',
    );
    final actualWidth = size?.width ?? base.width;
    final actualHeight = size?.height ?? base.height;
    debugPrint(
      '[PAGINATE] Using TurnablePage size: width=$actualWidth, height=$actualHeight, ratio=${actualWidth / actualHeight}',
    );
    return base.copyWith(
      backgroundFillColor: widget.backgroundColor,
      width: actualWidth,
      height: actualHeight,
    );
  }

  /// Called from external widgets (font size slider, theme/font pickers, …)
  /// after they update their state, and from [didUpdateWidget] /
  /// [didChangeDependencies] / layout changes.
  void _requestPaginate() {
    debugPrint(
      '[PAGINATE] _requestPaginate() called, isPaginating=$_isPaginating, pages.isEmpty=${pages.isEmpty}',
    );
    if (!mounted) {
      debugPrint('[PAGINATE] Widget not mounted, aborting request');
      return;
    }

    // A pass is already running. It reads the CURRENT widget + MediaQuery when
    // it starts, so a request that arrives while it runs is already covered —
    // starting a second pass would only throw away the first one.
    if (_isPaginating) {
      debugPrint('[PAGINATE] Pagination already in progress, skipping request');
      return;
    }

    // Nothing the paginator cares about changed (theme colours, header
    // toggling, a rebuild from the parent, …) → keep the pages as they are.
    final inputChanged = _inputChanged();
    debugPrint('[PAGINATE] inputChanged=$inputChanged');
    if (!inputChanged) {
      debugPrint('[PAGINATE] No input changes, skipping pagination');
      return;
    }

    if (pages.isEmpty) {
      debugPrint('[PAGINATE] First pass - will show spinner');
      // First ever pass: show the spinner until the pages exist.
      setState(_beginPaginate);
    } else {
      debugPrint(
        '[PAGINATE] Re-pagination - will keep current pages on screen',
      );
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
    debugPrint('[PAGINATE] _beginPaginate() starting new pass');
    _isPaginating = true;
    _pendingTextScaler = MediaQuery.textScalerOf(context);
    // Snapshot the inputs NOW, so pages are laid out with exactly the style
    // they were measured with even if the widget updates mid-pass.
    _pendingHtml = widget.htmlContent;
    _pendingFontSize = widget.style.fontSize;
    _pendingFontFamily = widget.rawFontFamily;
    debugPrint(
      '[PAGINATE] Captured inputs: htmlLength=${_pendingHtml.length}, fontSize=$_pendingFontSize, fontFamily=$_pendingFontFamily',
    );
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
  /// Returns false when this chapter has no next page AND there's no next chapter,
  /// so the caller knows we're at the end. Otherwise, it either flips to the next
  /// page in this chapter, or (if at the last page) it triggers a chapter change
  /// through the normal onLastPage callback mechanism.
  bool _flipToNextPage() {
    debugPrint('[PAGINATE] _flipToNextPage() called');
    debugPrint(
      '[PAGINATE] pages.length=${pages.length}, _currentPageIndex=$_currentPageIndex',
    );
    if (pages.isEmpty) {
      debugPrint('[PAGINATE] No pages available, returning false');
      return false;
    }

    // Check if we can flip to a next page in this chapter
    if (_currentPageIndex < pages.length - 1) {
      try {
        debugPrint('[PAGINATE] Calling _flipController.nextPage()');
        _flipController.nextPage();
      } catch (_) {
        debugPrint('[PAGINATE] Controller not attached, returning false');
        return false;
      }
      debugPrint('[PAGINATE] nextPage() succeeded');
      return true;
    }

    // We're at the last page of this chapter - check if there's a next chapter
    // For now, we return false to let the caller handle chapter navigation
    // TODO: We could pre-load the first page of the next chapter and flip to it
    debugPrint(
      '[PAGINATE] At last page of chapter ${widget.chapterIndex}, returning false for chapter navigation',
    );
    return false;
  }

  /// Animated backward page turn (see [_flipToNextPage]).
  bool _flipToPreviousPage() {
    debugPrint('[PAGINATE] _flipToPreviousPage() called');
    debugPrint(
      '[PAGINATE] pages.length=${pages.length}, _currentPageIndex=$_currentPageIndex',
    );
    if (pages.isEmpty) {
      debugPrint('[PAGINATE] No pages available, returning false');
      return false;
    }
    if (_currentPageIndex <= 0) {
      debugPrint('[PAGINATE] At first page!');
      return false;
    }
    try {
      debugPrint('[PAGINATE] Calling _flipController.previousPage()');
      _flipController.previousPage();
    } catch (_) {
      debugPrint('[PAGINATE] Controller not attached, returning false');
      return false;
    }
    debugPrint('[PAGINATE] previousPage() succeeded');
    return true;
  }

  void _onPageChanged(int leftIndex, int rightIndex) {
    debugPrint('[PAGINATE] _onPageChanged(left=$leftIndex, right=$rightIndex)');
    if (pages.isEmpty) {
      debugPrint('[PAGINATE] No pages, returning');
      return;
    }

    // Try to get the actual current page from the controller for more reliable tracking
    int controllerPage;
    try {
      controllerPage = _flipController.currentPageIndex;
      debugPrint('[PAGINATE] Controller page index: $controllerPage');
    } catch (e) {
      debugPrint('[PAGINATE] Could not get controller page: $e');
      controllerPage = -1;
    }

    // IMPORTANT: the engine calls this as
    //   onPageChanged(left: currentIndex, right: currentIndex + 1)
    // (`rightIndex` is the page NEXT to the current one, not the current one).
    // Using rightIndex reported every turn one page too far, which desynced
    // the index from the visible page and made the next button jump pages.

    // Use controller page if available, otherwise fall back to leftIndex
    int rawNewIndex = controllerPage >= 0 ? controllerPage : leftIndex;
    debugPrint(
      '[PAGINATE] rawNewIndex=$rawNewIndex (from ${controllerPage >= 0 ? 'controller' : 'leftIndex'}), current _currentPageIndex=$_currentPageIndex',
    );

    // WORKAROUND: TurnablePage sometimes skips pages during swipe gestures.
    // If we detect a skip (jump of more than 1 page), only advance by 1 page instead.
    int newIndex = rawNewIndex;
    if (_currentPageIndex >= 0 && pages.isNotEmpty) {
      // final expectedNext = _currentPageIndex + 1;
      // final expectedPrev = _currentPageIndex - 1;

      // If TurnablePage reports we jumped forward by more than 1 page,
      // only advance by 1 instead
      if (rawNewIndex > _currentPageIndex + 1) {
        debugPrint(
          '[PAGINATE] WARNING: Detected page skip forward from $_currentPageIndex to $rawNewIndex, correcting to ${_currentPageIndex + 1}',
        );
        newIndex = _currentPageIndex + 1;
      }
      // If TurnablePage reports we jumped backward by more than 1 page,
      // only go back by 1 instead
      else if (rawNewIndex < _currentPageIndex - 1) {
        debugPrint(
          '[PAGINATE] WARNING: Detected page skip backward from $_currentPageIndex to $rawNewIndex, correcting to ${_currentPageIndex - 1}',
        );
        newIndex = _currentPageIndex - 1;
      }
    }

    // FIX: When swiping from the last page of a chapter (where rightIndex = -1),
    // automatically trigger chapter navigation, just like the next button does.
    // This handles the case where a chapter has only 1 page and swiping should go to next chapter.
    if (pages.length > 1 && rightIndex == -1 && leftIndex == pages.length - 1) {
      debugPrint(
        '[PAGINATE] Swiped from last page of chapter, triggering onLastPage for chapter navigation',
      );
      widget.onLastPage(leftIndex, pages.length);
      // Don't update index or return, let normal flow continue
    }

    if (newIndex < 0 || newIndex >= pages.length) {
      debugPrint('[PAGINATE] newIndex out of bounds, returning');
      return;
    }

    // Only a real turn crosses a chapter boundary. Without this the engine's
    // post-layout 'flip' notification for page 0 (sent whenever the book is
    // laid out / re-created) was treated as "back from the first page" and
    // went straight to the previous chapter.
    final crossed = newIndex != _currentPageIndex;
    debugPrint(
      '[PAGINATE] crossed=$crossed, updating _currentPageIndex from $_currentPageIndex to $newIndex',
    );
    _currentPageIndex = newIndex;
    widget.onPageFlip(newIndex, pages.length);
    bookProgress.setCurrentPageIndex(widget.bookId, newIndex);
    if (!crossed) return;

    if (newIndex == pages.length - 1) {
      debugPrint('[PAGINATE] Reached last page, calling onLastPage');
      widget.onLastPage(newIndex, pages.length);
    }
    if (newIndex == 0) {
      debugPrint('[PAGINATE] Reached first page, calling onFirstPageBack');
      widget.onFirstPageBack?.call(0, pages.length);
    }
  }

  Future<void> _paginate() async {
    final token = ++_paginateToken;
    debugPrint('[PAGINATE] Starting pagination pass #$token');
    if (!mounted) {
      debugPrint('[PAGINATE] Widget not mounted, aborting pass #$token');
      return;
    }

    final renderObject = context.findRenderObject();
    debugPrint('[PAGINATE] RenderObject type: ${renderObject.runtimeType}');
    if (renderObject is! RenderBox) {
      debugPrint(
        '[PAGINATE] RenderObject is not RenderBox, aborting pass #$token',
      );
      _completePaginate(token);
      return;
    }
    if (!renderObject.hasSize) {
      debugPrint(
        '[PAGINATE] RenderBox has no size yet (${renderObject.size}), scheduling retry...',
      );
      // Schedule a retry for the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && token == _paginateToken) {
          debugPrint('[PAGINATE] Retry: calling _paginate() again');
          _paginate();
        }
      });
      _completePaginate(token);
      return;
    }
    debugPrint('[PAGINATE] RenderBox has size: ${renderObject.size}');
    _initializedRenderBox = renderObject;

    // Remember where the reader was so the position survives regeneration.
    final previousIndex = _resolvePageIndexAfterRepaginate();

    final pageSize = _initializedRenderBox.size;
    debugPrint('[PAGINATE] Page size: $pageSize');
    // Measure with the inputs captured by [_beginPaginate], so the pages are
    // consistent even if the widget is rebuilt during the pass.
    final html = _pendingHtml;
    final fontSize = _pendingFontSize ?? widget.style.fontSize ?? 17.0;
    final fontFamily = _pendingFontFamily;
    final textScaler = _pendingTextScaler ?? MediaQuery.textScalerOf(context);
    final textDirection = RTLHelper.getTextDirection(html);
    debugPrint(
      '[PAGINATE] HTML length: ${html.length}, fontSize: $fontSize, fontFamily: $fontFamily',
    );

    // Check if HTML is empty or very short
    if (html.trim().isEmpty) {
      debugPrint('[PAGINATE] WARNING: HTML content is empty!');
    } else if (html.length < 100) {
      debugPrint(
        '[PAGINATE] WARNING: HTML content is very short ($html.length chars)',
      );
    }

    // Resolve EPUB images to inline base64 data URIs
    String resolvedHtml = html;
    if (widget.contentParser != null) {
      debugPrint('[PAGINATE] Resolving images in HTML');
      resolvedHtml = widget.contentParser!.resolveImagesInHtml(resolvedHtml);
    }

    // Split HTML into page-sized chunks (before hyphenation so measurement is clean)
    // Subtract space for headers and margins
    final effectivePageHeight = pageSize.height - 150.h;
    debugPrint('[PAGINATE] Page size: $pageSize');
    debugPrint('[PAGINATE] Effective page height: $effectivePageHeight');
    debugPrint('[PAGINATE] Font size: $fontSize, font family: $fontFamily');
    debugPrint('[PAGINATE] Text direction: $textDirection');
    debugPrint('[PAGINATE] Text scaler: ${textScaler.scale(1.0)}');
    final paginator = HtmlPaginator(
      pageWidth: pageSize.width - 20.w,
      pageHeight: effectivePageHeight,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontPackage: 'cosmos_epub',
      textDirection: textDirection,
      textScaler: textScaler,
    );

    debugPrint(
      '[PAGINATE] Calling HtmlPaginator.paginate() with ${resolvedHtml.length} chars',
    );
    debugPrint(
      '[PAGINATE] HTML content preview: ${resolvedHtml.substring(0, resolvedHtml.length > 500 ? 500 : resolvedHtml.length)}...',
    );
    final newPageHtmls = paginator.paginate(resolvedHtml);
    debugPrint('[PAGINATE] Generated ${newPageHtmls.length} pages');

    if (newPageHtmls.length == 1) {
      debugPrint('[PAGINATE] WARNING: Only 1 page generated!');
      debugPrint(
        '[PAGINATE] Check if HTML is empty or page height is too large',
      );
      debugPrint('[PAGINATE] Effective page height used: $effectivePageHeight');
    }

    // A newer pass was requested while this one was running — drop this one.
    if (!mounted) {
      debugPrint(
        '[PAGINATE] Widget unmounted during pagination, dropping pass #$token',
      );
      return;
    }
    if (token != _paginateToken) {
      debugPrint(
        '[PAGINATE] Newer pass requested (current token: $_paginateToken), dropping pass #$token',
      );
      return;
    }

    // Nothing actually changed while this pass ran (e.g. the slider fired a
    // second request after the value settled): keep the existing pages and
    // make sure the spinner is gone.
    final sameResult = _samePageList(newPageHtmls, _pageHtmls);
    if (sameResult) {
      debugPrint('[PAGINATE] Same result as previous, not updating pages');
    } else {
      debugPrint(
        '[PAGINATE] New pages generated: ${newPageHtmls.length} pages',
      );
    }

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
    debugPrint(
      '[PAGINATE] Pending start page: $_pendingStartPage, current page: $_currentPageIndex',
    );

    if (sameResult && !_isFirstBuildPending) {
      // Same content as before — no rebuild needed, just leave the spinner.
      debugPrint('[PAGINATE] Not rebuilding, spinner will be hidden');
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
    debugPrint(
      '[PAGINATE] build() called, pages.length=${pages.length}, _isPaginating=$_isPaginating',
    );

    // Check if we have a size now and need to trigger pagination
    final renderObject = context.findRenderObject();
    debugPrint(
      '[PAGINATE] build() RenderObject: ${renderObject.runtimeType}, hasSize: ${renderObject is RenderBox ? (renderObject).hasSize : 'N/A'}, size: ${renderObject is RenderBox ? (renderObject).size : 'N/A'}',
    );
    if (pages.isEmpty &&
        !_isPaginating &&
        renderObject is RenderBox &&
        renderObject.hasSize) {
      debugPrint(
        '[PAGINATE] Build detected: pages empty but has size, triggering pagination',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pages.isEmpty) {
          debugPrint(
            '[PAGINATE] Post-frame: retrying pagination with available size',
          );
          _requestPaginate();
        }
      });
    }

    // The reader only exists once the first page list was built. While that
    // first pass runs the spinner is shown; afterwards the pages stay on
    // screen through every further pass, so the spinner never comes back.
    if (pages.isEmpty) {
      debugPrint('[PAGINATE] Pages empty, showing spinner');
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
                child: Listener(
                  onPointerDown: _handleSinglePagePointerDown,
                  onPointerUp: _handleSinglePagePointerUp,
                  onPointerCancel: (_) => _singlePageSwipeStart = null,
                  child: TurnablePage(
                    key: ValueKey('reader_${pages.length}_$_pendingStartPage'),
                    controller: _flipController,
                    pageCount: pages.length,
                    pageViewMode: PageViewMode.single,
                    pagesBoundaryIsEnabled: false,
                    autoResponseSize: false,
                    settings: _resolvedSettings().copyWith(
                      startPage: _pendingStartPage.clamp(0, pages.length - 1),
                    ),
                    onPageChanged: (left, right) {
                      debugPrint(
                        '[PAGINATE] TurnablePage onPageChanged: left=$left, right=$right, currentPageIndex=$_currentPageIndex',
                      );
                      _onPageChanged(left, right);
                    },
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
