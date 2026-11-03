// Shared setup for the reader tests.
import 'dart:io';

import 'package:cosmos_epub/Helpers/progress_singleton.dart';
import 'package:cosmos_epub/Model/book_progress_model.dart';
import 'package:cosmos_epub/show_epub.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnable_page_plus/src/page/page_host.dart';
import 'package:turnable_page_plus/src/render/render_turnable_book.dart';

/// In-memory reading progress: (spine item, page in it).
class FakeProgress implements BookProgressSingleton {
  FakeProgress([this.chapter = 0, this.page = 0]);
  int chapter;
  int page;

  (int, int) get location => (chapter, page);

  @override
  Future<bool> setCurrentChapterIndex(
    String bookId,
    int chapterIndex, {
    bool keepPage = false,
  }) async {
    chapter = chapterIndex;
    return true;
  }

  @override
  Future<bool> setCurrentPageIndex(String bookId, int pageIndex) async {
    page = pageIndex;
    return true;
  }

  @override
  BookProgressModel getBookProgress(String bookId) =>
      BookProgressModel(currentPageIndex: page, currentChapterIndex: chapter);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// turnable_page_plus paints its shadows with a Canvas whose native peer is
/// not available under flutter_test; that error is unrelated to the reader.
void ignoreCanvasErrors() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains(
      'native peer has been collected',
    )) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

/// Reads an EPUB from disk. Real I/O, so outside the test's fake clock.
Future<EpubBook> readEpub(
  WidgetTester tester, [
  String path = 'example/assets/book.epub',
]) async => (await tester.runAsync(
  () async => EpubReader.readBook(await File(path).readAsBytes()),
))!;

/// The book's render object widget (not a public type).
final readerFinder = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
);

RenderTurnableBook bookRender(WidgetTester tester) =>
    tester.renderObject<RenderTurnableBook>(readerFinder);

/// Book-wide index of the page on screen.
int shownPage(WidgetTester tester) =>
    bookRender(tester).pageFlip.getCurrentPageIndex();

/// Text of book page [index], as drawn (soft hyphens removed).
String pageText(WidgetTester tester, int index) => tester
    .widgetList<RichText>(
      find.descendant(
        of: find.byWidgetPredicate((w) => w is PageHost && w.index == index),
        matching: find.byType(RichText),
      ),
    )
    .map((r) => r.text.toPlainText())
    .join(' ')
    .replaceAll('\u00AD', '');

Future<void> pumpFrames(WidgetTester tester, [int count = 90]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Runs [action] and lets the turn finish. Returns whether a page folded and
/// which book pages were revealed under the folding page meanwhile.
Future<({bool folded, Set<int> revealed})> turnWith(
  WidgetTester tester,
  void Function() action,
) async {
  action();
  var folded = false;
  final revealed = <int>{};
  for (var i = 0; i < 90; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final render = bookRender(tester);
    if (render.flippingPage != null) folded = true;
    final bottom = render.bottomPage;
    if (bottom != null) revealed.add((bottom as dynamic).index as int);
  }
  return (folded: folded, revealed: revealed);
}

/// Drags across the book from the right edge, by [fraction] of its width.
Future<void> swipe(WidgetTester tester, double fraction) async {
  final size = tester.getSize(readerFinder);
  final topLeft = tester.getTopLeft(readerFinder);
  final start = topLeft + Offset(size.width - 10, size.height / 2);
  final end = start - Offset(size.width * fraction, 0);
  final gesture = await tester.startGesture(start);
  for (var i = 1; i <= 10; i++) {
    await gesture.moveTo(Offset.lerp(start, end, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await pumpFrames(tester);
}

/// Pumps [ShowEpub] for [book] (book.epub by default) with [progress] as the
/// saved position. With [waitForWholeBook], returns once every spine item is
/// paginated; otherwise as soon as the first pages are on screen.
Future<ShowEpubState> openShowEpub(
  WidgetTester tester,
  FakeProgress progress, {
  EpubBook? book,
  int starterChapter = -1,
  bool waitForWholeBook = true,
  void Function(int currentPage, int totalPages)? onPageFlip,
  void Function(int lastPageIndex)? onLastPage,
}) async {
  ignoreCanvasErrors();
  bookProgress = progress;
  book ??= await readEpub(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => ShowEpub(
            epubBook: book!,
            accentColor: Colors.blue,
            bookId: 'test_book',
            chapterListTitle: 'Contents',
            starterChapter: starterChapter,
            onPageFlip: onPageFlip,
            onLastPage: onLastPage,
          ),
        ),
      ),
    ),
  );
  if (!waitForWholeBook) {
    while (readerFinder.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  } else {
    // The rest of the book is added one spine item per frame.
    var count = -1;
    for (var stable = 0; stable < 30;) {
      await tester.pump(const Duration(milliseconds: 16));
      if (readerFinder.evaluate().isEmpty) continue;
      final now = bookRender(tester).pageCount;
      stable = now == count ? stable + 1 : 0;
      count = now;
    }
  }
  return tester.state<ShowEpubState>(find.byType(ShowEpub));
}

/// Unmounts the reader, letting a running animation stop cleanly.
Future<void> closeReader(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 16));
}
