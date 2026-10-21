# Debug Log Guide for Cosmos EPUB Page Turning Issue

## Issue Summary
Users reported that page turning (via drag or next button) doesn't work. Debug output showed only 1 page being created.

## Root Cause Analysis
The pagination system requires the widget to have a layout size before it can calculate page breaks. If pagination is called before the widget is laid out, it fails silently and only creates 1 page or no pages.

## Changes Made

### 1. Added Comprehensive Debug Logging
All key files now include debugPrint statements to trace the flow:

- **cosmos_epub.dart**: Book opening process
- **show_epub.dart**: Chapter loading and button presses
- **epub_content_parser.dart**: Chapter extraction from EPUB
- **pagination.dart**: Page creation and flipping
- **html_paginator.dart**: HTML block processing

### 2. Fixed Pagination Retry Logic
Modified `pagination.dart` to:
- Detect when widget has no size and automatically retry pagination in the next frame
- Added retry logic in the build method when pages are empty but size is now available
- Added detailed logging for all pagination states

## Expected Flow (with logs)

When opening a book, you should see:

```
[CosmosEpub] Opening asset book: assets/famouspaintings.epub
[CosmosEpub] Loaded XXXX bytes
[CosmosEpub] Parsed EPUB: Title, chapters: N
[CosmosEpub] Opening book viewer for bookId: 3
[EPUB_PARSER] Parsing EPUB book: Title
[EPUB_PARSER] Built N flat chapters
[EPUB_PARSER] Extracted M images
[SHOW_EPUB] loadChapter() called with index=-1
[SHOW_EPUB] Found N chapters
[SHOW_EPUB] Chapter 0: Chapter Name, htmlLength=XXXX
[... more chapter info ...]
[SHOW_EPUB] updateContentAccordingChapter(0)
[SHOW_EPUB] Chapter HTML length: XXXX
[SHOW_EPUB] Chapter HTML preview: <html>...
[SHOW_EPUB] Detected text direction: TextDirection.ltr
[PAGINATE] PagingWidget initState() called
[PAGINATE] Post-frame callback: requesting pagination
[PAGINATE] _requestPaginate() called, isPaginating=false, pages.isEmpty=true
[PAGINATE] inputChanged=true
[PAGINATE] First pass - will show spinner
[PAGINATE] _beginPaginate() starting new pass
[PAGINATE] Captured inputs: htmlLength=XXXX, fontSize=17.0, fontFamily=Segoe
[PAGINATE] Starting pagination pass #1
[PAGINATE] RenderObject type: RenderBox
[PAGINATE] RenderBox has size: Size(XXX, YYY)
[PAGINATE] Page size: Size(XXX, YYY)
[PAGINATE] HTML length: XXXX, fontSize: 17.0, fontFamily: Segoe
[PAGINATE] Resolving images in HTML
[PAGINATE] Effective page size: width=XXX, height=YYY
[PAGINATE] Calling HtmlPaginator.paginate() with XXXX chars
[HTML_PAGINATOR] paginate() called with XXXX chars
[HTML_PAGINATOR] Fixed HTML length: XXXX
[HTML_PAGINATOR] Collected N blocks
[HTML_PAGINATOR] Starting pagination with pageHeight=YYY
[HTML_PAGINATOR] Block tag=p, height=XX, textLength=YY
[... more blocks ...]
[HTML_PAGINATOR] Generated M pages
[HTML_PAGINATOR] Page 0: XXX chars
[HTML_PAGINATOR] Page 1: XXX chars
...
[PAGINATE] Generated M pages
[PAGINATE] New pages generated: M pages
[PAGINATE] Pending start page: 0, current page: 0
[PAGINATE] build() called, pages.length=M, _isPaginating=false
```

## What to Look For

### Problem 1: No Size Available
If you see:
```
[PAGINATE] RenderBox has no size yet (Size(0.0, 0.0)), scheduling retry...
```
This means pagination is being called before the widget is laid out. The new code should automatically retry.

### Problem 2: Only 1 Page Created
If you see:
```
[HTML_PAGINATOR] Generated 1 pages
```
This means the HTML content is fitting on a single page. Check:
- The effective page height (should be screen height minus ~150)
- The block heights being measured (might be too small)
- The HTML content itself (might be very short)

### Problem 3: HTML Content is Empty
If you see:
```
[SHOW_EPUB] Chapter HTML length: 0
```
This means the chapter content couldn't be extracted from the EPUB. Check:
- [EPUB_PARSER] Resolving content for source: XYZ
- [EPUB_PARSER] No content found for source: XYZ

This indicates the EPUB parser can't find the HTML for the chapter.

## Button Press Flow

When clicking the next button:
```
[SHOW_EPUB] Right button clicked, RTL=TextDirection.ltr
[SHOW_EPUB] LTR mode: calling nextPage()
[PAGINATE] _flipToNextPage() called
[PAGINATE] pages.length=N, _currentPageIndex=M
[PAGINATE] Calling _flipController.nextPage()
[PAGINATE] nextPage() succeeded
[PAGINATE] _onPageChanged(left=1, right=2)
[PAGINATE] newIndex=1, current _currentPageIndex=0
[PAGINATE] crossed=true
```

If you see:
```
[PAGINATE] At last page!
```
This means `_currentPageIndex >= pages.length - 1`, so there's no next page.

## Common Issues and Fixes

### Issue: Pagination never completes
**Symptom**: Stuck on spinner forever
**Check**: Look for "RenderBox has no size yet" messages without a subsequent successful pagination
**Fix**: The new retry logic should handle this, but if not, there may be a layout issue

### Issue: Only 1 page created
**Symptom**: Can't turn pages, pages.length=1
**Check**: 
1. Look at the HTML content length in the logs
2. Look at the page height being used
3. Look at the block heights being measured
**Fix**: The HTML content might be very short, or the page height calculation might be wrong

### Issue: Empty HTML content
**Symptom**: Chapter HTML length is 0 or very small
**Check**: Look at the EPUB_PARSER logs to see if content resolution is working
**Fix**: The EPUB file might have a broken TOC, or the content paths might be incorrect

## Testing

Run the example app with:
```bash
flutter run -d <device> --verbose
```

Or filter for just the debug logs:
```bash
flutter run -d <device> 2>&1 | grep -E "\[CosmosEpub\]|\[SHOW_EPUB\]|\[PAGINATE\]|\[HTML_PAGINATOR\]|\[EPUB_PARSER\]"
```

## Next Steps

1. Run the app with debug logging enabled
2. Capture the full log output
3. Look for the patterns described above
4. Identify where the flow breaks down
5. Report back with the relevant log sections

The most likely issues are:
- HTML content is empty or very short
- Page height is too large, causing all content to fit on one page
- Pagination is failing to retry properly
