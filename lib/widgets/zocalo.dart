import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';

/// Pinta las franjas del zócalo: rojo con divisiones en azul tinta.
class _ZocaloPainter extends CustomPainter {
  const _ZocaloPainter();

  static const block = 28.0;
  static const gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = CQColors.rojo);
    final ink = Paint()..color = CQColors.ink;
    for (var x = block; x < size.width; x += block + gap) {
      canvas.drawRect(Rect.fromLTWH(x, 0, gap, size.height), ink);
    }
  }

  @override
  bool shouldRepaint(_ZocaloPainter old) => false;
}

/// Zócalo: la franja inferior de las fachadas. Con [animate] se dibuja de
/// izquierda a derecha al aparecer (momentos de bienvenida y confirmación).
class Zocalo extends StatelessWidget {
  const Zocalo({super.key, this.height = 10, this.animate = false, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 400)});

  final double height;
  final bool animate;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final bar = SizedBox(height: height, width: double.infinity, child: const CustomPaint(painter: _ZocaloPainter()));
    if (!animate || CQMotion.reduced(context)) return bar;
    return _Reveal(delay: delay, duration: duration, child: bar);
  }
}

class _Reveal extends StatefulWidget {
  const _Reveal({required this.delay, required this.duration, required this.child});
  final Duration delay;
  final Duration duration;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => ClipRect(
          child: Align(alignment: Alignment.centerLeft, widthFactor: CQMotion.easeOut.transform(_c.value), child: child),
        ),
        child: widget.child,
      );
}

enum FacadeTone { verde, teal, mostaza, rosa, ink }

extension FacadeToneColors on FacadeTone {
  Color get wall => switch (this) {
        FacadeTone.verde => CQColors.verde,
        FacadeTone.teal => CQColors.teal,
        FacadeTone.mostaza => CQColors.mostaza,
        FacadeTone.rosa => CQColors.rosa,
        FacadeTone.ink => CQColors.ink,
      };

  /// Fachadas oscuras llevan texto blanco; las tintas claras, texto tinta.
  bool get isDark => this == FacadeTone.verde || this == FacadeTone.ink;
  Color get onWall => isDark ? CQColors.white : CQColors.ink;
  String get logo => isDark ? 'assets/brand/logo-blanco.webp' : 'assets/brand/logo-teal.webp';
}

/// Fachada: muro de color plano con una ilustración corporativa apoyada
/// sobre el zócalo. Se usa en bienvenida, espera y confirmación.
class Facade extends StatelessWidget {
  const Facade({super.key, required this.tone, this.image, this.imageHeight, this.imageWidth = 220, this.child, this.expand = false, this.imageWrapper});

  final FacadeTone tone;
  final String? image;
  final double? imageHeight;
  final double imageWidth;
  final Widget? child;

  /// Ocupa todo el alto disponible (pantallas completas).
  final bool expand;

  /// Permite animar la ilustración (p. ej. vaivén en las esperas).
  final Widget Function(Widget image)? imageWrapper;

  @override
  Widget build(BuildContext context) {
    Widget? art;
    if (image != null) {
      art = Image.asset(image!, width: imageHeight == null ? imageWidth : null, height: imageHeight, fit: BoxFit.contain);
      if (imageWrapper != null) art = imageWrapper!(art);
    }
    return ColoredBox(
      color: tone.wall,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: tone.onWall),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            ?child,
            if (expand) const Spacer(),
            if (art != null) Center(child: art),
            const Zocalo(),
          ],
        ),
      ),
    );
  }
}
