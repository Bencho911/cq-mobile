import 'package:cafe_quindio/features/shop/home.dart';
import 'package:cafe_quindio/features/shop/menu.dart';
import 'package:cafe_quindio/features/shop/notifications.dart';
import 'package:cafe_quindio/features/shop/stores.dart';
import 'dart:convert';

import 'package:cafe_quindio/data/history.dart';
import 'package:cafe_quindio/state/account.dart';
import 'package:cafe_quindio/state/cart.dart';
import 'package:cafe_quindio/state/loyalty.dart';
import 'package:cafe_quindio/state/notifications.dart';
import 'package:cafe_quindio/state/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(WidgetTester tester, Widget screen, {Map<String, Object> prefs0 = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs0);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (c, s) => screen),
    GoRoute(path: '/stores', builder: (c, s) => const StoresScreen()),
    GoRoute(path: '/track-order', builder: (c, s) => Scaffold(body: Text('seguimiento ${s.extra}'))),
    GoRoute(path: '/invoice/:id', builder: (c, s) => Scaffold(body: Text('recibo ${s.pathParameters['id']}'))),
    GoRoute(path: '/:any', builder: (c, s) => Scaffold(body: Text('ruta ${s.uri.path}'))),
  ]);
  // La fuente de pruebas (Ahem) es más ancha que la real: se ignoran los desbordes.
  final onError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!d.exceptionAsString().contains('overflowed')) onError?.call(d);
  };
  addTearDown(() => FlutterError.onError = onError);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
  await tester.pump();
  await tester.pump();
  return container;
}

PastOrder _order(int id, PastOrderStatus status, {DateTime? at}) => PastOrder(
      id: id,
      status: status,
      items: const [
        PastOrderItem(codProd: 3, name: 'Nitro Cold Brew', size: 'Grande', variant: 'Frío', toppings: ['espresso'], quantity: 1, unitPrice: 36000),
      ],
      store: 'Café Quindío · Centro',
      storeId: 1,
      createdAt: at ?? DateTime.now(),
      paymentMethod: 'Pago en kiosco',
    );

String _orders(List<PastOrder> list) => jsonEncode(list.map((o) => o.toJson()).toList());

final _account = jsonEncode(UserAccount(name: 'Laura Gómez', phone: '3138924671', createdAt: DateTime(2026)).toJson());

