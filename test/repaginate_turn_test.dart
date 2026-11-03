import 'package:cosmos_epub/Helpers/pagination.dart';
import 'package:cosmos_epub/Model/chapter_model.dart';
import 'package:cosmos_epub/show_epub.dart' as se;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnable_page_plus/src/render/render_turnable_book.dart';

import 'helpers.dart';

String _html(int paragraphs) => List.generate(
  paragraphs,
  (i) => '<p>Paragraph number $i with some text to fill the page.</p>',
).join();

Future<void> _pumpFrames(WidgetTester tester, [int frames = 120]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  se.bookProgress = FakeProgress();

  testWidgets('pages still turn after the content is re-paginated', (
    tester,
  ) async {
    ignoreCanvasErrors();

    PagingTextHandler? handler;
    final html = ValueNotifier<String>(_html(40));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => ValueListenableBuilder<String>(
              valueListenable: html,
              builder: (context, content, _) => PagingWidget(
                spine: [SpineItem(href: 'a.xhtml', htmlContent: content)],
                bookId: 'test',
                style: const TextStyle(fontSize: 17),
                handlerCallback: (ctrl) => handler = ctrl,
                onTextTap: () {},
                onPageFlip: (cur, total) {},
                onLastPage: (cur, total) {},
              ),
            ),
          ),
        ),
      ),
    );

    final bookFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
    );
    for (var i = 0; i < 200; i++) {
      await _pumpFrames(tester, 1);
      if (bookFinder.evaluate().isNotEmpty) break;
    }
    await _pumpFrames(tester);

    int lastEnd = 0;

    /// Turns [count] pages and returns the index the engine is on.
    Future<int> turn(int count) async {
      for (var i = 0; i < count; i++) {
        final turned = handler!.nextPage();
        expect(
          turned,
          isTrue,
          reason: 'nextPage() refused at page $i of this batch',
        );
        await _pumpFrames(tester);
      }
      final book = tester.renderObject<RenderTurnableBook>(bookFinder);
      return book.pageFlip.getCurrentPageIndex();
    }

    lastEnd = await turn(3);
    expect(lastEnd, 3);

    // New content = a new page list (this is what a chapter change or a font
    // change does). The reader must keep turning afterwards.
    html.value = _html(60);
    await _pumpFrames(tester, 200);

    lastEnd = await turn(3);
    debugPrint('After re-pagination, engine is on page $lastEnd');
    expect(lastEnd, greaterThan(0));

    // And a second re-pagination must not break it either.
    html.value = _html(80);
    await _pumpFrames(tester, 200);
    lastEnd = await turn(2);
    expect(lastEnd, greaterThan(0));
  });
}
