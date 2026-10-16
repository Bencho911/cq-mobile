/// Historial de pedidos del cliente. Se guarda en el teléfono (ver
/// state/orders.dart) hasta que el backend exponga el historial.
library;

import '../core/format.dart';

/// Estados como los muestra la app.
enum PastOrderStatus { pendiente, preparando, listo, completada, cancelada }

extension PastOrderStatusInfo on PastOrderStatus {
  /// En curso: todavía no se ha recogido ni cancelado.
  bool get isActive => this == PastOrderStatus.pendiente || this == PastOrderStatus.preparando || this == PastOrderStatus.listo;
}

class PastOrderItem {
  const PastOrderItem({
    this.codProd,
    required this.name,
    this.size,
    this.variant,
    this.toppings = const [],
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
  });

  final int? codProd;
  final String name;
  final String? size;
  final String? variant;

  /// Ids de adiciones (customization.dart).
  final List<String> toppings;
  final int quantity;
  final int unitPrice;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        'codProd': codProd,
        'name': name,
        'size': size,
        'variant': variant,
        'toppings': toppings,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'imageUrl': imageUrl,
      };

  factory PastOrderItem.fromJson(Map<String, dynamic> j) => PastOrderItem(
        codProd: (j['codProd'] as num?)?.toInt(),
        name: j['name'] as String,
        size: j['size'] as String?,
        variant: j['variant'] as String?,
        toppings: ((j['toppings'] as List?) ?? const []).cast<String>(),
        quantity: (j['quantity'] as num).toInt(),
        unitPrice: (j['unitPrice'] as num).toInt(),
        imageUrl: j['imageUrl'] as String?,
      );
}

class PastOrder {
  const PastOrder({
    required this.id,
    required this.status,
    required this.items,
    required this.store,
    required this.createdAt,
    required this.paymentMethod,
    this.storeId,
    this.discount = 0,
    this.address,
    this.deliveryType,
    this.pickupTime,
    this.earnedPoints = 0,
    this.rating,
    this.review,
  });

  final int id;
  final PastOrderStatus status;
  final List<PastOrderItem> items;

  /// Nombre de la tienda ("Café Quindío · Centro").
  final String store;
  final int? storeId;
  final DateTime createdAt;

  /// Texto del método de pago ("Tarjeta (Wompi)", "Efectivo en tienda"...).
  final String paymentMethod;
  final int discount;

  /// Dirección de la tienda o de entrega.
  final String? address;

  /// "Recoger en tienda" | "Domicilio".
  final String? deliveryType;

  /// Hora elegida para recoger; `null` = lo antes posible.
  final DateTime? pickupTime;

  /// Puntos que sumó el pedido.
  final int earnedPoints;

  /// Calificación 1..5 y reseña, si el cliente calificó.
  final int? rating;
  final String? review;

  int get subtotal => items.fold(0, (s, i) => s + i.quantity * i.unitPrice);
  int get total => subtotal - discount;

  /// "Hoy, 2:15 p. m." / "Ayer, 10:30 a. m." / "8 sep, 3:45 p. m.".
  String get date => formatOrderDate(createdAt);

  PastOrder copyWith({PastOrderStatus? status, int? rating, String? review}) => PastOrder(
        id: id,
        status: status ?? this.status,
        items: items,
        store: store,
        storeId: storeId,
        createdAt: createdAt,
        paymentMethod: paymentMethod,
        discount: discount,
        address: address,
        deliveryType: deliveryType,
        pickupTime: pickupTime,
        earnedPoints: earnedPoints,
        rating: rating ?? this.rating,
        review: review ?? this.review,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.name,
        'items': items.map((e) => e.toJson()).toList(),
        'store': store,
        'storeId': storeId,
        'createdAt': createdAt.toIso8601String(),
        'paymentMethod': paymentMethod,
        'discount': discount,
        'address': address,
        'deliveryType': deliveryType,
        'pickupTime': pickupTime?.toIso8601String(),
        'earnedPoints': earnedPoints,
        'rating': rating,
        'review': review,
      };

  factory PastOrder.fromJson(Map<String, dynamic> j) => PastOrder(
        id: (j['id'] as num).toInt(),
        status: PastOrderStatus.values.asNameMap()[j['status']] ?? PastOrderStatus.completada,
        items: ((j['items'] as List?) ?? const []).map((e) => PastOrderItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        store: j['store'] as String? ?? '',
        storeId: (j['storeId'] as num?)?.toInt(),
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        paymentMethod: j['paymentMethod'] as String? ?? '',
        discount: (j['discount'] as num?)?.toInt() ?? 0,
        address: j['address'] as String?,
        deliveryType: j['deliveryType'] as String?,
        pickupTime: DateTime.tryParse('${j['pickupTime'] ?? ''}'),
        earnedPoints: (j['earnedPoints'] as num?)?.toInt() ?? 0,
        rating: (j['rating'] as num?)?.toInt(),
        review: j['review'] as String?,
      );
}

const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Fecha corta y amable para listas: "Hoy, 2:15 p. m.", "Ayer, …", "8 sep, …".
String formatOrderDate(DateTime d, [DateTime? now]) {
  final today = _dateOnly(now ?? DateTime.now());
  final day = _dateOnly(d);
  final diff = today.difference(day).inDays;
  final when = diff == 0
      ? 'Hoy'
      : diff == 1
          ? 'Ayer'
          : '${d.day} ${_months[d.month - 1]}${d.year != today.year ? ' ${d.year}' : ''}';
  return '$when, ${formatClock(d)}';
}

/// Fecha larga para el recibo: "10 sep 2026, 2:15 p. m.".
String formatLongDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}, ${formatClock(d)}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
