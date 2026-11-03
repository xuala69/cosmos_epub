import 'dart:convert';

import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';

import '../Model/chapter_model.dart';

/// Parses an EpubBook into its reading order and table of contents, and
/// extracts all images for rendering.
///
/// Like other EPUB readers, the text is read in **spine** order (every linear
/// document, cover and title pages included) and the table of contents only
/// points into it. The TOC comes from:
/// 1. NCX NavMap with recursive ChildNavigationPoints (handles nested TOCs)
/// 2. epubx Chapters if NavMap is empty
/// 3. one entry per spine item if both fail
class EpubContentParser {
  final EpubBook epubBook;
  late final List<SpineItem> spine;
  late final List<TocEntry> toc;
  late final Map<String, Uint8List> imageMap;

  EpubContentParser(this.epubBook) {
    debugPrint('[EPUB_PARSER] Parsing EPUB book: ${epubBook.Title}');
    spine = _buildSpine();
    toc = _buildToc();
    debugPrint(
      '[EPUB_PARSER] Built ${spine.length} spine items, ${toc.length} TOC entries',
    );
    imageMap = _extractImages();
    debugPrint('[EPUB_PARSER] Extracted ${imageMap.length} images');
  }

  static String _fileName(String href) =>
      href.split('#').first.split('/').last;

  List<SpineItem> _buildSpine() {
    final list = <SpineItem>[];
    final package = epubBook.Schema?.Package;
    final manifest = package?.Manifest?.Items ?? const <EpubManifestItem>[];
    final spineItems = package?.Spine?.Items;

    if (spineItems != null && spineItems.isNotEmpty) {
      for (final spineItem in spineItems) {
        // Non-linear documents are only reachable through links.
        if (spineItem.IsLinear == false) continue;
        final item = manifest.where((m) => m.Id == spineItem.IdRef).firstOrNull;
        final href = item?.Href ?? '';
        if (href.isEmpty) continue;
        // The EPUB 3 navigation document is the TOC, not part of the text.
        if (item?.Properties?.contains('nav') == true ||
            RegExp(r'^(nav|toc)\.x?html?$').hasMatch(_fileName(href))) {
          continue;
        }
        final content = _resolveContentBySource(href);
        if (content.isEmpty) continue;
        list.add(SpineItem(href: href, htmlContent: content));
      }
    } else {
      // No spine — keep the documents in archive order.
      for (final entry in (epubBook.Content?.Html ?? {}).entries) {
        if (entry.key.contains('nav')) continue;
        list.add(
          SpineItem(href: entry.key, htmlContent: entry.value.Content ?? ''),
        );
      }
    }

    final cover = _coverImageHref(manifest);
    if (cover != null &&
        !list.any((s) => s.htmlContent.contains(_fileName(cover)))) {
      // A cover declared only as an image: show it as the first page, as
      // other readers do.
      list.insert(
        0,
        SpineItem(href: cover, htmlContent: '<img src="$cover" alt="cover"/>'),
      );
    }
    return list;
  }

  /// The cover image declared in the OPF (EPUB 3 `cover-image` property, or
  /// EPUB 2 `<meta name="cover">`).
  String? _coverImageHref(List<EpubManifestItem> manifest) {
    final byProperty = manifest
        .where((m) => m.Properties?.contains('cover-image') == true)
        .firstOrNull;
    if (byProperty?.Href != null) return byProperty!.Href;
    final id = epubBook.Schema?.Package?.Metadata?.MetaItems
        ?.where((m) => m.Name == 'cover')
        .firstOrNull
        ?.Content;
    if (id == null) return null;
    final item = manifest.where((m) => m.Id == id).firstOrNull;
    if (item?.MediaType?.startsWith('image/') != true) return null;
    return item!.Href;
  }

  /// Spine position of the document [source] points to, or -1.
  int _spineIndexOf(String source) {
    final file = _fileName(source);
    if (file.isEmpty) return -1;
    return spine.indexWhere((s) => _fileName(s.href) == file);
  }

