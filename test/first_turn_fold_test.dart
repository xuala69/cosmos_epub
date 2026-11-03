import 'package:cosmos_epub/Helpers/pagination.dart';
import 'package:cosmos_epub/Model/chapter_model.dart';
import 'package:cosmos_epub/Helpers/progress_singleton.dart';
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
  dynamic noSuchMethod(Invocation invocation) => null;
}

String _html() => List.generate(
  60,
  (i) => '<p>Paragraph number $i with some text to fill the page.</p>',
).join();

// One list for the whole test: a new list means a new book.
final _book = [SpineItem(href: 'a.xhtml', htmlContent: _html())];

void main() {
  se.bookProgress = _FakeProgress();

  for (final parentRebuilds in [false, true]) {
    testWidgets('every turn, including 0 -> 1, folds a page '
        '(parent rebuilds on page flip: $parentRebuilds)', (tester) async {
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

      PagingTextHandler? handler;
      late StateSetter parentSetState;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                parentSetState = setState;
                return ScreenUtilInit(
                  designSize: const Size(375, 812),
                  builder: (_, _) => PagingWidget(
                    spine: _book,
                    bookId: 'test',
                    style: const TextStyle(fontSize: 17),
                    handlerCallback: (c) => handler = c,
                    onTextTap: () {},
                    onPageFlip: (_, _) {
                      // ShowEpub calls updateUI() (a setState) here.
                      if (parentRebuilds) {
                        Future.microtask(() => parentSetState(() {}));
                      }
                    },
                    onLastPage: (_, _) {},
                  ),
                );
              },
            ),
          ),
        ),
      );

      final bookFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
      );
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (bookFinder.evaluate().isNotEmpty) break;
      }
      final book = tester.renderObject<RenderTurnableBook>(bookFinder);

      for (var turn = 0; turn < 3; turn++) {
        final from = book.pageFlip.getCurrentPageIndex();
        expect(handler!.nextPage(), isTrue);
        var folded = false;
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (book.flippingPage != null) folded = true;
        }
        debugPrint(
          'TURN $from -> ${book.pageFlip.getCurrentPageIndex()} '
          'folded=$folded',
        );
        expect(folded, isTrue, reason: 'turn from index $from did not fold');
      }

      // Swipe from the last-visited page back to 0 is covered above; now
      // swipe forward from page 0 of a fresh reader below.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 16));
    });
  }

  testWidgets('swipe from index 0 folds a page', (tester) async {
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
              spine: _book,
              bookId: 'test',
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
    final bookFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
    );
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (bookFinder.evaluate().isNotEmpty) break;
    }
    final book = tester.renderObject<RenderTurnableBook>(bookFinder);
    final size = tester.getSize(bookFinder);
    final topLeft = tester.getTopLeft(bookFinder);
    final start = topLeft + Offset(size.width - 20, size.height / 2);
    final end = topLeft + Offset(20, size.height / 2);

    final gesture = await tester.startGesture(start);
    var folded = false;
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
      if (book.flippingPage != null) folded = true;
    }
    await gesture.up();
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugPrint(
      'SWIPE 0 -> ${book.pageFlip.getCurrentPageIndex()} folded=$folded',
    );
    expect(folded, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 16));
  });
}
