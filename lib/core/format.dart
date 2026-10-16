/// Miles con punto: `25.000`.
String groupThousands(num value) {
  final digits = value.round().abs().toString();
  final b = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
    b.write(digits[i]);
  }
  return b.toString();
}

/// Pesos colombianos: `$ 25.000`.
String formatCOP(num value) => '\$ ${groupThousands(value)}';

/// Precio con descuento aplicado (porcentaje 0..100).
int discountedPrice(num price, num? discount) {
  if (discount == null || discount == 0) return price.round();
  return (price * (1 - discount / 100)).round();
}

/// "3:30 p. m."
String formatClock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// "Buenos días" / "Buenas tardes" / "Buenas noches".
String greetingFor(DateTime d) {
  if (d.hour < 12) return 'Buenos días';
  if (d.hour < 18) return 'Buenas tardes';
  return 'Buenas noches';
}
