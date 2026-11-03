import 'package:cosmos_epub/Helpers/epub_content_parser.dart';
import 'package:cosmos_epub/Helpers/html_paginator.dart';
import 'package:cosmos_epub/Helpers/html_text_builder.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:turnable_page_plus/turnable_page_plus.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/Model/chapter_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  /// is no next page.
  final bool Function() nextPage;

  /// Turns to the previous page WITH the flip animation. Returns false on the
  /// first page.
  final bool Function() previousPage;

  /// Book-wide index of the page currently shown (0-based).
  final int Function() currentPage;

  /// Turns to the first page of spine item [spineIndex] (TOC, chapters).
  final void Function(int spineIndex) goToSpineItem;

  /// The reader's position: spine item and page within it. The reader is
  /// the only owner of the position; read it here rather than copying it.
  final (int, int) Function() location;

  /// Whether a page exists before / after the current one, anywhere in the
  /// book (not only in the current chapter).
  final bool Function() canGoPrevious;
  final bool Function() canGoNext;

  PagingTextHandler({
    required this.paginate,
    bool Function()? nextPage,
    bool Function()? previousPage,
    int Function()? currentPage,
    void Function(int spineIndex)? goToSpineItem,
    (int, int) Function()? location,
    bool Function()? canGoPrevious,
    bool Function()? canGoNext,
  }) : nextPage = nextPage ?? (() => false),
       previousPage = previousPage ?? (() => false),
       currentPage = currentPage ?? (() => 0),
       goToSpineItem = goToSpineItem ?? ((_) {}),
       location = location ?? (() => (0, 0)),
       canGoPrevious = canGoPrevious ?? (() => false),
       canGoNext = canGoNext ?? (() => false);
}

/// The whole book as one run of pages: every spine item is paginated and the
/// pages are laid end to end in a single [TurnablePage], so every turn —
/// cover, title page and chapter boundaries included — folds like any other.
class PagingWidget extends StatefulWidget {
  final List<SpineItem> spine;
  final EpubContentParser? contentParser;
  final String bookId;

  /// Where to open: spine item and page within it.
  final int startSpineIndex;
  final int startPageInSpine;
  final String rawFontFamily;
  final Color accentColor;
  final Color backgroundColor;
  final TextStyle style;
  final Function handlerCallback;
  final VoidCallback onTextTap;

  /// Book-wide index of the page now shown, and the number of pages laid out
  /// so far (it grows while the rest of the book is paginated).
  final Function(int currentPage, int totalPages) onPageFlip;

  /// The page now shown as a reading-order position.
  final Function(int spineIndex, int pageInSpine)? onLocationChanged;

  /// A forward turn was asked for on the book's last page.
  final Function(int lastPage, int totalPages) onLastPage;
  final FlipSettings? flipSettings;

  const PagingWidget({
    super.key,
    required this.spine,
    this.contentParser,
    this.bookId = '',
    this.startSpineIndex = 0,
    this.startPageInSpine = 0,
    this.rawFontFamily = 'Segoe',
    this.accentColor = Colors.indigoAccent,
    this.backgroundColor = Colors.white,
    this.style = const TextStyle(color: Colors.black, fontSize: 30),
    required this.handlerCallback,
    required this.onTextTap,
    required this.onPageFlip,
    this.onLocationChanged,
    required this.onLastPage,
    this.flipSettings,
  });

  @override
  State<PagingWidget> createState() => _PagingWidgetState();
}

class _PagingWidgetState extends State<PagingWidget> {
  /// Pages of each spine item; null until that item has been paginated.
  List<List<String>?> _itemPages = [];

  /// Spine items whose pages are in the reader: `[_first, _last]`. Items are
  /// paginated outward from the one being read and added in batches.
  int _first = 0;
  int _last = -1;

  /// Book page → (spine item, page within it), for the pages in the reader.
  List<(int, int)> _refs = [];

