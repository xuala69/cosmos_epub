# Page Forward Navigation Bugfix Design

## Overview

The cosmos_epub reader opens correctly at the first page of a chapter but forward navigation is broken in two independent ways:

1. **Forward button defect** — the next-page (forward) `IconButton` in `lib/show_epub.dart` is a copy-paste of the previous-button handler and was never inverted. It calls `prevChapter()` / `controllerPaging.previousPage()` instead of `nextChapter()` / `controllerPaging.nextPage()`, so pressing "next" goes backward (or does nothing at the first page).
2. **Forward swipe defect** — a forward swipe/flip advances at the `PagingWidget`/engine level (the engine test turns page 0 → 1) but does not complete in the full running app. The reader's box wobbles and settles while the flip engine lays out (documented in code: 765 → 780 → 810), and the size-change guard in `_PagingWidgetState._inputChanged()` is broken: it compares `_paginatedPageSize` to **itself**, so the reader never re-paginates when its box settles. `TurnablePage` keeps `width`/`height`/`aspectRatio` for the stale box, the page rect no longer fills/aligns with the visible reader, and the flip gesture's hit-test misses the swipe.

The fix inverts the forward-button logic (with RTL mirroring) and repairs the size-settle detection so the page rect matches the reader, while suppressing any re-pagination that would recreate `TurnablePage` mid-gesture. Back navigation, TOC navigation, position restore, font/theme re-pagination, and RTL mirroring are preserved.

## Glossary

- **Bug_Condition (C)**: the inputs that trigger the bug — (a) a press of the forward `IconButton`, or (b) a forward swipe/flip on the reader, while the reader is open.
- **Property (P)**: the desired behavior for buggy inputs — the forward action advances one page, or to the next chapter at the last page, and the forward swipe completes.
- **Preservation**: existing backward navigation, TOC navigation, font/theme/position behavior, and RTL mirroring that must remain unchanged.
- **`_PagingWidgetState`**: the state of `PagingWidget` in `lib/Helpers/pagination.dart` that owns the page list, the `PageFlipController`, and the re-pagination logic.
- **`_inputChanged()`**: the method that decides whether `PagingWidget` must re-paginate (content / font / text-scale / size changed).
- **`_paginatedPageSize`**: the reader box size the current `pages` were built for; it feeds `TurnablePage`'s `settings.width`/`height` and the `aspectRatio` argument.
- **`TurnablePage`**: the page-flip widget from `turnable_page_plus`; its `ValueKey('reader_${pages.length}_$_pendingStartPage')` controls when the engine is recreated.
- **`RenderTurnableBook.updateSettings(settings, pageCount)`**: the package hook called on every rebuild; it resets the engine (`_initialized = false`, recreates the page collection) whenever `pageCount` changes.

## Bug Details

### Bug Condition

The bug manifests on any forward-navigation action while the reader is open. The forward `IconButton` runs the previous-button's logic, and the forward swipe's hit-test misses because `TurnablePage` is sized for a stale reader box.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type ForwardAction   // button press OR swipe/flip gesture
  OUTPUT: boolean

  RETURN
    ( input.kind == 'forwardButtonPress'
      AND forwardButtonHandler(input) invokes prevChapter() OR previousPage()
      AND does NOT invoke nextChapter() OR nextPage() )
    OR
    ( input.kind == 'forwardSwipe'
      AND reader is at a page with a next page (or a next chapter)
      AND TurnablePage.settings.width/height/aspectRatio derive from a
           _paginatedPageSize that does NOT match the settled reader box size
      AND the swipe hit-test misses the page rect
      AND pageFlip.getCurrentPageIndex() does not advance )
