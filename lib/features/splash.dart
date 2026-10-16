import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import '../widgets/zocalo.dart';

/// Duración total de la apertura antes de ceder el paso a la app.
const splashDuration = Duration(milliseconds: 1100);

const _doorW = 200.0;
const _doorH = 290.0;

/// Apertura de la app: la fachada se arma (zócalo de izquierda a derecha),
/// la puerta en arco se abre hacia adentro y adentro espera el Toche;
/// luego aparece el logo. Solo en el arranque en frío.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  /// Se llama al terminar la apertura.
  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: splashDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (CQMotion.reduced(context)) {
      _c.value = 1;
      Future.delayed(const Duration(milliseconds: 500), widget.onDone);
      return;
    }
    // La puerta no se abre hasta que el logo y el ave están listos (máx. 400 ms).
    Future.wait([
      precacheImage(const AssetImage('assets/brand/logo-blanco.webp'), context),
      precacheImage(const AssetImage('assets/brand/ave-toche.webp'), context),
    ]).timeout(const Duration(milliseconds: 400), onTimeout: () => []).whenComplete(() {
      if (mounted) _c.forward();
    });
  }

  /// Tramo [start, end] (en ms) de la línea de tiempo, con su curva.
  Animation<double> _seg(int start, int end, Curve curve) => CurvedAnimation(
        parent: _c,
        curve: Interval(start / splashDuration.inMilliseconds, end / splashDuration.inMilliseconds, curve: curve),
      );

  late final _zocalo = _seg(0, 400, CQMotion.easeOut);
  late final _doors = _seg(200, 750, CQMotion.easeInOut);
  late final _bird = _seg(450, 900, CQMotion.easeOut);
  late final _logo = _seg(500, 900, CQMotion.easeOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: CQColors.verde,
      child: Semantics(
        label: 'Café Quindío',
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Column(children: [
            // Logo y eslogan sobre la puerta.
            Expanded(
              child: Opacity(
                opacity: _logo.value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - _logo.value)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Image.asset('assets/brand/logo-blanco.webp', height: 36),
                    const SizedBox(height: 8),
                    Text('El café del corazón de Colombia', style: CQType.body(15, color: CQColors.onDark)),
                    const SizedBox(height: 48),
                  ]),
                ),
              ),
            ),
            _Doorway(doors: _doors.value, bird: _bird.value),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: math.max(_zocalo.value, 0.0001), child: const Zocalo()),
            ),
            Container(height: 120 + bottom, color: CQColors.mostaza),
          ]),
        ),
      ),
    );
  }
}

/// Puerta en arco: marco teal, interior en tinta, el ave y dos hojas que
/// giran hacia adentro sobre sus bisagras.
class _Doorway extends StatelessWidget {
  const _Doorway({required this.doors, required this.bird});

  /// 0 = cerrada, 1 = abierta.
  final double doors;

  /// Entrada del ave (0..1).
  final double bird;

  @override
  Widget build(BuildContext context) {
    const frame = 8.0;
    // Marco teal (arriba y a los lados) y vano en tinta.
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(_doorW)),
      child: Container(
        width: _doorW + frame * 2,
        height: _doorH + frame,
        color: CQColors.teal,
        padding: const EdgeInsets.fromLTRB(frame, frame, frame, 0),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(_doorW)),
          child: ColoredBox(
            color: CQColors.ink,
            child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: bird,
              child: Transform.translate(offset: Offset(0, 24 * (1 - bird)), child: Image.asset('assets/brand/ave-toche.webp', height: 200)),
            ),
          ),
          _Leaf(left: true, open: doors),
          _Leaf(left: false, open: doors),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Leaf extends StatelessWidget {
  const _Leaf({required this.left, required this.open});
  final bool left;
  final double open;

  @override
  Widget build(BuildContext context) {
    const w = _doorW / 2;
    // Abre hacia adentro: el borde libre se aleja del espectador.
    final angle = (left ? 1 : -1) * 80 * math.pi / 180 * open;
    final radius = left
        ? const BorderRadius.only(topLeft: Radius.circular(w))
        : const BorderRadius.only(topRight: Radius.circular(w));
    final panelRadius = left ? const BorderRadius.only(topLeft: Radius.circular(60)) : const BorderRadius.only(topRight: Radius.circular(60));
    final line = Border.all(color: CQColors.ink.withValues(alpha: 0.8), width: 2);
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 0,
      width: w,
      child: Transform(
        alignment: left ? Alignment.centerLeft : Alignment.centerRight,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 1 / 700)
          ..rotateY(angle),
        child: Container(
          decoration: BoxDecoration(color: CQColors.mostaza, borderRadius: radius),
          child: Stack(children: [
            // Canto donde se juntan las dos hojas.
            Positioned(top: 0, bottom: 0, width: 2, left: left ? null : 0, right: left ? 0 : null, child: const ColoredBox(color: CQColors.ink)),
            Positioned(left: 12, right: 12, top: 56, height: 92, child: DecoratedBox(decoration: BoxDecoration(border: line, borderRadius: panelRadius))),
            Positioned(left: 12, right: 12, bottom: 16, height: 96, child: DecoratedBox(decoration: BoxDecoration(border: line))),
            Positioned(
              top: 150,
              left: left ? null : 8,
              right: left ? 8 : null,
              child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: CQColors.ink, shape: BoxShape.circle)),
            ),
          ]),
        ),
      ),
    );
  }
}
