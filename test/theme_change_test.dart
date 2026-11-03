import 'package:cosmos_epub/Helpers/pagination.dart';
import 'package:cosmos_epub/Model/chapter_model.dart';
import 'package:cosmos_epub/show_epub.dart' as se;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnable_page_plus/turnable_page_plus.dart';
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

  testWidgets('changing the theme recolours the pages already built', (
    tester,
  ) async {
    ignoreCanvasErrors();

    final dark = ValueNotifier(false);
    PagingTextHandler? handler;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => ValueListenableBuilder<bool>(
              valueListenable: dark,
              builder: (_, isDark, _) => PagingWidget(
                spine: _book,
                bookId: 'test',
                backgroundColor: isDark ? Colors.black : Colors.white,
                style: TextStyle(
                  fontSize: 17,
                  color: isDark ? Colors.white : Colors.black,
                ),
                handlerCallback: (c) => handler = c,
                onTextTap: () {},
                onPageFlip: (_, _) {},
                onLastPage: (_, _) {},
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
      await tester.pump(const Duration(milliseconds: 16));
      if (bookFinder.evaluate().isNotEmpty) break;
    }
    // Move off the first page, so the theme change must keep the position.
    expect(handler!.nextPage(), isTrue);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final book = tester.renderObject<RenderTurnableBook>(bookFinder);
    expect(book.pageFlip.getCurrentPageIndex(), 1);

    Iterable<Color?> pageColors() => tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(TurnablePage),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.color);
    Iterable<Color?> textColors() => tester
        .widgetList<DefaultTextStyle>(
          find.descendant(
            of: find.byType(TurnablePage),
            matching: find.byType(DefaultTextStyle),
          ),
        )
        .map((t) => t.style.color);

    expect(pageColors(), contains(Colors.white));
    expect(pageColors(), isNot(contains(Colors.black)));

    dark.value = true;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(pageColors(), contains(Colors.black));
    expect(pageColors(), isNot(contains(Colors.white)));
    expect(textColors(), contains(Colors.white));
    expect(textColors(), isNot(contains(Colors.black)));
    expect(
      tester
          .renderObject<RenderTurnableBook>(bookFinder)
          .pageFlip
          .getCurrentPageIndex(),
      1,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 16));
  });
}
