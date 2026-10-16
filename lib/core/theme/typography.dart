import 'package:flutter/widgets.dart';

import 'colors.dart';

/// Tipografía: Bricolage Grotesque para titulares, Neutra Text para la
/// interfaz y Neutra Text TF (cifras tabulares) para precios y puntos.
abstract final class CQType {
  static const display = 'Bricolage Grotesque';
  static const sans = 'Neutra Text';
  static const num = 'Neutra Text TF';

  /// Titular de marca: extra negrita, interlineado apretado y tracking
  /// negativo. Bricolage es variable: el peso va por `fontVariations`.
  static TextStyle title(double size, {Color color = CQColors.ink, double height = 0.95, double weight = 800}) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        height: height,
        letterSpacing: size * -0.04,
        color: color,
        fontWeight: FontWeight.w800,
        fontVariations: [FontVariation.weight(weight), const FontVariation('opsz', 96)],
      );

  /// Texto de interfaz.
  static TextStyle body(double size, {Color color = CQColors.ink, FontWeight weight = FontWeight.w400, double height = 1.3}) =>
      TextStyle(fontFamily: sans, fontSize: size, color: color, fontWeight: weight, height: height);

  /// Cifras: precios, puntos, contadores.
  static TextStyle number(double size, {Color color = CQColors.ink, double height = 1.1}) => TextStyle(
        fontFamily: num,
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w600,
        height: height,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
