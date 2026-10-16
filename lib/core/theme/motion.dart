import 'package:flutter/widgets.dart';

/// Curvas y duraciones compartidas. Regla de la casa: poco movimiento en lo
/// que se usa a diario, más en los momentos raros (apertura, pedido, álbum).
abstract final class CQMotion {
  /// Entradas de interfaz (cubic-bezier(0.23, 1, 0.32, 1)).
  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Movimientos que van y vuelven (puertas, cambios de lugar).
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// Hojas y cajones.
  static const drawer = Cubic(0.32, 0.72, 0, 1);

  static const press = Duration(milliseconds: 140);
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 450);

  /// Respeta "reducir movimiento" del sistema.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
