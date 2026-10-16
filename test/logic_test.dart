import 'package:cafe_quindio/core/format.dart';
import 'package:cafe_quindio/data/mock_data.dart';
import 'package:cafe_quindio/state/cart.dart';
import 'package:cafe_quindio/state/loyalty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatCOP agrupa miles con punto', () {
    expect(formatCOP(25000), r'$ 25.000');
    expect(formatCOP(1234567), r'$ 1.234.567');
    expect(formatCOP(500), r'$ 500');
  });

  test('el precio de la línea incluye descuento y adiciones', () {
    final caramel = mockProducts.firstWhere((p) => p.codProd == 5); // 28.000 con 10 %
    final item = CartItem(product: caramel, toppings: const ['espresso']);
    expect(item.unitPrice, 25200 + 5000);
  });

  test('misma personalización = misma línea; distinta = otra línea', () {
    final nitro = mockProducts.firstWhere((p) => p.codProd == 3);
    final a = CartItem(product: nitro, size: 'Mediano', toppings: const ['jelly', 'espresso']);
    final b = CartItem(product: nitro, size: 'Mediano', toppings: const ['espresso', 'jelly']);
    final c = CartItem(product: nitro, size: 'Grande');
    expect(a.key, b.key);
    expect(a.key, isNot(c.key));
  });

  test('47 puntos = 4 aves y 70 % hacia la quinta', () {
    final s = summarize(const LoyaltyAccount(points: 47, completedCards: 2));
    expect(s.birdsEarned, 4);
    expect(s.pointsToReward, 3);
    expect(s.progressToNextBird, closeTo(0.7, 1e-9));
    expect(s.slots.where((x) => x.earned).length, 4);
  });

  test('preview avisa las aves nuevas y si se completa la tarjeta', () {
    final p = preview(const LoyaltyAccount(points: 18, completedCards: 0), 13);
    expect(p.newBirds.map((b) => b.id), ['toche', 'loro']);
    expect(p.completesCard, isFalse);
    expect(preview(const LoyaltyAccount(points: 47, completedCards: 0), 5).completesCard, isTrue);
  });
}
