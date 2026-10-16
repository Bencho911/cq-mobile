import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../widgets/controls.dart';

/// Celulares de Colombia: 10 dígitos, sin espacios ni guiones.
const phoneLength = 10;

/// Solo dígitos, con tope opcional.
List<TextInputFormatter> digitsOnly([int? max]) =>
    [FilteringTextInputFormatter.digitsOnly, if (max != null) LengthLimitingTextInputFormatter(max)];

/// Vuelve a la pantalla anterior; si no hay, va a [fallback].
void goBack(BuildContext context, {String fallback = '/login'}) =>
    context.canPop() ? context.pop() : context.go(fallback);

/// Con el teclado abierto se esconden los textos secundarios del pie para
/// que la acción principal siga a la vista.
bool keyboardOpen(BuildContext context) => MediaQuery.viewInsetsOf(context).bottom > 0;

/// Campo de las pantallas de acceso (equivale a `Input` de la web):
/// fondo gris claro, borde tinta al enfocar, ayuda debajo.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.prefix,
    this.keyboardType,
    this.inputFormatters,
    this.autofillHints,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.numeric = false,
    this.height = 48,
    this.borderColor = CQColors.line,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;

  /// Texto de ayuda bajo el campo; se anuncia al cambiar.
  final String? helper;

  /// Prefijo fijo separado por una línea (p. ej. «+57»).
  final String? prefix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  /// Cifras tabulares (teléfonos, documentos).
  final bool numeric;
  final double height;
  final Color borderColor;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.numeric ? CQType.number(16, height: 1.2) : CQType.body(16);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: CQType.body(14, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: _focus.requestFocus,
        child: AnimatedContainer(
          duration: CQMotion.fast,
          height: widget.height,
          decoration: BoxDecoration(
            color: CQColors.creamDeep,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _focus.hasFocus ? CQColors.ink : widget.borderColor, width: 1.5),
          ),
          child: Row(children: [
            if (widget.prefix != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: CQColors.line))),
                child: Text(widget.prefix!, style: CQType.number(16, height: 1.2)),
              ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                autofillHints: widget.autofillHints,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                onSubmitted: widget.onSubmitted,
                style: style,
                cursorColor: CQColors.ink,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: style.copyWith(color: CQColors.mutedSoft),
                  contentPadding: EdgeInsets.symmetric(horizontal: widget.prefix != null ? 14 : 16),
                ),
              ),
            ),
          ]),
        ),
      ),
      if (widget.helper != null) ...[
        const SizedBox(height: 6),
        Semantics(liveRegion: true, child: Text(widget.helper!, style: CQType.body(13, color: CQColors.muted))),
      ],
    ]);
  }
}

/// Enlace de texto subrayado con área táctil de 44 px.
class AuthLink extends StatelessWidget {
  const AuthLink(this.label, {super.key, required this.onTap, this.size = 15});

  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              style: CQType.body(size, weight: FontWeight.w600).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: CQColors.ink,
              ),
            ),
          ),
        ),
      );
}

/// Pregunta con enlace al final: «¿Primera vez? Crea tu cuenta».
class AuthPrompt extends StatelessWidget {
  const AuthPrompt({super.key, required this.question, required this.link, required this.onTap, this.center = true});

  final String question;
  final String link;
  final VoidCallback onTap;
  final bool center;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: center ? WrapAlignment.center : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$question ', style: CQType.body(15, color: CQColors.muted)),
          AuthLink(link, onTap: onTap),
        ],
      );
}

/// Subtítulo con el número resaltado: «… al +57 3001234567.»
class PhoneSubtitle extends StatelessWidget {
  const PhoneSubtitle({super.key, required this.before, required this.phone});

  final String before;
  final String phone;

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(text: before),
        // Espacio no separable para que el número no se parta.
        TextSpan(text: '+57 $phone', style: CQType.number(16, height: 1.5)),
        const TextSpan(text: '.'),
      ]));
}
