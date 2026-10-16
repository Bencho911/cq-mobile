import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import 'controls.dart';
import 'zocalo.dart';

/// Pantallas de acceso: fachada de color arriba con la marca y una
/// ilustración; formulario sobre blanco abajo y acción fija inferior.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.tone, required this.image, required this.title, this.subtitle, this.onBack, this.footer, this.child});

  final FacadeTone tone;
  final String image;
  final String title;
  final Widget? subtitle;
  final VoidCallback? onBack;
  final Widget? footer;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: tone.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: CQColors.white,
        body: Column(children: [
          Facade(
            tone: tone,
            image: image,
            imageHeight: 150,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, pad.top + 8, 12, 0),
              child: Row(children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: onBack == null
                      ? null
                      : Pressable(onTap: onBack, semanticLabel: 'Volver', child: Icon(LucideIcons.chevronLeft, size: 26, color: tone.onWall)),
                ),
                Expanded(child: Center(child: Image.asset(tone.logo, height: 24, semanticLabel: 'Café Quindío'))),
                const SizedBox(width: 44),
              ]),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: CQType.title(32, height: 1.02)),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  DefaultTextStyle.merge(style: CQType.body(16, color: CQColors.muted, height: 1.5), child: subtitle!),
                ],
                const SizedBox(height: 24),
                ?child,
              ]),
            ),
          ),
          if (footer != null) Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, pad.bottom + 20), child: footer),
        ]),
      ),
    );
  }
}

/// Código de N dígitos con un solo campo real (se puede pegar el código y
/// el teclado ofrece el del SMS); las casillas son solo visuales.
class CodeInput extends StatefulWidget {
  const CodeInput({super.key, required this.length, required this.value, required this.onChanged, this.secret = false, this.autofocus = true, this.label = 'Código'});

  final int length;
  final String value;
  final ValueChanged<String> onChanged;

  /// Oculta los dígitos (PIN).
  final bool secret;
  final bool autofocus;
  final String label;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  late final _ctrl = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(CodeInput old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) _ctrl.text = widget.value;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final active = math.min(v.length, widget.length - 1);
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(children: [
        Row(children: [
          for (var i = 0; i < widget.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: AnimatedContainer(
                duration: CQMotion.fast,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < v.length ? CQColors.white : CQColors.creamDeep,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    width: 1.5,
                    color: i < v.length || (_focus.hasFocus && i == active) ? CQColors.ink : Colors.transparent,
                  ),
                ),
                child: i < v.length
                    ? (widget.secret
                        ? Container(width: 12, height: 12, decoration: const BoxDecoration(color: CQColors.ink, shape: BoxShape.circle))
                        : Text(v[i], style: CQType.number(26)))
                    : null,
              ),
            ),
          ],
        ]),
        // Campo real, invisible, encima de las casillas.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.length)],
              onChanged: widget.onChanged,
              showCursor: false,
              decoration: InputDecoration(border: InputBorder.none, semanticCounterText: widget.label),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Campo de texto de la casa: fondo gris claro, sin borde, etiqueta encima.
class CQTextField extends StatelessWidget {
  const CQTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.prefix,
    this.onChanged,
    this.autofillHints,
    this.textInputAction,
    this.maxLines = 1,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: CQType.body(15, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        style: CQType.body(17),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: CQType.body(17, color: CQColors.mutedSoft),
          prefixIcon: prefix,
          filled: true,
          fillColor: CQColors.creamDeep,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: CQColors.ink, width: 1.5)),
        ),
      ),
    ]);
  }
}

/// Espera breve a pantalla completa: dice qué está pasando y la
/// ilustración se mece mientras tanto (en lugar de un spinner).
class WaitScreen extends StatelessWidget {
  const WaitScreen({super.key, required this.tone, required this.image, required this.title, this.description});

  final FacadeTone tone;
  final String image;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: tone.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: tone.wall,
        body: Facade(
          tone: tone,
          image: image,
          imageWidth: 240,
          expand: true,
          imageWrapper: (img) => Sway(child: img),
          child: Semantics(
            liveRegion: true,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 28, 24, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Image.asset(tone.logo, height: 24, semanticLabel: 'Café Quindío'),
                const SizedBox(height: 40),
                Text(title, style: CQType.title(40, color: tone.onWall)),
                if (description != null) ...[
                  const SizedBox(height: 12),
                  Text(description!, style: CQType.body(17, color: tone.isDark ? CQColors.onDark : CQColors.ink)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vaivén suave apoyado en la base: indica que algo está pasando.
class Sway extends StatefulWidget {
  const Sway({super.key, required this.child});
  final Widget child;

  @override
  State<Sway> createState() => _SwayState();
}

class _SwayState extends State<Sway> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CQMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOutSine.transform(_c.value);
          return Transform.translate(
            offset: Offset(0, -4 * t),
            child: Transform.rotate(angle: (-1.6 + 3.2 * t) * math.pi / 180, alignment: Alignment.bottomCenter, child: child),
          );
        },
        child: widget.child,
      );
}
