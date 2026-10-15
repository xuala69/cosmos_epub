# Requirements Document

## Introduction

This feature replaces the cosmos_epub page-flip engine — `PageFlipWidget`, `PageFlipBuilder`, and `PageFlipEffect` — with the `turnable_page_plus` package sourced from a GitLab git dependency. The goal is to eliminate the screenshot-based flip pipeline (100 ms capture delay, CPU column loop, global image cache) and adopt a geometrically accurate 3D fold engine with inertia, easing, and a clean programmatic navigation API. All public-facing APIs, all chapter navigation callbacks, RTL text direction support, per-page theming, and text highlighting remain unchanged.

## Glossary

- **TurnablePage**: The main widget provided by `turnable_page_plus` that renders a page-turn animation using angle-based fold mathematics.
- **PageFlipController**: The programmatic navigation controller supplied by `turnable_page_plus` exposing `nextPage()`, `previousPage()`, and `goToPage(int)`.
- **FlipSettings**: The configuration object accepted by `TurnablePage` that controls inertia, easing, corner trigger size, shadow, and boundary decorations.
- **PagingWidget**: The existing `StatefulWidget` in `lib/Helpers/pagination.dart` that owns the flip widget, drives pagination, and forwards chapter boundary callbacks upward. Its constructor signature is frozen.
- **ShowEpub**: The existing top-level reader widget in `lib/show_epub.dart`. Its constructor signature is frozen.
- **CosmosEpub**: The static public API class in `lib/cosmos_epub.dart`. All method signatures are frozen.
- **Screenshot_Pipeline**: The legacy mechanism comprising `imageData` global map, `_captureImage`, `RepaintBoundary.toImage()`, and `flip_cache.imageData.clear()` calls.
- **Chapter_Boundary_Callback**: The `onLastPage` and `onFirstPageBack` callbacks on `PagingWidget` that signal when the reader reaches the last or first page of a chapter.
- **Double_Swipe_Workaround**: The `lastSwipe` / `prevSwipe` counter logic in `ShowEpub` that requires two forward swipes past the final page before advancing to the next chapter.
- **RTL_Helper**: The `RTLHelper.getTextDirection()` utility used to detect right-to-left content and wrap pages in `Directionality`.

## Requirements

### Requirement 1: Add turnable_page_plus as a git dependency

**User Story:** As a developer, I want `turnable_page_plus` declared as a git dependency in `pubspec.yaml`, so that the package is fetched from the canonical GitLab repository without introducing any pub.dev dependencies.

#### Acceptance Criteria

1. THE `pubspec.yaml` SHALL declare `turnable_page_plus` under `dependencies` using a `git` block pointing to `https://gitlab.com/wegen-technologies/wegen-website/e-book/turnable-page-plus.git`.
2. THE `pubspec.yaml` SHALL NOT introduce any additional pub.dev package dependencies beyond those already present.
3. WHEN `flutter pub get` is executed, THE build system SHALL resolve the dependency without error.

---

### Requirement 2: Implement TurnablePage as the flip widget

**User Story:** As a reader, I want the page-turn animation powered by `TurnablePage`, so that page flips are rendered using geometrically accurate 3D folding rather than a CPU column-by-column loop.

#### Acceptance Criteria

1. THE `PagingWidget` SHALL instantiate `TurnablePage` as its flip widget in place of `PageFlipWidget`.
2. WHEN `TurnablePage` is constructed, THE `PagingWidget` SHALL pass `pageCount` equal to the number of paginated page widgets and a `builder` callback that returns the corresponding page widget for each index.
3. WHEN `TurnablePage` is constructed, THE `PagingWidget` SHALL pass a `FlipSettings` instance derived from the `flipSettings` parameter (see Requirement 6).
4. WHEN `TurnablePage` is constructed, THE `PagingWidget` SHALL pass `pagesBoundaryIsEnabled: false` inside `FlipSettings` so that no vintage book-edge frame is rendered.
5. THE `PagingWidget` SHALL NOT pass any `lastPage` widget to `TurnablePage` via a dedicated child slot; chapter boundary detection SHALL be handled via `PageFlipController` callbacks instead.

