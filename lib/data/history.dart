/// Historial de pedidos del cliente. MOCK hasta que el backend lo exponga.
library;

/// Estados como los muestra la app.
enum PastOrderStatus { pendiente, preparando, listo, completada, cancelada }

class PastOrderItem {
  const PastOrderItem({this.codProd, required this.name, this.size, required this.quantity, required this.unitPrice});
  final int? codProd;
  final String name;
  final String? size;
  final int quantity;
  final int unitPrice;
}

class PastOrder {
  const PastOrder({
    required this.id,
    required this.status,
    required this.items,
    required this.store,
    required this.date,
    required this.paymentMethod,
    this.discount = 0,
  });

  final int id;
  final PastOrderStatus status;
  final List<PastOrderItem> items;
  final String store;
  final String date;
  final String paymentMethod;
  final int discount;

  int get total => items.fold(0, (s, i) => s + i.quantity * i.unitPrice) - discount;
}
