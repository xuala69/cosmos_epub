# Graph Report - cosmos_epub  (2026-11-02)

## Corpus Check
- 68 files · ~91,230 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 124 file(s) not represented in the graph (top: (none) 27, .cmake 16, .ttf 14)

## Summary
- 910 nodes · 1132 edges · 67 communities (50 shown, 17 thin omitted)
- Extraction: 98% EXTRACTED · 1% INFERRED · 1% AMBIGUOUS · INFERRED: 15 edges (avg confidence: 0.75)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Pagination Core
- Epub Helpers & Chapters
- CosmosEpub Entry API
- Context Extensions
- Progress Model Queries
- Package Dependencies
- Progress Model Schema
- Rendering & Pagination Design
- HTML Paginator
- HTML Text Builder
- Soft Hyphen Text
- Highlight Model
- Example App Config
- iOS App Delegate
- Extension Guides
- Generated Assets
- Example Main
- Isar Service
- Forward Nav Bugfix Spec
- Turnable Page Integration Spec
- Pagination Refresh Tests
- Chapter Functions
- Nav Probe Test
- iOS Plugin Registrant
- Repaginate Turn Test
- RTL Helpers
- ShowEpub Test
- Multi Turn Test
- Query Builders
- Page Flip Animation
- Flip Animation Test
- Example README
- RTL Example & Widget Test
- Pagination Features
- Android Plugin Registrant
- Circle Button
- Custom Toast
- Fake Progress Tests
- Chapter Navigation & RTL
- Example Lint Config
- Example Widgets
- Highlight Toolbar
- Paging Widget
- Chapter Model
- Book Source Guide
- CosmosEpub Class
- Theme Colors
- System Architecture
- Lint Config
- Font Constants
- Debug Logging Guide
- Known Issues
- Progress Collection
- Turnable Package Notes
- Android MainActivity (example)
- Android MainActivity
- TOC Navigation
- ShowEpub State
- Community 59
- Community 63
- Community 64
- Community 65
- Community 66

