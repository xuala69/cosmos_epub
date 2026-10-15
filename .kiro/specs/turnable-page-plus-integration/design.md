# Design Document

## Overview

This design replaces the cosmos_epub page-flip engine — the custom `PageFlipWidget`, `PageFlipBuilder`, and `PageFlipEffect` classes — with the `turnable_page_plus` pub.dev package. The swap eliminates the screenshot-based rendering pipeline (100 ms capture delay, CPU column loop, global `imageData` cache) and replaces it with a geometry-based 3D fold engine.

The replacement is entirely internal. All public constructor signatures for `PagingWidget`, `ShowEpub`, and `CosmosEpub` remain unchanged. An optional `flipSettings` parameter is added to `PagingWidget` as a purely additive, backward-compatible extension.

The `Double_Swipe_Workaround` counters (`lastSwipe`, `prevSwipe`, `isLastPage`) in `ShowEpub` are removed because `TurnablePage.onPageChanged` delivers a reliable single-fire callback, removing the need for double-tap debouncing.

---

## Architecture

### Before

```
ShowEpub
  └── PagingWidget
        ├── GlobalKey<PageFlipWidgetState>  ← programmatic nav
        ├── PageFlipWidget (custom)
        │     ├── RepaintBoundary + toImage()  ← 100 ms screenshot per page
        │     ├── flip_cache.imageData (global Map)
        │     └── PageFlipEffect (column-by-column render)
        └── _HighlightablePage (x N)
```

### After

```
ShowEpub
  └── PagingWidget
        ├── PageFlipController  ← programmatic nav
        ├── TurnablePage (turnable_page_plus)
        │     └── 3D fold geometry engine
        └── _HighlightablePage (x N)
```

The `lib/PageFlip/` directory is fully deleted once migration is complete.

---

## Components and Interfaces

### 1. pubspec.yaml

Add one line under `dependencies`:

```yaml
turnable_page_plus: ^1.0.0
```

No other dependency changes. The existing git URL entry (if present) is replaced by this pub.dev reference.

---

### 2. PagingWidget (`lib/Helpers/pagination.dart`)

#### 2a. New optional constructor parameter

```dart
class PagingWidget extends StatefulWidget {
  // ... all existing parameters unchanged ...
  final FlipSettings? flipSettings;   // NEW — optional

  const PagingWidget({
    // ... existing named params ...
    this.flipSettings,                // additive, defaults to null
  });
}
```

`FlipSettings` is imported from `package:turnable_page_plus/turnable_page.dart`.

#### 2b. Controller field replacement

Remove:

```dart
final _pageController = GlobalKey<PageFlipWidgetState>();
```

Add:

```dart
late final PageFlipController _flipController;
```

Initialise in `initState` before calling `rePaginate()`:

```dart
@override
void initState() {
  _flipController = PageFlipController();
  rePaginate();
  widget.handlerCallback(PagingTextHandler(paginate: rePaginate));
  super.initState();
}
```

Dispose in `dispose`:

```dart
@override
void dispose() {
  _flipController.dispose();
  super.dispose();
}
```

#### 2c. FlipSettings resolution helper

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

`pagesBoundaryIsEnabled` is always `false`; it is passed directly to `TurnablePage` as a top-level widget parameter, not inside `FlipSettings`.

#### 2d. Page-change callback

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

`TurnablePage.onPageChanged` delivers `(leftIndex, rightIndex)`. In `PageViewMode.single` the active page is `rightIndex` when non-negative, otherwise `leftIndex` (the last page).

#### 2e. TurnablePage instantiation

Replace `PageFlipWidget(...)` with:

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

#### 2f. Restoring saved reading position

After `_paginate()` resolves, call:

```dart
final target = widget.starterPageIndex.clamp(0, pages.length - 1);
if (target > 0) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _flipController.goToPage(target);
  });
}
```

When `rePaginate` is triggered by font/theme changes (not chapter loads), call `_flipController.goToPage(0)` instead — no `starterPageIndex` offset applies on a relayout.

