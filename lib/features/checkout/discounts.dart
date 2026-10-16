import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../state/cart.dart';
import '../../state/loyalty.dart';

/// Cupón de descuento: porcentaje o valor fijo, con monto mínimo de compra.
class Voucher {
  const Voucher({
    required this.id,
    required this.code,
    this.percent,
    this.amount,
    required this.minTotal,
    this.listed = true,
  });

  final int id;

  /// Código que el cliente puede escribir ("CAFE20").
  final String code;
  final int? percent;
  final int? amount;

  /// Monto mínimo del pedido para poder usarlo.
  final int minTotal;

  /// `false` = solo se obtiene escribiendo el código.
  final bool listed;

  /// "15%" o "$20.000" (para la estampilla del cupón).
  String get label => percent != null ? '$percent%' : formatCOP(amount!).replaceAll(' ', '');

  String get title => percent != null ? 'Descuento del $percent%' : 'Descuento de $label';
  String get subtitle => minTotal > 0 ? 'En compras desde ${formatCOP(minTotal).replaceAll(' ', '')}' : 'Sin monto mínimo';

  /// Lo que falta para usarlo con [subtotal] (0 si ya alcanza).
  int missing(int subtotal) => subtotal >= minTotal ? 0 : minTotal - subtotal;

  /// Descuento que da sobre [subtotal] (0 si no alcanza el mínimo).
  int discountFor(int subtotal) {
    if (missing(subtotal) > 0) return 0;
    final d = percent != null ? subtotal * percent! ~/ 100 : amount!;
    return d.clamp(0, subtotal);
  }
}

// MOCK: el backend no expone cupones aún; la lista vive en la app.
const vouchers = [
  Voucher(id: 1, code: 'CAFE10', percent: 10, minTotal: 20000),
  Voucher(id: 2, code: 'CAFE15', percent: 15, minTotal: 25000),
  Voucher(id: 3, code: 'BONO75', amount: 75000, minTotal: 280000),
  Voucher(id: 4, code: 'BONO20', amount: 20000, minTotal: 80000),
  Voucher(id: 5, code: 'CAFE30', percent: 30, minTotal: 30000),
  Voucher(id: 6, code: 'CAFE20', percent: 20, minTotal: 0, listed: false),
];

Voucher? voucherById(int? id) => vouchers.where((v) => v.id == id).firstOrNull;
Voucher? voucherByCode(String code) => vouchers.where((v) => v.code == code.trim().toUpperCase()).firstOrNull;

/// Cupón aplicado al carrito (guardado en el teléfono). Se borra al pagar.
class AppliedVoucherNotifier extends Notifier<Voucher?> {
  static const _key = 'cq.voucher';

  @override
  Voucher? build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return null;
    try {
      return voucherById((jsonDecode(raw) as Map)['id'] as int?);
    } catch (_) {
      return null;
    }
  }

  void apply(Voucher v) {
    state = v;
    ref.read(prefsProvider).setString(_key, jsonEncode({'id': v.id}));
    // Un descuento por pedido: el cupón reemplaza la bebida gratis.
    ref.read(useFreeDrinkProvider.notifier).set(false);
  }

  void clear() {
    state = null;
    ref.read(prefsProvider).remove(_key);
  }
}

final appliedVoucherProvider = NotifierProvider<AppliedVoucherNotifier, Voucher?>(AppliedVoucherNotifier.new);

/// El cliente eligió usar una bebida gratis en este pedido.
class UseFreeDrinkNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    state = value;
    if (value) ref.read(appliedVoucherProvider.notifier).clear();
  }
}

final useFreeDrinkProvider = NotifierProvider<UseFreeDrinkNotifier, bool>(UseFreeDrinkNotifier.new);

/// MOCK: bebida = producto de "Café" (1) o "Sin café" (2), o cualquiera que
/// no sea de pastelería (3) mientras el backend no marque las bebidas.
bool isDrink(Product p) => p.categoryIds.any((c) => c == 1 || c == 2) || !p.categoryIds.contains(3);

/// Precio de la bebida más barata del carrito (lo que cubre la bebida gratis).
int? cheapestDrink(CartState cart) {
  final prices = [for (final i in cart.items) if (isDrink(i.product)) i.unitPrice];
  if (prices.isEmpty) return null;
  return prices.reduce((a, b) => a < b ? a : b);
}

enum DiscountKind { none, voucher, freeDrink }

/// Descuento del pedido: un solo tipo a la vez.
class CheckoutDiscount {
  const CheckoutDiscount({this.kind = DiscountKind.none, this.amount = 0, this.voucher, this.missing = 0});
  final DiscountKind kind;
  final int amount;
  final Voucher? voucher;

  /// Para un cupón que aún no alcanza el mínimo: lo que falta.
  final int missing;
}

final checkoutDiscountProvider = Provider<CheckoutDiscount>((ref) {
  final cart = ref.watch(cartProvider);
  if (ref.watch(useFreeDrinkProvider) && ref.watch(loyaltyProvider.select((b) => b.freeDrinks)) > 0) {
    final price = cheapestDrink(cart);
    if (price != null) return CheckoutDiscount(kind: DiscountKind.freeDrink, amount: price.clamp(0, cart.subtotal));
  }
  final v = ref.watch(appliedVoucherProvider);
  if (v != null) {
    return CheckoutDiscount(kind: DiscountKind.voucher, voucher: v, amount: v.discountFor(cart.subtotal), missing: v.missing(cart.subtotal));
  }
  return const CheckoutDiscount();
});

/// Resultado de puntos del último pago, para la confirmación ("¡Ganaste al Toche!").
class LastRewardNotifier extends Notifier<({int orderId, PointsResult points})?> {
  @override
  ({int orderId, PointsResult points})? build() => null;

  void set(int orderId, PointsResult points) => state = (orderId: orderId, points: points);
}

final lastRewardProvider = NotifierProvider<LastRewardNotifier, ({int orderId, PointsResult points})?>(LastRewardNotifier.new);

/// Pedidos cuyo aviso de "listo" ya se mostró (una sola vez por pedido).
class ReadyShown {
  ReadyShown(this._ref);
  final Ref _ref;
  static const _key = 'cq.ready-shown';

  Set<int> _read() => (_ref.read(prefsProvider).getStringList(_key) ?? const []).map(int.tryParse).whereType<int>().toSet();

  bool contains(int id) => _read().contains(id);

  void add(int id) {
    final s = _read()..add(id);
    // Solo los últimos 50 para no crecer sin fin.
    _ref.read(prefsProvider).setStringList(_key, s.map((e) => '$e').toList().reversed.take(50).toList());
  }
}

final readyShownProvider = Provider<ReadyShown>(ReadyShown.new);
