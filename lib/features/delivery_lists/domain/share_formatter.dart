class ShareFormatter {
  String format({
    required String title,
    required DateTime date,
    required Iterable<String> names,
  }) {
    final grouped = <String, ({String display, int count})>{};
    for (final rawName in names) {
      final display = rawName.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (display.isEmpty) continue;
      final key = _normalize(display);
      final current = grouped[key];
      grouped[key] = (
        display: current?.display ?? display,
        count: (current?.count ?? 0) + 1,
      );
    }
    final entries = grouped.values.toList()
      ..sort(
        (a, b) => a.display.toLowerCase().compareTo(b.display.toLowerCase()),
      );
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final body = entries
        .map(
          (entry) => entry.count > 1
              ? '${entry.display} (${entry.count})'
              : entry.display,
        )
        .join('\n');
    return '$title\n$dateText\n\n$body';
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
