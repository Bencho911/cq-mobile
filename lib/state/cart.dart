import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../data/models.dart';
import 'customization.dart';

/// Preferencias del dispositivo; se inyecta en `main` ya cargada.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefsProvider sin override'));

class CartItem {
  const CartItem({
    required this.product,
    this.quantity = 1,
    this.size,
    this.variant,
    this.sugar,
    this.ice,
    this.toppings = const [],
    this.notes,
  });

  final Product product;
  final int quantity;
  // MOCK: personalización de bebida (no soportada por el backend aún).
  final String? size;
  final String? variant;
  final String? sugar;
  final String? ice;
  final List<String> toppings;
  final String? notes;

  /// Identidad de la línea: producto más su personalización. Un Nitro
  /// mediano y uno grande con espresso extra son dos líneas distintas.
  String get key => [
        product.codProd,
        size ?? '',
        variant ?? '',
        sugar ?? '',
        ice ?? '',
        ([...toppings]..sort()).join('+'),
        notes?.trim() ?? '',
      ].join('|');

  /// Precio unitario que paga el cliente: producto con descuento más adiciones.
  int get unitPrice => discountedPrice(product.price, product.discount) + toppingsPrice(toppings);

  CartItem copyWith({int? quantity, List<String>? toppings}) => CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        size: size,
        variant: variant,
        sugar: sugar,
        ice: ice,
        toppings: toppings ?? this.toppings,
        notes: notes,
      );

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
        'size': size,
        'variant': variant,
        'sugar': sugar,
        'ice': ice,
        'toppings': toppings,
        'notes': notes,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        product: Product.fromJson(Map<String, dynamic>.from(j['product'] as Map)),
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        size: j['size'] as String?,
        variant: j['variant'] as String?,
        sugar: j['sugar'] as String?,
        ice: j['ice'] as String?,
        toppings: ((j['toppings'] as List?) ?? const []).cast<String>(),
        notes: j['notes'] as String?,
      );
}

enum DeliveryType { recoger, domicilio }

class CartState {
  const CartState({
    this.items = const [],
    this.storeId,
    this.deliveryType = DeliveryType.recoger,
    this.pickupTime,
    this.paymentMethod,
  });

  final List<CartItem> items;
  final int? storeId;
  final DeliveryType deliveryType;

  /// Hora de recogida; `null` = "lo antes posible".
  final DateTime? pickupTime;
  final String? paymentMethod;

  int get count => items.fold(0, (sum, i) => sum + i.quantity);
  int get subtotal => items.fold(0, (sum, i) => sum + i.quantity * i.unitPrice);

  /// Hora válida solo si es futura: una hora que ya pasó vuelve a "lo antes posible".
  DateTime? upcomingPickup([DateTime? now]) {
    final t = pickupTime;
    return t != null && t.isAfter(now ?? DateTime.now()) ? t : null;
  }

  CartState copyWith({
    List<CartItem>? items,
    int? storeId,
    DeliveryType? deliveryType,
    DateTime? Function()? pickupTime,
    String? Function()? paymentMethod,
  }) =>
      CartState(
        items: items ?? this.items,
        storeId: storeId ?? this.storeId,
        deliveryType: deliveryType ?? this.deliveryType,
        pickupTime: pickupTime != null ? pickupTime() : this.pickupTime,
        paymentMethod: paymentMethod != null ? paymentMethod() : this.paymentMethod,
      );

  /// Líneas de orden para el backend (precio con descuento, el que vio el cliente).
  List<OrderLine> toOrderLines() => items
      .map((i) => OrderLine(
            codProd: i.product.codProd,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            name: i.product.name,
            imageUrl: i.product.imageUrl,
          ))
      .toList();

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'storeId': storeId,
        'deliveryType': deliveryType.name,
        'pickupTime': pickupTime?.toIso8601String(),
        'paymentMethod': paymentMethod,
      };

  factory CartState.fromJson(Map<String, dynamic> j) => CartState(
        items: ((j['items'] as List?) ?? const [])
            .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        storeId: (j['storeId'] as num?)?.toInt(),
        deliveryType: DeliveryType.values.asNameMap()[j['deliveryType']] ?? DeliveryType.recoger,
        pickupTime: DateTime.tryParse('${j['pickupTime'] ?? ''}'),
        paymentMethod: j['paymentMethod'] as String?,
      );
}

/// Carrito persistente (se guarda entre visitas).
class CartNotifier extends Notifier<CartState> {
  static const _key = 'cq-cart-v1';

  @override
  CartState build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const CartState();
    try {
      return CartState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const CartState();
    }
  }

  void _set(CartState next) {
    state = next;
    ref.read(prefsProvider).setString(_key, jsonEncode(next.toJson()));
  }

  /// Solo se suman líneas idénticas.
  void add(CartItem item) {
    final i = state.items.indexWhere((e) => e.key == item.key);
    if (i < 0) {
      _set(state.copyWith(items: [...state.items, item]));
    } else {
      final items = [...state.items];
      items[i] = items[i].copyWith(quantity: items[i].quantity + item.quantity);
      _set(state.copyWith(items: items));
    }
  }

  void remove(String key) => _set(state.copyWith(items: state.items.where((e) => e.key != key).toList()));

  void setQuantity(String key, int quantity) => _set(state.copyWith(
      items: state.items.map((e) => e.key == key ? e.copyWith(quantity: quantity < 1 ? 1 : quantity) : e).toList()));

  void clear() => _set(state.copyWith(items: const []));
  void setStore(int storeId) => _set(state.copyWith(storeId: storeId));
  void setDelivery(DeliveryType type) => _set(state.copyWith(deliveryType: type));
  void setPickupTime(DateTime? time) => _set(state.copyWith(pickupTime: () => time));
  void setPaymentMethod(String? method) => _set(state.copyWith(paymentMethod: () => method));
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