  /// Inputs the current pages were built with. Used to ignore no-op rebuilds
  /// (theme change, tap toggling the header, …).
  List<SpineItem>? _paginatedSpine;
  double? _paginatedFontSize;
  String? _paginatedFontFamily;
  TextScaler _paginatedTextScaler = TextScaler.noScaling;
  Size? _paginatedPageSize;

  /// Bumped on every pass; a pass (or its background extension) that is no
  /// longer the latest stops.
  int _paginateToken = 0;

  /// True only while the first part of a pass runs (spinner on first open).
  bool _isPaginating = false;

  /// Book page shown now.
  int _currentPageIndex = 0;

  /// Page the reader opens on after a rebuild.
  int _pendingStartPage = 0;

  /// Position a pass must open on instead of the current one (TOC jump to a
  /// part of the book that is not paginated yet).
  (int, int)? _jumpAnchor;

  /// Bumped whenever the page list changes. Part of the TurnablePage key: a
  /// different page count re-initialises the engine's page collection, so the
  /// engine is rebuilt (with a NEW controller, see below) on the same page.
  int _revision = 0;
  final _pageKey = GlobalKey();

  /// Book engine of the current pages.
  ///
  /// TurnablePage owns all of its state inside its `PageFlip`, created in
  /// `initState`. A rebuilt TurnablePage therefore needs a brand-new
  /// controller: handing it the previous one would leave the controller
  /// pointing at the destroyed engine, and every `nextPage()` is refused.
  PageFlipController _flipController = PageFlipController();
  Offset? _swipeStart;

  bool get _wholeBookLoaded => _first == 0 && _last == widget.spine.length - 1;

  (int, int) get _location => _refs.isEmpty
      ? (widget.startSpineIndex, widget.startPageInSpine)
      : _refs[_currentPageIndex.clamp(0, _refs.length - 1)];

  void _handlePointerDown(PointerDownEvent event) {
    _swipeStart = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    final start = _swipeStart;
    _swipeStart = null;
    if (start == null || _refs.isEmpty) return;

    final dx = event.position.dx - start.dx;
    // LTR advances with a right-to-left swipe, RTL with a left-to-right one.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = rtl ? dx > 48 : dx < -48;
    // The engine refuses a turn past the last page, so this swipe is the
    // only signal that the reader wants to go on past the end of the book.
    if (forward && _currentPageIndex == _refs.length - 1 && _wholeBookLoaded) {
      widget.onLastPage(_currentPageIndex, _refs.length);
    }
  }

