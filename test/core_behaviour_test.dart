import 'package:cosmos_epub/Helpers/chapters.dart';
import 'package:cosmos_epub/Helpers/epub_content_parser.dart';
import 'package:cosmos_epub/Helpers/pagination.dart';
import 'package:cosmos_epub/show_epub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// First [count] words of [text], for "is this the same place" checks.
String _words(String text, [int count = 6]) => text
    .replaceAll('-', '')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .take(count)
    .join(' ');

String _flat(String text) =>
    text.replaceAll('-', '').replaceAll(RegExp(r'\s+'), ' ');

void main() {
  testWidgets('1. changing the font size keeps the reader on the same text', (
    tester,
  ) async {
    ignoreCanvasErrors();
    bookProgress = FakeProgress();
    final parser = EpubContentParser(await readEpub(tester));
    final fontSize = ValueNotifier(17.0);
    PagingTextHandler? handler;
    var location = (0, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => ValueListenableBuilder<double>(
              valueListenable: fontSize,
              builder: (_, size, _) => PagingWidget(
                spine: parser.spine,
                contentParser: parser,
                bookId: 'test',
                // Deep inside the long "TASHLANDI" chapter.
                startSpineIndex: 3,
                startPageInSpine: 15,
                style: TextStyle(fontSize: size),
                handlerCallback: (c) => handler = c,
                onTextTap: () {},
                onPageFlip: (_, _) {},
                onLocationChanged: (s, p) => location = (s, p),
                onLastPage: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await pumpFrames(tester, 200);
    expect(location, (3, 15), reason: 'fixture position');
    final before = _words(pageText(tester, shownPage(tester)));
    expect(before, isNotEmpty);

    for (final size in [26.0, 13.0]) {
      fontSize.value = size;
      await pumpFrames(tester, 200);
      expect(handler, isNotNull);
      expect(location.$1, 3, reason: 'still in the same chapter at $size');
      // The text that was at the top of the page starts on the page now
      // shown (it may run on to the next one).
      final page = shownPage(tester);
      expect(
        _flat(pageText(tester, page)),
        contains(before.split(' ').first),
        reason: 'font $size lost the reading position',
      );
      expect(
        _flat('${pageText(tester, page)} ${pageText(tester, page + 1)}'),
        contains(before),
        reason: 'font $size lost the reading position',
      );
    }
    await closeReader(tester);
  });

  testWidgets('2. closing the reader while the book is still paginating', (
    tester,
  ) async {
    await openShowEpub(tester, FakeProgress(3, 2), waitForWholeBook: false);
    // Background pagination of the other spine items has just started.
    await pumpFrames(tester, 3);
    await closeReader(tester);
    // Any pass still running must stop without touching the disposed state;
    // an error here fails the test through FlutterError.onError.
    await pumpFrames(tester, 120);
    expect(tester.takeException(), isNull);
  });

  testWidgets('3. jumping to a chapter that is not paginated yet', (
    tester,
  ) async {
    final progress = FakeProgress();
    final state = await openShowEpub(tester, progress, waitForWholeBook: false);
    final target = state.toc.last.spineIndex;
    // Right after opening, only the first spine items exist.
    state.controllerPaging.goToSpineItem(target);
    await pumpFrames(tester, 400);

    expect(progress.location, (target, 0));
    expect(state.currentTocIndex, state.toc.length - 1);
    // The rest of the book was added around it: one page back is the end of
    // the previous spine item.
    final before = shownPage(tester);
    expect(before, greaterThan(0));
    await turnWith(tester, state.previousPage);
    expect(shownPage(tester), before - 1);
    expect(progress.chapter, target - 1);
    await closeReader(tester);
  });

  testWidgets('4. pages added in the background never cut a turn short', (
    tester,
  ) async {
    final progress = FakeProgress();
    final state = await openShowEpub(tester, progress, waitForWholeBook: false);
    // Near the start of the book every finished spine item is added at once,
    // which rebuilds the engine: it must wait while a page is turning.
    for (var turn = 1; turn <= 3; turn++) {
      final from = shownPage(tester);
      state.nextPage();
      Object? engine;
      var folded = false;
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final render = bookRender(tester);
        if (render.flippingPage != null) {
          folded = true;
          engine ??= render;
          expect(
            identical(render, engine),
            isTrue,
            reason: 'engine rebuilt during turn $turn',
          );
        }
      }
      expect(folded, isTrue);
      expect(shownPage(tester), from + 1);
    }
    expect(progress.chapter, greaterThan(0));
    await closeReader(tester);
  });

  testWidgets('5a. onPageFlip reports book-wide positions', (tester) async {
    final flips = <(int, int)>[];
    final state = await openShowEpub(
      tester,
      FakeProgress(),
      onPageFlip: (current, total) => flips.add((current, total)),
    );
    final total = bookRender(tester).pageCount;
    for (var i = 1; i <= 3; i++) {
      await turnWith(tester, state.nextPage);
      expect(flips.last, (i, total));
    }
    await closeReader(tester);
  });

  testWidgets('5b. onLastPage fires once per attempt past the end', (
    tester,
  ) async {
    var lastPageCalls = 0;
    final state = await openShowEpub(
      tester,
      FakeProgress(1 << 20, 1 << 20),
      onLastPage: (_) => lastPageCalls++,
    );
    expect(shownPage(tester), bookRender(tester).pageCount - 1);
    expect(lastPageCalls, 0, reason: 'arriving is not an attempt');

    await turnWith(tester, state.nextPage);
    expect(lastPageCalls, 1);
    await swipe(tester, 0.9);
    expect(lastPageCalls, 2);
    await closeReader(tester);
  });

  testWidgets('5c. onLastPage waits until the whole book is paginated', (
    tester,
  ) async {
    var lastPageCalls = 0;
    final state = await openShowEpub(
      tester,
      FakeProgress(1 << 20, 1 << 20),
      waitForWholeBook: false,
      onLastPage: (_) => lastPageCalls++,
    );
    // Earlier spine items are still being added: this is not the end yet.
    state.nextPage();
    expect(lastPageCalls, 0);
    await closeReader(tester);
  });

  testWidgets('6a. the reading position survives closing and reopening', (
    tester,
  ) async {
    final progress = FakeProgress(2, 0);
    var state = await openShowEpub(tester, progress);
    for (var i = 0; i < 3; i++) {
      await turnWith(tester, state.nextPage);
    }
    final saved = progress.location;
    final page = shownPage(tester);
    final text = _words(pageText(tester, page));
    await closeReader(tester);

    state = await openShowEpub(tester, progress);
    expect(progress.location, saved);
    expect(shownPage(tester), page);
    expect(_words(pageText(tester, page)), text);
    await closeReader(tester);
  });

  testWidgets('6b. starterChapter opens that TOC entry, -1 resumes', (
    tester,
  ) async {
    final progress = FakeProgress(3, 4);
    var state = await openShowEpub(tester, progress, starterChapter: 2);
    expect(progress.location, (state.toc[2].spineIndex, 0));
    await closeReader(tester);

    progress
      ..chapter = 3
      ..page = 4;
    state = await openShowEpub(tester, progress);
    expect(progress.location, (3, 4));
    await closeReader(tester);
  });

  testWidgets('7a. the contents list highlights and opens entries', (
    tester,
  ) async {
    final progress = FakeProgress(3, 4);
    final state = await openShowEpub(tester, progress);
    final current = state.currentTocIndex;

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byType(ChaptersList), findsOneWidget);
    Color? colorOf(String title) => tester
        .widget<Text>(
          find.descendant(
            of: find.byType(ChaptersList),
            matching: find.text(title),
          ),
        )
        .style
        ?.color;
    expect(colorOf(state.toc[current].title), Colors.blue);
    expect(colorOf(state.toc[current + 1].title), isNot(Colors.blue));

    final target = state.toc[1];
    await tester.tap(
      find.descendant(
        of: find.byType(ChaptersList),
        matching: find.text(target.title),
      ),
    );
    await pumpFrames(tester, 120);
    expect(find.byType(ChaptersList), findsNothing);
    expect(progress.location, (target.spineIndex, 0));
    await closeReader(tester);
  });

  testWidgets('7b. nested contents entries are indented', (tester) async {
    final parser = EpubContentParser(
      await readEpub(tester, 'example/assets/book_nested.epub'),
    );
    final top = parser.toc.firstWhere((e) => e.depth == 0);
    // A section and its first child can share a title; pick a distinct one.
    final topTitles = {
      for (final e in parser.toc)
        if (e.depth == 0) e.title,
    };
    final nested = parser.toc.firstWhere(
      (e) => e.depth == 1 && !topTitles.contains(e.title),
    );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: ChaptersList(
            chapters: parser.toc,
            currentIndex: 0,
            accentColor: Colors.blue,
            chapterListTitle: 'Contents',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    double left(String title) => tester.getTopLeft(find.text(title).first).dx;
    expect(left(nested.title), greaterThan(left(top.title)));
  });
}
