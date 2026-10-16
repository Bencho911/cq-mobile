import 'package:cafe_quindio/data/mock_data.dart';
import 'package:cafe_quindio/features/checkout/checkout.dart';
import 'package:cafe_quindio/features/checkout/order_success.dart';
import 'package:cafe_quindio/features/checkout/payment_method.dart';
import 'package:cafe_quindio/features/checkout/track_order.dart';
import 'package:cafe_quindio/features/checkout/vouchers.dart';
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
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (c, s) => screen),
      GoRoute(
        path: '/:any',
        builder: (c, s) => Scaffold(body: Text('ruta ${s.uri.path}')),
      ),
    ],
  );
  // La fuente de pruebas (Ahem) es más ancha que la real: se ignoran los desbordes.
  final onError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!d.exceptionAsString().contains('overflowed')) onError?.call(d);
  };
  addTearDown(() => FlutterError.onError = onError);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return container;
}

void main() {
  testWidgets('carrito vacío muestra el estado vacío', (tester) async {
    await _pump(tester, const CheckoutScreen());
    await tester.pump();
    expect(find.text('Tu pedido está vacío'), findsOneWidget);
  });

  testWidgets('carrito con productos, cantidades y hoja de hora', (tester) async {
    final c = await _pump(tester, const CheckoutScreen());
    c.read(cartProvider.notifier).add(CartItem(product: mockProducts[2], quantity: 2, size: 'Mediano'));
    await tester.pumpAndSettle();
    expect(find.text('Nitro Cold Brew'), findsOneWidget);
    expect(find.text('Pagar y pedir'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Agregar uno'));
    await tester.pumpAndSettle();
    expect(c.read(cartProvider).count, 3);
    await tester.tap(find.text('Hora de recogida'));
    await tester.pumpAndSettle();
    expect(find.text('¿A qué hora lo recoges?'), findsOneWidget);
    await tester.tap(find.text('Recoger lo antes posible'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Domicilio'));
    await tester.pumpAndSettle();
    expect(find.text('Dirección de entrega'), findsOneWidget);
  });

  testWidgets('pagar crea el pedido y vacía el carrito', (tester) async {
    final c = await _pump(tester, const CheckoutScreen());
    c.read(cartProvider.notifier).add(CartItem(product: mockProducts[0], quantity: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagar y pedir'));
    await tester.pumpAndSettle();
    expect(c.read(cartProvider).items, isEmpty);
    expect(find.text('ruta /order-success'), findsOneWidget);
  });

  testWidgets('confirmación cuenta puntos y pasa al seguimiento', (tester) async {
    await _pump(tester, const OrderSuccessScreen(orderId: 1001, earned: 10));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('+10'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('ruta /track-order'), findsOneWidget);
  });

  testWidgets('seguimiento avanza y muestra el aviso de listo', (tester) async {
    await _pump(tester, const TrackOrderScreen(orderId: 1001));
    await tester.pump();
    expect(find.text('Recibimos tu pedido'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Preparando tu pedido'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Tu pedido está listo.'), findsOneWidget);
    await tester.tap(find.text('Ya lo recogí'));
    await tester.pumpAndSettle();
    expect(find.text('ruta /rating-review'), findsOneWidget);
  });

  testWidgets('método de pago y cupones', (tester) async {
    final c = await _pump(tester, const PaymentMethodScreen());
    await tester.pump();
    await tester.tap(find.text('Efectivo en tienda'));
    await tester.pumpAndSettle();
    expect(c.read(cartProvider).paymentMethod, 'efectivo');

    await _pump(tester, const VouchersScreen());
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'cafe20');
    await tester.pump();
    expect(find.text('CAFE20'), findsOneWidget);
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No encontramos ese código'), findsOneWidget);
  });
}
