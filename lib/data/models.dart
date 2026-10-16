/// Tipos que reflejan el contrato del API Gateway (kiora-backend).
///  - Producto: cod_prod, nom_prod, descrip_prod, precio_unitario,
///    url_imagen, descuento, stock_actual, stock_minimo, fk_cod_cats.
///  - Orden: id_vent, montofinal_vent, estado, metodopago_usu, items[].
/// Los `fromJson` toleran los alias de campo que usan los microservicios.
library;

num _num(Object? v, [num fallback = 0]) => v is num ? v : num.tryParse('${v ?? ''}') ?? fallback;
String? _str(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

class Product {
  const Product({
    required this.codProd,
    required this.name,
    required this.description,
    required this.price,
    this.discount,
    this.imageUrl,
    this.categoryIds = const [],
    this.stock,
    this.stockMin,
  });

  final int codProd;
  final String name;
  final String description;

  /// Precio unitario de lista (COP).
  final int price;

  /// Descuento 0..100 (porcentaje).
  final num? discount;
  final String? imageUrl;
  final List<int> categoryIds;
  final int? stock;
  final int? stockMin;

  bool get hasDiscount => (discount ?? 0) > 0;
  bool get isAvailable => stock == null || stock! > 0;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        codProd: _num(j['cod_prod'] ?? j['id']).toInt(),
        name: '${j['nom_prod'] ?? j['nombre'] ?? ''}',
        description: '${j['desc_prod'] ?? j['descrip_prod'] ?? ''}',
        price: _num(j['precio_unitario'] ?? j['precio_prod'] ?? j['precio']).round(),
        discount: j['descuento'] == null ? null : _num(j['descuento']),
        imageUrl: _str(j['url_imagen']),
        categoryIds: (j['fk_cod_cats'] is List)
            ? (j['fk_cod_cats'] as List).map((e) => _num(e, -1).toInt()).where((n) => n >= 0).toList()
            : const [],
        stock: j['stock_actual'] == null ? null : _num(j['stock_actual']).toInt(),
        stockMin: j['stock_minimo'] == null ? null : _num(j['stock_minimo']).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'cod_prod': codProd,
        'nom_prod': name,
        'desc_prod': description,
        'precio_unitario': price,
        'descuento': discount,
        'url_imagen': imageUrl,
        'fk_cod_cats': categoryIds,
        'stock_actual': stock,
        'stock_minimo': stockMin,
      };
}

class ProductCategory {
  const ProductCategory({required this.codCat, required this.name, this.description});
  final int codCat;
  final String name;
  final String? description;

  factory ProductCategory.fromJson(Map<String, dynamic> j) => ProductCategory(
        codCat: _num(j['cod_cat'] ?? j['id']).toInt(),
        name: '${j['nom_cat'] ?? j['nombre'] ?? ''}',
        description: _str(j['desc_cat']),
      );
}

class OrderLine {
  const OrderLine({required this.codProd, required this.quantity, required this.unitPrice, this.name, this.imageUrl});
  final int codProd;
  final int quantity;
  final int unitPrice;
  final String? name;
  final String? imageUrl;

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        codProd: _num(j['cod_prod']).toInt(),
        quantity: _num(j['cantidad'], 1).toInt(),
        unitPrice: _num(j['precio_unit']).round(),
        name: _str(j['nom_prod']),
        imageUrl: _str(j['url_imagen']),
      );

  Map<String, dynamic> toJson() => {
        'cod_prod': codProd,
        'cantidad': quantity,
        'precio_unit': unitPrice,
        if (name != null) 'nom_prod': name,
        if (imageUrl != null) 'url_imagen': imageUrl,
      };
}

class Order {
  const Order({
    required this.id,
    this.total = 0,
    this.status = 'pendiente',
    this.paymentMethod,
    this.storeId,
    this.deliveryType,
    this.date,
    this.items = const [],
  });

  final int id;
  final int total;

  /// pendiente | completada | cancelada | reembolsada
  final String status;
  final String? paymentMethod;
  final int? storeId;
  final String? deliveryType;
  final DateTime? date;
  final List<OrderLine> items;

  Order copyWith({String? status}) => Order(
        id: id,
        total: total,
        status: status ?? this.status,
        paymentMethod: paymentMethod,
        storeId: storeId,
        deliveryType: deliveryType,
        date: date,
        items: items,
      );

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: _num(j['id_vent']).toInt(),
        total: _num(j['montofinal_vent']).round(),
        status: '${j['estado'] ?? 'pendiente'}',
        paymentMethod: _str(j['metodopago_usu']),
        storeId: j['store_id'] == null ? null : _num(j['store_id']).toInt(),
        deliveryType: _str(j['tipo_entrega']),
        date: DateTime.tryParse('${j['fecha_vent'] ?? ''}'),
        items: (j['items'] is List)
            ? (j['items'] as List).map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e as Map))).toList()
            : const [],
      );
}

class Store {
  const Store({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    this.status = 'CERRADO',
    this.city,
    this.lat,
    this.lng,
  });

  final int id;
  final String name;
  final String address;
  final String? phone;

  /// ABIERTO | CERRADO | OFFLINE
  final String status;
  final String? city;
  final double? lat;
  final double? lng;

  bool get isOpen => status == 'ABIERTO';

  /// "Café Quindío · Centro" → "Centro".
  String get shortName => name.replaceFirst(RegExp(r'^Café Quindío\s*[·-]\s*', caseSensitive: false), '');

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: _num(j['id_tienda'] ?? j['id']).toInt(),
        name: '${j['nombre'] ?? ''}',
        address: '${j['direccion'] ?? ''}',
        phone: _str(j['telefono']),
        status: '${j['estado'] ?? 'CERRADO'}'.toUpperCase(),
        city: _str(j['ciudad_nombre']),
        lat: j['latitud'] == null ? null : _num(j['latitud']).toDouble(),
        lng: j['longitud'] == null ? null : _num(j['longitud']).toDouble(),
      );
}
