import 'dart:io';
import 'package:cosmos_epub/Helpers/epub_content_parser.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspect assets/book.epub', () async {
    final bytes = await File('example/assets/book.epub').readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final parser = EpubContentParser(book);
    debugPrint('Spine items: ${parser.spine.length}');
    for (final entry in parser.toc) {
      debugPrint('TOC "${entry.title}" -> spine ${entry.spineIndex}');
    }
  });
}
