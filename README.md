# CosmosEpub 💫

**A comprehensive, feature-rich EPUB reader package for Flutter** with realistic page flip animations, text highlighting, intelligent hyphenation, infinite nested chapters, image support, RTL language detection, customizable themes and fonts.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Module Structure](#module-structure)
4. [Core Functionalities](#core-functionalities)
5. [Database & Storage](#database--storage)
6. [Usage Guide](#usage-guide)
7. [API Reference](#api-reference)
8. [Customization](#customization)
9. [RTL Language Support](#rtl-language-support)
10. [Adding New Features](#adding-new-features)
11. [Technical Notes](#technical-notes)
12. [License](#license)

---

## Overview

CosmosEpub is a Flutter package that provides a complete EPUB reading solution with:
- **Realistic 3D page flip animations** powered by `turnable_page_plus`
- **Text highlighting** with 6 color options and persistence
- **Intelligent hyphenation** with Uzbek digraph support
- **Infinite nested chapter support** with recursive TOC parsing
- **RTL language detection** for Arabic, Persian, Hebrew, Urdu, and more
- **Multiple EPUB sources**: assets, local files, URLs, raw bytes
- **5 theme colors** and **14 embedded fonts**
- **Reading progress tracking** with Isar database
- **Screen brightness control**
- **Responsive design** for phone, tablet, landscape, and portrait modes

---

## Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                           CosmosEpub Class                            │
│                    (Main Entry Point - cosmos_epub.dart)             │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   initialize()   │  │ openAssetBook()  │  │ openLocalBook()  │  │
│  │   openURLBook()  │  │ openFileBook()   │  │                 │  │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘  │
└───────────┼─────────────────────┼─────────────────────┼────────────┘
            │                     │                     │
            └─────────────────────┼─────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                         ShowEpub Widget                              │
│                      (Main Reader UI - show_epub.dart)             │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                      PagingWidget                             │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │  │
│  │  │  TurnablePage    │  │   PageWidget     │  │ Pagination   │  │  │
│  │  │  (3D flip engine)│  │ (_Highlightable) │  │  Logic      │  │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────┘  │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   AppBar         │  │  Bottom Controls │  │  Brightness     │  │
│  │ (Theme/Font/TOC)  │  │  (Prev/Next)      │  │  Slider         │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
          │                          │                          │
          ▼                          ▼                          ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Theme Settings   │  │ Chapter List     │  │ Highlight       │
│  (Modal Sheet)    │  │ (Drawer)         │  │ Toolbar         │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Data Flow

```
EPUB File (any source)
    ↓
EpubReader.readBook() → EpubBook Object
    ↓
EpubContentParser (Helpers/epub_content_parser.dart)
    ├─→ Extracts HTML content from chapters
    ├─→ Builds flat chapter list with infinite nesting
    ├─→ Extracts images and converts to base64
    ↓
HtmlPaginator (Helpers/html_paginator.dart)
    ├─→ Splits HTML into page-sized chunks
    ├─→ Measures text height using TextPainter
    ↓
HtmlTextBuilder (Helpers/html_text_builder.dart)
    ├─→ Converts HTML to Flutter widgets
    ├─→ Handles inline styling (bold, italic, etc.)
    ↓
SoftHyphenParagraph (Helpers/soft_hyphen_text.dart)
    ├─→ Resolves soft hyphens (\u00AD) to visible "-" at line breaks
    ├─→ Applies highlight backgrounds
    ↓
TurnablePage (from turnable_page_plus)
    ├─→ Renders pages with 3D flip animation
    ↓
User Interaction → Progress saved via BookProgressSingleton
```

---

## Module Structure

### Directory Structure

```
lib/
├── cosmos_epub.dart              # Main entry point with public API
├── show_epub.dart                # Main reader widget
│
├── Component/                    # Reusable UI components
│   ├── constants.dart            # Storage keys (libTheme, libFont, libFontSize)
│   ├── theme_colors.dart         # Theme color constants (cVioletishColor, cBluishColor, cPinkishColor)
│   ├── circle_button.dart        # Theme color selection buttons
│   └── highlight_toolbar.dart    # Color picker for text highlighting
│
├── Helpers/                     # Utility classes and services
│   ├── chapters.dart             # Table of Contents widget
│   ├── context_extensions.dart   # MediaQuery shortcuts and device detection
│   ├── custom_toast.dart         # Toast notification helper
│   ├── epub_content_parser.dart # EPUB parsing and chapter extraction
│   ├── functions.dart            # RTLHelper for language detection
│   ├── html_paginator.dart       # HTML content pagination
│   ├── html_text_builder.dart   # HTML to Flutter widget conversion
│   ├── isar_service.dart         # Isar database initialization
│   ├── pagination.dart           # Page management and PagingWidget
│   ├── progress_singleton.dart   # Reading progress management
│   └── soft_hyphen_text.dart     # Soft hyphen handling with highlighting
│
├── Model/                       # Data models
│   ├── book_progress_model.dart  # Isar model for reading progress (auto-generated .g.dart)
│   ├── chapter_model.dart        # LocalChapterModel for TOC structure
│   └── highlight_model.dart      # HighlightModel and HighlightStorage
│
└── assets/                      # Package assets
    ├── fonts/                    # 14 embedded font files
    └── ornament.svg              # Decorative SVG for TOC
```

### Module Descriptions

#### 1. **Core Module** (`cosmos_epub.dart`)
Main entry point providing the public API:
- `CosmosEpub.initialize()` - Initialize the reader
- `CosmosEpub.openAssetBook()` - Open EPUB from assets
- `CosmosEpub.openLocalBook()` - Open EPUB from local file
- `CosmosEpub.openURLBook()` - Open EPUB from URL
- `CosmosEpub.openFileBook()` - Open EPUB from bytes
- Progress management methods
- Highlight management methods
- Theme cache management

#### 2. **Reader UI Module** (`show_epub.dart`)
Main reader widget (`ShowEpub`) that:
- Loads and displays EPUB content
- Manages theme, font, and brightness settings
- Handles chapter navigation
- Coordinates with PagingWidget for page rendering
- Provides app bar with menu, font settings, and brightness control

#### 3. **Pagination Module** (`Helpers/pagination.dart`)
Handles page creation and management:
- `PagingWidget` - Main widget for displaying paginated content
- `PagingTextHandler` - Callback handlers for page navigation
- `_PagingWidgetState` - Manages pagination state and logic
- `_HighlightablePage` - Individual page with highlight support
- `_TapDetector` - Detects taps without interfering with flip gestures

Key features:
- Dynamic pagination based on screen size
- Automatic re-pagination on font size or orientation change
- Position tracking across page regeneration
- Integration with TurnablePage for flip animation

#### 4. **EPUB Parsing Module** (`Helpers/epub_content_parser.dart`)
Responsible for EPUB content extraction:
- `EpubContentParser` - Main parser class
- **Three-tier chapter resolution**:
  1. NCX NavMap with recursive ChildNavigationPoints (handles nested TOCs)
  2. Falls back to epubx Chapters
  3. Falls back to spine order
- Image extraction and base64 conversion
- Image resolution in HTML content

#### 5. **HTML Processing Module**
- `HtmlPaginator` (`Helpers/html_paginator.dart`):
  - Splits HTML into page-sized chunks
  - Measures block heights using TextPainter
  - Handles various HTML tags (headings, blockquotes, lists, etc.)
  - Estimates image heights
  
- `HtmlTextBuilder` (`Helpers/html_text_builder.dart`):
  - Converts HTML to Flutter widgets
  - Builds TextSpan trees from HTML
  - Applies inline styling (bold, italic, underline, etc.)
  - Handles block-level elements with appropriate padding
  - Supports highlight overlay

#### 6. **Soft Hyphen Module** (`Helpers/soft_hyphen_text.dart`)
- `SoftHyphenParagraph` - Widget that:
  - Resolves soft hyphens (\u00AD) to visible "-" at line breaks
  - Applies stored highlights as colored backgrounds
  - Uses LayoutBuilder for accurate measurement
  - Verifies hyphen placement to avoid mid-line hyphens

Special feature: **Uzbek digraph support**
- Never breaks digraphs like "ch", "sh", "g'", "o'"
- Respects vowel/consonant patterns for syllable-aware breaking

#### 7. **RTL Support Module** (`Helpers/functions.dart`)
- `RTLHelper` - Utility class for RTL language support
- Detects RTL characters using Unicode ranges:
  - Arabic (0x0600-0x06FF, 0x0750-0x077F, 0x08A0-0x08FF, 0xFB50-0xFDFF, 0xFE70-0xFEFF)
  - Hebrew (0x0590-0x05FF, 0xFB1D-0xFB4F)
  - Syriac (0x0700-0x074F)
  - Dhivehi/Thaana (0x0780-0x07BF)
  - Yiddish
- Auto-detects text direction based on character ratio
- Adjusts UI for RTL (navigation buttons, text alignment)

#### 8. **Database & Storage Module**
- `IsarService` (`Helpers/isar_service.dart`):
  - Initializes Isar database
  - Uses `isar_community` for cross-platform support
  - Database name: 'cosmos_epub'
  - Stores: BookProgressModel

- `BookProgressSingleton` (`Helpers/progress_singleton.dart`):
  - Manages reading progress CRUD operations
  - Methods: setCurrentChapterIndex, setCurrentPageIndex, getBookProgress, deleteBookProgress, deleteAllBooksProgress
  - Uses Isar for persistence

- `HighlightStorage` (in `Model/highlight_model.dart`):
  - Stores highlights using GetStorage
  - Key: 'cosmos_highlights_v2'
  - Methods: getBookHighlights, getParagraphHighlights, addOrUpdate, removeHighlight, removeAllForBook
  - Uses JSON serialization for storage

#### 9. **Model Module**
- `BookProgressModel` (`Model/book_progress_model.dart`):
  - Isar collection model
  - Fields: localId (auto-increment), bookId, currentChapterIndex, currentPageIndex

- `LocalChapterModel` (`Model/chapter_model.dart`):
  - Represents a chapter in the TOC
  - Fields: chapter (title), depth, htmlContent, isSectionTitle

- `HighlightModel` (`Model/highlight_model.dart`):
  - Represents a text highlight
  - Fields: id, bookId, chapterIndex, paragraphKey, startIndex, endIndex, selectedText, colorValue
  - Includes serialization (toJson/fromJson)
  - Helper methods: generateId(), makeParagraphKey()

#### 10. **UI Components Module**
- `ChaptersList` (`Helpers/chapters.dart`):
  - Displays Table of Contents
  - Shows nested chapters with indentation
  - Allows chapter selection
  - Detects RTL for proper alignment

- `HighlightToolbar` (`Component/highlight_toolbar.dart`):
  - Color picker for text highlighting
  - 6 color options: Yellow, Green, Blue, Red, Orange, Purple
  - Dismiss button

- `CircleButton` (`Component/circle_button.dart`):
  - Theme color selection button
  - Shows border when selected

- `CustomToast` (`Helpers/custom_toast.dart`):
  - Shows toast notifications
  - Uses fluttertoast package

---

## Core Functionalities

### 1. EPUB Loading
The package supports loading EPUB files from multiple sources:

```dart
// From Flutter assets
await CosmosEpub.openAssetBook(
  assetPath: 'assets/book.epub',
  context: context,
  bookId: 'book_1',
);

// From local file system
await CosmosEpub.openLocalBook(
  localPath: '/path/to/book.epub',
  context: context,
  bookId: 'book_2',
);

// From URL
await CosmosEpub.openURLBook(
  urlPath: 'https://example.com/book.epub',
  context: context,
  bookId: 'book_3',
);

// From raw bytes
await CosmosEpub.openFileBook(
  bytes: myUint8List,
  context: context,
  bookId: 'book_4',
);
```

**Note**: Each book must have a unique `bookId`. Reusing the same ID for different books will cause progress conflicts.

### 2. Reading Progress Tracking
Progress is automatically saved and restored:

```dart
// Get current progress
BookProgressModel progress = CosmosEpub.getBookProgress('book_1');
print('Chapter: ${progress.currentChapterIndex}');
print('Page: ${progress.currentPageIndex}');

// Set progress manually
await CosmosEpub.setCurrentChapterIndex('book_1', 5);
await CosmosEpub.setCurrentPageIndex('book_1', 10);

// Delete progress
await CosmosEpub.deleteBookProgress('book_1');
await CosmosEpub.deleteAllBooksProgress();
```

**Database**: Uses Isar (via `isar_community`) for progress persistence. Only works on Android/iOS/Desktop (no web support).

### 3. Text Highlighting
Users can select text and highlight it with one of 6 colors:

```dart
// Get all highlights for a book
List<HighlightModel> highlights = CosmosEpub.getBookHighlights('book_1');

// Remove a specific highlight
CosmosEpub.removeHighlight(highlights.first.id);

// Remove all highlights for a book
CosmosEpub.removeAllHighlights('book_1');
```

**Storage**: Highlights are stored locally via GetStorage and persist across app restarts.

**Highlight Colors**:
- Yellow (0xFFFFEB3B)
- Green (0xFF81C784)
- Blue (0xFF64B5F6)
- Red (0xFFE57373)
- Orange (0xFFFFAB91)
- Purple (0xFFCE93D8)

### 4. Theme System
5 color themes available:
1. Violetish (cVioletishColor: 0xffe4e4ff)
2. Bluish (cBluishColor: 0xffE2E5EA)
3. White (Colors.white)
4. Black (Colors.black)
5. Pinkish (cPinkishColor: 0xffffdedb)

14 embedded fonts:
- Segoe
- Alegreya
- Amazon Ember
- Atkinson Hyperlegible
- Bitter Pro
- Bookerly
- Droid Sans
- EB Garamond
- Gentium Book Plus
- Halant
- IBM Plex Sans
- LinLibertine
- Literata
- Lora
- Ubuntu

```dart
// Clear cached theme, font, and font size
await CosmosEpub.clearThemeCache();
```

### 5. Chapter Navigation
- Infinite nested chapter support
- Table of Contents with proper indentation
- Previous/Next chapter navigation
- Auto-opens to last read position
- Section title pages for TOC sections

### 6. Page Flip Animation
- Realistic 3D page curl effect
- Swipe gestures for page turning
- Animated page transitions
- Configurable flip settings (duration, sensitivity, etc.)

### 7. Hyphenation
- Syllable-aware word breaking for justified text
- Visible "-" at line breaks
- Special handling for Uzbek digraphs:
  - ch, sh, g', o', ҳ, ў, Ч, Ш, Ғ, О, CH, SH, G', O', Ғ, О
  - Prevents breaking within digraphs

### 8. RTL Language Support
Automatic detection and support for:
- Arabic (العربية)
- Persian/Farsi (فارسی)
- Hebrew (עברית)
- Urdu (اردو)
- Pashto (پښتو)
- Sindhi (سنڌي)
- Kurdish (کوردی)
- Dhivehi (ދިވެހި)
- Yiddish (ייִדיש)

Features:
- Auto-detects text direction
- Adjusts UI layout (navigation buttons swap, text alignment)
- Proper character display
- Works with mixed LTR/RTL content

### 9. Image Support
- EPUB images rendered inline
- Supported formats: PNG, JPEG, GIF, SVG, WebP, BMP
- Images converted to base64 data URIs
- Automatic resolution of image paths
- Height estimation for pagination

### 10. Brightness Control
- In-reader brightness slider
- Accessible from the app bar
- System brightness adjustment
- Auto-hide after 7 seconds

---

## Database & Storage

### Isar Database
**Purpose**: Stores reading progress (chapter and page positions)

**Setup** (`Helpers/isar_service.dart`):
```dart
class IsarService {
  static Future<Isar> buildIsarService() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [BookProgressModelSchema],
      name: 'cosmos_epub',
      directory: dir.path,
    );
  }
}
```

**Model** (`Model/book_progress_model.dart`):
```dart
@collection
@Name("BookProgressModel")
class BookProgressModel {
  Id localId = Isar.autoIncrement;
  String? bookId;
  int? currentChapterIndex;
  int? currentPageIndex;
}
```

**Operations** (`Helpers/progress_singleton.dart`):
- `setCurrentChapterIndex(bookId, index)` - Update chapter position
- `setCurrentPageIndex(bookId, index)` - Update page position
- `getBookProgress(bookId)` - Retrieve progress for a book
- `deleteBookProgress(bookId)` - Remove progress for a book
- `deleteAllBooksProgress()` - Remove all progress data

### GetStorage
**Purpose**: Stores user preferences and highlights

**Theme/Font Settings** (`Component/constants.dart`):
```dart
const String libTheme = "lib_theme";        // Theme ID (1-5)
const String libFont = "lib_font";          // Font family name
const String libFontSize = "lib_font_settings";  // Font size (15.0-30.0)
```

**Highlights Storage** (`Model/highlight_model.dart`):
```dart
class HighlightStorage {
  static const _key = 'cosmos_highlights_v2';
  static final _gs = GetStorage();
  
  // Methods: getBookHighlights, getParagraphHighlights, addOrUpdate
  //          removeHighlight, removeAllForBook, _readAll, _writeAll
}
```

**Format**: JSON array of HighlightModel objects with all fields serialized.

---

## Usage Guide

### Quick Start

1. **Add dependency** to `pubspec.yaml`:
```yaml
dependencies:
  cosmos_epub: ^1.0.1
```

2. **Run**:
```bash
flutter pub get
```

3. **Initialize** in your `main.dart`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CosmosEpub.initialize();
  runApp(MyApp());
}
```

4. **Open a book**:
```dart
ElevatedButton(
  onPressed: () async {
    await CosmosEpub.openAssetBook(
      assetPath: 'assets/book.epub',
      context: context,
      bookId: 'my_book',
      accentColor: Colors.indigoAccent,
      onPageFlip: (currentPage, totalPages) {
        print('Page $currentPage of $totalPages');
      },
      onLastPage: (lastPageIndex) {
        print('Reached last page of chapter');
      },
    );
  },
  child: Text('Open Book'),
)
```

### Full Example

```dart
import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CosmosEpub.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My EPUB Reader',
      home: BookListScreen(),
    );
  }
}

class BookListScreen extends StatelessWidget {
  final List<BookInfo> books = [...];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Library')),
      body: ListView.builder(
        itemCount: books.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(books[index].title),
            onTap: () => _openBook(context, books[index]),
          );
        },
      ),
    );
  }

  void _openBook(BuildContext context, BookInfo book) async {
    await CosmosEpub.openAssetBook(
      assetPath: book.assetPath,
      context: context,
      bookId: book.id,
      accentColor: Colors.blueAccent,
      chapterListTitle: 'Contents',
      shouldOpenDrawer: true,  // Open TOC on start
      onPageFlip: (current, total) {
        // Update your own progress tracking if needed
      },
    );
  }
}
```

---

## API Reference

### CosmosEpub Class

#### Initialization

```dart
static Future<bool> initialize() async
```
Initialize the reader. Must be called once before using any other methods.

**Returns**: `true` on success

#### Opening Books

```dart
static Future<void> openAssetBook({
  required String assetPath,
  required BuildContext context,
  required String bookId,
  Color accentColor = Colors.indigoAccent,
  Function(int currentPage, int totalPages)? onPageFlip,
  Function(int lastPageIndex)? onLastPage,
  String chapterListTitle = 'Table of Contents',
  bool shouldOpenDrawer = false,
  int starterChapter = -1,
}) async
```
Open an EPUB from Flutter assets.

**Parameters**:
- `assetPath`: Path to EPUB file in assets
- `context`: BuildContext for navigation
- `bookId`: Unique identifier for this book (used for progress tracking)
- `accentColor`: Primary accent color for the reader
- `onPageFlip`: Callback when user flips a page (currentPage, totalPages)
- `onLastPage`: Callback when user reaches the last page of a chapter
- `chapterListTitle`: Title for the Table of Contents screen
- `shouldOpenDrawer`: Whether to automatically open the TOC on start
- `starterChapter`: Chapter index to start at (-1 for last read position)

```dart
static Future<void> openLocalBook({
  required String localPath,
  required BuildContext context,
  required String bookId,
  Color accentColor = Colors.indigoAccent,
  Function(int currentPage, int totalPages)? onPageFlip,
  Function(int lastPageIndex)? onLastPage,
  String chapterListTitle = 'Table of Contents',
  bool shouldOpenDrawer = false,
  int starterChapter = -1,
}) async
```
Open an EPUB from local file system.

```dart
static Future<void> openURLBook({
  required String urlPath,
  required BuildContext context,
  required String bookId,
  Color accentColor = Colors.indigoAccent,
  Function(int currentPage, int totalPages)? onPageFlip,
  Function(int lastPageIndex)? onLastPage,
  String chapterListTitle = 'Table of Contents',
  bool shouldOpenDrawer = false,
  int starterChapter = -1,
}) async
```
Open an EPUB from a URL.

```dart
static Future<void> openFileBook({
  required Uint8List bytes,
  required BuildContext context,
  required String bookId,
  Color accentColor = Colors.indigoAccent,
  Function(int currentPage, int totalPages)? onPageFlip,
  Function(int lastPageIndex)? onLastPage,
  String chapterListTitle = 'Table of Contents',
  bool shouldOpenDrawer = false,
  int starterChapter = -1,
}) async
```
Open an EPUB from raw bytes.

#### Progress Management

```dart
static BookProgressModel getBookProgress(String bookId)
```
Get the reading progress for a book.

**Returns**: `BookProgressModel` with currentChapterIndex and currentPageIndex

```dart
static Future<bool> setCurrentPageIndex(String bookId, int index) async
```
Set the current page index for a book.

**Returns**: `true` on success

```dart
static Future<bool> setCurrentChapterIndex(String bookId, int index) async
```
Set the current chapter index for a book.

**Returns**: `true` on success

```dart
static Future<bool> deleteBookProgress(String bookId) async
```
Delete reading progress for a specific book.

**Returns**: `true` on success

```dart
static Future<bool> deleteAllBooksProgress() async
```
Delete reading progress for all books.

**Returns**: `true` on success

#### Highlight Management

```dart
static List<HighlightModel> getBookHighlights(String bookId)
```
Get all highlights for a book.

**Returns**: List of `HighlightModel` objects

```dart
static void removeHighlight(String highlightId)
```
Remove a specific highlight by its ID.

```dart
static void removeAllHighlights(String bookId)
```
Remove all highlights for a book.

#### Theme Management

```dart
static Future<bool> clearThemeCache() async
```
Clear cached theme, font, and font size preferences.

**Returns**: `true` on success

---

## Customization

### Themes

The package provides 5 built-in themes. Users can select them via the font settings modal:

```dart
// Theme IDs:
// 1 = Violetish (0xffe4e4ff)
// 2 = Bluish (0xffE2E5EA)
// 3 = White (Colors.white)
// 4 = Black (Colors.black)
// 5 = Pinkish (0xffffdedb)
```

Themes affect:
- Background color
- Text color (automatically adjusted for contrast)
- Accent color (from parameters)

### Fonts

14 embedded fonts are available. Users can select them via the font settings modal:

```dart
List<String> fontNames = [
  "Segoe",
  "Alegreya",
  "Amazon Ember",
  "Atkinson Hyperlegible",
  "Bitter Pro",
  "Bookerly",
  "Droid Sans",
  "EB Garamond",
  "Gentium Book Plus",
  "Halant",
  "IBM Plex Sans",
  "LinLibertine",
  "Literata",
  "Lora",
  "Ubuntu",
];
```

Font sizes can be adjusted from 15.0 to 30.0 using the slider in the font settings modal.

### Adding Custom Fonts

To add a custom font:
1. Add the font file to your project's assets
2. Update `pubspec.yaml` to include the font
3. Add the font name to the `fontNames` list in `show_epub.dart`

### Customizing Flip Animation

The flip animation uses `turnable_page_plus` package. You can customize it by passing `flipSettings` to `PagingWidget`:

```dart
FlipSettings(
  enableInertia: true,
  enableEasing: true,
  flippingTime: 650,        // Animation duration in milliseconds
  swipeDistance: 48,        // Minimum swipe distance to trigger flip
  releaseCompletionThreshold: 0.38,  // How far to swipe before auto-complete
  cornerTriggerAreaSize: 0.25,      // Corner tap area size
)
```

### Customizing Colors

To change the default colors:
1. Modify `Component/theme_colors.dart` for theme colors
2. Modify `Component/highlight_toolbar.dart` for highlight colors
3. Pass custom `accentColor` when opening a book

---

## RTL Language Support 🌍

The package automatically detects and supports RTL languages. No configuration needed.

### Supported Languages

- **Arabic** (العربية) - `ar`
- **Persian/Farsi** (فارسی) - `fa`
- **Hebrew** (עברית) - `he`
- **Urdu** (اردو) - `ur`
- **Pashto** (پښتو) - `ps`
- **Sindhi** (سنڌي) - `sd`
- **Kurdish** (کوردی) - `ku`
- **Sorani Kurdish** (کوردی) - `ckb`
- **Dhivehi/Maldivian** (ދިވެހި) - `dv`
- **Yiddish** (ייִדיש) - `yi`

### Detection Method

The `RTLHelper` class uses Unicode character ranges to detect RTL text:
- Hebrew: 0x0590-0x05FF, 0xFB1D-0xFB4F
- Arabic: 0x0600-0x06FF, 0x0750-0x077F, 0x08A0-0x08FF, 0xFB50-0xFDFF, 0xFE70-0xFEFF
- Syriac: 0x0700-0x074F
- Thaana (Dhivehi): 0x0780-0x07BF

Text is considered RTL if more than 30% of its characters are RTL characters.

### UI Adjustments for RTL

- Navigation buttons swap positions (left becomes next, right becomes previous)
- Text alignment adjusts to right-aligned
- Chapter list indentation adjusts
- TOC drawer properly handles RTL

---

## Adding New Features

This section is specifically for AI/developers who need to extend the package.

### Architecture Guidelines

1. **Keep it modular**: Each feature should be in its own file/helper
2. **Separation of concerns**: UI, business logic, and data should be separate
3. **Use existing patterns**: Follow the current code style and structure
4. **Document changes**: Update this README for new features

### Common Integration Points

#### 1. Adding New Book Source

To support a new EPUB source (e.g., from cloud storage):

1. Add a new method to `CosmosEpub` class:
```dart
static Future<void> openCloudBook({
  required String cloudPath,
  required BuildContext context,
  required String bookId,
  // ... other parameters
}) async {
  // Download the file
  final bytes = await cloudStorage.download(cloudPath);
  
  // Reuse existing logic
  EpubBook epubBook = await EpubReader.readBook(bytes);
  
  if (!context.mounted) return;
  _openBook(
    context: context,
    epubBook: epubBook,
    bookId: bookId,
    // ... other parameters
  );
}
```

2. The `_openBook` method is private and handles the common logic for all sources.

#### 2. Adding New Theme

To add a new theme:

1. Add color constant to `Component/theme_colors.dart`:
```dart
const cNewColor = Color(0xFF...);
```

2. Update theme selection in `show_epub.dart`:
- Add new theme ID constant
- Update `updateTheme` method
- Update theme button in font settings modal

3. Update theme IDs in `Component/constants.dart` if needed

#### 3. Adding New Font

To add a new embedded font:

1. Add font file to `assets/fonts/`

2. Update `pubspec.yaml`:
```yaml
flutter:
  fonts:
    - family: MyNewFont
      fonts:
        - asset: assets/fonts/MyNewFont-Regular.ttf
```

3. Add font name to `fontNames` list in `show_epub.dart`

4. Ensure font is included in package assets

#### 4. Adding New Feature (e.g., Bookmarks)

To add bookmarks:

1. Create new model in `Model/bookmark_model.dart`:
```dart
class BookmarkModel {
  final String id;
  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final String title;
  final DateTime createdAt;
  
  // Serialization methods
}

class BookmarkStorage {
  // CRUD operations
}
```

2. Add public API to `CosmosEpub` class:
```dart
// Add bookmark
static Future<bool> addBookmark(String bookId, int chapterIndex, int pageIndex) async

// Get bookmarks
static List<BookmarkModel> getBookmarks(String bookId)

// Remove bookmark
static Future<bool> removeBookmark(String bookmarkId) async
```

3. Add UI for managing bookmarks:
- Create new widget in `Component/` or `Helpers/`
- Add button to reader UI
- Implement bookmark list screen

4. Update initialization if needed

#### 5. Adding New Highlight Feature

To add a new highlight feature (e.g., underline highlights):

1. Extend `HighlightModel`:
```dart
class HighlightModel {
  // ... existing fields
  bool isUnderline;  // New field
  
  // Update serialization
}
```

2. Update `HighlightStorage` to handle new field

3. Update `SoftHyphenParagraph` to render underline highlights

4. Add underline option to `HighlightToolbar`

5. Update highlight creation logic

#### 6. Adding Text-to-Speech

To add TTS support:

1. Add dependency to `pubspec.yaml`:
```yaml
dependencies:
  flutter_tts: ^3.6.3
```

2. Create TTS helper in `Helpers/tts_helper.dart`:
```dart
class TTSHelper {
  static final FlutterTts _tts = FlutterTts();
  
  static Future<void> speak(String text) async {
    await _tts.speak(text);
  }
  
  static Future<void> stop() async {
    await _tts.stop();
  }
  
  static Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }
  
  static Future<void> setRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }
}
```

3. Add TTS controls to reader UI:
- Add play/pause/stop buttons
- Add speed control
- Add language selection

4. Add highlight tracking for TTS:
- Highlight current word/sentence being read
- Sync TTS position with reading progress

### Key Files to Modify

| Feature Type | Key Files |
|-------------|-----------|
| New book source | `cosmos_epub.dart` |
| New theme/color | `Component/theme_colors.dart`, `show_epub.dart` |
| New font | `pubspec.yaml`, `show_epub.dart` |
| New UI component | `Component/` or `Helpers/` directory |
| New data model | `Model/` directory |
| New storage | `Helpers/` directory or extend existing |
| New UI feature | `show_epub.dart`, `pagination.dart` |
| New text processing | `html_text_builder.dart`, `soft_hyphen_text.dart` |
| EPUB parsing | `epub_content_parser.dart` |
| Progress tracking | `progress_singleton.dart`, `book_progress_model.dart` |

### Important Considerations

1. **State Management**: The package uses a mix of:
   - SetState for local widget state
   - Singleton pattern for global state (BookProgressSingleton, bookProgress global variable)
   - GetStorage for persistent preferences
   - Isar for structured data

2. **Performance**:
   - Pagination is expensive - cache results when possible
   - Image loading can be slow - consider lazy loading
   - Text measurement (TextPainter) is used extensively for pagination

3. **RTL Support**:
   - Always use `RTLHelper.getTextDirection()` for text
   - Use `Directionality` widget when needed
   - Remember that navigation buttons swap in RTL mode

4. **Responsive Design**:
   - Uses `flutter_screenutil` for responsive sizing
   - Check `context.isTablet`, `context.isPhone` for device type
   - Handle both portrait and landscape orientations

5. **Error Handling**:
   - Handle malformed EPUBs gracefully
   - Provide fallback parsing strategies
   - Show user-friendly error messages

### Testing New Features

1. Create test file in `test/` directory
2. Test with various EPUB files
3. Test on different screen sizes
4. Test in both LTR and RTL modes
5. Test with different fonts and themes
6. Test persistence across app restarts

---

## Technical Notes

### Dependencies

The package uses the following dependencies:

| Package | Purpose | Version |
|---------|---------|---------|
| flutter | Flutter SDK | SDK |
| epubx | EPUB parsing | ^4.0.0 |
| html | HTML parsing | ^0.15.4 |
| http | HTTP requests for URL books | ^1.1.0 |
| isar_community | Database for progress | ^3.3.2 |
| isar_community_flutter_libs | Isar Flutter libs | ^3.3.2 |
| get_storage | Local storage for highlights/preferences | ^2.1.1 |
| path_provider | Directory access | ^2.1.3 |
| flutter_screenutil | Responsive design | ^5.9.0 |
| flutter_svg | SVG rendering | ^2.2.3 |
| fading_edge_scrollview | Fading edge effect | ^4.1.1 |
| screen_brightness | Brightness control | ^2.1.11 |
| fluttertoast | Toast notifications | ^10.0.2 |
| turnable_page_plus | 3D page flip animation | ^1.0.0 |

### Platform Support

| Platform | Progress Tracking | Highlights | All Features |
|----------|------------------|------------|--------------|
| Android | ✅ Yes | ✅ Yes | ✅ Yes |
| iOS | ✅ Yes | ✅ Yes | ✅ Yes |
| macOS | ✅ Yes | ✅ Yes | ✅ Yes |
| Windows | ✅ Yes | ✅ Yes | ✅ Yes |
| Linux | ✅ Yes | ✅ Yes | ✅ Yes |
| Web | ❌ No (Isar) | ✅ Yes | ⚠️ Partial |

**Note**: Isar database does not support web. For web builds, progress tracking will not work, but highlights (using GetStorage) should still work.

### Performance Optimizations

1. **Pagination Caching**: Pages are regenerated when:
   - Content changes
   - Font size changes
   - Font family changes
   - Text scale changes
   - Screen size/orientation changes

2. **Image Handling**:
   - Images are extracted once and cached in memory
   - Images are converted to base64 for inline rendering
   - Image heights are estimated for pagination

3. **Text Measurement**:
   - Uses TextPainter for accurate measurement
   - Caches measurements where possible
   - Accounts for soft hyphens and special characters

4. **Lazy Loading**:
   - Chapters are loaded on demand
   - Only current chapter is paginated
   - Previous/next chapters loaded when navigating

### Known Limitations

1. **No Web Support for Isar**: Reading progress won't persist on web
2. **Memory Usage**: Large EPUBs with many images can use significant memory
3. **Pagination Time**: First load of a chapter can take time for large chapters
4. **Text Selection**: Cross-paragraph text selection has some limitations
5. **Image Formats**: Not all EPUB image formats may be supported

### Error Handling

The package handles various error scenarios:
- Malformed EPUB files (3-tier fallback parsing)
- Missing chapters (generates placeholder)
- Missing images (skips gracefully)
- Database errors (returns default values)
- Storage errors (falls back to defaults)

---

## Troubleshooting

### Common Issues

**1. Pages not displaying**
- Check that `CosmosEpub.initialize()` was called
- Verify EPUB file is valid
- Check for errors in console

**2. Progress not saving**
- Verify unique `bookId` is used
- Check Isar initialization
- Ensure running on supported platform (not web)

**3. Highlights not showing**
- Verify GetStorage is initialized
- Check highlight data in storage
- Ensure bookId matches

**4. RTL not working**
- Verify text contains RTL characters
- Check Unicode ranges in RTLHelper
- Test with known RTL text

**5. Images not displaying**
- Verify image paths in EPUB
- Check image format support
- Test with simple EPUB first

### Debugging

The package now includes comprehensive debug logging throughout the entire flow. Enable it by running:
```bash
flutter run --verbose
```

Or filter for package-specific logs:
```bash
flutter run 2>&1 | grep -E "\[CosmosEpub\]|\[SHOW_EPUB\]|\[PAGINATE\]|\[HTML_PAGINATOR\]|\[EPUB_PARSER\]"
```

**Log Tags:**
- `[CosmosEpub]` - Book opening process
- `[SHOW_EPUB]` - Chapter loading and UI interactions
- `[EPUB_PARSER]` - EPUB parsing and chapter extraction
- `[PAGINATE]` - Page creation and flipping logic
- `[HTML_PAGINATOR]` - HTML block processing and pagination

**Common Issues Identified by Logs:**

1. **No pages created** - Check for `[PAGINATE] RenderBox has no size yet` - pagination is being called before layout
2. **Only 1 page** - Check `[HTML_PAGINATOR] Generated 1 pages` - content fits on one page or HTML is very short
3. **Empty content** - Check `[SHOW_EPUB] Chapter HTML length: 0` - chapter content couldn't be extracted

For more details, see [DEBUG_LOG_GUIDE.md](DEBUG_LOG_GUIDE.md).

Check Isar database:
```dart
final isar = await IsarService.buildIsarService();
final allProgress = await isar.bookProgressModels.where().findAll();
print('All progress: $allProgress');
```

Check GetStorage:
```dart
final storage = GetStorage();
final highlights = storage.read<String>('cosmos_highlights_v2');
print('Highlights: $highlights');
```

---

## License

BSD-3 License

See [LICENSE](LICENSE) file for details.

---

## Contact & Support

- **GitHub**: [https://github.com/Mamasodikov/cosmos_epub](https://github.com/Mamasodikov/cosmos_epub)
- **Issues**: [https://github.com/Mamasodikov/cosmos_epub/issues](https://github.com/Mamasodikov/cosmos_epub/issues)
- **Author**: Mamasodikov
- **Links**: [https://allmylinks.com/mamasodikov](https://allmylinks.com/mamasodikov)

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Update tests and documentation
5. Submit a pull request

---

*Last updated: 2026-10-21 (Added comprehensive debug logging and pagination retry fixes)