END FUNCTION
```

### Examples

- **Button, first page of first chapter (multi-chapter book)**: press the right-arrow (forward) button. Expected: advance to page 1. Actual: `atChapterStart` is true so `prevChapter()` runs — but `index == 0`, so it is a guarded no-op; the reader stays on page 0 (defect 1.1).
- **Button, mid-chapter**: press the forward button from page 3. Expected: page 4. Actual: `previousPage()` runs and the reader goes to page 2 (defect 1.2).
- **Swipe, page 0 of a chapter (running app)**: forward swipe. Expected: flip completes, page 1 shown. Actual: the flip does not start/complete because the page rect is sized for a stale box and the hit-test misses (defect 1.3).
- **Edge — last page of the final chapter**: the forward button is hidden (`showNext == false`), and `nextChapter()` is a guarded no-op, so no forward advance is available (expected, 2.3).

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- The previous-page (back) `IconButton` must continue to call `prevChapter()` at the first page and `previousPage()` mid-chapter (LTR).
- A backward swipe/flip must continue to move to the previous page, or the previous chapter at the first page.
- Opening the table of contents and selecting a chapter must continue to navigate to that chapter at its first page.
- Changing font family, font size, or theme must continue to re-paginate and keep the current reading position.
- Reopening a book must continue to restore the last-read chapter and page index.
- RTL content must continue to mirror navigation so the forward action advances the book in the RTL-appropriate direction.
- On the first page of the first chapter the reader must continue to offer no previous-chapter action.

**Scope:**
All inputs that are NOT a forward button press or a forward swipe must be unaffected. This includes backward button presses, backward swipes, TOC selection, font/theme changes, brightness, and tap-to-toggle-header.

## Hypothesized Root Cause

### Defect 1 — Forward button (confirmed)

`lib/show_epub.dart` has two `IconButton`s in the bottom navigation `Row`. The first is the back control; the second is the forward control. The second button's `onPressed` is an exact copy of the first button's `onPressed` and was never inverted:

```dart
// forward (second) button — current, BUGGY:
final rtl = currentTextDirection == TextDirection.rtl;
final atChapterStart = controllerPaging.currentPage() == 0;
if (!rtl && atChapterStart) {
  prevChapter();                 // should be nextChapter() at LAST page
} else if (rtl) {
  nextChapter();                 // RTL branch is the back action, not forward
} else {
  controllerPaging.previousPage(); // should be nextPage()
}
```

It uses the back-button's `atChapterStart` (page 0) test and the back-button's actions, so it goes backward instead of forward. The forward control needs the mirror: `atLastPage` (page count − 1) → `nextChapter()`, else `nextPage()`, with the RTL branch swapped to the back action.

### Defect 2 — Forward swipe (hypothesized, to be confirmed by exploration)

1. **The reader box wobbles/settles while the flip engine lays out.** The `_inputChanged()` comment records the device log 765 → 780 → 810 across the first frames. `_PagingWidgetState._paginate()` captures `_paginatedPageSize` from `context.findRenderObject().size` on its first post-frame pass, so it can capture a transient wobble size (e.g. 765), not the settled size (810).

2. **The size-change guard is broken and there is no settle detection.** `_inputChanged()` compares the built-for size to itself:
   ```dart
   final size = _paginatedPageSize;
   final measured = _paginatedPageSize;   // <-- same value, always equal
   if ((size.width - measured.width).abs() > 10 || ...) return true;
   ```
   This branch can never return `true`, so a settled size change is never detected. Worse, the guard only runs from `didUpdateWidget`/`didChangeDependencies` (parent rebuild or dependency change) — a pure render-box size change triggers neither, so nothing re-evaluates the size at all. The field comment even says "a resize pass is already queued for the end of the frame," but no such pass is implemented.

3. **Stale size → mis-placed page rect → dead hit-test.** `TurnablePage` receives `settings.width`/`height` from `_resolvedSettings()` and `aspectRatio: _paginatedPageSize?.aspectRatio` in `build()`. With a stale `_paginatedPageSize`, the engine lays out its page rect for the old box; the rect no longer fills/aligns with the visible reader, so `hitTestChildren`/`hitTestSelf` (which test the page rect) miss the user's forward swipe and the turn never starts — "the page turn does not complete." This is the same mis-placed-rect / "only one page responds" class the portrait test was written to prevent.

4. **Secondary risk — re-pagination mid-gesture aborts the flip.** The code comment's historical "re-paginated several times on open … left the reader unable to flip" is the other failure mode: `TurnableBookRenderObjectWidget.updateRenderObject` → `RenderTurnableBook.updateSettings(settings, pageCount)` resets the engine (`_initialized = false`, recreates the page collection) whenever `pageCount` changes. A re-pagination that fires while a flip is in progress recreates `TurnablePage` (new `ValueKey` because `pages.length` changed) and resets the engine, aborting the flip.

5. **Why the engine test passes but the app fails.** The widget tests use a fixed viewport, so `_paginatedPageSize` matches the box and the rect fills it; a forward swipe turns 0 → 1. A probe that mimics `ShowEpub` by calling `setState` inside `onPageFlip` **also** turns 0 → 1, proving the parent rebuild is not the cause. The failure is specific to the real-app box settle, which the fixed-viewport tests do not reproduce.

## Correctness Properties

Property 1: Bug Condition - Forward actions advance the book

_For any_ forward action (forward button press, or forward swipe/flip) on a page that has a next page, the fixed reader SHALL advance exactly one page; on the last page of a non-final chapter it SHALL advance to the first page of the next chapter; on the last page of the final chapter it SHALL remain. The forward swipe SHALL complete (the page index advances and the flip settles to the new page).

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**

Property 2: Preservation - Non-forward inputs are unchanged

_For any_ input that is NOT a forward button press or forward swipe (back button, back swipe, TOC selection, font/theme change, reopen/restore, RTL), the fixed reader SHALL produce the same result as the original reader, preserving backward navigation, table-of-contents navigation, font/theme re-pagination with position kept, last-position restore, and RTL mirroring.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

## Fix Implementation

### Change 1 — Forward button logic (`lib/show_epub.dart`)

Make the two bottom-nav `IconButton`s exact mirrors. The forward control advances (LTR) and goes back (RTL); the back control keeps its current LTR back behavior and, for RTL, advances at page granularity (mirroring the forward control). Add a `totalPages()` getter to `PagingTextHandler` (`lib/Helpers/pagination.dart`) returning `pages.length` so "last page of chapter" can be tested explicitly and symmetrically with the back button's `currentPage() == 0`.

Forward (second) button, LTR advances; RTL is the back action:
```
if (!rtl) {                          // LTR forward
  atLastPage = currentPage() >= totalPages() - 1
  atLastPage ? nextChapter() : nextPage()
} else {                             // RTL back (mirror)
  atChapterStart = currentPage() == 0
  atChapterStart ? prevChapter() : previousPage()
}
```

Back (first) button: keep its LTR back branch unchanged; change its RTL branch from a bare `nextChapter()` to the forward mirror:
```
if (!rtl) {                          // LTR back (UNCHANGED)
  atChapterStart = currentPage() == 0
  atChapterStart ? prevChapter() : previousPage()
} else {                             // RTL forward (mirror)
  atLastPage = currentPage() >= totalPages() - 1
  atLastPage ? nextChapter() : nextPage()
}
```

The existing chapter-level visibility (`showPrevious`/`showNext` from `setupNavButtons()`) already enforces "no previous-chapter past the start" and "no next-chapter past the end," and is left untouched. This change is an additive alignment of the RTL forward branch to page granularity (it still advances, so 3.6 is preserved) and is flagged as a tradeoff below.

### Change 2 — Detect and re-paginate on box settle (`lib/Helpers/pagination.dart`)

- Repair `_inputChanged()`: compare `_paginatedPageSize` against the **current** reader render-box size (`context.findRenderObject()`), not against itself; keep the >10px threshold to ignore sub-pixel/rounding wobble.
- Add end-of-frame settle detection (the "resize pass queued for the end of the frame" the comments describe but never implemented): after each `build`, in a post-frame callback, measure the render-box size and compare to `_paginatedPageSize`; if it differs beyond the threshold, request a single re-paginate. This re-paginates once at the settled size so `TurnablePage`'s `width`/`height`/`aspectRatio` match the reader and the page rect fills it.
- Debounce: only re-paginate when the size is still different on the next frame, so transient wobble does not thrash through several `TurnablePage` recreations.

### Change 3 — Never re-paginate mid-gesture

- Track an `_isFlipping` flag set when `_onPageChanged` reports a real page cross and cleared once the engine is idle (short post-flip deferral). Skip/defer `_requestPaginate()` while `_isFlipping` is true so a size change during a flip can never recreate `TurnablePage` or reset the engine (which `updateSettings(pageCount)` would do via `_initialized = false`). This is the safety net for the historical "unable to flip" failure mode.

### Change 4 — Stop the spurious parent rebuild on layout notification

- In `_onPageChanged`, move the `widget.onPageFlip(...)` call (and thus `ShowEpub.updateUI()`) inside the `if (crossed)` guard. The engine emits a non-crossing page-0 'flip' notification whenever `TurnablePage` is laid out/re-created; calling `onPageFlip` on it triggers a redundant parent `setState`. Real turns always cross, so the host is still notified on every real turn; progress is already saved by the direct `bookProgress.setCurrentPageIndex` in `_onPageChanged`.

### Tradeoffs and Risks

- **RTL forward granularity (Change 1)**: aligning the RTL forward branch to page granularity changes existing behavior — an RTL forward press mid-chapter now turns one page instead of jumping to the next chapter. This is the correct forward behavior per 2.1–2.3 and still advances the book (3.6 preserved), but it is a visible behavior change to confirm. If minimal-change is preferred, the RTL forward branch can be left at chapter granularity (`nextChapter()` only) and only the confirmed LTR forward-button bug is inverted; this leaves 2.1–2.3 unmet for RTL forward via button.
- **Back navigation (3.1, 3.2)**: the LTR back button is untouched. The RTL back control is corrected to `previousPage()`/`prevChapter()` (it currently runs the forward action, which is wrong); this fixes, not regresses, back navigation.
- **TOC navigation (3.3)**: untouched — no change to `openTableOfContents`, `reLoadChapter`, or chapter selection.
- **Position restore (3.4, 3.5)**: untouched — the existing `_resolvePageIndexAfterRepaginate()` remap and `starterPageIndex` flow remain; the new settle re-pagination uses the same restore path, so a re-paginate at the settled size keeps the reading position.
- **Mid-gesture recreation (Change 3)**: the `_isFlipping` deferral is a heuristic (post-flip settle window). Risk: a flip that takes longer than the window could still race a queued re-pagination; mitigated by also checking `_isPaginating` and only applying a settled-size pass when the engine is idle.
- **Settle detection (Change 2)**: end-of-frame size measurement relies on `context.findRenderObject()` having a size; it is guarded by `hasSize`. Risk: very fast oscillation could queue extra passes; the debounce (re-check next frame) bounds this to one re-paginate per stable size.
- **Chapter-level button visibility**: `showNext`/`showPrevious` are chapter-based, so within the final chapter the forward button is hidden and mid-chapter forward page-turns there are swipe-only. This is existing behavior and out of scope for this fix; flagged so it is not mistaken for a regression.

## Testing Strategy

### Validation Approach

Two phases: first surface counterexamples that demonstrate both defects on the current (unfixed) code, then verify the fix advances correctly and preserves all other behavior.

### Exploratory Bug Condition Checking

**Goal**: Confirm/refute the root causes before implementing the fix. The forward-button cause is confirmed by reading; the swipe cause is a hypothesis to validate.

**Test Plan**:
1. **Forward button (confirm)**: drive the forward `IconButton`'s `onPressed` at page 0 and mid-chapter on the current code and assert it calls `prevChapter`/`previousPage` (counterexample).
2. **Swipe settle (refute-or-confirm)**: in a widget test that grows the reader box after the first pagination (mimicking the 765 → 810 settle), assert on the current code that `_paginatedPageSize` stays at the first size while the render box settles, and that a forward swipe then fails to advance; then assert that after the fix the reader re-paginates to the settled size and the swipe advances.
3. **setState-is-not-the-cause (already run)**: a probe that calls `setState` inside `onPageFlip` still advances 0 → 1 — kept as a regression guard to prove the parent rebuild alone never breaks the flip.

**Expected Counterexamples**:
- Forward button advances backward or no-ops.
- After a box settle, `TurnablePage` settings width/height/aspectRatio do not match the render box, and a forward swipe leaves `getCurrentPageIndex()` unchanged.

### Fix Checking

**Goal**: for all buggy inputs, the fixed function produces the expected behavior.
```
FOR ALL input WHERE isBugCondition(input) DO
  result := fixedReader(input)
  ASSERT expectedBehavior(result)   // advances one page / next chapter / stays on last page; swipe completes
