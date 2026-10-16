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
    this.address,
    this.deliveryType,
  });

  final int id;
  final PastOrderStatus status;
  final List<PastOrderItem> items;
  final String store;
  final String date;
  final String paymentMethod;
  final int discount;

  /// Dirección de la tienda (solo la trae el recibo).
  final String? address;

  /// "Recoger en tienda" | "Domicilio".
  final String? deliveryType;

  int get subtotal => items.fold(0, (s, i) => s + i.quantity * i.unitPrice);
  int get total => subtotal - discount;
}

// MOCK: pedidos de ejemplo hasta que el backend exponga el historial del usuario.
const mockActiveOrders = [
  PastOrder(
    id: 1238,
    status: PastOrderStatus.preparando,
    items: [
      PastOrderItem(codProd: 3, name: 'Nitro Cold Brew', quantity: 1, unitPrice: 31000),
      PastOrderItem(codProd: 5, name: 'Caramel Latte', quantity: 1, unitPrice: 33000),
    ],
    store: 'Café Quindío · Centro',
    date: 'Hoy, 2:15 p. m.',
    paymentMethod: 'Tarjeta (Wompi)',
  ),
];

// MOCK
const mockOrderHistory = [
  PastOrder(
    id: 1237,
    status: PastOrderStatus.completada,
    items: [
      PastOrderItem(codProd: 1, name: 'Café con leche', quantity: 1, unitPrice: 25000),
      PastOrderItem(codProd: 4, name: 'Caffè Mocha', quantity: 1, unitPrice: 29000),
      PastOrderItem(name: 'Croissant', quantity: 1, unitPrice: 28000),
    ],
    store: 'Café Quindío · Norte',
    date: 'Ayer, 10:30 a. m.',
    paymentMethod: 'Efectivo en tienda',
  ),
  PastOrder(
    id: 1236,
    status: PastOrderStatus.completada,
    items: [PastOrderItem(codProd: 2, name: 'Cocoa Caramel Latte', quantity: 1, unitPrice: 33000)],
    store: 'Café Quindío · Centro',
    date: '8 sep, 3:45 p. m.',
    paymentMethod: 'Tarjeta (Wompi)',
  ),
  PastOrder(
    id: 1235,
    status: PastOrderStatus.completada,
    items: [
      PastOrderItem(codProd: 5, name: 'Caramel Latte', quantity: 1, unitPrice: 28000),
      PastOrderItem(codProd: 3, name: 'Nitro Cold Brew', quantity: 1, unitPrice: 31000),
    ],
    store: 'Café Quindío · Aeropuerto',
    date: '5 sep, 9:00 a. m.',
    paymentMethod: 'Pago en kiosco',
  ),
  PastOrder(
    id: 1234,
    status: PastOrderStatus.cancelada,
    items: [PastOrderItem(codProd: 1, name: 'Café con leche', quantity: 1, unitPrice: 25000)],
    store: 'Café Quindío · Centro',
    date: '2 sep, 11:20 a. m.',
    paymentMethod: 'Tarjeta (Wompi)',
  ),
];

// MOCK: recibo de ejemplo si no llega el pedido ni se encuentra por id.
const mockInvoice = PastOrder(
  id: 1238,
  status: PastOrderStatus.completada,
  date: '10 sep 2026, 2:15 p. m.',
  store: 'Café Quindío · Centro',
  address: 'Calle 12 #9-34, Armenia, Quindío',
  paymentMethod: 'Tarjeta Visa terminada en 4521 (Wompi)',
  deliveryType: 'Recoger en tienda',
  items: [
    PastOrderItem(codProd: 3, name: 'Nitro Cold Brew', size: 'Grande', quantity: 1, unitPrice: 31000),
    PastOrderItem(codProd: 5, name: 'Caramel Latte', size: 'Regular', quantity: 1, unitPrice: 28000),
    PastOrderItem(name: 'Espresso extra', quantity: 1, unitPrice: 5000),
  ],
  discount: 2500,
);