void main() {
  testWidgets('inicio: cliente nuevo ve bienvenida, 0 puntos y sin pedido activo', (tester) async {
    await _pump(tester, const HomeScreen(), prefs0: {'cq.account': _account});
    expect(find.textContaining('Laura.'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('Tu primer pedido'), findsOneWidget);
    expect(find.text('¿Lo de siempre?'), findsNothing);
    expect(find.text('Empieza tu álbum'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Sin café'), findsOneWidget);
    await tester.tap(find.text('Ver el menú'));
    await tester.pumpAndSettle();
    expect(find.text('ruta /menu'), findsOneWidget);
  });

  testWidgets('inicio: lo de siempre repite con la personalización y muestra el pedido activo', (tester) async {
    final c = await _pump(tester, const HomeScreen(), prefs0: {
      'cq.account': _account,
      'cq.orders': _orders([_order(1002, PastOrderStatus.preparando), _order(1001, PastOrderStatus.completada)]),
      'cq.loyalty': jsonEncode(const LoyaltyBook(account: LoyaltyAccount(points: 20, completedCards: 0), freeDrinks: 1).toJson()),
    });
    c.read(notificationsProvider.notifier).add(NotificationKind.promo, 'Hola', 'Prueba');
    await tester.pump();
    expect(find.text('¿Lo de siempre?'), findsOneWidget);
    expect(find.text('Tienes 1 bebida gratis'), findsOneWidget);
    expect(find.text('Te faltan '), findsNothing);
    expect(find.bySemanticsLabel(RegExp('1 sin leer')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tu pedido número 1002: Preparando')), findsOneWidget);

    await tester.tap(find.text('Pedir por '));
    await tester.pumpAndSettle();
    final item = c.read(cartProvider).items.single;
    expect(item.product.codProd, 3);
    expect(item.size, 'Grande');
    expect(item.toppings, ['espresso']);
    expect(find.text('ruta /checkout'), findsOneWidget);
  });

  testWidgets('inicio: la franja del pedido activo abre el seguimiento', (tester) async {
    await _pump(tester, const HomeScreen(), prefs0: {'cq.orders': _orders([_order(1005, PastOrderStatus.listo)])});
    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(find.text('seguimiento 1005'), findsOneWidget);
  });

  testWidgets('detalle: personalizar y agregar suma al carrito', (tester) async {
    final c = await _pump(tester, const HomeScreen());
    await tester.scrollUntilVisible(find.text('Café con leche'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Ver todo el menú'), findsOneWidget);
    await tester.tap(find.text('Café con leche'));
    await tester.pumpAndSettle();
    expect(find.text('Notas para la barra'), findsOneWidget);
    await tester.tap(find.text('Grande'));
    await tester.tap(find.bySemanticsLabel('Agregar uno'));
    await tester.pump();
    expect(find.text(r'$ 50.000'), findsOneWidget);
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    final cart = c.read(cartProvider);
    expect(cart.count, 2);
    expect(cart.items.single.size, 'Grande');
    expect(find.text('Notas para la barra'), findsNothing);
    expect(find.text('Ver pedido ('), findsOneWidget);
  });

  testWidgets('detalle: arrastrar hacia abajo desde el tope lo cierra', (tester) async {
    await _pump(tester, const MenuScreen());
    await tester.tap(find.text('Nitro Cold Brew'));
    await tester.pumpAndSettle();
    expect(find.text('Notas para la barra'), findsOneWidget);
    await tester.drag(find.text('Temperatura'), const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(find.text('Notas para la barra'), findsOneWidget);
    await tester.fling(find.text('Temperatura'), const Offset(0, 300), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Notas para la barra'), findsNothing);
  });

  testWidgets('menú: filtra por categoría y búsqueda', (tester) async {
    await _pump(tester, const MenuScreen(category: 'Pastelería'));
    expect(find.text('Sin resultados'), findsOneWidget);
    await tester.tap(find.text('Todos'));
    await tester.pump();
    expect(find.text('Nitro Cold Brew'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'caramel');
    await tester.pump();
    expect(find.text('Nitro Cold Brew'), findsNothing);
    expect(find.text('Caramel Latte'), findsOneWidget);
  });

  testWidgets('tiendas: elegir guarda la tienda en el carrito', (tester) async {
    final c = await _pump(tester, const StoresScreen());
    expect(find.text('Abierta'), findsNWidgets(2));
    expect(find.text('Cómo llegar'), findsWidgets);
    await tester.tap(find.text('Norte'));
    await tester.pumpAndSettle();
    expect(c.read(cartProvider).storeId, 2);
  });

  testWidgets('tiendas: la favorita se guarda y sube al primer lugar', (tester) async {
    final c = await _pump(tester, const StoresScreen());
    final norte = find.bySemanticsLabel(RegExp('Marcar Norte como favorita'));
    expect(norte, findsOneWidget);
    await tester.tap(norte);
    await tester.pumpAndSettle();
    expect(c.read(preferencesProvider).favoriteStores, {2});
    expect(find.bySemanticsLabel(RegExp('Quitar Norte de favoritas')), findsOneWidget);
    // Norte queda arriba de las demás.
    final names = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).where((d) => d == 'Norte' || d == 'Centro').toList();
    expect(names.first, 'Norte');
  });

  testWidgets('notificaciones: vacío, agrupadas, marcar todas y abrir pedido', (tester) async {
    final c = await _pump(tester, const NotificationsScreen(),
        prefs0: {'cq.orders': _orders([_order(1001, PastOrderStatus.completada), _order(1002, PastOrderStatus.preparando)])});
    expect(find.text('Sin notificaciones'), findsOneWidget);

    final inbox = c.read(notificationsProvider.notifier);
    inbox.add(NotificationKind.orderPlaced, 'Pedido confirmado', 'Tu pedido #1001 está en la barra.', orderId: 1001);
    inbox.add(NotificationKind.points, 'Sumaste 5 puntos', 'Por tu pedido #1002.', orderId: 1002);
    await tester.pump();
    expect(find.text('HOY'), findsOneWidget);
    expect(find.text('Tienes 2 sin leer'), findsOneWidget);

    await tester.tap(find.text('Pedido confirmado'));
    await tester.pumpAndSettle();
    expect(find.text('recibo 1001'), findsOneWidget);
    expect(c.read(unreadNotificationsProvider), 1);
  });

  testWidgets('notificaciones: marcar todas como leídas', (tester) async {
    final c = await _pump(tester, const NotificationsScreen());
    c.read(notificationsProvider.notifier)
      ..add(NotificationKind.promo, 'Uno', 'a')
      ..add(NotificationKind.promo, 'Dos', 'b');
    await tester.pump();
    expect(find.text('Tienes 2 sin leer'), findsOneWidget);
    await tester.tap(find.text('Marcar todas como leídas'));
    await tester.pump();
    expect(find.text('Tienes 2 sin leer'), findsNothing);
    expect(find.text('Marcar todas como leídas'), findsNothing);
  });
}
