import 'package:cosmos_epub/Helpers/pagination.dart';
import 'package:cosmos_epub/Helpers/progress_singleton.dart';
import 'package:cosmos_epub/Model/book_progress_model.dart';
import 'package:cosmos_epub/show_epub.dart' as se;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnable_page_plus/src/render/render_turnable_book.dart';

class _FakeProgress implements BookProgressSingleton {
  int page = 0;
  @override
  Future<bool> setCurrentChapterIndex(
    String bookId,
    int chapterIndex, {
    bool keepPage = false,
  }) async => true;

  @override
  Future<bool> setCurrentPageIndex(String bookId, int pageIndex) async {
    page = pageIndex;
    return true;
  }

  @override
  BookProgressModel getBookProgress(String bookId) =>
      BookProgressModel(currentPageIndex: page, currentChapterIndex: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

String _html() => List.generate(
  60,
  (i) => '<p>Paragraph number $i with some text to fill the page.</p>',
).join();

Widget _host() => MaterialApp(
  home: Scaffold(
    body: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => PagingWidget(
        htmlContent: _html(),
        bookId: 'test',
        chapterTitle: 'Chapter',
        chapterIndex: 0,
        totalChapters: 1,
        style: const TextStyle(fontSize: 17),
        handlerCallback: (_) {},
        onTextTap: () {},
        onPageFlip: (_, _) {},
        onLastPage: (_, _) {},
      ),
    ),
  ),
);

Future<void> _pumpUntilBook(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  final bookFinder = find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
  );
  for (int i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (bookFinder.evaluate().isNotEmpty) break;
  }
}

void main() {
  se.bookProgress = _FakeProgress();

  testWidgets('forward swipe advances page index', (tester) async {
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

    await _pumpUntilBook(tester);
    final bookFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
    );
    final book = tester.renderObject<RenderTurnableBook>(bookFinder);
    final size = tester.getSize(bookFinder);
    debugPrint(
      'BEFORE: pages=${book.pageCount} current=${book.pageFlip.getCurrentPageIndex()}',
    );

    // Forward (next-page) swipe: right -> left.
    final start = Offset(size.width - 20, size.height / 2);
    final end = Offset(20, size.height / 2);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 16));
    for (int i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    // Let release animation finish.
    for (int i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugPrint(
      'AFTER forward swipe: pages=${book.pageCount} current=${book.pageFlip.getCurrentPageIndex()} state=${book.pageFlip.getState()}',
    );

    expect(
      book.pageFlip.getCurrentPageIndex(),
      1,
      reason: 'forward swipe should advance to page 1',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 16));
  });
}