#### 2g. Import changes

Add:

```dart
import 'package:turnable_page_plus/turnable_page.dart';
```

Remove:

```dart
import 'package:cosmos_epub/PageFlip/builders/builder.dart' as flip_cache;
import 'package:cosmos_epub/PageFlip/page_flip_widget.dart';
```

#### 2h. Remove screenshot pipeline remnant

In `_HighlightablePageState.onHighlightChanged`, remove:

```dart
flip_cache.imageData.clear();
```

The callback body becomes:

```dart
onHighlightChanged: () {
  if (mounted) setState(() {});
},
```

---

### 3. ShowEpub (`lib/show_epub.dart`)

#### 3a. Remove double-swipe workaround state

Delete these state variable declarations:

```dart
bool isLastPage = false;
int lastSwipe = 0;
int prevSwipe = 0;
```

Delete the helper method:

```dart
void _resetSwipeState() { ... }
```

#### 3b. Simplify boundary callbacks

`onLastPage` lambda inside `PagingWidget` construction becomes:

```dart
onLastPage: (index, totalPages) async {
  widget.onLastPage?.call(index);
  if (totalPages <= 1) {
    nextChapter();
  } else {
    nextChapter();
  }
},
```

Which simplifies to:

```dart
onLastPage: (index, totalPages) async {
  widget.onLastPage?.call(index);
  nextChapter();
},
```

`onFirstPageBack` becomes:

```dart
onFirstPageBack: (index, totalPages) {
  prevChapter();
},
```

`onPageFlip` removes its counter resets, keeping only the progress save and UI update:

```dart
onPageFlip: (currentPage, totalPages) {
  widget.onPageFlip?.call(currentPage, totalPages);
  bookProgress.setCurrentPageIndex(
    bookId,
    currentPage == totalPages - 1 ? 0 : currentPage,
  );
  updateUI();
},
```

No other changes to `ShowEpub`.

---

### 4. Delete lib/PageFlip/

The following files are deleted entirely. Nothing outside `lib/PageFlip/` imports them after the migration is complete:

| File | Reason |
|---|---|
| `lib/PageFlip/page_flip_widget.dart` | Replaced by `TurnablePage` |
| `lib/PageFlip/builders/builder.dart` | Screenshot pipeline root |
| `lib/PageFlip/builders/image.dart` | Screenshot image helper |
| `lib/PageFlip/builders/index.dart` | Barrel export |
| `lib/PageFlip/effects/flip_effect.dart` | Column render loop |

After deletion, no Dart file in `lib/` imports from `package:cosmos_epub/PageFlip/`.

---

## Data Models

No new data models are introduced. The only data-model change is the type of the navigation controller field in `_PagingWidgetState`:

| Field | Before | After |
|---|---|---|
| `_pageController` | `GlobalKey<PageFlipWidgetState>` | `PageFlipController` |

`FlipSettings` is a value type provided by `turnable_page_plus`; it is accepted as an optional input to `PagingWidget` and forwarded to `TurnablePage` after `copyWith(backgroundFillColor: ...)` is applied.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: pageCount matches pages list length

*For any* HTML content that produces N paginated pages, the `pageCount` argument passed to `TurnablePage` shall equal N.

**Validates: Requirements 2.2**

### Property 2: onLastPage fires exactly when the last page is active

*For any* page list of length N, when `_onPageChanged` is called with `newIndex == N - 1`, `onLastPage` shall be invoked; when called with any `newIndex < N - 1`, `onLastPage` shall not be invoked.

**Validates: Requirements 5.1, 5.3**

### Property 3: onFirstPageBack fires exactly when the first page is active

*For any* page list, when `_onPageChanged` is called with `newIndex == 0`, `onFirstPageBack` shall be invoked; when called with any `newIndex > 0`, `onFirstPageBack` shall not be invoked.

**Validates: Requirements 5.2, 5.4**

### Property 4: backgroundColor is always reflected in FlipSettings

