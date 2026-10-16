import 'dart:convert';

import 'package:cafe_quindio/data/history.dart';
import 'package:cafe_quindio/features/account/album.dart';
import 'package:cafe_quindio/features/account/edit_profile.dart';
import 'package:cafe_quindio/features/account/invoice.dart';
import 'package:cafe_quindio/features/account/order_details.dart';
import 'package:cafe_quindio/features/account/orders.dart';
import 'package:cafe_quindio/features/account/preferences.dart';
import 'package:cafe_quindio/features/account/privacy.dart';
import 'package:cafe_quindio/features/account/profile.dart';
import 'package:cafe_quindio/features/account/rating_review.dart';
import 'package:cafe_quindio/features/account/receipt_pdf.dart';
import 'package:cafe_quindio/state/account.dart';
import 'package:cafe_quindio/state/cart.dart';
import 'package:cafe_quindio/state/loyalty.dart';
import 'package:cafe_quindio/state/orders.dart';
import 'package:cafe_quindio/state/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Pedidos de prueba guardados en el teléfono.
final _now = DateTime.now();
final _orders = [
  PastOrder(
    id: 1003,
    status: PastOrderStatus.preparando,
    items: const [PastOrderItem(name: 'Nitro Cold Brew', quantity: 1, unitPrice: 12000)],
    store: 'Café Quindío · Centro',
    createdAt: _now,
    paymentMethod: 'Tarjeta (Wompi)',
  ),
  PastOrder(
    id: 1002,
    status: PastOrderStatus.completada,
    items: const [
      PastOrderItem(name: 'Café con leche', size: 'Grande', variant: 'Caliente', quantity: 2, unitPrice: 9000),
      PastOrderItem(name: 'Caffè Mocha', quantity: 1, unitPrice: 14000),
    ],
    store: 'Café Quindío · Norte',
    createdAt: _now.subtract(const Duration(days: 1)),
    paymentMethod: 'Efectivo en tienda',
    discount: 2000,
    earnedPoints: 6,
  ),
  PastOrder(
    id: 1001,
    status: PastOrderStatus.cancelada,
    items: const [PastOrderItem(name: 'Capuchino', quantity: 1, unitPrice: 8000)],
    store: 'Café Quindío · Centro',
    createdAt: _now.subtract(const Duration(days: 5)),
    paymentMethod: 'Pago en kiosco',
  ),
];

Map<String, Object> _seed({bool orders = true, int points = 0, int cards = 0, int freeDrinks = 0}) => {
      'cq.account': jsonEncode(UserAccount(name: 'Santiago Restrepo', phone: '3138924671', createdAt: _now).toJson()),
      'cq.session': true,
      if (orders) 'cq.orders': jsonEncode(_orders.map((o) => o.toJson()).toList()),
      'cq.loyalty': jsonEncode(LoyaltyBook(
        account: LoyaltyAccount(points: points, completedCards: cards),
        movements: points > 0 ? [LoyaltyMovement(label: 'Compra en Tienda Centro', points: points, date: _now)] : const [],
        freeDrinks: freeDrinks,
      ).toJson()),
    };

/// Teléfono sin biometría (las pruebas no tienen canal de plataforma).
class _NoBiometrics extends LocalAuthentication {
  @override
  Future<bool> isDeviceSupported() async => false;
}

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<ProviderContainer> _pump(WidgetTester tester, Widget screen, {SharedPreferences? prefs}) async {
  final p = prefs ?? await _prefs(_seed());
  // Teléfono (la fuente de prueba Ahem es más ancha que Neutra): detecta desbordes.
  tester.view.physicalSize = const Size(420, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => screen),
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('inicio'))),
    GoRoute(path: '/checkout', builder: (_, _) => const Scaffold(body: Text('checkout'))),
    GoRoute(path: '/track-order', builder: (_, s) => Scaffold(body: Text('seguimiento ${s.extra}'))),
    GoRoute(path: '/invoice/:id', builder: (_, s) => InvoiceScreen(id: int.parse(s.pathParameters['id']!), order: s.extra as PastOrder?)),
  ]);
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(p),
    localAuthProvider.overrideWithValue(_NoBiometrics()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
  await tester.pump();
  return container;
}

