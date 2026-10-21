# Implementation Plan

- [ ] 1. Write bug condition exploration tests (BEFORE the fix)
  - **Property 1: Bug Condition** - Forward actions advance the book
  - **CRITICAL**: These tests MUST FAIL on unfixed code - failure confirms both defects exist
  - **DO NOT attempt to fix the test or the code when they fail**
  - **NOTE**: These tests encode the expected behavior - they validate the fix when they pass after implementation
  - **GOAL**: Surface counterexamples demonstrating the forward-button and forward-swipe defects
  - **Scoped PBT Approach**: For these deterministic bugs, scope properties to concrete failing cases (button at page 0; button mid-chapter; box-settle swipe) for reproducibility
  - Tests, run on UNFIXED code:
    - 1.1 Forward button at page 0 of first chapter: drive the forward `IconButton` `onPressed` (show_epub.dart ~line 784) and assert it currently calls `prevChapter()`/`previousPage()` (counterexample); the expected-behavior assertion (page index becomes 1) will FAIL
    - 1.2 Forward button mid-chapter (e.g. page 3): assert it currently calls `previousPage()` and moves backward (counterexample); the expected-behavior assertion (page index becomes 4) will FAIL
    - 1.3 Box-settle swipe: in a widget test that pumps a `PagingWidget`, grows the reader box after the first pagination (mimicking the 765 → 810 settle), then issues a forward swipe (right → left gesture as in `_temp_nav_probe_test.dart`); assert on UNFIXED code that `_paginatedPageSize` stays at the first size while the render box settled, the `TurnablePage` `settings.width`/`height`/`aspectRatio` do NOT match the new box, and `pageFlip.getCurrentPageIndex()` stays at 0 (the swipe misses)
  - **EXPECTED OUTCOME**: Tests FAIL (this proves the bug exists)
  - Document the concrete counterexamples found (e.g. "forward button at page 0 invokes prevChapter(), index stays 0"; "after box grow, settings.width=765 but box.width=810, swipe leaves current page index 0")
  - Mark task complete when tests are written, run, and failures documented
  - _Requirements: 1.1, 1.2, 1.3_

- [ ] 2. Write preservation property tests (BEFORE implementing the fix)
  - **Property 2: Preservation** - Non-forward inputs are unchanged
  - **IMPORTANT**: Follow observation-first methodology - observe behavior on UNFIXED code, then write tests capturing it
  - Observe on UNFIXED code for non-buggy inputs and capture behavior:
    - Back button (LTR) at page 0 → `prevChapter()`; mid-chapter → `previousPage()`
    - Back swipe → previous page / previous chapter at first page
    - TOC selection → navigates to selected chapter at its first page
    - Font family / font size / theme change → re-paginates and keeps current reading position
    - Reopen book → restores last-read chapter and page index
    - RTL content → forward/back controls mirror navigation direction; first page of first chapter offers no previous-chapter action
  - Write property-based tests across the input domain (random `(pageIndex, pageCount, chapterIndex, totalChapters, rtl)` states for back nav/RTL; random font/theme/restore states) asserting the observed behavior
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [ ] 3. Fix the forward button (Change 1)

  - [ ] 3.1 Add `totalPages()` getter to `PagingTextHandler`
    - In `lib/Helpers/pagination.dart`, add `final int Function() totalPages;` to `PagingTextHandler`, defaulting to `(() => 0)`, and wire it from `_PagingWidgetState` to return `pages.length` (symmetric with the existing `currentPage()` getter)
    - _Bug_Condition: isBugCondition(input) where input.kind == 'forwardButtonPress' and forwardButtonHandler invokes prevChapter()/previousPage() (show_epub.dart ~line 784)_
    - _Expected_Behavior: expectedBehavior(result) - last page of chapter testable via currentPage() >= totalPages() - 1_
    - _Preservation: back-button `currentPage() == 0` test unchanged (3.1)_
    - _Requirements: 2.1, 2.2, 2.3_

  - [ ] 3.2 Invert the forward (second) button logic in `lib/show_epub.dart`
    - Replace the second `IconButton` `onPressed` (~line 784-793): LTR → `atLastPage = controllerPaging.currentPage() >= controllerPaging.totalPages() - 1; atLastPage ? nextChapter() : controllerPaging.nextPage()`; RTL → back mirror `atChapterStart = currentPage() == 0; atChapterStart ? prevChapter() : controllerPaging.previousPage()`
    - Leave chapter-level `showPrevious`/`showNext` visibility untouched
    - _Bug_Condition: isBugCondition(input) where input.kind == 'forwardButtonPress'_
    - _Expected_Behavior: 2.1 advance one page; 2.2 at last page of non-final chapter → nextChapter; 2.3 at last page of final chapter → stays (button hidden via showNext)_
    - _Preservation: 3.1 LTR back button untouched; 3.6 RTL forward still advances the book_
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.6_

  - [ ] 3.3 Correct the back (first) button's RTL branch in `lib/show_epub.dart`
    - Replace the first `IconButton` `onPressed` RTL branch (~line 734-735): from bare `nextChapter()` to the forward mirror `atLastPage = currentPage() >= totalPages() - 1; atLastPage ? nextChapter() : controllerPaging.nextPage()`; keep the LTR back branch unchanged
    - _Bug_Condition: back control currently runs the forward action under RTL (wrong direction)_
    - _Expected_Behavior: RTL back control goes back via previousPage()/prevChapter()_
    - _Preservation: 3.1 LTR back branch unchanged; 3.6 RTL forward (this button's RTL branch) still advances; 3.7 first page of first chapter offers no previous-chapter action_
    - _Requirements: 3.1, 3.6, 3.7_

  - [ ] 3.4 Verify bug condition exploration test 1 now passes
    - **Property 1: Expected Behavior** - Forward button advances the book
    - **IMPORTANT**: Re-run the SAME tests from task 1 - do NOT write new tests
    - Re-run exploration tests 1.1 and 1.2 (forward button at page 0 and mid-chapter)
    - **EXPECTED OUTCOME**: Tests PASS (confirms forward button is fixed)
    - _Requirements: 2.1, 2.2_

  - [ ] 3.5 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-forward inputs are unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2 (back button, RTL, TOC, font/theme, restore)
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions from Change 1)
    - Confirm back button (LTR unchanged) and RTL forward/back still behave as expected

