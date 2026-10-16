/// MOCK: personalización de bebida (el backend no expone variantes aún).
library;

class Topping {
  const Topping(this.id, this.name, this.price);
  final String id;
  final String name;
  final int price;
}

const toppings = [
  Topping('espresso', 'Espresso extra', 5000),
  Topping('jelly', 'Coffee jelly', 3000),
  Topping('icecream', 'Helado de chocolate', 7000),
  Topping('caramelo', 'Shot de caramelo', 2500),
];

/// Tamaños que ofrece el detalle de producto.
const sizes = [('Pequeño', '12 oz'), ('Mediano', '16 oz'), ('Grande', '20 oz')];

int toppingsPrice(Iterable<String> ids) =>
    ids.fold(0, (sum, id) => sum + (toppings.where((t) => t.id == id).firstOrNull?.price ?? 0));

List<String> toppingNames(Iterable<String> ids) =>
    ids.map((id) => toppings.where((t) => t.id == id).firstOrNull?.name).whereType<String>().toList();
