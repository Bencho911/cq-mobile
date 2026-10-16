import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/services.dart';
import 'cart.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final productServiceProvider = Provider((ref) => ProductService(ref.watch(apiClientProvider)));
final orderServiceProvider = Provider((ref) => OrderService(ref.watch(apiClientProvider)));
final storeServiceProvider = Provider((ref) => StoreService(ref.watch(apiClientProvider)));

final productsProvider = FutureProvider<List<Product>>((ref) => ref.watch(productServiceProvider).getProducts());
final categoriesProvider = FutureProvider<List<ProductCategory>>((ref) => ref.watch(productServiceProvider).getCategories());
final storesProvider = FutureProvider<List<Store>>((ref) => ref.watch(storeServiceProvider).getStores());

/// Tienda donde se recoge: la elegida en el carrito o la primera abierta.
final selectedStoreProvider = Provider<Store?>((ref) {
  final stores = ref.watch(storesProvider).value ?? const <Store>[];
  final id = ref.watch(cartProvider.select((c) => c.storeId));
  return stores.where((s) => s.id == id).firstOrNull ??
      stores.where((s) => s.isOpen).firstOrNull ??
      stores.firstOrNull;
});
