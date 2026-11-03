## 2.0.0

The reader is rebuilt around the EPUB reading order and a new page-turn
engine. The whole book is one continuous run of pages, so every turn folds
like a real page — cover, title page and chapter boundaries included.

### Breaking changes
* **Reading order is the spine.** Every linear spine document is shown, in
  order, including ones the table of contents does not list (notices, title
  pages). The table of contents is navigation only.
* **Saved progress has a new meaning.** `BookProgressModel.currentChapterIndex`
  is the spine index and `currentPageIndex` the page within that spine item.
  Progress and highlights saved by 1.x do not line up with 2.0 and are best
  cleared (`CosmosEpub.deleteAllBooksProgress()`,
  `CosmosEpub.removeAllHighlights(bookId)`).
* **`onPageFlip(currentPage, totalPages)` is book-wide.** `totalPages` grows
  while the rest of the book is paginated in the background.
* **`onLastPage` fires when the reader tries to turn past the last page of
  the book**, once per attempt — no longer at the end of each chapter.
* **`starterChapter` is a table-of-contents entry index**; `-1` (default)
  resumes the saved position.
* **The header arrows turn one page** (crossing chapters). Chapter navigation
  is in the table of contents and in `ShowEpubState.nextChapter()` /
  `prevChapter()`; `goToBeginning()` is new.
* **Models and widgets:** `LocalChapterModel` and
  `EpubContentParser.flatChapters` are replaced by `SpineItem` /
  `EpubContentParser.spine` and `TocEntry` / `EpubContentParser.toc`.
  `PagingWidget` takes `spine`, `startSpineIndex`, `startPageInSpine` and
  `onLocationChanged`; `htmlContent`, `chapterIndex`, `chapterTitle`,
  `totalChapters`, `starterPageIndex`, `onFirstPageBack` and `lastWidget` are
  gone. `PagingTextHandler` gains `goToSpineItem`, `location`,
  `canGoPrevious` and `canGoNext`.
* **Text selection is disabled** so pages can be dragged to turn them.
  Existing highlights are still drawn; creating new ones is not possible yet.
* The bundled `PageFlip` widgets are removed in favour of
  [`turnable_page_plus`](https://pub.dev/packages/turnable_page_plus) ^1.0.4.

### New
* 3D page-turn animation (drag, buttons, table-of-contents jumps).
* A cover declared only as an image (EPUB 3 `cover-image`, EPUB 2
  `<meta name="cover">`) is shown as the first page.
* Paragraphs taller than a page continue on the next page instead of being
  cut off; a word split at the page break keeps its hyphen.

### Fixes
* Text no longer hides behind the app bar or the bottom bar; pages are measured
  and drawn with the same margins, and showing / hiding the bars no longer
  resizes the page.
* Pagination measures text exactly as it is drawn (hyphens resolved, system
  text scale applied), so large text no longer overflows the page.
* Changing the font size keeps the reader on the same text.
* Changing the theme recolours pages that were already built.
* No more `setState() or markNeedsBuild() called during build` when changing
  the font size.
* Page-button presses during the first layout or a background update are no
  longer lost.
* The table of contents no longer duplicates text pointing into the same file,
  and entries for missing files are skipped.
* Debug logging removed from the parser and paginator (it flooded the console
  and repeated work on every page).

## 1.0.1

* Upgraded to Flutter 3.44.8 (Dart SDK >=3.12.2); minimum Flutter/Dart versions raised accordingly.
* Updated dependencies: `screen_brightness` ^2.1.11, `fluttertoast` ^10.0.2, `flutter_lints` ^6.0.0, `build_runner` ^2.15.1.
* Removed obsolete Android Gradle files.

## 1.0.0

### Major Rewrite
This release is a complete rewrite of the core rendering engine and a major feature upgrade.

### New Features
* **Text Highlighting**: Select text and highlight with 6 colors. Highlights persist across sessions. Re-highlight to change color. Copy and Select All support.
* **Syllable-Aware Hyphenation**: Built-in hyphenation engine that breaks words at syllable boundaries for better justified text. Respects Uzbek digraphs (ch, sh, g', o'). Visible hyphen "-" at line breaks via two-pass TextPainter resolution.
* **Infinite Nested Chapters**: Recursive chapter tree with unlimited nesting depth. Proper TOC indentation by depth level. Section title pages auto-generated for TOC groupings.
* **Image Support**: EPUB images extracted and rendered inline via base64 data URIs. Supports PNG, JPEG, GIF, SVG, WebP.
* **Robust EPUB Parsing**: 3-tier chapter resolution: NCX NavMap → epubx Chapters → Spine order. Handles malformed EPUBs, nested TOCs, missing content files. XHTML compatibility fixes for HTML5 parser.

### Rendering Engine
* **Native Text Rendering**: Replaced flutter_html with native `Text.rich`/`SelectableText.rich` for full control over text layout, selection, and hyphenation.
* **HTML to TextSpan**: Custom `HtmlTextBuilder` converts HTML to Flutter widget tree preserving bold, italic, underline, strikethrough, headings, lists, blockquotes, code blocks, images.
* **Accurate Pagination**: TextPainter-based page splitting with real font metrics instead of height estimation. Pages are consistent in height.

### Improvements
* **Selection Color**: Visible blue selection highlight with configurable accent color.
* **Font Selection**: Fixed font loading for package fonts. Fonts apply correctly across the reader.
* **Chapter Navigation**: Proper swipe-to-advance with direction-aware callbacks. 1-page chapters advance immediately. Swipe counters reset between chapters.
* **Page Flip Animation**: `didUpdateWidget` properly resets animation state on chapter change. Cached page images cleared after highlighting.
* **TOC Ornament**: Decorative SVG divider in Table of Contents replacing plain text title.
* **Background Color**: Separated from TextStyle to prevent covering selection overlay.

### Breaking Changes
* Minimum Flutter version raised to 3.10.0
* Replaced `isar` with `isar_community` (^3.3.2)
* Removed `flutter_html_reborn` dependency (replaced with native rendering)
* `HighlightModel` added to public API
* `getBookHighlights`, `removeHighlight`, `removeAllHighlights` added to `CosmosEpub`

### Bug Fixes
* Fixed chapters not showing (XHTML `<title/>` breaking HTML5 parser)
* Fixed blank pages on startup (`ScreenUtil.ensureScreenSize` deadlock)
* Fixed Isar version mismatch between runtime and native libs
* Fixed font not changing (double package prefix on fontFamily)
* Fixed selection invisible (TextStyle.backgroundColor covering overlay)
* Fixed highlight rendering on wrong word occurrence
* Fixed page flip breaking after chapter change
* Fixed 1-page chapter navigation (forward/backward)

---

## 0.0.3

* **RTL Language Support**: Added comprehensive support for Right-to-Left languages
* **Automatic Text Direction Detection**: Library automatically detects and handles RTL content
* **RTL-Aware Navigation**: Navigation buttons automatically reverse for RTL languages
* **Multi-Language Support**: Added support for Arabic, Persian, Hebrew, Urdu, and other RTL languages
* **Smart Text Alignment**: Proper text alignment based on detected language direction
* **Chapter List RTL Support**: Table of contents now supports RTL layout with proper indentation
* **Mixed Content Handling**: Seamlessly handles documents with both LTR and RTL text
* **Unicode Range Detection**: Advanced RTL character detection using Unicode ranges
* **Bidirectional Text Support**: Improved rendering for mixed directional content

## 0.0.2

* Build error fix
* Add `CosmosEpub.openURLBook` & `CosmosEpub.openFileBook` methods

## 0.0.1

* Initial release of cosmos_epub package