*For any* background color supplied to `PagingWidget`, the `FlipSettings` produced by `_resolvedSettings()` shall have `backgroundFillColor` equal to that color, regardless of whether a caller-supplied `flipSettings` is present or the default is used.

**Validates: Requirements 8.1, 8.2**

### Property 5: starterPageIndex clamping

*For any* `starterPageIndex` value (including out-of-range values), the index passed to `_flipController.goToPage()` shall be in the range `[0, pages.length - 1]` — never negative and never out of bounds.

**Validates: Requirements 3.2**

---

## Error Handling

| Scenario | Handling |
|---|---|
| `pages` is empty after pagination | Existing `if (pages.isEmpty) return const Center(child: Text('No content'))` guard remains; `TurnablePage` is never constructed with `pageCount: 0` |
| `starterPageIndex` out of range | Clamped to `[0, pages.length - 1]` before calling `goToPage` |
| `_flipController.goToPage` called before widget mounts | Wrapped in `addPostFrameCallback` so the call is deferred until the widget tree is laid out |
| `flipSettings.copyWith` unavailable | The design assumes `turnable_page_plus ^1.0.0` provides `FlipSettings.copyWith`; if not available the fallback is a direct field assignment using a new `FlipSettings(...)` constructor call with all fields explicit |
| `onPageChanged` rightIndex is -1 | `_onPageChanged` falls back to `leftIndex` so the active page is always deterministic |

---

## Testing Strategy

PBT applies here because `_onPageChanged` and `_resolvedSettings` are pure transformation functions whose correctness varies meaningfully with input (page count, page index, background color, starterPageIndex). The five properties above are implemented as property-based tests.

Infrastructure concerns (pub dependency resolution, file deletion) are verified by smoke and integration checks, not property tests.

**Property-based testing library**: [`dart_mappable`](https://pub.dev/packages/dart_mappable) is already in the ecosystem, but for PBT the standard Dart choice is [`dart_check`](https://pub.dev/packages/dart_check) (a QuickCheck-style library). Each property test runs a minimum of 100 iterations.

**Tag format**: Each property test is annotated with a comment:  
`// Feature: turnable-page-plus-integration, Property N: <property_text>`

### Unit tests

- `_resolvedSettings()` returns `FlipSettings` with `backgroundFillColor` matching `backgroundColor` when no `flipSettings` is supplied
- `_resolvedSettings()` applies `copyWith` over a caller-supplied `FlipSettings`, preserving all caller fields except `backgroundFillColor`
- `_onPageChanged` invokes `onLastPage` when `newIndex == pages.length - 1`
- `_onPageChanged` invokes `onFirstPageBack` when `newIndex == 0`
- `_onPageChanged` does not invoke either boundary callback for mid-list pages
- `PageFlipController` is disposed when `PagingWidget` is disposed
- `onHighlightChanged` triggers `setState` without calling `imageData.clear()`

### Property-based tests

- **Property 1**: Generate random HTML snippets; verify `pageCount` equals `pages.length` after pagination
- **Property 2**: Generate random `(N, index)` pairs; verify `onLastPage` fires iff `index == N - 1`
- **Property 3**: Generate random `(N, index)` pairs; verify `onFirstPageBack` fires iff `index == 0`
- **Property 4**: Generate random `Color` values and optional `FlipSettings`; verify `_resolvedSettings().backgroundFillColor` always equals the supplied color
- **Property 5**: Generate random `starterPageIndex` integers (positive, zero, negative, larger than page count); verify clamped index is always in `[0, pages.length - 1]`

### Integration / smoke checks

- `flutter pub get` resolves without error after adding `turnable_page_plus: ^1.0.0`
- `lib/PageFlip/` directory and all its files are absent
- No file in `lib/` contains an import of `package:cosmos_epub/PageFlip/`
- `flip_cache.imageData.clear()` is absent from `_HighlightablePageState`
- `PagingWidget` and `ShowEpub` constructor signatures compile unchanged at all existing call sites
