import 'package:cafe_quindio/data/history.dart';
import 'package:cafe_quindio/features/account/album.dart';
import 'package:cafe_quindio/features/account/invoice.dart';
import 'package:cafe_quindio/features/account/order_details.dart';
import 'package:cafe_quindio/features/account/orders.dart';
import 'package:cafe_quindio/features/account/privacy.dart';
import 'package:cafe_quindio/features/account/profile.dart';
import 'package:cafe_quindio/features/account/rating_review.dart';
import 'package:cafe_quindio/state/cart.dart';
import 'package:cafe_quindio/state/loyalty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<void> _pump(WidgetTester tester, Widget screen, {SharedPreferences? prefs}) async {
  final p = prefs ?? await _prefs();
  // Teléfono (la fuente de prueba Ahem es más ancha que Neutra): detecta desbordes.
  tester.view.physicalSize = const Size(420, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => screen),
    GoRoute(path: '/checkout', builder: (_, _) => const Scaffold(body: Text('checkout'))),
    GoRoute(path: '/invoice/:id', builder: (_, s) => InvoiceScreen(id: int.parse(s.pathParameters['id']!), order: s.extra as PastOrder?)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(p)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
}

void main() {
  testWidgets('Pedidos: en curso, historial y abrir recibo', (tester) async {
    await _pump(tester, const OrdersScreen());
    expect(find.text('Preparando'), findsOneWidget);
    expect(find.text('Repetir pedido'), findsNothing);
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Repetir pedido'), findsNWidgets(3));
    expect(find.text('Volver a pedir'), findsOneWidget);
    await tester.tap(find.textContaining('Café con leche, Caffè Mocha'));
    await tester.pumpAndSettle();
    expect(find.text('Recibo'), findsOneWidget);
    expect(find.text('Tienda Norte'), findsOneWidget);
  });

  testWidgets('Recibo sin pedido usa el de ejemplo con descuento', (tester) async {
    await _pump(tester, const InvoiceScreen(id: 0));
    await tester.pumpAndSettle();
    expect(find.text('Descuento'), findsOneWidget);
    expect(find.text(r'$ 61.500'), findsNWidgets(2));
  });

  testWidgets('Álbum: primera visita sella las aves ganadas y guarda lo visto', (tester) async {
    final prefs = await _prefs();
    await _pump(tester, const AlbumScreen(), prefs: prefs);
    expect(find.text('0'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('47'), findsOneWidget);
    expect(find.text('Te faltan 3 para tu bebida gratis'), findsOneWidget);
    expect(find.text('Por descubrir'), findsNothing);
    final container = ProviderScope.containerOf(tester.element(find.byType(AlbumScreen)));
    expect(container.read(loyaltySeenProvider).read()?.points, 47);
  });

  testWidgets('Álbum: sin cambios no anima', (tester) async {
    final prefs = await _prefs({'cq.loyalty.seen': '{"points":47,"completedCards":2}'});
    await _pump(tester, const AlbumScreen(), prefs: prefs);
    expect(find.text('47'), findsOneWidget);
  });

  testWidgets('Calificar habilita el envío al elegir estrellas', (tester) async {
    await _pump(tester, const RatingReviewScreen());
    expect(find.text('Toca una estrella'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Casi perfecto'));
    await tester.pump();
    expect(find.text('Casi perfecto'), findsOneWidget);
  });

  testWidgets('Perfil, privacidad y detalle se dibujan', (tester) async {
    await _pump(tester, const ProfileScreen());
    expect(find.text('Próxima ave: Barranquero'), findsOneWidget);
    await _pump(tester, const PrivacyScreen());
    expect(find.text('Eliminar mi cuenta'), findsOneWidget);
    await _pump(tester, const OrderDetailsScreen());
    expect(find.text('No encontramos este pedido'), findsOneWidget);
  });
}
