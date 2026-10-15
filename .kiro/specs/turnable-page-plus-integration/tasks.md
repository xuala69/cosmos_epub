# Implementation Plan: turnable-page-plus Integration

## Overview

Replace the custom screenshot-based `PageFlipWidget` engine with `turnable_page_plus` from pub.dev. Changes touch three files (`pubspec.yaml`, `lib/Helpers/pagination.dart`, `lib/show_epub.dart`) and delete the entire `lib/PageFlip/` directory. All public constructor signatures remain unchanged.

## Tasks

- [x] 1. Add turnable_page_plus dependency to pubspec.yaml
  - In `pubspec.yaml`, replace the existing `turnable_page_plus` git block under `dependencies` with the pub.dev entry: `turnable_page_plus: ^1.0.3`
  - Run `flutter pub get` and confirm it resolves without error
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Replace PageFlipWidget with TurnablePage in pagination.dart
  - [x] 2.1 Swap controller field and imports
    - Remove `import 'package:cosmos_epub/PageFlip/builders/builder.dart' as flip_cache;`
    - Remove `import 'package:cosmos_epub/PageFlip/page_flip_widget.dart';`
    - Add `import 'package:turnable_page_plus/turnable_page.dart';`
    - In `_PagingWidgetState`, replace `final _pageController = GlobalKey<PageFlipWidgetState>();` with `late final PageFlipController _flipController;`
    - _Requirements: 2.1, 3.4, 4.7_

  - [x] 2.2 Initialise and dispose PageFlipController
    - In `initState`, assign `_flipController = PageFlipController();` before calling `rePaginate()`
    - Add an `@override dispose()` method that calls `_flipController.dispose()` then `super.dispose()`
    - _Requirements: 3.1, 3.5_

  - [x] 2.3 Add optional flipSettings constructor parameter to PagingWidget
    - Add `final FlipSettings? flipSettings;` field to `PagingWidget`
    - Add `this.flipSettings,` to the const constructor (after `lastWidget`)
    - _Requirements: 6.1, 6.4, 9.1, 9.4_

  - [x] 2.4 Implement _resolvedSettings() helper
    - Add the `FlipSettings _resolvedSettings()` method to `_PagingWidgetState`:
      ```dart
      FlipSettings _resolvedSettings() {
        final base = widget.flipSettings ??
            const FlipSettings(
              enableInertia: true,
              enableEasing: true,
              flippingTime: 650,
              swipeDistance: 48,
              releaseCompletionThreshold: 0.38,
              cornerTriggerAreaSize: 0.25,
            );
        return base.copyWith(backgroundFillColor: widget.backgroundColor);
      }
      ```
    - _Requirements: 6.2, 6.3, 8.1, 8.2_

  - [x] 2.5 Implement _onPageChanged callback
    - Add the `void _onPageChanged(int leftIndex, int rightIndex)` method to `_PagingWidgetState`:
      ```dart
      void _onPageChanged(int leftIndex, int rightIndex) {
        final newIndex = rightIndex >= 0 ? rightIndex : leftIndex;
        _currentPageIndex = newIndex;
        widget.onPageFlip(newIndex, pages.length);
        bookProgress.setCurrentPageIndex(widget.bookId, newIndex);
        if (newIndex == pages.length - 1) {
          widget.onLastPage(newIndex, pages.length);
        }
        if (newIndex == 0) {
          widget.onFirstPageBack?.call(0, pages.length);
        }
      }
      ```
    - _Requirements: 5.1, 5.2, 5.5_

  - [x] 2.6 Replace PageFlipWidget instantiation with TurnablePage in build()
    - Remove the `PageFlipWidget(key: _pageController, ...)` call and replace with:
      ```dart
      TurnablePage(
        controller: _flipController,
        pageCount: pages.length,
        pageViewMode: PageViewMode.single,
        pagesBoundaryIsEnabled: false,
        autoResponseSize: true,
        settings: _resolvedSettings(),
        onPageChanged: _onPageChanged,
        builder: (context, index, constraints) => pages[index],
      )
      ```
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 7.2, 7.3_

  - [x] 2.7 Wire goToPage() for saved reading position and repagination
    - At the end of `_paginate()`, after `pages` is populated, add:
      ```dart
      final target = widget.starterPageIndex.clamp(0, pages.length - 1);
      if (target > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _flipController.goToPage(target);
        });
      }
      ```
    - In `rePaginate()` (the non-chapter-load path), call `_flipController.goToPage(0)` after `paginateFuture` is reassigned so reflows always reset to page 0
    - _Requirements: 3.2, 3.3_

  - [x] 2.8 Remove imageData.clear() from _HighlightablePageState
    - In `_HighlightablePageState._buildContent()`, remove the `flip_cache.imageData.clear();` call from the `onHighlightChanged` closure; the body should become just `if (mounted) setState(() {});`
    - _Requirements: 4.6, 4.7_

  - [ ]* 2.9 Write property test for _resolvedSettings() backgroundColor passthrough
    - Create `test/pagination_test.dart`; add a property test using `dart_check` (or `test` + manual iteration) that generates random `Color` values and optional `FlipSettings` objects, calls the extracted `resolvedSettings` logic, and asserts `backgroundFillColor` always equals the supplied color
    - **Property 4: backgroundColor is always reflected in FlipSettings**
    - **Validates: Requirements 8.1, 8.2**
    - _Feature: turnable-page-plus-integration, Property 4: backgroundColor is always reflected in FlipSettings_

  - [ ]* 2.10 Write property test for starterPageIndex clamping
    - In `test/pagination_test.dart`, generate random `(pageCount, starterPageIndex)` pairs (including negative and out-of-range values) and assert the clamped result is always in `[0, pageCount - 1]`
    - **Property 5: starterPageIndex clamping**
    - **Validates: Requirements 3.2**
    - _Feature: turnable-page-plus-integration, Property 5: starterPageIndex clamping_

