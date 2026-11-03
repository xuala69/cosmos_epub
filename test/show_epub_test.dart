import 'dart:io';
import 'package:cosmos_epub/Helpers/progress_singleton.dart';
import 'package:cosmos_epub/Model/book_progress_model.dart';
import 'package:cosmos_epub/show_epub.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnable_page_plus/src/render/render_turnable_book.dart';

class _FakeProgress implements BookProgressSingleton {
  int page = 0;
  int chapter = 0;

  @override
  Future<bool> setCurrentChapterIndex(
    String bookId,
    int chapterIndex, {
    bool keepPage = false,
  }) async {
    chapter = chapterIndex;
    if (!keepPage) page = 0;
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

void main() {
  setUpAll(() async {
    bookProgress = _FakeProgress();
  });

  testWidgets('ShowEpub chapter navigation test', (tester) async {
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

    final bytes = await File('example/assets/book.epub').readAsBytes();
    final book = await EpubReader.readBook(bytes);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => ShowEpub(
              epubBook: book,
              accentColor: Colors.blue,
              bookId: 'test_book',
              chapterListTitle: 'Table of Contents',
            ),
          ),
        ),
      ),
    );

    // Pump until loaded
    for (int i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final bookFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
      );
      if (bookFinder.evaluate().isNotEmpty) break;
    }

    final state = tester.state<ShowEpubState>(find.byType(ShowEpub));
    debugPrint(
      'Initial chapterIndex=${bookProgress.getBookProgress('test_book').currentChapterIndex}',
    );

    // Let's find the next button in ShowEpub
    // In ShowEpub:
    // nextChapter() or controllerPaging.nextPage()
    debugPrint('Calling next on controllerPaging or next button');

    // Check if next button is present
    final iconButtons = find.byType(IconButton);
    debugPrint('Found ${iconButtons.evaluate().length} icon buttons');

    // Turn pages or chapters
    for (int step = 0; step < 10; step++) {
      debugPrint('=== Step $step ===');
      final curChapter =
          bookProgress.getBookProgress('test_book').currentChapterIndex ?? 0;
      final curPage =
          bookProgress.getBookProgress('test_book').currentPageIndex ?? 0;
      debugPrint('Current progress: chapter=$curChapter, page=$curPage');

      final bookFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
      );
      if (bookFinder.evaluate().isNotEmpty) {
        final renderBook = tester.renderObject<RenderTurnableBook>(bookFinder);
        debugPrint(
          'RenderBook: pageCount=${renderBook.pageCount}, current=${renderBook.pageFlip.getCurrentPageIndex()}',
        );
      } else {
        debugPrint('RenderBook NOT found (spinner visible?)');
      }

      // Try turning page
      final turned = state.controllerPaging.nextPage();
      debugPrint('nextPage() returned: $turned');
      if (!turned) {
        debugPrint('At end of chapter, calling nextChapter()');
        await state.nextChapter();
      }

      for (int i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
  });
}
