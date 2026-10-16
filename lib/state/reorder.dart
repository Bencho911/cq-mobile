import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import 'cart.dart';
import 'customization.dart';
import 'providers.dart';

/// Línea de un pedido anterior, tal como la conocen Pedidos y Recibo.
class ReorderLine {
  const ReorderLine({this.codProd, required this.name, required this.quantity, this.size, this.variant, this.toppings = const []});

  /// Código del producto; si falta, se busca por nombre.
  final int? codProd;
  final String name;
  final int quantity;
  final String? size;
  final String? variant;
  final List<String> toppings;
}

class ReorderResult {
  const ReorderResult({required this.added, required this.missing, required this.hadItems});
  final List<String> added;
  final List<String> missing;
  final bool hadItems;

  /// Título del aviso para el cliente.
  String get title => added.length == 1 ? 'Agregamos 1 producto a tu pedido.' : 'Agregamos ${added.length} productos a tu pedido.';

  /// Detalle del aviso.
  String get detail => [
        if (missing.isNotEmpty) 'No está disponible: ${missing.join(', ')}.',
        if (hadItems) 'Lo sumamos a lo que ya tenías.',
        'Con los precios de hoy.',
      ].join(' ');
}

String _normalize(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final lower = s.trim().toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

/// "Repetir pedido": busca cada producto en el menú de hoy y lo agrega al
/// carrito con la misma cantidad y personalización, al precio actual. Lo
/// que ya no está disponible se omite; lo que había en el carrito se conserva.
Future<ReorderResult> reorder(WidgetRef ref, List<ReorderLine> lines) async {
  final products = await ref.read(productServiceProvider).getProducts();
  final hadItems = ref.read(cartProvider).items.isNotEmpty;
  final items = <CartItem>[];
  final missing = <String>[];

  for (final line in lines) {
    final topping = toppings.where((t) => _normalize(t.name) == _normalize(line.name)).firstOrNull;
    if (topping != null) {
      // Algunos pedidos traen las adiciones como líneas propias: se suman a la bebida anterior.
      if (items.isNotEmpty && !items.last.toppings.contains(topping.id)) {
        items[items.length - 1] = items.last.copyWith(toppings: [...items.last.toppings, topping.id]);
      }
      continue;
    }
    Product? product;
    if (line.codProd != null) product = products.where((p) => p.codProd == line.codProd).firstOrNull;
    product ??= products.where((p) => _normalize(p.name) == _normalize(line.name)).firstOrNull;
    if (product == null || !product.isAvailable) {
      missing.add(line.name);
      continue;
    }
    items.add(CartItem(
      product: product,
      quantity: line.quantity,
      size: sizes.any((s) => s.$1 == line.size) ? line.size : 'Mediano',
      variant: line.variant ?? 'Frío',
      sugar: 'Normal',
      ice: 'Normal',
      toppings: [...line.toppings],
    ));
  }

  final cart = ref.read(cartProvider.notifier);
  for (final item in items) {
    cart.add(item);
  }
  return ReorderResult(added: items.map((i) => i.product.name).toList(), missing: missing, hadItems: hadItems);
}
