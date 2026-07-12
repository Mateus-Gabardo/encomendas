import 'package:encomendas/features/delivery_lists/domain/delivery_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lista nova fica com status não enviado', () {
    final list = DeliveryList(
      id: '1',
      title: 'Entregas Shopee',
      createdAt: DateTime(2026, 7, 12),
    );

    expect(list.isSent, isFalse);
    expect(list.sentStatusLabel, 'Não enviado');
  });

  test('lista com sentAt fica com status enviado e persiste em json', () {
    final sentAt = DateTime(2026, 7, 12, 10, 30);
    final list = DeliveryList(
      id: '1',
      title: 'Entregas Shopee',
      createdAt: DateTime(2026, 7, 12),
      sentAt: sentAt,
    );

    final restored = DeliveryList.fromJson(list.toJson());

    expect(restored.isSent, isTrue);
    expect(restored.sentStatusLabel, 'Enviado');
    expect(restored.sentAt, sentAt);
  });
}
