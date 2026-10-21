# Bugfix Requirements Document

## Introduction

The cosmos_epub reader opens correctly at the first page (index 0) of a chapter, but forward page navigation is broken. The next-page (forward) navigation button does not advance to the next page, and a forward swipe/flip gesture does not advance to the next page in the running app. As a result the reader stays stuck on the first page and the user cannot move forward through the chapter or the book.

The bug condition is any attempt to advance forward one page while the reader is open: pressing the next-page (forward) button, or performing a forward swipe/flip. The fix must make both actions advance to the next page (or to the next chapter when already on the last page), while preserving backward navigation, table-of-contents navigation, font/theme/position behavior, and RTL mirroring.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the reader is open at the first page (index 0) of the first chapter and the user presses the next-page (forward) navigation button THEN the reader performs no forward advance and stays on page 0.

1.2 WHEN the reader is open at any page that is not the first page of a chapter and the user presses the next-page (forward) navigation button THEN the reader moves to the previous page instead of the next page.

1.3 WHEN the reader is open at the first page (index 0) of a chapter and the user performs a forward swipe/flip gesture THEN the reader does not advance to the next page (the page turn does not complete in the running app).

### Expected Behavior (Correct)

2.1 WHEN the user presses the next-page (forward) navigation button on a page that is not the last page of the chapter THEN the reader SHALL advance to the next page (page index increases by one).

2.2 WHEN the user presses the next-page (forward) navigation button on the last page of a non-final chapter THEN the reader SHALL advance to the first page of the next chapter.

2.3 WHEN the user presses the next-page (forward) navigation button on the last page of the final chapter THEN the reader SHALL remain on the last page (no further forward advance is available).

2.4 WHEN the user performs a forward swipe/flip gesture on a page that is not the last page of the chapter THEN the reader SHALL complete the flip and advance to the next page.

2.5 WHEN the user performs a forward swipe/flip gesture on the last page of a non-final chapter THEN the reader SHALL advance to the next chapter.

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the user presses the previous-page (back) navigation button THEN the reader SHALL CONTINUE TO move to the previous page, or to the previous chapter when already on the first page of a chapter.

3.2 WHEN the user performs a backward swipe/flip gesture THEN the reader SHALL CONTINUE TO move to the previous page, or to the previous chapter when already on the first page of a chapter.

3.3 WHEN the user opens the table of contents and selects a chapter THEN the reader SHALL CONTINUE TO navigate to that chapter and open it at its first page.

3.4 WHEN the user changes font family, font size, or theme THEN the reader SHALL CONTINUE TO re-paginate and keep the current reading position.

3.5 WHEN the reader reopens a book THEN the reader SHALL CONTINUE TO restore the last-read chapter and page index.

3.6 WHEN the page content is right-to-left (RTL) THEN the reader SHALL CONTINUE TO mirror the navigation direction so that the forward action advances the book in the RTL-appropriate direction.

3.7 WHEN the reader is on the first page of the first chapter THEN the reader SHALL CONTINUE TO offer no previous-chapter action (no backward navigation past the start of the book).