## God Nodes (most connected - your core abstractions)
1. `dependencies` - 15 edges
2. `Version 1.0.0 Major Rewrite` - 14 edges
3. `BookProgressSingleton` - 8 edges
4. `CosmosEpub Package` - 8 edges
5. `Page Forward Navigation Bugfix Design` - 6 edges
6. `CosmosEpub Class` - 6 edges
7. `PagingWidget` - 6 edges
8. `HighlightStorage` - 6 edges
9. `Summary of Changes: Page Turning Fix and Debug Logging` - 6 edges
10. `Debug Log Guide for Cosmos EPUB` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Ornament SVG (decorative TOC divider)` --references--> `Module Structure`  [AMBIGUOUS]
  assets/ornament.svg → README.md
- `FlutterToast_example Project` --conceptually_related_to--> `CosmosEpub Package`  [AMBIGUOUS]
  example/README.md → README.md
- `Ornament SVG (decorative TOC divider)` --conceptually_related_to--> `ChaptersList`  [INFERRED]
  assets/ornament.svg → README.md
- `_FakeProgress` --implements--> `BookProgressSingleton`  [EXTRACTED]
  test/flip_animation_test.dart → lib/Helpers/progress_singleton.dart
- `_FakeProgress` --implements--> `BookProgressSingleton`  [EXTRACTED]
  test/multi_turn_test.dart → lib/Helpers/progress_singleton.dart

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Forward navigation fix** — _kiro_specs_page_forward_navigation_bugfix_forward_button_defect, _kiro_specs_page_forward_navigation_bugfix_forward_swipe_defect, _kiro_specs_page_forward_navigation_design_forward_button_logic, _kiro_specs_page_forward_navigation_design_inputchanged, _kiro_specs_page_forward_navigation_design_mid_gesture_guard [INFERRED 0.75]
- **TurnablePage migration components** — _kiro_specs_turnable_page_plus_integration_design_pagingwidget, _kiro_specs_turnable_page_plus_integration_design_flipsettings, _kiro_specs_turnable_page_plus_integration_design_pagecontroller, _kiro_specs_turnable_page_plus_integration_design_onpagechanged, _kiro_specs_turnable_page_plus_integration_design_delete_pageflip_dir [INFERRED 0.85]
- **Chapter boundary handling** — _kiro_specs_turnable_page_plus_integration_requirements_chapter_boundary_callbacks, _kiro_specs_turnable_page_plus_integration_design_onpagechanged, _kiro_specs_turnable_page_plus_integration_tasks_simplify_double_swipe [INFERRED 0.75]
- **EPUB to Flip Render Pipeline** — readme_epub_content_parser, readme_html_paginator, readme_html_text_builder, readme_soft_hyphen_paragraph, readme_turnable_page [EXTRACTED 1.00]
- **Reader Persistence Stores** — readme_isar_service, readme_book_progress_singleton, readme_highlight_storage, readme_get_storage_keys [INFERRED 0.85]
- **Page Flip Gesture Stack** — readme_page_flip_animation, readme_flip_settings, readme_turnable_page, readme_page_0_swipe_issue [INFERRED 0.75]
- **Page Flip Fix Chain** — changes_summary_pagination_retry, debug_log_guide_boundary_fix, changelog_page_flip_animation [INFERRED 0.75]

## Communities (67 total, 17 thin omitted)

### Community 0 - "Pagination Core"
Cohesion: 0.02
Nodes (75): 1, accentColor, backgroundColor, _beginPaginate, bookId, buf, build, _buildContent (+67 more)

### Community 1 - "Epub Helpers & Chapters"
Cohesion: 0.03
Nodes (49): accentColor, backColor, backPress, bookId, bookProgress, bookTitle, brightnessLevel, build (+41 more)

### Community 2 - "CosmosEpub Entry API"
Cohesion: 0.04
Nodes (32): _checkInitialization, clearThemeCache, CosmosEpub, deleteAllBooksProgress, deleteBookProgress, getBookHighlights, getBookProgress, initialize (+24 more)

### Community 3 - "Context Extensions"
Cohesion: 0.05
Nodes (26): ContextExtensionss, devicePixelRatio, height, heightTransformer, iconColor, isDarkMode, isLandscape, isLargeTablet (+18 more)

### Community 4 - "Progress Model Queries"
Cohesion: 0.05
Nodes (36): anyLocalId, bookIdBetween, bookIdEqualTo, bookIdGreaterThan, bookIdIsEmpty, bookIdIsNotEmpty, bookIdIsNotNull, bookIdStartsWith (+28 more)

### Community 5 - "Package Dependencies"
Cohesion: 0.05
Nodes (36): dependencies, epubx, fading_edge_scrollview, flutter, flutter_screenutil, flutter_svg, fluttertoast, get_storage (+28 more)

### Community 6 - "Progress Model Schema"
Cohesion: 0.06
Nodes (29): bookId, currentChapterIndex, currentPageIndex, localId, bookIdContains, bookIdEndsWith, bookIdIsNull, bookIdLessThan (+21 more)

### Community 7 - "Rendering & Pagination Design"
Cohesion: 0.07
Nodes (32): TextPainter-Based Pagination, 3-Tier Chapter Resolution, flutter_html_reborn Removal, HighlightModel Public API, HtmlTextBuilder, Inline Image Support, isar_community Replacement, Native Text Rendering (+24 more)

### Community 8 - "HTML Paginator"
Cohesion: 0.06
Nodes (29): _applyInlineTag, _baseStyle, _buildSpans, _collectBlocks, _countImagesInBlock, element, _estimateBlockWithImages, _estimateImageHeight (+21 more)

### Community 9 - "HTML Text Builder"
Cohesion: 0.06
Nodes (24): accentColor, _addImage, _applyInlineTag, _baseStyle, build, _buildSpans, _collectWidgets, _fixXhtml (+16 more)

### Community 10 - "Soft Hyphen Text"
Cohesion: 0.07
Nodes (21): _applyHighlights, build, _Counter, _findBreakOffsets, _flattenSpan, highlights, onTap, paragraphKey (+13 more)

### Community 11 - "Highlight Model"
Cohesion: 0.07
Nodes (23): addOrUpdate, bookId, chapterIndex, colorValue, endIndex, fromJson, generateId, getBookHighlights (+15 more)

### Community 12 - "Example App Config"
Cohesion: 0.10
Nodes (20): path, dependencies, cosmos_epub, cupertino_icons, flutter, flutter_screenutil, description, dev_dependencies (+12 more)

### Community 13 - "iOS App Delegate"
Cohesion: 0.11
Nodes (6): AppDelegate, SceneDelegate, RunnerTests, Flutter, UIKit, XCTest

### Community 14 - "Extension Guides"
Cohesion: 0.11
Nodes (20): Bookmarks Extension Guide, Text-to-Speech Extension Guide, Underline Highlight Extension Guide, BookProgressModel, BookProgressSingleton, CircleButton, Embedded Font System (14 fonts), GetStorage Keys (constants.dart) (+12 more)

### Community 15 - "Generated Assets"
Cohesion: 0.11
Nodes (12): AssetGenImage, _assetName, Assets, book, bookNested, custom, flavors, image (+4 more)

### Community 16 - "Example Main"
Cohesion: 0.13
Nodes (13): build, createState, deleteAllBooksProgress, deleteBookProgress, initialize, lateFuture, main, MyHomePage (+5 more)

### Community 17 - "Isar Service"
Cohesion: 0.14
Nodes (10): buildIsarService, isar, IsarService, deleteAllBooksProgress, deleteBookProgress, getBookProgress, isar, setCurrentChapterIndex (+2 more)

### Community 18 - "Forward Nav Bugfix Spec"
Cohesion: 0.21
Nodes (15): Page Forward Navigation Bugfix Requirements, Forward button advances backward, Forward swipe does not complete, Preservation requirements (back nav, TOC, font/theme, restore, RTL), Page Forward Navigation Bugfix Design, ShowEpub forward IconButton logic, _inputChanged() size guard, Mid-gesture re-pagination guard (_isFlipping) (+7 more)

### Community 19 - "Turnable Page Integration Spec"
Cohesion: 0.20
Nodes (15): Turnable Page Plus Integration Design, Delete lib/PageFlip directory, FlipSettings resolution, _onPageChanged callback, PageFlipController, PagingWidget, Turnable Page Plus Integration Requirements, Chapter boundary callbacks (onLastPage, onFirstPageBack) (+7 more)

### Community 20 - "Pagination Refresh Tests"
Cohesion: 0.14
Nodes (12): PagingTextHandler, buildPhaseExceptions, getBookProgress, handler, _html, i, main, noSuchMethod (+4 more)

### Community 21 - "Chapter Functions"
Cohesion: 0.15
Nodes (6): accentColor, bookId, build, chapterListTitle, chapters, leadingIcon

### Community 22 - "Nav Probe Test"
Cohesion: 0.15
Nodes (12): bookFinder, getBookProgress, _host, _html, i, main, noSuchMethod, page (+4 more)

### Community 24 - "Repaginate Turn Test"
Cohesion: 0.18
Nodes (9): chapter, _html, i, main, noSuchMethod, page, _pumpFrames, setCurrentChapterIndex (+1 more)

### Community 25 - "RTL Helpers"
Cohesion: 0.20
Nodes (7): containsRTLCharacters, getJustifiedAlign, getTextAlign, getTextDirection, RTLHelper, rtlLanguages, rtlUnicodeRanges

### Community 26 - "ShowEpub Test"
Cohesion: 0.20
Nodes (7): chapter, getBookProgress, main, noSuchMethod, page, setCurrentChapterIndex, setCurrentPageIndex

### Community 27 - "Multi Turn Test"
Cohesion: 0.20
Nodes (8): getBookProgress, _html, i, main, noSuchMethod, page, setCurrentChapterIndex, setCurrentPageIndex

### Community 28 - "Query Builders"
Cohesion: 0.20
Nodes (9): BookProgressModelQueryFilter, BookProgressModelQueryLinks, BookProgressModelQueryObject, BookProgressModelQueryProperty, BookProgressModelQuerySortBy, BookProgressModelQuerySortThenBy, BookProgressModelQueryWhere, BookProgressModelQueryWhereDistinct (+1 more)

### Community 29 - "Page Flip Animation"
Cohesion: 0.31
Nodes (9): FlipSettings, _HighlightablePage, Known Issue: Swipe Fails on Page 0, Page Flip Animation, PagingTextHandler, PagingWidget, _TapDetector, TurnablePage (turnable_page_plus) (+1 more)

### Community 30 - "Flip Animation Test"
Cohesion: 0.22
Nodes (7): getBookProgress, _html, i, main, noSuchMethod, setCurrentChapterIndex, setCurrentPageIndex

### Community 31 - "Example README"
Cohesion: 0.25
Nodes (8): FlutterToast_example Project, Example Getting Started Section, API Reference, Mamasodikov (Author), Core Functionalities, CosmosEpub Package, BSD-3 License, Module Structure

### Community 33 - "Pagination Features"
Cohesion: 0.29
Nodes (8): HtmlPaginator, HtmlTextBuilder, Syllable-aware Hyphenation, Image Support, Lazy Chapter Loading, Pagination Caching, SoftHyphenParagraph, Uzbek Digraph Hyphenation

### Community 35 - "Circle Button"
Cohesion: 0.29
Nodes (3): accentColor, build, id

### Community 36 - "Custom Toast"
Cohesion: 0.29
Nodes (4): CustomToast, showToast, snack, snackBar

### Community 37 - "Fake Progress Tests"
Cohesion: 0.29
Nodes (7): BookProgressSingleton, _FakeProgress, _FakeProgress, _FakeProgress, _FakeProgress, _FakeProgress, _FakeProgress

### Community 38 - "Chapter Navigation & RTL"
Cohesion: 0.33
Nodes (6): Ornament SVG (decorative TOC divider), Chapter Navigation, ChaptersList, LocalChapterModel, RTLHelper, RTL Language Support

### Community 39 - "Example Lint Config"
Cohesion: 0.33
Nodes (5): analyzer, exclude, include, linter, rules

### Community 40 - "Example Widgets"
Cohesion: 0.33
Nodes (5): MyApp, RTLEpubExample, CircleButton, ChaptersList, SoftHyphenParagraph

### Community 41 - "Highlight Toolbar"
Cohesion: 0.33
Nodes (4): build, highlightColors, HighlightToolbar, onDismiss

### Community 42 - "Paging Widget"
Cohesion: 0.40
Nodes (4): _HighlightablePage, _HighlightablePageState, PagingWidget, _PagingWidgetState

### Community 43 - "Chapter Model"
Cohesion: 0.33
Nodes (5): chapter, depth, htmlContent, isSectionTitle, LocalChapterModel

### Community 44 - "Book Source Guide"
Cohesion: 0.33
Nodes (6): Adding New Book Source Guide, Unique bookId Requirement, EpubContentParser, epubx Dependency, CosmosEpub.openAssetBook, Three-tier Chapter Resolution

### Community 45 - "CosmosEpub Class"
Cohesion: 0.33
Nodes (6): clearThemeCache, CosmosEpub Class, CosmosEpub.initialize, CosmosEpub.openFileBook, CosmosEpub.openLocalBook, CosmosEpub.openURLBook

### Community 46 - "Theme Colors"
Cohesion: 0.40
Nodes (3): cBluishColor, cPinkishColor, cVioletishColor

### Community 47 - "System Architecture"
Cohesion: 0.40
Nodes (5): System Architecture, Brightness Control, CustomToast, screen_brightness Package, ShowEpub Widget

### Community 48 - "Lint Config"
Cohesion: 0.50
Nodes (3): analyzer, exclude, include

### Community 50 - "Font Constants"
Cohesion: 0.50
Nodes (3): libFont, libFontSize, libTheme

### Community 51 - "Debug Logging Guide"
Cohesion: 0.50
Nodes (4): DEBUG_LOG_GUIDE.md, Debug Logging Tags, Troubleshooting and Debugging, Isar and GetStorage Inspection Snippets

### Community 52 - "Known Issues"
Cohesion: 0.50
Nodes (4): Known Issue: Too Few Pages Generated, flutter_screenutil Dependency, Known Issues and Workarounds, Responsive Design

### Community 54 - "Turnable Package Notes"
Cohesion: 0.67
Nodes (3): TurnablePage Aspect Ratio, hitTestChildren Right-Slot Matching, turnable_page_plus Package

## Ambiguous Edges - Review These
- `CosmosEpub Package` → `FlutterToast_example Project`  [AMBIGUOUS]
  example/README.md · relation: conceptually_related_to
- `Module Structure` → `Ornament SVG (decorative TOC divider)`  [AMBIGUOUS]
  assets/ornament.svg · relation: references
- `Troubleshooting and Debugging` → `Three-tier Chapter Resolution`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `ShowEpub Widget` → `CustomToast`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `FlipSettings` → `Embedded Font System (14 fonts)`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `Summary of Changes: Page Turning Fix and Debug Logging` → `Debug Log Guide for Cosmos EPUB`  [AMBIGUOUS]
  DEBUG_LOG_GUIDE.md · relation: conceptually_related_to

## Knowledge Gaps
- **461 isolated node(s):** `+registerWithRegistry`, `XCTest`, `Assets`, `AssetGenImage`, `book` (+456 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 592 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Debug Log Guide for Cosmos EPUB` connect `Rendering & Pagination Design` to `Nav Probe Test`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **What connects `+registerWithRegistry`, `XCTest`, `Assets` to the rest of the system?**
  _461 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Pagination Core` be split into smaller, more focused modules?**
  _Cohesion score 0.023809523809523808 - nodes in this community are weakly interconnected._
- **Should `Epub Helpers & Chapters` be split into smaller, more focused modules?**
  _Cohesion score 0.03225806451612903 - nodes in this community are weakly interconnected._

### Low-confidence Hints
_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._

- **What is the exact relationship between `CosmosEpub Package` and `FlutterToast_example Project`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Module Structure` and `Ornament SVG (decorative TOC divider)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Troubleshooting and Debugging` and `Three-tier Chapter Resolution`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._