- [ ] 4. Repair box-settle detection (Change 2)

  - [ ] 4.1 Fix `_inputChanged()` to compare against the real render-box size
    - In `lib/Helpers/pagination.dart` `_inputChanged()` (~line 282-301): replace `final measured = _paginatedPageSize;` with the current reader render-box size via `context.findRenderObject()` (guard with `is RenderBox && hasSize`); keep the >10px width/height threshold to ignore sub-pixel/rounding wobble
    - _Bug_Condition: isBugCondition(input) where input.kind == 'forwardSwipe' and TurnablePage settings derive from a _paginatedPageSize that does NOT match the settled reader box_
    - _Expected_Behavior: a real settle (>10px) returns true so the reader re-paginates to the settled size_
    - _Preservation: same content/font/text-scale does NOT return true (no spurious re-pagination); 3.4 font/theme re-pagination still triggers via the existing non-size branches_
    - _Requirements: 1.3, 2.4, 2.5_

  - [ ] 4.2 Add end-of-frame settle re-pagination with debounce
    - Add a post-frame callback after each `build` (e.g. via `WidgetsBinding.instance.addPostFrameCallback`) that measures the render-box size, compares to `_paginatedPageSize` beyond the threshold, and requests a single `_requestPaginate()` when the size is still different on the next frame (debounce) so transient wobble does not thrash through several `TurnablePage` recreations
    - Guard with `hasSize`/`mounted`; reuse the existing position-restore path (`_resolvePageIndexAfterRepaginate`) so a re-paginate at the settled size keeps the reading position
    - _Bug_Condition: the settle pass the field comments describe but never implement_
    - _Expected_Behavior: after a box settle, `_paginatedPageSize` and `TurnablePage` `settings.width`/`height`/`aspectRatio` match the new render-box size and the page rect fills the reader_
    - _Preservation: 3.4/3.5 re-paginate/restore paths unchanged; 3.7 unaffected_
    - _Requirements: 1.3, 2.4, 2.5, 3.4, 3.5_

  - [ ] 4.3 Verify bug condition exploration test 1.3 now passes
    - **Property 1: Expected Behavior** - Forward swipe completes after box settle
    - **IMPORTANT**: Re-run the SAME test 1.3 from task 1 - do NOT write a new test
    - Re-run the box-settle swipe test (grow the box after first pagination, then forward swipe)
    - **EXPECTED OUTCOME**: Test PASSES - reader re-paginates to the settled size and the forward swipe advances `getCurrentPageIndex()` to 1
    - _Requirements: 1.3, 2.4_

  - [ ] 4.4 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-forward inputs are unchanged
    - Re-run preservation property tests from step 2; add/confirm a unit assertion that `_inputChanged()` returns false for sub-pixel wobble and same content/font, and true only for a real >10px settle
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions from Change 2)
    - _Requirements: 3.4, 3.5_