---

### Requirement 3: Wire PageFlipController for programmatic navigation

**User Story:** As a developer, I want `PageFlipController` to replace the `GlobalKey<PageFlipWidgetState>` navigation mechanism, so that programmatic page jumps on chapter load are handled through the supported controller API.

#### Acceptance Criteria

1. THE `PagingWidget` SHALL create a `PageFlipController` instance and pass it to `TurnablePage`.
2. WHEN a chapter is re-loaded and a `starterPageIndex` is provided, THE `PagingWidget` SHALL call `PageFlipController.goToPage(starterPageIndex)` to restore the saved reading position.
3. WHEN pagination is re-computed (font size change, theme change, orientation change), THE `PagingWidget` SHALL call `PageFlipController.goToPage(0)` to reset to the first page of the new layout.
4. THE `_pageController` field in `PagingWidget` SHALL be of type `PageFlipController` and SHALL NOT use a `GlobalKey<PageFlipWidgetState>`.
5. WHEN the `PagingWidget` is disposed, THE `PagingWidget` SHALL dispose the `PageFlipController`.

---

### Requirement 4: Remove the screenshot pipeline

**User Story:** As a developer, I want the screenshot-based image capture removed, so that the 100 ms capture delay, the global mutable `imageData` map, and the `flip_cache.imageData.clear()` hack in highlight updates are eliminated.

#### Acceptance Criteria

1. THE `lib/PageFlip/builders/builder.dart` file SHALL be deleted as part of this change.
2. THE `lib/PageFlip/effects/flip_effect.dart` file SHALL be deleted.
3. THE `lib/PageFlip/builders/image.dart` file SHALL be deleted.
4. THE `lib/PageFlip/page_flip_widget.dart` file SHALL be deleted.
5. THE `lib/PageFlip/` directory SHALL be deleted once all files within it are removed.
6. THE `_HighlightablePageState` in `lib/Helpers/pagination.dart` SHALL NOT contain any call to `flip_cache.imageData.clear()` after this change.
7. THE codebase SHALL NOT contain any import of `package:cosmos_epub/PageFlip/builders/builder.dart` after this change.

---

### Requirement 5: Preserve chapter boundary callbacks

**User Story:** As a developer, I want `onLastPage` and `onFirstPageBack` to continue firing at the correct moment, so that `ShowEpub` can advance or retreat chapters when the reader reaches a boundary.

#### Acceptance Criteria

1. WHEN the reader flips forward past the last page of a chapter, THE `PagingWidget` SHALL invoke `onLastPage(currentPageIndex, totalPages)`.
2. WHEN the reader flips backward from the first page of a chapter, THE `PagingWidget` SHALL invoke `onFirstPageBack(currentPageIndex, totalPages)`.
3. THE `PagingWidget` SHALL detect the last-page boundary using `PageFlipController.hasNextPage` returning `false` at the moment a forward flip completes.
4. THE `PagingWidget` SHALL detect the first-page boundary using `PageFlipController.hasPreviousPage` returning `false` at the moment a backward flip completes.
5. WHEN `PageFlipController.hasNextPage` and `PageFlipController.hasPreviousPage` are not available as discrete properties, THE `PagingWidget` SHALL derive boundary state from the `leftPageIndex` value delivered by `TurnablePage.onPageChanged`.
6. THE `Double_Swipe_Workaround` counter logic (`lastSwipe`, `prevSwipe`) in `ShowEpub` SHALL be simplified or removed once `PagingWidget` provides a reliable single-fire boundary signal; the simplified logic SHALL still advance chapters correctly for single-page chapters.

---

### Requirement 6: Expose FlipSettings as an optional PagingWidget parameter

**User Story:** As a developer integrating cosmos_epub, I want to customise the flip animation settings, so that I can tune inertia, easing, and corner sensitivity without forking the package.

#### Acceptance Criteria

