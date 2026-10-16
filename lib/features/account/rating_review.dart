import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../widgets/controls.dart';
import 'common.dart';

const _labels = ['Muy malo', 'Malo', 'Normal', 'Casi perfecto', 'Perfecto'];

/// Calificar el pedido: 1–5 estrellas y reseña opcional.
class RatingReviewScreen extends StatefulWidget {
  const RatingReviewScreen({super.key});

  @override
  State<RatingReviewScreen> createState() => _RatingReviewScreenState();
}

class _RatingReviewScreenState extends State<RatingReviewScreen> {
  int _rating = 0;
  final _review = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _review.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    // MOCK: el backend no expone endpoint de reseñas.
    HapticFeedback.lightImpact();
    showToast(context, 'Gracias por calificar tu pedido');
    context.go('/home');
  }

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            PageHeader(title: 'Calificar', onBack: _back),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('¿Cómo estuvo tu pedido?', style: CQType.title(36, height: 0.98)),
                const SizedBox(height: 8),
                Text('Tu opinión le llega a la barra de la tienda.', style: CQType.body(16, color: CQColors.muted)),
                const SizedBox(height: 28),
                Semantics(
                  label: 'Calificación',
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    for (var i = 0; i < _labels.length; i++)
                      Semantics(
                        inMutuallyExclusiveGroup: true,
                        checked: _rating == i + 1,
                        label: _labels[i],
                        excludeSemantics: true,
                        child: Pressable(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _rating = i + 1);
                          },
                          child: SizedBox(width: 56, height: 56, child: Center(child: _Star(on: i < _rating))),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 24,
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _rating > 0 ? _labels[_rating - 1] : 'Toca una estrella',
                      textAlign: TextAlign.center,
                      style: _rating > 0 ? CQType.body(17, weight: FontWeight.w600) : CQType.body(17, color: CQColors.muted),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text('Cuéntanos más (opcional)', style: CQType.body(14, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: CQMotion.fast,
                  height: 128,
                  decoration: BoxDecoration(
                    color: CQColors.creamDeep,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _focus.hasFocus ? CQColors.ink : CQColors.line),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextField(
                    controller: _review,
                    focusNode: _focus,
                    maxLines: null,
                    expands: true,
                    textCapitalization: TextCapitalization.sentences,
                    textAlignVertical: TextAlignVertical.top,
                    style: CQType.body(16),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Qué te gustó o qué podemos mejorar',
                      hintStyle: CQType.body(16, color: CQColors.mutedSoft),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Tu reseña será visible para otros clientes.', style: CQType.body(13, color: CQColors.muted)),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: CQButton(label: 'Enviar calificación', onPressed: _rating == 0 ? null : _submit),
      ),
    );
  }
}

/// Estrella con contorno tinta; se rellena de mostaza al elegirla.
class _Star extends StatelessWidget {
  const _Star({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: on ? CQColors.mostaza : CQColors.mostaza.withValues(alpha: 0)),
      duration: CQMotion.reduced(context) ? Duration.zero : CQMotion.fast,
      builder: (context, fill, _) => CustomPaint(size: const Size.square(40), painter: _StarPainter(fill ?? Colors.transparent)),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.fill);
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    // Estrella de 5 puntas como la de Lucide (radio interior ~0,45).
    final c = size.center(Offset.zero);
    final outer = size.width * 0.44;
    final inner = outer * 0.45;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r + size.height * 0.03);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = CQColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * size.width / 24
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.fill != fill;
}