- [x] 3. Checkpoint — pagination compiles cleanly
  - Run `flutter analyze lib/Helpers/pagination.dart` and confirm zero errors or warnings before touching show_epub.dart. Ask the user if anything looks off.

- [x] 4. Simplify ShowEpub double-swipe workaround
  - [x] 4.1 Remove double-swipe state and helper
    - In `ShowEpubState`, delete the three field declarations: `bool isLastPage`, `int lastSwipe`, `int prevSwipe`
    - Delete the `_resetSwipeState()` method
    - _Requirements: 5.6_

  - [x] 4.2 Simplify boundary callbacks and onPageFlip in PagingWidget construction
    - In the `PagingWidget(...)` construction inside `ShowEpub.build()`:
      - Replace the `onLastPage` lambda body with:
        ```dart
        onLastPage: (index, totalPages) async {
          widget.onLastPage?.call(index);
          nextChapter();
        },
        ```
      - Replace the `onFirstPageBack` lambda body with:
        ```dart
        onFirstPageBack: (index, totalPages) {
          prevChapter();
        },
        ```
      - In `onPageFlip`, remove the `lastSwipe` / `prevSwipe` / `isLastPage` counter assignments; keep only the `widget.onPageFlip?.call(...)`, `bookProgress.setCurrentPageIndex(...)`, and `updateUI()` lines
    - _Requirements: 5.6, 9.2_

  - [x] 4.3 Remove _resetSwipeState() calls from nextChapter() and prevChapter()
    - In `nextChapter()` and `prevChapter()`, remove the `_resetSwipeState()` call (the method and its state no longer exist)
    - _Requirements: 5.6_

  - [ ]* 4.4 Write unit tests for _onPageChanged boundary logic
    - In `test/pagination_test.dart`, add unit tests that construct a mock `_onPageChanged`-equivalent function and verify:
      - `onLastPage` fires when `newIndex == N - 1`, does not fire for `newIndex < N - 1`
      - `onFirstPageBack` fires when `newIndex == 0`, does not fire for `newIndex > 0`
    - **Property 2: onLastPage fires exactly when the last page is active**
    - **Property 3: onFirstPageBack fires exactly when the first page is active**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4**
    - _Feature: turnable-page-plus-integration, Property 2 & 3: boundary callback firing conditions_

  - [ ]* 4.5 Write property tests for boundary callback firing across input space
    - Generate random `(N, index)` pairs where `N >= 1` and `0 <= index < N`; run 100 iterations verifying the boundary conditions hold universally
    - **Property 2 & 3** (generative coverage)
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4**

- [x] 5. Delete lib/PageFlip/ directory
  - Delete `lib/PageFlip/builders/builder.dart`
  - Delete `lib/PageFlip/builders/image.dart`
  - Delete `lib/PageFlip/builders/index.dart`
  - Delete `lib/PageFlip/effects/flip_effect.dart`
  - Delete `lib/PageFlip/page_flip_widget.dart`
  - Confirm no file under `lib/` contains an import of `package:cosmos_epub/PageFlip/`
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 10.1, 10.2, 10.3, 10.4_

- [x] 6. Final verification checkpoint
  - Run `flutter analyze` from the workspace root and confirm zero errors
  - Confirm `lib/PageFlip/` no longer exists
  - Confirm `flip_cache.imageData.clear()` does not appear anywhere in `lib/`
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Task 3 is a deliberate mid-point checkpoint — `pagination.dart` must compile before `show_epub.dart` is touched, since `ShowEpub` depends on `PagingWidget`
- The `goToPage(0)` reset on repagination (task 2.7) must happen inside `rePaginate()` after `paginateFuture` is set, not inside `_paginate()`, to avoid calling the controller before `TurnablePage` is mounted
- `pagesBoundaryIsEnabled: false` is a top-level `TurnablePage` parameter per the design; do not place it inside `FlipSettings`
- Property tests for Property 1 (pageCount matches pages.length) are skipped here because that relationship is a direct assignment in the same expression — an integration test via `flutter test` on the widget covers it adequately
- No new pub.dev packages are needed for the non-optional tasks; `dart_check` or equivalent is only required if the optional property-test sub-tasks are executed

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "2.3"] },
    { "id": 3, "tasks": ["2.4", "2.5"] },
    { "id": 4, "tasks": ["2.6"] },
    { "id": 5, "tasks": ["2.7", "2.8"] },
    { "id": 6, "tasks": ["2.9", "2.10"] },
    { "id": 7, "tasks": ["4.1"] },
    { "id": 8, "tasks": ["4.2", "4.3"] },
    { "id": 9, "tasks": ["4.4", "4.5"] },
    { "id": 10, "tasks": ["5"] },
    { "id": 11, "tasks": ["6"] }
  ]
}
```
