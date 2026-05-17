/// A parsed section from the Markdown summary produced by SummaryApi.
///
/// Used by MeetingDetailPage to render each section as an animated card
/// ([IP-0041] staggered fade-in).
class SummarySection {
  const SummarySection({required this.heading, required this.body});

  final String heading;
  final String body;

  /// Parses the flat Markdown string into ordered sections.
  ///
  /// Splits on lines beginning with `## ` so each heading starts a new section.
  static List<SummarySection> parse(String markdown) {
    final sections = <SummarySection>[];
    String? currentHeading;
    final bodyLines = <String>[];

    for (final line in markdown.split('\n')) {
      if (line.startsWith('## ')) {
        if (currentHeading != null) {
          sections.add(SummarySection(
            heading: currentHeading,
            body: bodyLines.join('\n').trim(),
          ));
          bodyLines.clear();
        }
        currentHeading = line.substring(3).trim();
      } else {
        bodyLines.add(line);
      }
    }

    if (currentHeading != null) {
      sections.add(SummarySection(
        heading: currentHeading,
        body: bodyLines.join('\n').trim(),
      ));
    }

    return sections;
  }
}