  @override
  void initState() {
    // Pagination needs the size of the reader, which is only known after the
    // first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestPaginate();
    });
    widget.handlerCallback(
      PagingTextHandler(
        paginate: _requestPaginate,
        nextPage: _flipToNextPage,
        previousPage: _flipToPreviousPage,
        currentPage: () => _currentPageIndex,
        goToSpineItem: _goToSpineItem,
        location: () => _location,
        // Earlier/later spine items still being paginated count as pages:
        // they are added before the reader can reach them.
        canGoPrevious: () =>
            _refs.isNotEmpty && (_currentPageIndex > 0 || _first > 0),
        canGoNext: () =>
            _refs.isNotEmpty &&
            (_currentPageIndex < _refs.length - 1 || !_wholeBookLoaded),
      ),
    );
    super.initState();
  }

  @override
  void didUpdateWidget(covariant PagingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.spine, widget.spine)) {
      // A different book: start over with the spinner (build follows).
      _refs = [];
    }
    if (_inputChanged()) _requestPaginateAfterFrame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // System / accessibility text scaling changed → regenerate pages.
    if (_inputChanged()) _requestPaginateAfterFrame();
  }

  /// A pass reports the new location to the parent, which rebuilds it, so it
  /// must not start while the tree is building (font size change, …).
  void _requestPaginateAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestPaginate();
    });
  }

  /// True when the reader would have to paginate again: book, font size,
  /// font family or text scale differ from what the pages were built for.
  bool _inputChanged() {
    if (_paginatedSpine == null) return true;
    if (!identical(widget.spine, _paginatedSpine)) return true;
    if (widget.style.fontSize != _paginatedFontSize) return true;
    if (widget.rawFontFamily != _paginatedFontFamily) return true;
    if (MediaQuery.textScalerOf(context) != _paginatedTextScaler) return true;
    return false;
  }

  @override
  void dispose() {
    // Stop any pass still in flight so it cannot touch the state afterwards.
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

    // `width` / `height` are the page size used by the engine's layout:
    // `calculateBoundsRect` clamps the page to them. Passing the real reader
    // box makes the page fill it exactly; the ratio must match the reader's
    // own, or the page shifts sideways and hit testing misses it.
    final size = _paginatedPageSize;
    return base.copyWith(
      backgroundFillColor: widget.backgroundColor,
      width: size?.width ?? base.width,
      height: size?.height ?? base.height,
    );
  }

  /// Called from external widgets (font size slider, theme/font pickers, …)
  /// and from [didUpdateWidget] / [didChangeDependencies].
  void _requestPaginate() {
    if (!mounted || _isPaginating || !_inputChanged()) return;
    if (_refs.isEmpty) {
      // First pass: show the spinner until the first pages exist.
      setState(_beginPaginate);
    } else {
      // Re-pagination: keep the current pages on screen meanwhile.
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

  void _beginPaginate() {
    _isPaginating = true;
    final token = ++_paginateToken;
    _paginate(token).whenComplete(() {
      if (!mounted || token != _paginateToken || !_isPaginating) return;
      setState(() => _isPaginating = false);
    });
  }

  /// First two words of the page at [location], to find the same text again
  /// after re-pagination.
  String? _needleAt((int, int) location) {
    final pages = location.$1 < _itemPages.length
        ? _itemPages[location.$1]
        : null;
    if (pages == null || location.$2 >= pages.length) return null;
    final words = _plainText(
      pages[location.$2],
    ).split(' ').where((w) => w.isNotEmpty).take(2).toList();
    return words.isEmpty ? null : words.join(' ');
  }

  static String _plainText(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(_shyChar, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  /// Page of [pages] that starts with [needle], searching from [from] onward
  /// first (short needles also appear earlier in the text).
  static int _findPage(List<String> pages, int from, String? needle) {
    from = from.clamp(0, pages.length - 1);
    if (needle != null) {
      for (final i in [
        for (var i = from; i < pages.length; i++) i,
        for (var i = 0; i < from; i++) i,
      ]) {
        if (_plainText(pages[i]).startsWith(needle)) return i;
      }
    }
    return from;
  }

  List<String> _paginateItem(int index, Size pageSize, TextScaler scaler) {
    var html = widget.spine[index].htmlContent;
    if (widget.contentParser != null) {
      html = widget.contentParser!.resolveImagesInHtml(html);
    }
    // Subtract space for headers and margins.
    final paginator = HtmlPaginator(
      pageWidth: pageSize.width - 20.w,
      pageHeight: pageSize.height - 150.h,
      fontSize: _paginatedFontSize ?? 17.0,
      fontFamily: _paginatedFontFamily ?? '',
      fontPackage: 'cosmos_epub',
      textDirection: RTLHelper.getTextDirection(html),
      textScaler: scaler,
    );
    // Soft hyphens go in AFTER pagination, so measurement is clean.
    return paginator.paginate(html).map(_hyphenateHtml).toList();
  }

  Future<void> _paginate(int token) async {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      // Not laid out yet: try again after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && token == _paginateToken) _paginate(token);
      });
      return;
    }
    final spineCount = widget.spine.length;
    if (spineCount == 0) return;

    final pageSize = renderObject.size;
    final scaler = MediaQuery.textScalerOf(context);
    final jump = _jumpAnchor;
    _jumpAnchor = null;
    final (anchor, anchorPage) = jump ?? _location;
    final needle = jump == null ? _needleAt((anchor, anchorPage)) : null;
    final oldCount = anchor < _itemPages.length
        ? _itemPages[anchor]?.length
        : null;

    _paginatedSpine = widget.spine;
    _paginatedFontSize = widget.style.fontSize ?? 17.0;
    _paginatedFontFamily = widget.rawFontFamily;
    _paginatedTextScaler = scaler;
    _paginatedPageSize = pageSize;

    final spineIndex = anchor.clamp(0, spineCount - 1);
    final items = List<List<String>?>.filled(spineCount, null);
    final pages = items[spineIndex] = _paginateItem(
      spineIndex,
      pageSize,
      scaler,
    );
    // Same text as before, or the same relative position in the item.
    var page = needle == null && oldCount != null && oldCount > 0
        ? anchorPage * pages.length ~/ oldCount
        : anchorPage;
    page = _findPage(pages, page, needle);

    if (!mounted || token != _paginateToken) return;
    setState(() {
      _itemPages = items;
      _first = _last = spineIndex;
      _applyRange((spineIndex, page));
      _isPaginating = false;
    });
    _reportLocation();
    await _paginateRest(token, pageSize, scaler);
  }

  /// Paginates the other spine items one per frame — forward first, since
  /// that is where the reader is going — and adds them to the reader in
  /// batches, only while no page is being turned.
  Future<void> _paginateRest(
    int token,
    Size pageSize,
    TextScaler scaler,
  ) async {
    final spineCount = widget.spine.length;
    var loadedFirst = _first;
    var loadedLast = _last;
    final sinceApply = Stopwatch()..start();
    final order = [
      for (var i = _last + 1; i < spineCount; i++) i,
      for (var i = _first - 1; i >= 0; i--) i,
    ];
    for (final (n, index) in order.indexed) {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted || token != _paginateToken) return;
      _itemPages[index] = _paginateItem(index, pageSize, scaler);
      if (index > loadedLast) loadedLast = index;
      if (index < loadedFirst) loadedFirst = index;

      final done = n == order.length - 1;
      final nearEdge =
          _currentPageIndex <= 1 || _currentPageIndex >= _refs.length - 2;
      if (!done && !nearEdge && sinceApply.elapsed.inSeconds < 2) continue;

      // Rebuilding the engine mid-turn would cut the animation off.
      while (!_isIdle) {
        await SchedulerBinding.instance.endOfFrame;
        if (!mounted || token != _paginateToken) return;
      }
      setState(() {
        final location = _location;
        _first = loadedFirst;
        _last = loadedLast;
        _applyRange(location);
      });
      _reportLocation();
      sinceApply.reset();
    }
  }

  bool get _isIdle {
    if (_swipeStart != null) return false;
    final state = _flipController.pageFlipInstance?.getState();
    return state == null || state.value == 'read';
  }

  /// Lays out the pages of spine items `[_first, _last]` and opens the
  /// reader on [location]. Call inside [setState].
  void _applyRange((int, int) location) {
    _refs = [
      for (var s = _first; s <= _last; s++)
        for (var p = 0; p < _itemPages[s]!.length; p++) (s, p),
    ];
    final start = _refs.indexWhere((r) => r.$1 == location.$1);
    final count = _itemPages[location.$1]?.length ?? 1;
    _currentPageIndex = _pendingStartPage = start < 0
        ? 0
        : start + location.$2.clamp(0, count - 1);
    _revision++;
    _flipController = PageFlipController();
  }

  void _reportLocation() {
    if (_refs.isEmpty) return;
    widget.onPageFlip(_currentPageIndex, _refs.length);
    final (spineIndex, page) = _refs[_currentPageIndex];
    widget.onLocationChanged?.call(spineIndex, page);
  }

  /// Animated page turn used by the reader's buttons.
  bool _flipToNextPage() {
    if (_refs.isEmpty) return false;
    if (_currentPageIndex < _refs.length - 1) {
      return _flipController.pageFlipInstance != null &&
          _flipController.nextPage();
    }
    if (_wholeBookLoaded) {
      widget.onLastPage(_currentPageIndex, _refs.length);
    }
    return false;
  }

  /// Animated backward page turn (see [_flipToNextPage]).
  bool _flipToPreviousPage() {
    if (_refs.isEmpty || _currentPageIndex <= 0) return false;
    return _flipController.pageFlipInstance != null &&
        _flipController.previousPage();
  }

  void _goToSpineItem(int spineIndex) {
    if (spineIndex < 0 || spineIndex >= widget.spine.length) return;
    final target = _refs.indexWhere((r) => r.$1 == spineIndex);
    if (target < 0) {
      // Not paginated yet: open a new pass there.
      _jumpAnchor = (spineIndex, 0);
      _isPaginating = false;
      _beginPaginate();
      return;
    }
    if (target == _currentPageIndex) return;
    // One animated turn that lands on the target page.
    final turned =
        _flipController.pageFlipInstance != null &&
        _flipController.goToPage(target);
    if (!turned) {
      // A turn is already running: jump without animation.
      setState(() {
        _currentPageIndex = _pendingStartPage = target;
        _revision++;
        _flipController = PageFlipController();
      });
      _reportLocation();
    }
  }

  void _onPageChanged(int leftIndex, int rightIndex) {
    if (_refs.isEmpty) return;
    // `leftIndex` is the page just landed on; `rightIndex` its neighbour.
    final index =
        _flipController.pageFlipInstance?.getCurrentPageIndex() ?? leftIndex;
    if (index < 0 || index >= _refs.length) return;
    _currentPageIndex = index;
    _reportLocation();
  }

  Widget _pageWidget(int index) {
    final (spineIndex, page) = _refs[index];
    final html = _itemPages[spineIndex]![page];
    return _HighlightablePage(
      // Key by content+style so a regenerated page never reuses the old
      // (differently sized) layout of a previous pagination pass.
      key: ValueKey(
        '${spineIndex}_${page}_${_paginatedFontSize}_${_paginatedFontFamily}_'
        '${html.hashCode}',
      ),
      pageHtml: html,
      style: widget.style,
      rawFontFamily: _paginatedFontFamily ?? widget.rawFontFamily,
      bookId: widget.bookId,
      chapterIndex: spineIndex,
      accentColor: widget.accentColor,
      backgroundColor: widget.backgroundColor,
      onTextTap: widget.onTextTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spine.isEmpty) {
      return const Center(child: Text('No content'));
    }
    // Until the first pages exist the spinner is shown; afterwards the pages
    // stay on screen through every further pass.
    if (_refs.isEmpty) {
      return Center(
        child: CupertinoActivityIndicator(
          color: Theme.of(context).primaryColor,
          radius: 30.r,
        ),
      );
    }

    return SizedBox.expand(
      key: _pageKey,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: (_) => _swipeStart = null,
        child: TurnablePage(
          key: ValueKey('reader_$_revision'),
          controller: _flipController,
          pageCount: _refs.length,
          pageViewMode: PageViewMode.single,
          pagesBoundaryIsEnabled: false,
          autoResponseSize: false,
          aspectRatio:
              _paginatedPageSize != null && _paginatedPageSize!.height > 0
              ? _paginatedPageSize!.width / _paginatedPageSize!.height
              : null,
          settings: _resolvedSettings().copyWith(
            startPage: _pendingStartPage.clamp(0, _refs.length - 1),
          ),
          // Theme/colour changes keep the page list but change how pages look:
          // the engine caches built pages, so tell it to build them again.
          pageRevision: Object.hash(
            widget.style,
            widget.backgroundColor,
            widget.accentColor,
          ),
          onPageChanged: _onPageChanged,
          builder: (context, index, constraints) => _pageWidget(index),
        ),
      ),
    );
  }
}

class _HighlightablePage extends StatefulWidget {
  final String pageHtml;
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
