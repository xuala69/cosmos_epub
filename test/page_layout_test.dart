import 'package:cosmos_epub/Helpers/html_paginator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:turnable_page_plus/turnable_page_plus.dart';

import 'helpers.dart';

String _plain(String html) => (html_parser.parse(html).body?.text ?? '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

void main() {
  testWidgets('a paragraph taller than a page continues on the next page', (
    tester,
  ) async {
    final words = List.generate(400, (i) => 'word$i').join(' ');
    final html = '<p>Start <b>bold part</b> $words <i>end</i></p>';
    final pages = HtmlPaginator(
      pageWidth: 300,
      pageHeight: 400,
      fontSize: 20,
    ).paginate(html);

    expect(pages.length, greaterThan(2));
    // Nothing lost or repeated: the pages read back as the paragraph.
    expect(pages.map(_plain).join(' '), _plain(html));
    // Every part is still a paragraph, with its inline markup intact.
    for (final page in pages) {
      expect(page, startsWith('<p>'));
    }
    expect(pages.first, contains('<b>bold part</b>'));
    expect(pages.last, contains('<i>end</i>'));
  });

  testWidgets('hyphenated text split across pages loses nothing', (
    tester,
  ) async {
    // Long words with soft hyphens, as the reader hyphenates them.
    final words = List.generate(
      300,
      (i) => 'pa\u00ADra\u00ADgraph\u00ADword$i',
    ).join(' ');
    final html = '<p>$words</p>';
    final pages = HtmlPaginator(
      pageWidth: 300,
      pageHeight: 400,
      fontSize: 20,
    ).paginate(html);
    expect(pages.length, greaterThan(2));

    String letters(String s) =>
        _plain(s).replaceAll(RegExp('[\\s\u00AD-]'), '');
    expect(pages.map(letters).join(), letters(html));
  });

  testWidgets('with huge text, page content stays inside the text area', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final state = await openShowEpub(tester, FakeProgress(3, 5));

    // Each page: ClipRect (the text area) > OverflowBox > Column (the text).
    final areas = find.descendant(
      of: find.byType(TurnablePage),
      matching: find.byType(ClipRect),
    );
    expect(areas, findsWidgets);
    for (final area in areas.evaluate()) {
      final clip = area.renderObject! as RenderBox;
      final column = tester.renderObject<RenderBox>(
        find
            .descendant(
              of: find.byWidget(area.widget),
              matching: find.byType(Column),
            )
            .first,
      );
      expect(
        column.size.height,
        lessThanOrEqualTo(clip.size.height),
        reason: 'text taller than its page is cut off',
      );
    }

    // Showing / hiding the bars does not resize the reader.
    final reader = find.byType(TurnablePage);
    final size = tester.getSize(reader);
    state.showHeader = false;
    state.updateUI();
    await pumpFrames(tester, 20);
    expect(tester.getSize(reader), size);

    await closeReader(tester);
  });
}