END FOR
```

### Preservation Checking

**Goal**: for all non-buggy inputs, the fixed reader equals the original.
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT originalReader(input) = fixedReader(input)
END FOR
```
Property-based testing is recommended: it generates many states across the input domain (back button, back swipe, TOC, font/theme, restore, RTL) and catches edge cases manual tests miss.

**Test Plan**: capture back-button, back-swipe, TOC, font/theme, restore, and RTL behavior on the unfixed code, then assert the fixed code matches across many generated states.

### Unit Tests

- Forward button: page 0 → page 1; mid-chapter → next page; last page of a non-final chapter → `nextChapter`; last page of the final chapter → stays (button hidden).
- Back button: unchanged (page 0 → `prevChapter`; mid-chapter → previous page).
- RTL: forward control advances (nextPage/nextChapter), back control goes back (previousPage/prevChapter); visibility hides back at the first chapter and forward at the last chapter.
- `_inputChanged()`: a real settle (>10px) returns true; sub-pixel wobble does not; same content/font does not.
- Box-settle re-pagination: after a resize, `_paginatedPageSize` and `TurnablePage` settings match the new render-box size.
- Mid-gesture guard: a size change while `_isFlipping` does not recreate `TurnablePage`.

### Property-Based Tests

- For random (pageIndex, pageCount, chapterIndex, totalChapters, rtl) states, the forward action advances by one page or one chapter exactly when a next page/chapter exists, and stays at the end.
- For random non-forward inputs, the fixed reader matches the original reader (back nav, TOC, font/theme, restore, RTL).
- For random reader-box sizes and settle sequences, the page rect always fills the reader after settle, and a forward swipe always advances when a next page exists.

### Integration Tests

- Full reader flow: open a multi-chapter book, use the forward button and forward swipe to reach the next chapter, then go back with the back button and back swipe.
- Switch between LTR and RTL content and verify the correct control advances and the page rect still fills the reader.
- Reopen a book and verify the last chapter/page is restored, then navigate forward.
