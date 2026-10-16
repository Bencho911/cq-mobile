import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../state/loyalty.dart';

/// Contorno de estampilla perforada: un rectángulo con medias lunas a lo
/// largo de los cuatro bordes. Forma reservada para la lealtad.
class StampBorder extends ShapeBorder {
  const StampBorder({this.radius = 4});

  /// Radio de cada perforación.
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = Path()..addRect(rect);
    final holes = Path();
    void edge(Offset a, Offset b) {
      final length = (b - a).distance;
      final n = (length / (radius * 3)).round().clamp(1, 999);
      for (var i = 0; i <= n; i++) {
        holes.addOval(Rect.fromCircle(center: Offset.lerp(a, b, i / n)!, radius: radius));
      }
    }

    edge(rect.topLeft, rect.topRight);
    edge(rect.bottomLeft, rect.bottomRight);
    edge(rect.topLeft, rect.bottomLeft);
    edge(rect.topRight, rect.bottomRight);
    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => StampBorder(radius: radius * t);
}

enum StampState { earned, next, locked }

extension StampToneColor on StampTone {
  Color get color => switch (this) {
        StampTone.rosa => CQColors.rosa,
        StampTone.teal => CQColors.teal,
        StampTone.mostaza => CQColors.mostaza,
        StampTone.rosaSoft => CQColors.rosaSoft,
        StampTone.mostazaSoft => CQColors.mostazaSoft,
      };
}

/// Estampilla con un ave. `earned`: a color. `next`: silueta sobre
/// mostaza. `locked`: silueta gris con "?".
class Stamp extends StatelessWidget {
  const Stamp({super.key, required this.bird, this.state = StampState.earned, this.height = 128});

  final Bird bird;
  final StampState state;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      StampState.earned => bird.tone.color,
      StampState.next => CQColors.mostaza,
      StampState.locked => const Color(0xFFE9EDEF),
    };
    final silhouette = state != StampState.earned;
    Widget art = Image.asset(bird.image, fit: BoxFit.contain);
    if (silhouette) {
      art = Opacity(
        opacity: state == StampState.next ? 0.16 : 0.07,
        child: ColorFiltered(colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn), child: art),
      );
    }
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: color, shape: StampBorder(radius: (height * 0.032).clamp(3, 6))),
        child: Padding(
          padding: EdgeInsets.all(height * 0.07),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: Semantics(label: state == StampState.earned ? bird.name : null, child: art)),
              if (state == StampState.locked)
                Text('?',
                    style: TextStyle(
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 40,
                        fontVariations: const [FontVariation.weight(800)],
                        color: CQColors.muted.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ),
    );
  }
}
