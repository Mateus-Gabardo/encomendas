import 'package:encomendas/features/delivery_lists/domain/name_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final extractor = NameExtractor();

  test('extrai nome após destinatário', () {
    final result = extractor.extract(
      'DANFE SIMPLIFICADO\nDESTINATÁRIO: Mateus Gabardo Lemos\nUF: SC',
    );
    expect(result.name, 'Mateus Gabardo Lemos');
    expect(result.confidence, greaterThan(.9));
  });

  test('extrai nome imediatamente antes do endereço', () {
    final result = extractor.extract(
      'SEG 15/06/2026\nMateus Gabardo Lemos (GABARDOLEMOSMATEUS)\nEndereço: Rio da Anta SN',
    );
    expect(result.name, 'Mateus Gabardo Lemos');
    expect(result.confidence, greaterThanOrEqualTo(.9));
  });

  test('não inventa nome quando só existem códigos', () {
    final result = extractor.extract('47243498645\nCEP: 89199000\nNF: 205291');
    expect(result.name, isNull);
  });
}