1. THE `PagingWidget` constructor SHALL accept an optional `flipSettings` parameter of type `FlipSettings` from the `turnable_page_plus` package.
2. WHEN `flipSettings` is not supplied, THE `PagingWidget` SHALL use a default `FlipSettings` instance with `pagesBoundaryIsEnabled: false`, `enableInertia: true`, and `enableEasing: true`.
3. WHEN `flipSettings` is supplied by the caller, THE `PagingWidget` SHALL pass it directly to `TurnablePage`, overriding the default (except `pagesBoundaryIsEnabled` which SHALL always be `false`).
4. THE addition of the `flipSettings` parameter SHALL NOT change any other existing `PagingWidget` constructor parameters.
5. THE `ShowEpub` widget SHALL NOT be required to pass `flipSettings`; it SHALL continue to construct `PagingWidget` without this parameter and receive the default settings.

---

### Requirement 7: Preserve RTL text direction per page

**User Story:** As a reader of right-to-left content, I want each page to continue rendering in the correct text direction, so that Arabic, Hebrew, or Persian chapters display correctly regardless of the flip engine.

#### Acceptance Criteria

1. THE `_HighlightablePage` widget SHALL continue to wrap its content in a `Directionality` widget whose `textDirection` is determined by `RTLHelper.getTextDirection(pageHtml)`.
2. THE `TurnablePage` builder callback SHALL render each page as the same `_HighlightablePage` widget that currently exists, preserving its internal `Directionality` wrapping.
3. THE flip engine SHALL NOT impose a fixed text direction on the page content widgets it hosts.

---

### Requirement 8: Preserve per-page background colour

**User Story:** As a reader, I want the reader background and page background to stay consistent when I switch themes, so that the flip animation does not expose a mismatched colour behind the fold.

#### Acceptance Criteria

1. THE `PagingWidget` SHALL pass the `backgroundColor` parameter to `TurnablePage` (or the equivalent `FlipSettings` colour field) so that the flip engine renders the page-back colour correctly.
2. WHEN the user changes the theme (background colour), THE new `backgroundColor` SHALL be reflected in the flip widget on the next rebuild without requiring a full chapter reload.
3. THE `_HighlightablePage` widget SHALL continue to set its own `Container` colour to `widget.backgroundColor`.

---

### Requirement 9: Preserve all existing PagingWidget and ShowEpub constructor signatures

**User Story:** As a consumer of the cosmos_epub package, I want all existing constructor parameters to remain unchanged, so that I do not need to update any call sites in my application.

#### Acceptance Criteria

1. THE `PagingWidget` constructor SHALL retain all existing parameters: `htmlContent`, `contentParser`, `bookId`, `chapterIndex`, `rawFontFamily`, `accentColor`, `backgroundColor`, `style`, `handlerCallback`, `onTextTap`, `onPageFlip`, `onLastPage`, `onFirstPageBack`, `starterPageIndex`, `chapterTitle`, `totalChapters`, `lastWidget`.
2. THE `ShowEpub` constructor SHALL retain all existing parameters: `key`, `epubBook`, `accentColor`, `starterChapter`, `shouldOpenDrawer`, `bookId`, `chapterListTitle`, `onPageFlip`, `onLastPage`.
3. THE `CosmosEpub` static methods SHALL retain their existing signatures unchanged.
4. THE new `flipSettings` parameter on `PagingWidget` SHALL be optional and SHALL NOT break existing call sites that omit it.

---

### Requirement 10: Delete lib/PageFlip directory after replacement

**User Story:** As a developer maintaining the package, I want the `lib/PageFlip/` directory and all its contents removed, so that there are no dead code files referencing the obsolete flip engine.

#### Acceptance Criteria

1. WHEN the new flip engine is confirmed working, THE `lib/PageFlip/` directory and all files within it SHALL be deleted.
2. THE deleted files SHALL include: `page_flip_widget.dart`, `builders/builder.dart`, `builders/image.dart`, and `effects/flip_effect.dart`.
3. AFTER deletion, no Dart file in `lib/` SHALL import from `package:cosmos_epub/PageFlip/`.
4. AFTER deletion, the package SHALL compile without errors referencing the deleted files.
