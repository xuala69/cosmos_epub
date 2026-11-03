/// One document of the book's reading order (an OPF spine item).
class SpineItem {
  final String href;
  final String htmlContent;

  const SpineItem({required this.href, required this.htmlContent});
}

/// One table-of-contents entry. It only points into the reading order; the
/// text itself lives in [SpineItem]s.
class TocEntry {
  final String title;
  final int depth;
  final int spineIndex;

  const TocEntry({
    required this.title,
    required this.spineIndex,
    this.depth = 0,
  });
}
