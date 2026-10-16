import 'package:cafe_quindio/features/shop/home.dart';
import 'package:cafe_quindio/features/shop/menu.dart';
import 'package:cafe_quindio/features/shop/notifications.dart';
import 'package:cafe_quindio/features/shop/stores.dart';
import 'package:cafe_quindio/state/cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (c, s) => screen),
    GoRoute(path: '/stores', builder: (c, s) => const StoresScreen()),
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

void main() {
  testWidgets('inicio: lo de siempre, puertas, lealtad y productos', (tester) async {
    await _pump(tester, const HomeScreen());
    expect(find.text('¿Lo de siempre?'), findsOneWidget);
    expect(find.text('Sin café'), findsOneWidget);
    expect(find.textContaining('puntos'), findsWidgets);
    expect(find.text('Café con leche'), findsOneWidget);
    expect(find.text('Ver todo el menú'), findsOneWidget);
  });

  testWidgets('detalle: personalizar y agregar suma al carrito', (tester) async {
    final c = await _pump(tester, const HomeScreen());
    await tester.ensureVisible(find.text('Café con leche'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Norte'));
    await tester.pumpAndSettle();
    expect(c.read(cartProvider).storeId, 2);
  });

  testWidgets('notificaciones: marcar todas como leídas', (tester) async {
    await _pump(tester, const NotificationsScreen());
    expect(find.text('Tienes 2 sin leer'), findsOneWidget);
    await tester.tap(find.text('Marcar todas como leídas'));
    await tester.pump();
    expect(find.text('Tienes 2 sin leer'), findsNothing);
    expect(find.text('Marcar todas como leídas'), findsNothing);
  });
}
