import 'package:cosmos_epub/Helpers/pagination.dart';
import 'package:cosmos_epub/Model/chapter_model.dart';
import 'package:cosmos_epub/show_epub.dart' as se;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnable_page_plus/src/render/render_turnable_book.dart';

import 'helpers.dart';

String _html() => List.generate(
  60,
  (i) => '<p>Paragraph number $i with some text to fill the page.</p>',
).join();

// One list for the whole test: a new list means a new book.
final _book = [SpineItem(href: 'a.xhtml', htmlContent: _html())];

void main() {
  se.bookProgress = FakeProgress();

  testWidgets('turning beyond page 1', (tester) async {
    ignoreCanvasErrors();

    PagingTextHandler? handler;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => PagingWidget(
              spine: _book,
              bookId: 'test',
              style: const TextStyle(fontSize: 17),
              handlerCallback: (ctrl) {
                handler = ctrl;
              },
              onTextTap: () {},
              onPageFlip: (cur, total) {
                debugPrint('TEST onPageFlip: cur=$cur, total=$total');
              },
              onLastPage: (cur, total) {
                debugPrint('TEST onLastPage: cur=$cur, total=$total');
              },
            ),
          ),
        ),
      ),
    );

    final bookFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
    );
    for (int i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (bookFinder.evaluate().isNotEmpty) break;
    }

    final book = tester.renderObject<RenderTurnableBook>(bookFinder);
    debugPrint(
      'Initial book pageCount=${book.pageCount}, current=${book.pageFlip.getCurrentPageIndex()}',
    );

    // Turn to page 1 via controller
    debugPrint('--- Turning to page 1 via handler.nextPage() ---');
    expect(handler!.nextPage(), isTrue);
    for (int i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugPrint('After turn 1: current=${book.pageFlip.getCurrentPageIndex()}');

    // Turn to page 2 via controller
    debugPrint('--- Turning to page 2 via handler.nextPage() ---');
    expect(handler!.nextPage(), isTrue);
    for (int i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugPrint('After turn 2: current=${book.pageFlip.getCurrentPageIndex()}');

    // Turn to page 3 via controller
    debugPrint('--- Turning to page 3 via handler.nextPage() ---');
    expect(handler!.nextPage(), isTrue);
    for (int i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugPrint('After turn 3: current=${book.pageFlip.getCurrentPageIndex()}');
  });
}
