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
  _FakeProgress([this.chapter = 0, this.page = 0]);
  int chapter;
  int page;

  @override
  Future<bool> setCurrentChapterIndex(
    String bookId,
    int chapterIndex, {
    bool keepPage = false,
  }) async {
    chapter = chapterIndex;
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

final _bookFinder = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
);

RenderTurnableBook _render(WidgetTester tester) =>
    tester.renderObject<RenderTurnableBook>(_bookFinder);

int _shownPage(WidgetTester tester) =>
    _render(tester).pageFlip.getCurrentPageIndex();

/// Runs [action] and lets the turn finish. Returns whether a page folded and
/// which book pages were revealed under the folding page meanwhile.
Future<({bool folded, Set<int> revealed})> _turn(
  WidgetTester tester,
  void Function() action,
) async {
  action();
  var folded = false;
  final revealed = <int>{};
  for (var i = 0; i < 90; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final render = _render(tester);
    if (render.flippingPage != null) folded = true;
    final bottom = render.bottomPage;
    if (bottom != null) revealed.add((bottom as dynamic).index as int);
  }
  return (folded: folded, revealed: revealed);
}

/// Drags across the book from the right edge, by [fraction] of its width.
Future<void> _swipe(WidgetTester tester, double fraction) async {
  final size = tester.getSize(_bookFinder);
  final topLeft = tester.getTopLeft(_bookFinder);
  final start = topLeft + Offset(size.width - 10, size.height / 2);
  final end = start - Offset(size.width * fraction, 0);
  final gesture = await tester.startGesture(start);
  for (var i = 1; i <= 10; i++) {
    await gesture.moveTo(Offset.lerp(start, end, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  for (var i = 0; i < 90; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Opens book.epub and waits until the whole book is paginated.
Future<ShowEpubState> _open(WidgetTester tester, _FakeProgress progress) async {
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('native peer has been collected')) {
      return;
    }
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);
  bookProgress = progress;

  final book = (await tester.runAsync(
    () async => EpubReader.readBook(
      await File('example/assets/book.epub').readAsBytes(),
    ),
  ))!;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => ShowEpub(
            epubBook: book,
            accentColor: Colors.blue,
            bookId: 'test_book',
            chapterListTitle: 'Contents',
          ),
        ),
      ),
    ),
  );
  // Pages of the rest of the book are added one spine item per frame.
  var count = -1;
  for (var stable = 0; stable < 30;) {
    await tester.pump(const Duration(milliseconds: 16));
    if (_bookFinder.evaluate().isEmpty) continue;
    final now = _render(tester).pageCount;
    stable = now == count ? stable + 1 : 0;
    count = now;
  }
  return tester.state<ShowEpubState>(find.byType(ShowEpub));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('every turn folds, across chapter boundaries, both ways', (
    tester,
  ) async {
    final progress = _FakeProgress();
    final state = await _open(tester, progress);
    expect(_render(tester).pageFlip.getCurrentPageIndex(), 0);

    final log = <String>[];
    Future<void> turn(bool forward) async {
      final from = _render(tester).pageFlip.getCurrentPageIndex();
      expect(
        forward
            ? state.controllerPaging.nextPage()
            : state.controllerPaging.previousPage(),
        isTrue,
      );
      var folded = false;
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (_render(tester).flippingPage != null) folded = true;
      }
      final to = _render(tester).pageFlip.getCurrentPageIndex();
      log.add('$from->$to@${progress.chapter}:${progress.page}');
      expect(folded, isTrue, reason: 'turn $from -> $to did not fold');
      expect(to, from + (forward ? 1 : -1));
    }

    // The first spine items are one-page documents (download notice, title
    // page), so these turns cross several of them.
    for (var i = 0; i < 4; i++) {
      await turn(true);
    }
    expect(progress.chapter, greaterThan(1));
    for (var i = 0; i < 4; i++) {
      await turn(false);
    }
    debugPrint('TURNS $log');
    expect(progress.chapter, 0);
    await _close(tester);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('reopens at the saved page after earlier pages are added', (
    tester,
  ) async {
    final progress = _FakeProgress(3, 2);
    final state = await _open(tester, progress);
    // Pages of spine items 0-2 were laid out before the saved page.
    expect(_render(tester).pageFlip.getCurrentPageIndex(), greaterThan(2));
    expect((progress.chapter, progress.page), (3, 2));
    expect(state.toc[state.currentTocIndex].spineIndex, lessThanOrEqualTo(3));
    await _close(tester);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('chapter arrows go to the start of the next/previous chapter', (
    tester,
  ) async {
    final progress = _FakeProgress();
    final state = await _open(tester, progress);
    final starts = state.toc.map((e) => e.spineIndex).toSet().toList()..sort();
    expect(state.showPrevious, isFalse);

    // Each press is one animated turn, even when it skips several pages.
    Future<void> press(Future<void> Function() arrow, int spineIndex) async {
      final from = _render(tester).pageFlip.getCurrentPageIndex();
      await arrow();
      var folded = false;
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (_render(tester).flippingPage != null) folded = true;
      }
      final to = _render(tester).pageFlip.getCurrentPageIndex();
      debugPrint('ARROW $from->$to folded=$folded');
      expect(folded, isTrue, reason: 'jump $from -> $to did not fold');
      expect((progress.chapter, progress.page), (spineIndex, 0));
    }

    await press(state.nextChapter, starts[0]);
    await press(state.nextChapter, starts[1]);
    await press(state.nextChapter, starts[2]);
    await press(state.prevChapter, starts[1]);
    await press(state.prevChapter, starts[0]);
    // The first chapter is not the first page: back still goes to the start.
    expect(state.showPrevious, isTrue);
    await press(state.prevChapter, 0);
    expect(state.showPrevious, isFalse);
    await _close(tester);
  }, timeout: const Timeout(Duration(minutes: 2)));

  // book.epub at the test size: spine 0 is a two-page Royallib.com notice that
  // the TOC does not list, spine 1 the one-page "Koinot oqimlari" title page
  // (first TOC entry), then the chapters ("TASHLANDI" = spine 3 is long).
  group('page navigation', () {
    (int, int) at(_FakeProgress p) => (p.chapter, p.page);

    /// Opens at [location] and checks the fixture really starts there.
    Future<(ShowEpubState, _FakeProgress)> openAt(
      WidgetTester tester,
      (int, int) location,
    ) async {
      final progress = _FakeProgress(location.$1, location.$2);
      final state = await _open(tester, progress);
      expect(at(progress), location, reason: 'fixture position');
      return (state, progress);
    }

    /// Previous/Next Page: one folding turn onto the adjacent book page.
    Future<void> pageTurn(
      WidgetTester tester,
      ShowEpubState state,
      _FakeProgress progress, {
      required bool forward,
      required (int, int) expected,
    }) async {
      final from = _shownPage(tester);
      final target = from + (forward ? 1 : -1);
      final result = await _turn(
        tester,
        forward ? state.nextPage : state.previousPage,
      );
      expect(result.folded, isTrue);
      // The page shown under the fold is the adjacent page, nothing else.
      expect(result.revealed, {target});
      expect(_shownPage(tester), target);
      expect(at(progress), expected);
    }

    testWidgets('1. previous page within a chapter: 15 -> 14', (tester) async {
      final (state, progress) = await openAt(tester, (3, 15));
      await pageTurn(
        tester,
        state,
        progress,
        forward: false,
        expected: (3, 14),
      );
      await _close(tester);
    });

    testWidgets('2. previous page within a chapter: 2 -> 1', (tester) async {
      final (state, progress) = await openAt(tester, (3, 2));
      await pageTurn(tester, state, progress, forward: false, expected: (3, 1));
      await _close(tester);
    });

    testWidgets('3+5. first page of a chapter <-> last page of the previous '
        'spine item', (tester) async {
      final (state, progress) = await openAt(tester, (3, 0));
      await _turn(tester, state.previousPage);
      // Last page of spine 2, not its first page.
      expect(progress.chapter, 2);
      expect(progress.page, greaterThan(0));
      final last = progress.page;
      await _turn(tester, state.previousPage);
      expect(at(progress), (2, last - 1));
      await pageTurn(
        tester,
        state,
        progress,
        forward: true,
        expected: (2, last),
      );
      await pageTurn(tester, state, progress, forward: true, expected: (3, 0));
      await _close(tester);
    });

    testWidgets('4. previous page reaches a spine item missing from the TOC', (
      tester,
    ) async {
      final (state, progress) = await openAt(tester, (1, 0));
      expect(state.toc.first.spineIndex, 1, reason: 'notice is not in TOC');
      expect(state.showPrevious, isTrue);
      await pageTurn(tester, state, progress, forward: false, expected: (0, 1));
      await pageTurn(tester, state, progress, forward: false, expected: (0, 0));
      // 5. and forward again across both boundaries.
      await pageTurn(tester, state, progress, forward: true, expected: (0, 1));
      await pageTurn(tester, state, progress, forward: true, expected: (1, 0));
      await pageTurn(tester, state, progress, forward: true, expected: (2, 0));
      await _close(tester);
    });

    testWidgets('6. previous page is hidden at the first page of the book', (
      tester,
    ) async {
      final (state, progress) = await openAt(tester, (0, 0));
      expect(state.showPrevious, isFalse);
      expect(state.showNext, isTrue);
      final result = await _turn(tester, state.previousPage);
      expect(result.folded, isFalse);
      expect(at(progress), (0, 0));
      await _close(tester);
    });

    testWidgets('7. next page is hidden at the last page of the book', (
      tester,
    ) async {
      final progress = _FakeProgress(1 << 20, 1 << 20);
      final state = await _open(tester, progress);
      expect(_shownPage(tester), _render(tester).pageCount - 1);
      expect(progress.chapter, state.spine.length - 1);
      expect(state.showNext, isFalse);
      expect(state.showPrevious, isTrue);
      final before = at(progress);
      final result = await _turn(tester, state.nextPage);
      expect(result.folded, isFalse);
      expect(at(progress), before);
      await _close(tester);
    });

    testWidgets(
      '8. previous chapter goes to the start of the previous chapter',
      (tester) async {
        final (state, progress) = await openAt(tester, (3, 5));
        final result = await _turn(tester, state.prevChapter);
        expect(result.folded, isTrue);
        expect(at(progress), (2, 0));
        await _close(tester);
      },
    );

    testWidgets('9. go to beginning goes to the first page of the book', (
      tester,
    ) async {
      final (state, progress) = await openAt(tester, (3, 5));
      final result = await _turn(tester, state.goToBeginning);
      expect(result.folded, isTrue);
      expect(at(progress), (0, 0));
      expect(_shownPage(tester), 0);
      await _close(tester);
    });

    testWidgets('10. swipe and button land on the same page', (tester) async {
      final (state, progress) = await openAt(tester, (3, 3));
      await _turn(tester, state.nextPage);
      final byButton = (at(progress), _shownPage(tester));
      await _turn(tester, state.previousPage);
      expect(at(progress), (3, 3));
      await _swipe(tester, 0.9);
      expect((at(progress), _shownPage(tester)), byButton);
      expect(byButton.$1, (3, 4));
      await _close(tester);
    });

    testWidgets('12. a cancelled turn does not move the position', (
      tester,
    ) async {
      final (state, progress) = await openAt(tester, (3, 3));
      final page = _shownPage(tester);
      await _swipe(tester, 0.1);
      expect(_shownPage(tester), page);
      expect(at(progress), (3, 3));
      // The reader still turns normally afterwards.
      await pageTurn(tester, state, progress, forward: true, expected: (3, 4));
      await _close(tester);
    });
  });
}
