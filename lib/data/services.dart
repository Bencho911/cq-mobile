import 'package:flutter/foundation.dart';

import '../core/config.dart';
import 'api_client.dart';
import 'mock_data.dart';
import 'models.dart';

List<Map<String, dynamic>> _dataList(dynamic json) {
  final data = json is Map ? json['data'] : json;
  if (data is! List) return const [];
  return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

/// Productos y categorías. Con USE_MOCKS (o si el backend falla) usa los
/// datos locales.
class ProductService {
  ProductService(this._api);
  final ApiClient _api;

  Future<List<Product>> getProducts({int? storeId}) async {
    if (AppConfig.useMocks) return mockProducts;
    try {
      final qs = storeId != null ? '?store_id=$storeId&limit=100' : '?limit=100';
      return _dataList(await _api.get('/public/products$qs')).map(Product.fromJson).toList();
    } catch (e) {
      debugPrint('[ProductService] getProducts → mock: $e');
      return mockProducts;
    }
  }

  Future<List<ProductCategory>> getCategories() async {
    if (AppConfig.useMocks) return mockCategories;
    try {
      return _dataList(await _api.get('/public/categories?limit=100')).map(ProductCategory.fromJson).toList();
    } catch (e) {
      debugPrint('[ProductService] getCategories → mock: $e');
      return mockCategories;
    }
  }
}

class CreateOrderInput {
  const CreateOrderInput({required this.items, this.paymentMethod, this.storeId, this.deliveryType});
  final List<OrderLine> items;
  final String? paymentMethod;
  final int? storeId;
  final String? deliveryType;

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        if (paymentMethod != null) 'metodopago_usu': paymentMethod,
        if (storeId != null) 'store_id': storeId,
        if (deliveryType != null) 'tipo_entrega': deliveryType,
      };
}

/// Pedidos. En modo mock guarda las órdenes en memoria para que el
/// seguimiento y el detalle funcionen sin backend.
class OrderService {
  OrderService(this._api);
  final ApiClient _api;

  int _mockCounter = 1000;
  final _mockOrders = <int, Order>{};

  Future<Order> createOrder(CreateOrderInput input) async {
    if (AppConfig.useMocks) {
      final id = ++_mockCounter;
      final order = Order(
        id: id,
        total: input.items.fold(0, (sum, i) => sum + i.quantity * i.unitPrice),
        paymentMethod: input.paymentMethod ?? 'kiosco',
        storeId: input.storeId,
        deliveryType: input.deliveryType,
        date: DateTime.now(),
        items: input.items,
      );
      _mockOrders[id] = order;
      return order;
    }
    return Order.fromJson(Map<String, dynamic>.from(await _api.post('/orders', input.toJson()) as Map));
  }

  Future<Order> getOrderById(int id) async {
    if (AppConfig.useMocks) return _mockOrders[id] ?? Order(id: id);
    return Order.fromJson(Map<String, dynamic>.from(await _api.get('/orders/$id') as Map));
  }

  /// Sesión de pago (Wompi): devuelve la URL de checkout.
  Future<String> createCheckoutUrl(int orderId, String redirectUrl) async {
    if (AppConfig.useMocks) return redirectUrl;
    final j = Map<String, dynamic>.from(
        await _api.post('/orders/checkout/$orderId', {'redirect_url': redirectUrl}) as Map);
    return '${j['checkout_url'] ?? j['checkoutUrl'] ?? j['url'] ?? ''}';
  }
}

class StoreService {
  StoreService(this._api);
  final ApiClient _api;

  Future<List<Store>> getStores() async {
    if (AppConfig.useMocks) return mockStores;
    try {
      return _dataList(await _api.get('/stores')).map(Store.fromJson).toList();
    } catch (e) {
      debugPrint('[StoreService] getStores → mock: $e');
      return mockStores;
    }
  }
}