- [ ] 5. Add the mid-gesture re-pagination guard (Change 3)

  - [ ] 5.1 Track `_isFlipping` and defer re-pagination while a flip is in progress
    - In `_PagingWidgetState` (`lib/Helpers/pagination.dart`): add an `_isFlipping` flag set when `_onPageChanged` reports a real page cross (`crossed == true`) and cleared once the engine is idle (short post-flip deferral via post-frame callback). Make `_requestPaginate()` (or the new settle pass) skip/defer when `_isFlipping` is true, also checking `_isPaginating` and only applying a settled-size pass when the engine is idle
    - _Bug_Condition: a re-pagination that fires while a flip is in progress recreates TurnablePage (new ValueKey because pages.length changed) and resets the engine via RenderTurnableBook.updateSettings(pageCount) → _initialized = false, aborting the flip_
    - _Expected_Behavior: a size change during a flip never recreates TurnablePage/resets the engine; the flip completes_
    - _Preservation: 3.4/3.5 re-pagination still runs when the engine is idle; settle detection still fires after the flip settles_
    - _Requirements: 1.3, 2.4, 2.5, 3.4, 3.5_

  - [ ] 5.2 Verify the mid-gesture guard
    - **Property 2: Preservation** - Mid-gesture size change does not recreate TurnablePage
    - Write/run a test: start a forward flip and trigger a size change mid-gesture; assert `TurnablePage`'s `ValueKey` (reader_${pages.length}_$_pendingStartPage) does NOT change and `RenderTurnableBook` is not reset while `_isFlipping` is true; the flip still advances to the next page
    - **EXPECTED OUTCOME**: Test PASSES (confirms mid-gesture guard works and the historical "unable to flip" failure mode does not regress)
    - Re-run box-settle swipe test 1.3 to confirm the swipe still completes
    - _Requirements: 1.3, 2.4_

  - [ ] 5.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-forward inputs are unchanged
    - Re-run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions from Change 3)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [ ] 6. Stop the spurious parent rebuild on layout notification (Change 4)

  - [ ] 6.1 Move `widget.onPageFlip(...)` inside the `if (crossed)` guard in `_onPageChanged`
    - In `_onPageChanged` (`lib/Helpers/pagination.dart` ~line 523-541): move the `widget.onPageFlip(newIndex, pages.length)` call (and thus `ShowEpub.updateUI()`) inside the `if (crossed)` guard so the engine's non-crossing page-0 'flip' notification on layout/re-create no longer triggers a redundant parent `setState`; keep the direct `bookProgress.setCurrentPageIndex(widget.bookId, newIndex)` where it is (progress is still saved)
    - _Bug_Condition: the engine emits a non-crossing page-0 'flip' notification whenever TurnablePage is laid out/re-created, calling onPageFlip on it triggers a redundant parent setState_
    - _Expected_Behavior: the host is still notified on every real turn (real turns always cross); progress still saved by the direct setCurrentPageIndex_
    - _Preservation: real-turn onPageFlip callbacks still fire (3.x unchanged); the setState-is-not-the-cause probe still advances 0 → 1 (kept as a regression guard)_
    - _Requirements: 1.3, 2.4, 2.5_

  - [ ] 6.2 Verify the spurious-rebuild fix
    - **Property 2: Preservation** - No spurious parent rebuild on non-crossing layout notification
    - Write/run a test that lays out/recreates TurnablePage without a real turn and assert `onPageFlip` is NOT called (counter for parent setState); assert a real forward swipe still calls `onPageFlip` exactly once with the new index
    - Keep the existing `_temp_nav_probe_test.dart` probe (setState inside onPageFlip still advances 0 → 1) as a regression guard proving the parent rebuild alone never breaks the flip
    - **EXPECTED OUTCOME**: Tests PASS (confirms spurious rebuild stopped and real turns still notify)
    - _Requirements: 1.3, 2.4_

  - [ ] 6.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-forward inputs are unchanged
    - Re-run preservation property tests from step 2 (especially real-turn onPageFlip still fires for back swipe / TOC / restore flows)
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions from Change 4)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [ ] 7. Checkpoint - Ensure all tests pass
  - Run the full unit + widget + property-based test suite (forward button, back button, RTL, `_inputChanged`, box-settle re-pagination, mid-gesture guard, spurious-rebuild, and the setState probe)
  - Run the integration tests: open a multi-chapter book, use the forward button AND forward swipe to reach the next chapter, then go back with the back button and back swipe; switch LTR/RTL and verify the correct control advances and the page rect still fills the reader; reopen a book and verify last chapter/page restored, then navigate forward
  - Ensure all tests pass; ask the user if questions arise
