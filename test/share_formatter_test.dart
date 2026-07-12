import 'package:encomendas/features/delivery_lists/domain/share_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agrupa nomes repetidos e ordena', () {
    final text = ShareFormatter().format(
      title: 'Entregas Mercado Livre',
      date: DateTime(2026, 7, 11),
      names: ['Pedro Lima', 'Mateus Gabardo', 'mateus gabardo'],
    );
    expect(
      text,
      'Entregas Mercado Livre\n11/07/2026\n\nMateus Gabardo (2)\nPedro Lima',
    );
  });
}
