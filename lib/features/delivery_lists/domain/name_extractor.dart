class NameExtraction {
  const NameExtraction({this.name, required this.confidence});

  final String? name;
  final double confidence;
}

class NameExtractor {
  static const _contextWords = <String>{
    'destinatario',
    'recebedor',
    'cliente',
    'endereco',
    'cep',
  };

  NameExtraction extract(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map(_clean)
        .where((line) => line.isNotEmpty)
        .toList();

    String? best;
    var bestScore = 0.0;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final normalized = _normalize(line);
      if (_looksLikeNoise(normalized)) continue;

      var candidate = _clean(line.replaceAll(RegExp(r'\([^)]*\)'), ''));
      var score = _looksLikeName(candidate) ? 0.55 : 0.0;
      if (normalized.startsWith('destinatario')) {
        candidate = _clean(
          line.replaceFirst(
            RegExp(r'^destinat[aá]rio\s*:?\s*', caseSensitive: false),
            '',
          ),
        );
        score = 0.96;
      }
      if (index + 1 < lines.length &&
          _contextWords.any(normalized.startsWith) &&
          _looksLikeName(lines[index + 1])) {
        candidate = lines[index + 1];
        score = 0.88;
      }
      if (index + 1 < lines.length &&
          _normalize(lines[index + 1]).startsWith('endereco') &&
          _looksLikeName(candidate)) {
        score = 0.9;
      }
      candidate = _clean(candidate.replaceAll(RegExp(r'\([^)]*\)'), ''));
      if (_looksLikeName(candidate) && score > bestScore) {
        best = _titleCase(candidate);
        bestScore = score;
      }
    }
    return NameExtraction(name: best, confidence: bestScore);
  }

  bool _looksLikeName(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    return words.length >= 2 &&
        words.length <= 6 &&
        value.length >= 5 &&
        value.length <= 70 &&
        !RegExp(r'\d{3,}').hasMatch(value) &&
        words.every((word) => RegExp(r"^[A-Za-zÀ-ÿ'.-]+$").hasMatch(word));
  }

  bool _looksLikeNoise(String value) =>
      value.contains('remetente') ||
      value.contains('nota fiscal') ||
      value.contains('danfe') ||
      value.contains('chave de acesso') ||
      value.contains('codigo') ||
      value.startsWith('rua ') ||
      value.startsWith('cidade ') ||
      value.startsWith('complemento ');

  String _clean(String value) => value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[^A-Za-zÀ-ÿ]+|[^A-Za-zÀ-ÿ)]+$'), '')
      .trim();

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàãâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòõôö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c');

  String _titleCase(String value) => value
      .toLowerCase()
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
