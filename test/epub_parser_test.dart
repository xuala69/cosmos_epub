import 'dart:io';

import 'package:cosmos_epub/Helpers/epub_content_parser.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';

Future<EpubContentParser> _parse(String name) async => EpubContentParser(
  await EpubReader.readBook(await File('example/assets/$name').readAsBytes()),
);

void main() {
  test('reads every spine document, even ones the TOC skips', () async {
    final book = await _parse('book.epub');
    // The first document is a download notice the TOC does not list.
    expect(book.spine.first.htmlContent, contains('Royallib.com'));
    expect(book.toc.first.title, 'Ayzek Azimov Koinot oqimlari');
    expect(
      book.spine[book.toc.first.spineIndex].htmlContent,
      contains('Ayzek'),
    );
    expect(book.toc[1].spineIndex, book.toc.first.spineIndex + 1);
  });

  test('TOC entries point into the spine without duplicating text', () async {
    final book = await _parse('book_nested.epub');
    final htmls = book.spine.map((s) => s.htmlContent).toList();
    expect(htmls.toSet(), hasLength(htmls.length));
    // The navigation document is not part of the text.
    expect(
      book.spine.map((s) => s.href),
      isNot(contains(endsWith('nav.xhtml'))),
    );
    for (final entry in book.toc) {
      expect(entry.spineIndex, inInclusiveRange(0, book.spine.length - 1));
    }
    // A section wrapper points at its first child.
    final part = book.toc.first;
    expect(part.depth, 0);
    expect(book.toc[1].depth, 1);
    expect(part.spineIndex, book.toc[1].spineIndex);
  });

  test('a book with a cover keeps it as the first page', () async {
    final book = await _parse('famouspaintings.epub');
    expect(book.spine, isNotEmpty);
    expect(book.toc.map((e) => e.title), contains('Cover'));
    for (final entry in book.toc) {
      expect(entry.spineIndex, inInclusiveRange(0, book.spine.length - 1));
    }
  });
}
