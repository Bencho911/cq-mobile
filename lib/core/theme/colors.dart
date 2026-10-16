import 'package:flutter/widgets.dart';

/// Paleta «Fachadas»: color plano de las fachadas de Salento sobre blanco
/// cal, texto y acciones en azul tinta. Las tintas son las de las
/// ilustraciones corporativas y se usan a pleno con texto tinta encima.
abstract final class CQColors {
  // Tintas de las fachadas (texto encima: tinta).
  static const mostaza = Color(0xFFE6A90E);
  static const mostazaSoft = Color(0xFFF8E7B6);
  static const rosa = Color(0xFFE66C92);
  static const rosaSoft = Color(0xFFF8DCE5);
  static const teal = Color(0xFF62AAA9);
  static const tealSoft = Color(0xFFDDEEEC);
  static const verde = Color(0xFF1D6B64); // texto blanco encima
  static const rojo = Color(0xFFC2391F); // texto blanco encima

  // Superficies.
  static const white = Color(0xFFFFFFFF);
  static const creamMid = Color(0xFFF4F6F7);
  static const creamDeep = Color(0xFFEEF3F3); // inputs, chips
  static const ink = Color(0xFF18303C); // azul tinta: acción y texto
  static const inkMid = Color(0xFF22404D);
  static const inkStrong = Color(0xFF0F222B);

  // Neutros.
  static const line = Color(0xFFE3E7E9);
  static const lineDark = Color(0xFF34505D);
  static const muted = Color(0xFF4E5F68);
  static const mutedSoft = Color(0xFF5E6E76);
  static const onDark = Color(0xFFD7ECE9); // texto secundario sobre verde/tinta
  static const navInactive = Color(0xFFA9B8BF);

  // Semánticos.
  static const success = Color(0xFF2B7A55);
  static const successSoft = Color(0xFFD5EDE3);
  static const danger = Color(0xFFB83025);
  static const dangerSoft = Color(0xFFFDE8E5);
  static const accentDeep = Color(0xFF805600); // texto mostaza sobre blanco
}