void main() {
  testWidgets('Pedidos: en curso abre el seguimiento', (tester) async {
    await _pump(tester, const OrdersScreen());
    expect(find.text('Preparando'), findsOneWidget);
    expect(find.text('Repetir pedido'), findsNothing);
    await tester.tap(find.text('Nitro Cold Brew'));
    await tester.pumpAndSettle();
    expect(find.text('seguimiento 1003'), findsOneWidget);
  });

  testWidgets('Pedidos: historial y abrir recibo con descuento y puntos', (tester) async {
    await _pump(tester, const OrdersScreen());
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Repetir pedido'), findsOneWidget);
    expect(find.text('Volver a pedir'), findsOneWidget);
    await tester.tap(find.textContaining('Café con leche, Caffè Mocha'));
    await tester.pumpAndSettle();
    expect(find.text('Recibo'), findsOneWidget);
    expect(find.text('Tienda Norte'), findsOneWidget);
    expect(find.text('Descuento'), findsOneWidget);
    expect(find.text('+6'), findsOneWidget);
    expect(find.text(r'$ 30.000'), findsNWidgets(2));
    expect(find.text('Calificar pedido'), findsOneWidget);
    expect(find.text('Grande, caliente'), findsOneWidget);
  });

  testWidgets('Pedidos: cliente nuevo ve el estado vacío', (tester) async {
    await _pump(tester, const OrdersScreen(), prefs: await _prefs(_seed(orders: false)));
    expect(find.text('Aún no tienes pedidos'), findsOneWidget);
    expect(find.text('Ver el menú'), findsOneWidget);
  });

  testWidgets('Recibo de un pedido que no existe', (tester) async {
    await _pump(tester, const InvoiceScreen(id: 0));
    await tester.pumpAndSettle();
    expect(find.text('No encontramos este pedido'), findsOneWidget);
  });

  testWidgets('Recibo en PDF y en texto', (tester) async {
    final o = _orders[1];
    final bytes = await tester.runAsync(() => buildReceiptPdf(o));
    expect(utf8.decode(bytes!.sublist(0, 4)), '%PDF');
    final text = receiptText(o);
    expect(text, contains('Pedido 1002'));
    expect(text, contains(r'Total: $ 30.000'));
    expect(text, contains('Puntos ganados: 6'));
  });

  testWidgets('Álbum: cliente nuevo arranca en 0 con la tarjeta vacía', (tester) async {
    await _pump(tester, const AlbumScreen(), prefs: await _prefs(_seed(orders: false)));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Te faltan 50 para tu bebida gratis'), findsOneWidget);
    expect(find.text('Por descubrir'), findsNWidgets(4));
    expect(find.textContaining('Aún no tienes movimientos'), findsOneWidget);
  });

  testWidgets('Álbum: primera visita sella las aves ganadas y guarda lo visto', (tester) async {
    final prefs = await _prefs({..._seed(points: 47, cards: 2, freeDrinks: 1), 'cq.preferences': '{"sounds":false}'});
    final container = await _pump(tester, const AlbumScreen(), prefs: prefs);
    expect(find.text('0'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('47'), findsOneWidget);
    expect(find.text('Te faltan 3 para tu bebida gratis'), findsOneWidget);
    expect(find.text('Por descubrir'), findsNothing);
    expect(find.text('Tienes 1 bebida gratis'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Compra en Tienda Centro'), 200);
    expect(find.textContaining('2 tarjetas completas'), findsOneWidget);
    expect(container.read(loyaltySeenProvider).read()?.points, 47);
  });

  testWidgets('Álbum: sin cambios no anima y suma al recibir puntos', (tester) async {
    final prefs = await _prefs({..._seed(points: 20), 'cq.loyalty.seen': '{"points":20,"completedCards":0}', 'cq.preferences': '{"sounds":false}'});
    final container = await _pump(tester, const AlbumScreen(), prefs: prefs);
    expect(find.text('Te faltan 30 para tu bebida gratis'), findsOneWidget);
    container.read(loyaltyProvider.notifier).addPoints(12, 'Compra en Tienda Norte');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('32'), findsOneWidget);
  });

  testWidgets('Calificar guarda la calificación del pedido', (tester) async {
    final container = await _pump(tester, const RatingReviewScreen());
    expect(find.text('Toca una estrella'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Casi perfecto'));
    await tester.pump();
    expect(find.text('Casi perfecto'), findsOneWidget);
    await tester.tap(find.text('Enviar calificación'));
    await tester.pump();
    expect(find.text('¡Gracias!'), findsOneWidget);
    expect(container.read(ordersProvider.notifier).byId(1002)?.rating, 4);
  });

  testWidgets('Calificar sin pedidos muestra el estado vacío', (tester) async {
    await _pump(tester, const RatingReviewScreen(), prefs: await _prefs(_seed(orders: false)));
    expect(find.text('Aún no hay pedidos para calificar'), findsOneWidget);
  });

  testWidgets('Perfil con datos de la cuenta y cierre de sesión', (tester) async {
    final container = await _pump(tester, const ProfileScreen(), prefs: await _prefs(_seed(points: 12)));
    expect(find.text('Santiago Restrepo'), findsOneWidget);
    expect(find.text('+57 313 892 4671'), findsOneWidget);
    expect(find.text('Próxima ave: Toche'), findsOneWidget);
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();
    expect(container.read(authProvider).loggedIn, isFalse);
  });

  testWidgets('Editar perfil valida y guarda', (tester) async {
    final container = await _pump(tester, const EditProfileScreen());
    await tester.enterText(find.byType(TextField).at(1), '12345');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    expect(find.text('El celular tiene 10 dígitos y empieza por 3.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '3001234567');
    await tester.enterText(find.byType(TextField).at(3), 'santi@correo.com');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    final a = container.read(authProvider).account!;
    expect(a.phone, '3001234567');
    expect(a.email, 'santi@correo.com');
  });

  testWidgets('Preferencias se guardan', (tester) async {
    final container = await _pump(tester, const PreferencesScreen());
    await tester.tap(find.bySemanticsLabel('Sonidos del álbum'));
    await tester.pump();
    expect(container.read(preferencesProvider).sounds, isFalse);
    final saved = container.read(prefsProvider).getString('cq.preferences');
    expect(saved, contains('"sounds":false'));
  });

  testWidgets('Privacidad y detalle se dibujan', (tester) async {
    await _pump(tester, const PrivacyScreen());
    await tester.pumpAndSettle();
    expect(find.text('Eliminar mi cuenta'), findsOneWidget);
    expect(find.text('Este teléfono no tiene Face ID ni huella configurados'), findsOneWidget);
    await tester.tap(find.text('Términos y condiciones'));
    await tester.pumpAndSettle();
    expect(find.text('Versión resumida'), findsOneWidget);

    await _pump(tester, const OrderDetailsScreen());
    expect(find.text('No encontramos este pedido'), findsOneWidget);
    await _pump(tester, const OrderDetailsScreen(orderId: 1002));
    expect(find.text('Pedido '), findsNothing);
    expect(find.text('Entregado'), findsOneWidget);
    expect(find.text('Descargar recibo'), findsOneWidget);
  });
}
