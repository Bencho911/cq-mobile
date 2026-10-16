import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../data/history.dart';
import '../data/models.dart';
import '../data/services.dart';
import 'cart.dart';
import 'customization.dart';
import 'loyalty.dart';
import 'notifications.dart';
import 'providers.dart';

/// Etiquetas de los métodos de pago guardados en el carrito.
const paymentLabels = {
  'wompi': 'Tarjeta (Wompi)',
  'efectivo': 'Efectivo en tienda',
  'kiosco': 'Pago en kiosco',
};

/// Pedidos del cliente guardados en el teléfono (más reciente primero).
/// Con backend real, el id es el de la orden del servidor.
class OrdersNotifier extends Notifier<List<PastOrder>> {
  static const _key = 'cq.orders';

  @override
  List<PastOrder> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).map((e) => PastOrder.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return const [];
    }
  }

  void _set(List<PastOrder> list) {
    state = list;
    ref.read(prefsProvider).setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  PastOrder? byId(int id) => state.where((o) => o.id == id).firstOrNull;

  /// Crea el pedido con lo que hay en el carrito: lo envía al backend (o al
  /// mock), lo guarda en el historial, suma los puntos y deja las
  /// notificaciones. No vacía el carrito (lo hace la pantalla de pago).
  Future<({PastOrder order, PointsResult points})> placeOrder({required Store? store, int discount = 0}) async {
    final cart = ref.read(cartProvider);
    final created = await ref.read(orderServiceProvider).createOrder(CreateOrderInput(
          items: cart.toOrderLines(),
          paymentMethod: cart.paymentMethod ?? 'kiosco',
          storeId: store?.id,
          deliveryType: cart.deliveryType.name,
        ));
    // En modo mock el contador del servicio arranca en 1001 en cada apertura:
    // el id local sigue la numeración del historial guardado.
    final lastId = state.isEmpty ? 1000 : state.map((o) => o.id).reduce((a, b) => a > b ? a : b);
    final id = AppConfig.useMocks ? lastId + 1 : created.id;
    final total = cart.subtotal - discount;
    final storeName = store?.name ?? 'Café Quindío';
    final order = PastOrder(
      id: id,
      status: PastOrderStatus.pendiente,
      items: [
        for (final i in cart.items)
          PastOrderItem(
            codProd: i.product.codProd,
            name: i.product.name,
            size: i.size,
            variant: i.variant,
            toppings: i.toppings,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            imageUrl: i.product.imageUrl,
          ),
      ],
      store: storeName,
      storeId: store?.id,
      address: cart.deliveryType == DeliveryType.domicilio ? cart.address.label : store?.address,
      createdAt: DateTime.now(),
      paymentMethod: paymentLabels[cart.paymentMethod] ?? paymentLabels['kiosco']!,
      discount: discount,
      deliveryType: cart.deliveryType == DeliveryType.domicilio ? 'Domicilio' : 'Recoger en tienda',
      pickupTime: cart.upcomingPickup(),
      earnedPoints: estimatePoints(total),
    );
    _set([order, ...state]);

    final points = ref.read(loyaltyProvider.notifier).addPoints(order.earnedPoints, 'Compra en ${store?.shortName != null ? 'Tienda ${store!.shortName}' : storeName}');
    final inbox = ref.read(notificationsProvider.notifier);
    inbox.add(NotificationKind.orderPlaced, 'Pedido confirmado', 'Tu pedido #$id está en la barra. Te avisamos cuando esté listo.', orderId: id);
    if (points.earned > 0) {
      inbox.add(NotificationKind.points, 'Sumaste ${points.earned} puntos', 'Por tu pedido #$id.', orderId: id);
    }
    for (final b in points.newBirds) {
      inbox.add(NotificationKind.bird, 'Ganaste un ave: ${b.name}', 'Ya está sellada en tu álbum.');
    }
    if (points.cardsCompleted > 0) {
      inbox.add(NotificationKind.reward, 'Tienes una bebida gratis', 'Completaste la tarjeta del álbum. Úsala en tu próximo pedido.');
    }
    return (order: order, points: points);
  }

  /// Avance del pedido (seguimiento). Al quedar listo deja la notificación.
  void setStatus(int id, PastOrderStatus status) {
    final o = byId(id);
    if (o == null || o.status == status) return;
    _set([for (final x in state) x.id == id ? x.copyWith(status: status) : x]);
    if (status == PastOrderStatus.listo) {
      ref.read(notificationsProvider.notifier).add(
            NotificationKind.orderReady,
            'Tu pedido está listo',
            'Pedido #$id: recógelo en la barra de ${o.store.replaceFirst(RegExp(r'^Café Quindío\s*[·-]\s*'), 'la Tienda ')}.',
            orderId: id,
          );
    }
  }

  void rate(int id, int rating, String? review) =>
      _set([for (final x in state) x.id == id ? x.copyWith(rating: rating, review: review?.trim().isEmpty ?? true ? null : review!.trim()) : x]);

  void clear() => _set(const []);
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<PastOrder>>(OrdersNotifier.new);

final activeOrdersProvider = Provider<List<PastOrder>>((ref) => ref.watch(ordersProvider).where((o) => o.status.isActive).toList());
final orderHistoryProvider = Provider<List<PastOrder>>((ref) => ref.watch(ordersProvider).where((o) => !o.status.isActive).toList());

/// Productos del último pedido, para "¿Lo de siempre?" en el inicio.
final lastOrderProvider = Provider<PastOrder?>((ref) => ref.watch(ordersProvider).firstOrNull);

/// Resumen de un pedido para mostrar en listas: "Nitro Cold Brew, Caramel Latte".
String orderSummary(PastOrder o) => o.items.map((i) => i.quantity > 1 ? '${i.quantity}× ${i.name}' : i.name).join(', ');

/// Texto de la personalización de una línea: "Grande, frío, + Espresso extra".
String itemDetail(PastOrderItem i) => [
      ?i.size,
      if (i.variant != null) i.variant!.toLowerCase(),
      ...toppingNames(i.toppings).map((t) => '+ $t'),
    ].join(', ');
