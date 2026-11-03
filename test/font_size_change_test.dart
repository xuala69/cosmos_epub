import 'package:cosmos_epub/Helpers/pagination.dart';
import 'package:cosmos_epub/Model/chapter_model.dart';
import 'package:cosmos_epub/show_epub.dart' as se;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnable_page_plus/src/render/render_turnable_book.dart';

import 'helpers.dart';

String _html(String word) => List.generate(
  60,
  (i) => '<p>$word $i with some text to fill the page.</p>',
).join();

// One list for the whole test: a new list means a new book.
final _book = [
  SpineItem(href: 'a.xhtml', htmlContent: _html('First')),
  SpineItem(href: 'b.xhtml', htmlContent: _html('Second')),
];

void main() {
  se.bookProgress = FakeProgress();

  testWidgets('changing the font size never builds during build', (
    tester,
  ) async {
    final errors = <String>[];
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      final text = d.exceptionAsString();
      if (text.contains('native peer has been collected')) return;
      errors.add(text);
    };
    addTearDown(() => FlutterError.onError = original);

    final fontSize = ValueNotifier(17.0);
    PagingTextHandler? handler;
    var locationReports = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenUtilInit(
            designSize: const Size(375, 812),
            // Like ShowEpub: the location callback rebuilds the parent.
            builder: (_, _) => StatefulBuilder(
              builder: (context, setState) => ValueListenableBuilder<double>(
                valueListenable: fontSize,
                builder: (_, size, _) => PagingWidget(
                  spine: _book,
                  bookId: 'test',
                  style: TextStyle(fontSize: size),
                  handlerCallback: (c) => handler = c,
                  onTextTap: () {},
                  onPageFlip: (_, _) {},
                  onLocationChanged: (_, _) =>
                      setState(() => locationReports++),
                  onLastPage: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final bookFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
    );
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (bookFinder.evaluate().isNotEmpty) break;
    }
    await frames(60);
    expect(handler!.nextPage(), isTrue);
    await frames(90);

    final pagesBefore = tester
        .renderObject<RenderTurnableBook>(bookFinder)
        .pageCount;
    // Same order as the Aa slider: rebuild the reader, then ask to paginate.
    fontSize.value = 26;
    handler!.paginate();
    await frames(120);

    FlutterError.onError = original;
    for (final e in errors) {
      debugPrint('CAPTURED ${e.split('\n').take(3).join(' | ')}');
    }
    expect(errors, isEmpty);
    expect(
      tester.renderObject<RenderTurnableBook>(bookFinder).pageCount,
      greaterThan(pagesBefore),
      reason: 'bigger text needs more pages',
    );
    expect(locationReports, greaterThan(0));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 16));
  });
}
