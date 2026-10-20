import 'package:cosmos_epub/Helpers/pagination.dart';
import 'package:cosmos_epub/Helpers/progress_singleton.dart';
import 'package:cosmos_epub/Model/book_progress_model.dart';
import 'package:cosmos_epub/show_epub.dart' as se;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnable_page_plus/src/render/render_turnable_book.dart';

class _FakeProgress implements BookProgressSingleton {
  @override
  Future<bool> setCurrentChapterIndex(
    String bookId,
    int chapterIndex, {
    bool keepPage = false,
  }) async => true;

  @override
  Future<bool> setCurrentPageIndex(String bookId, int pageIndex) async => true;

  @override
  BookProgressModel getBookProgress(String bookId) =>
      BookProgressModel(currentPageIndex: 0, currentChapterIndex: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

String _html() => List.generate(
  60,
  (i) => '<p>Paragraph number $i with some text to fill the page.</p>',
).join();

void main() {
  se.bookProgress = _FakeProgress();

  testWidgets('dragging starts the flip animation', (tester) async {
    // turnable_page_plus paints a book shadow via a Canvas whose native peer
    // is unavailable in the test environment; unrelated to flip behaviour.
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

    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );

    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final book = tester.renderObject<RenderTurnableBook>(
      find.byType(RenderTurnableBook),
    );
    final size = tester.getSize(find.byType(RenderTurnableBook));
    // ignore: avoid_debugPrint
    debugPrint(
      'size=$size pages=${book.pageCount} current=${book.pageFlip.getCurrentPageIndex()}',
    );

    final start = Offset(size.width - 20, size.height / 2);
    final end = Offset(20, size.height / 2);
    debugPrint('drag start=$start end=$end');

    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 16));
    debugPrint(
      'afterDown state=${book.pageFlip.getState()} flipping=${book.flippingPage != null}',
    );

    for (int i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
      debugPrint(
        'move$i state=${book.pageFlip.getState()} flipping=${book.flippingPage != null}',
      );
    }

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    debugPrint(
      'afterUp state=${book.pageFlip.getState()} flipping=${book.flippingPage != null}',
    );
  });
}
