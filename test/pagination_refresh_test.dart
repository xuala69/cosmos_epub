import 'package:cosmos_epub/Helpers/pagination.dart';
import 'package:cosmos_epub/Helpers/progress_singleton.dart';
import 'package:cosmos_epub/Model/book_progress_model.dart';
import 'package:cosmos_epub/show_epub.dart' as se;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnable_page_plus/turnable_page_plus.dart';
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
  40,
  (i) => '<p>Paragraph number $i with some text to fill the page.</p>',
).join();

void main() {
  se.bookProgress = _FakeProgress();

  // ignore: unused_field
  late PagingTextHandler handler;

  Future<void> pumpReader(WidgetTester tester, double fontSize) {
    return tester.pumpWidget(
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
              style: TextStyle(fontSize: fontSize),
              handlerCallback: (ctrl) => handler = ctrl,
              onTextTap: () {},
              onPageFlip: (_, _) {},
              onLastPage: (_, _) {},
            ),
          ),
        ),
      ),
    );
  }

  /// Pumps frames until the TurnablePage is laid out; returns the frame
  /// number, or -1. (The internal RenderTurnableBook is not registered as a
  /// widget type for finders, so its widget is used as the marker.)
  Future<int> pumpUntilBook(WidgetTester tester) async {
    for (int i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(TurnablePage).evaluate().isNotEmpty) return i;
    }
    return -1;
  }

  var buildPhaseExceptions = <String>[];

  setUp(() {
    // turnable_page_plus paints with a Canvas whose native peer is not
    // available under flutter_test; unrelated to pagination.
    final original = FlutterError.onError;
    buildPhaseExceptions = <String>[];
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('native peer has been collected')) return;
      buildPhaseExceptions.add(text);
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  });

  testWidgets('a re-layout never calls setState during build', (tester) async {
    // A tall surface: the long page Column clips by design at real sizes, and
    // an unrelated RenderFlex overflow here would mask the assertion we test.
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpReader(tester, 17);
    expect(await pumpUntilBook(tester), greaterThanOrEqualTo(0));

    // Force a re-layout of the reader: the page count changes from 5 to 4 when
    // the box grows, so TurnablePage is re-created and the engine notifies its
    // new page, exactly the sequence that used to throw from LayoutBuilder.
    tester.view.physicalSize = const Size(500, 1700);

    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final duringBuild = buildPhaseExceptions
        .where((e) => e.contains('called during build'))
        .toList();
    // ignore: avoid_print
    print(
      'exceptionsDuringResize=${buildPhaseExceptions.length} '
      'duringBuild=${duringBuild.length}',
    );
    expect(duringBuild, isEmpty);
    expect(find.byType(TurnablePage), findsOneWidget);
  });

  testWidgets('reader appears and stays on its page', (tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpReader(tester, 17);
    final frames = await pumpUntilBook(tester);
    // ignore: avoid_print
    print('framesUntilBook=$frames');
    // Once the reader is up, a re-pagination (font size change) must NOT
    // bring the spinner back: that is the spinner → text → spinner loop.
    handler.paginate();
    int spinnerFrames = 0;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(CupertinoActivityIndicator).evaluate().isNotEmpty) {
        spinnerFrames++;
      }
    }
    // ignore: avoid_print
    print('spinnerFramesDuringRepaginate=$spinnerFrames');
    expect(find.byType(TurnablePage), findsOneWidget);
    expect(spinnerFrames, 0);
    expect(frames, greaterThanOrEqualTo(0));
  });

  testWidgets('a page fills the reader in portrait too', (tester) async {
    // The real-device case: 420x765 reader (as reported by the device log).
    tester.view.physicalSize = const Size(420, 765);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpReader(tester, 17);
    expect(await pumpUntilBook(tester), greaterThanOrEqualTo(0));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final bookFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
    );
    final book = tester.renderObject<RenderTurnableBook>(bookFinder);
    final rect = book.getRect();
    final bookSize = tester.getSize(bookFinder);
    // ignore: avoid_print
    print(
      'portrait page=${rect.pageWidth}x${rect.height} left=${rect.left} '
      'top=${rect.top} book=${bookSize.width}x${bookSize.height}',
    );
    // In portrait the engine keeps its page box one page to the left and the
    // VISIBLE page is the right slot, painted and hit-tested at
    // `rect.left + rect.pageWidth`. That must land exactly on the reader, or
    // drags miss the page (the "only one page responds" symptom).
    expect(rect.left + rect.pageWidth, closeTo(0, 1));
    expect(rect.top, closeTo(0, 1));
    // One page must fill the reader in BOTH directions. Only checking the
    // width let a `maxWidth / aspectRatio` book slip through: 420 wide but
    // only 140 tall, so the text sat in a thin strip.
    expect(rect.pageWidth, closeTo(bookSize.width, 1));
    expect(rect.height, closeTo(bookSize.height, 1));

    // The very FIRST gesture must start the flip, with no nextPage()/button
    // needed first. Each of three consecutive drags is checked separately,
    // because "only one slot responds" is exactly a hit-test problem: the
    // engine only tests the right-hand page, so a mis-placed page rect makes
    // every page except the middle one dead to the touch.
    Future<void> dragForwardAndExpect(int expected) async {
      final start = Offset(bookSize.width - 24, bookSize.height / 2);
      final end = Offset(bookSize.width * 0.1, bookSize.height / 2);
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 16));
      for (int i = 1; i <= 20; i++) {
        await gesture.moveTo(Offset.lerp(start, end, i / 20)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      // ignore: avoid_print
      print(
        'drag from ${expected - 1}: flipping=${book.flippingPage != null} '
        'state=${book.pageFlip.getState()}',
      );
      await gesture.up();
      for (int i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // ignore: avoid_print
      print('after drag -> ${book.pageFlip.getCurrentPageIndex()}');
      expect(
        book.pageFlip.getCurrentPageIndex(),
        expected,
        reason: 'page ${expected - 1} must accept a drag',
      );
    }

    await dragForwardAndExpect(1);
    await dragForwardAndExpect(2);
    await dragForwardAndExpect(3);
  });

  testWidgets('handler turns pages with the flip animation', (tester) async {
    tester.view.physicalSize = const Size(420, 765);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpReader(tester, 17);
    expect(await pumpUntilBook(tester), greaterThanOrEqualTo(0));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final bookFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
    );
    final book = tester.renderObject<RenderTurnableBook>(bookFinder);

    // The reader's next button goes through the handler.
    expect(handler.nextPage(), isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));

    // Mid-flight: the engine must be ANIMATING a flip, not just swapping the
    // page index (that was the old nextChapter()/setState behaviour).
    // ignore: avoid_print
    print(
      'button turn: flipping=${book.flippingPage != null} '
      'state=${book.pageFlip.getState()}',
    );
    expect(book.flippingPage, isNotNull);

    for (int i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // ignore: avoid_print
    print('button turn landed on ${book.pageFlip.getCurrentPageIndex()}');
    expect(book.pageFlip.getCurrentPageIndex(), 1);

    // Backwards, same animation.
    expect(handler.previousPage(), isTrue);
    for (int i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // ignore: avoid_print
    print('back turn landed on ${book.pageFlip.getCurrentPageIndex()}');
    expect(book.pageFlip.getCurrentPageIndex(), 0);

    // At the first page the handler reports "no page", so the caller may move
    // to the previous chapter instead.
    await tester.pump(const Duration(milliseconds: 16));
    // ignore: avoid_print
    print('engine index=${book.pageFlip.getCurrentPageIndex()} '
        'handler index=${handler.currentPage()}');
    expect(handler.currentPage(), 0);
    expect(handler.previousPage(), isFalse);
  });

  testWidgets('one page fills a landscape screen and turns one at a time', (
    tester,
  ) async {
    // Wide (landscape) viewport: the engine would switch to two-page spreads
    // and show pages 0+1 at once unless the page aspect is known.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpReader(tester, 17);
    expect(await pumpUntilBook(tester), greaterThanOrEqualTo(0));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // The engine's render object is not a widget, so it is addressed through
    // the widget that owns it.
    final bookRender = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TurnableBookRenderObjectWidget',
    );
    final bookFinder = bookRender;
    final size = tester.getSize(bookFinder);
    // ignore: avoid_print
    print('landscape bookSize=$size');
    final book = tester.renderObject<RenderTurnableBook>(bookFinder);
    // A single page must fill the book width. Before `aspectRatio: 1 / 2` the
    // engine laid out a two-page landscape spread: the visible page spanned
    // only HALF the widget and the other half belonged to its neighbour.
    final rect = book.getRect();
    // ignore: avoid_print
    print(
      'pageWidth=${rect.pageWidth} bookWidth=${size.width} '
      'pageLeft=${rect.left} pageTop=${rect.top}',
    );
    expect(rect.left + rect.pageWidth, closeTo(0, 1));
    expect(rect.top, closeTo(0, 1));
    expect(
      rect.pageWidth,
      greaterThan(size.width * 0.99),
      reason: 'a page must span the whole reader, not half a spread',
    );
    expect(
      rect.height,
      closeTo(size.height, 1),
      reason: 'the page must fill the reader height',
    );

    // Drag across the visible page: start near its right edge and release well
    // past the midpoint. Coordinates are in the book widget's own box.
    final double pageLeft = rect.left < 0 ? 0 : rect.left;
    final double pageRight = pageLeft + rect.pageWidth;
    // ignore: avoid_print
    print('pageLeft=$pageLeft pageRight=$pageRight height=${rect.height}');
    final start = Offset(pageRight - 20, rect.height / 2);
    final end = Offset(pageLeft + rect.pageWidth * 0.15, rect.height / 2);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 16));
    for (int i = 1; i <= 20; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / 20)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    // ignore: avoid_print
    print(
      'midDrag index=${book.pageFlip.getCurrentPageIndex()} '
      'flipping=${book.flippingPage != null} state=${book.pageFlip.getState()}',
    );
    await gesture.up();
    for (int i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // ignore: avoid_print
    print('afterFirstDrag=${book.pageFlip.getCurrentPageIndex()}');
    expect(book.pageFlip.getCurrentPageIndex(), 1);

    // Second turn from the same spot must go one page further, not two: the
    // engine keeps its page cache across turns.
    final gesture2 = await tester.startGesture(start);
    for (int i = 1; i <= 10; i++) {
      await gesture2.moveTo(Offset.lerp(start, end, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture2.up();
    for (int i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // ignore: avoid_print
    print('afterSecondDrag=${book.pageFlip.getCurrentPageIndex()}');
    expect(book.pageFlip.getCurrentPageIndex(), 2);
  });
}