  List<TocEntry> _buildToc() {
    // Strategy 1: NCX NavMap (supports nested navPoints)
    final navPoints = epubBook.Schema?.Navigation?.NavMap?.Points;
    if (navPoints != null && navPoints.isNotEmpty) {
      final list = <TocEntry>[];
      _flattenNavPoints(navPoints, list, 0);
      if (list.isNotEmpty) return list;
    }

    // Strategy 2: epubx Chapters (works for simple flat TOCs)
    if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
      final list = <TocEntry>[];
      _flattenEpubChapters(epubBook.Chapters!, list, 0);
      if (list.isNotEmpty) return list;
    }

    // Strategy 3: one entry per spine item
    return [
      for (var i = 0; i < spine.length; i++)
        TocEntry(title: 'Chapter ${i + 1}', spineIndex: i),
    ];
  }

  /// Recursively flatten NCX navigation points — handles infinite nesting.
  ///
  /// A section wrapper without content of its own points at its first child.
  /// Entries whose document is not in the reading order are dropped.
  void _flattenNavPoints(
    List<EpubNavigationPoint> points,
    List<TocEntry> list,
    int depth,
  ) {
    for (final point in points) {
      final title = point.NavigationLabels?.isNotEmpty == true
          ? point.NavigationLabels!.first.Text ?? '...'
          : '...';
      final at = list.length;
      final children = point.ChildNavigationPoints ?? const [];
      _flattenNavPoints(children, list, depth + 1);

      var index = _spineIndexOf(point.Content?.Source ?? '');
      if (index < 0 && list.length > at) index = list[at].spineIndex;
      if (index >= 0) {
        list.insert(
          at,
          TocEntry(title: title, spineIndex: index, depth: depth),
        );
      }
    }
  }

  /// Flatten epubx EpubChapter objects (fallback).
  void _flattenEpubChapters(
    List<EpubChapter> chapters,
    List<TocEntry> list,
    int depth,
  ) {
    for (final chapter in chapters) {
      final index = _spineIndexOf(chapter.ContentFileName ?? '');
      if (index >= 0) {
        list.add(
          TocEntry(
            title: chapter.Title ?? '...',
            spineIndex: index,
            depth: depth,
          ),
        );
      }
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        _flattenEpubChapters(chapter.SubChapters!, list, depth + 1);
      }
    }
  }

  /// Resolve a manifest/TOC path to actual HTML content from the EPUB.
  String _resolveContentBySource(String source) {
    if (source.isEmpty) return '';

    // Strip fragment (#anchor)
    final cleanSource = source.split('#').first;

    final htmlFiles = epubBook.Content?.Html;
    if (htmlFiles == null) return '';

    // Try exact match
    if (htmlFiles.containsKey(cleanSource)) {
      return htmlFiles[cleanSource]?.Content ?? '';
    }

    // Try matching by filename
    final filename = cleanSource.split('/').last;
    for (final entry in htmlFiles.entries) {
      if (entry.key.endsWith(filename)) return entry.value.Content ?? '';
    }

    debugPrint('[EPUB_PARSER] No content found for source: $source');
    return '';
  }

  Map<String, Uint8List> _extractImages() {
    final map = <String, Uint8List>{};
    final images = epubBook.Content?.Images;
    if (images != null) {
      for (final entry in images.entries) {
        if (entry.value.Content != null) {
          map[entry.key] = Uint8List.fromList(entry.value.Content!);
        }
      }
    }
    return map;
  }

  Uint8List? resolveImage(String src) {
    if (imageMap.containsKey(src)) return imageMap[src];

    final filename = src.split('/').last.split('?').first;
    for (final entry in imageMap.entries) {
      if (entry.key.endsWith(filename)) return entry.value;
    }

    final normalized = src.replaceAll(RegExp(r'^(\.\./)+'), '');
    if (imageMap.containsKey(normalized)) return imageMap[normalized];
    for (final entry in imageMap.entries) {
      if (entry.key.endsWith(normalized)) return entry.value;
    }

    return null;
  }

  String resolveImagesInHtml(String html) {
    return html.replaceAllMapped(RegExp(r'''src\s*=\s*["']([^"']+)["']'''), (
      match,
    ) {
      final src = match.group(1)!;
      if (src.startsWith('data:')) return match.group(0)!;
      final bytes = resolveImage(src);
      if (bytes != null) {
        final mimeType = _getMimeType(src);
        final base64Str = base64Encode(bytes);
        return 'src="data:$mimeType;base64,$base64Str"';
      }
      return match.group(0)!;
    });
  }

  static String _getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/png';
  }
}
