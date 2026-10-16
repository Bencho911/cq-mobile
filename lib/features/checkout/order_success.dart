import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../widgets/controls.dart';
import '../../widgets/zocalo.dart';
import 'common.dart';
import 'discounts.dart';

const _countdown = 3;

/// Duración total de la entrada: la píldora de puntos termina de contar a
/// los 1.050 ms (entra a los 450 ms y cuenta durante 600 ms).
const _total = 1050.0;
Interval _at(double startMs, double endMs) => Interval(startMs / _total, endMs / _total, curve: CQMotion.easeOut);

/// Confirmación breve antes del seguimiento: verde de fachada, sin halos.
class OrderSuccessScreen extends ConsumerStatefulWidget {
  const OrderSuccessScreen({super.key, this.orderId, this.earned = 0});

  final int? orderId;

  /// Puntos que sumó el pedido.
  final int earned;

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _total.round()),
  );
  late final Timer _tick;
  late final Timer _leave;
  int _count = _countdown;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _count = (_count - 1).clamp(0, _countdown));
    });
    _leave = Timer(const Duration(seconds: _countdown), _track);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Con "reducir movimiento" todo aparece ya en su lugar.
    if (CQMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  void _track() {
    if (mounted) context.go('/track-order', extra: widget.orderId);
  }

  @override
  void dispose() {
    _tick.cancel();
    _leave.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final title = CurvedAnimation(parent: _c, curve: _at(0, 450));
    final art = CurvedAnimation(parent: _c, curve: _at(150, 650));

    // Premio del pago recién hecho (ave nueva o tarjeta completa).
    final reward = ref.watch(lastRewardProvider);
    final points = reward != null && reward.orderId == widget.orderId ? reward.points : null;
    final bird = points?.newBirds.lastOrNull;
    final prize = bird != null
        ? '¡Ganaste al ${bird.name}!'
        : (points?.cardsCompleted ?? 0) > 0
        ? '¡Ganaste una bebida gratis!'
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: CQColors.verde,
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, (pad.top).clamp(28, double.infinity), 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.orderId != null) OrderPill(orderId: widget.orderId!),
                  const SizedBox(height: 16),
                  _Rise(
                    animation: title,
                    distance: 12,
                    child: Semantics(header: true, child: Text('Recibimos tu pedido.', style: facadeTitle(CQColors.white))),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'La barra ya lo está preparando. Te avisamos cuando esté listo.',
                    style: CQType.body(17, color: CQColors.onDark, height: 1.35),
                  ),
                  if (widget.earned > 0) ...[const SizedBox(height: 20), _EarnedPoints(earned: widget.earned, prize: prize, controller: _c)],
                ],
              ),
            ),

            // La fachada se arma: el zócalo se dibuja y la ventana con el ave sube a su lugar.
            Positioned(
              left: 0,
              right: 0,
              bottom: 150,
              child: ExcludeSemantics(
                child: Center(
                  child: _Rise(
                    animation: art,
                    distance: 16,
                    child: Image.asset('assets/brand/ventana-ave.webp', width: 230, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            const Positioned(left: 0, right: 0, bottom: 0, height: 150, child: ColoredBox(color: CQColors.mostaza)),
            const Positioned(left: 0, right: 0, bottom: 150, child: Zocalo(animate: true, delay: Duration(milliseconds: 50))),

            Positioned(
              left: 20,
              right: 20,
              bottom: pad.bottom + 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CQButton(label: 'Ver estado del pedido', onPressed: _track),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Te llevamos al seguimiento en '),
                          TextSpan(text: '$_count', style: CQType.number(14)),
                          const TextSpan(text: ' s'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: CQType.body(14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aparece con fundido mientras sube [distance] px a su lugar.
class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.distance, required this.child});
  final Animation<double> animation;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, child) => Opacity(
      opacity: animation.value.clamp(0, 1),
      child: Transform.translate(offset: Offset(0, distance * (1 - animation.value)), child: child),
    ),
    child: child,
  );
}

/// Puntos que sumó el pedido: la píldora entra y el número sube desde 0.
class _EarnedPoints extends StatelessWidget {
  const _EarnedPoints({required this.earned, this.prize, required this.controller});
  final int earned;

  /// "¡Ganaste al Toche!" si el pedido dio un premio.
  final String? prize;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final enter = CurvedAnimation(parent: controller, curve: _at(450, 800));
    final count = CurvedAnimation(parent: controller, curve: _at(450, _total));
    return Semantics(
      label: prize != null ? '+$earned puntos. $prize' : '+$earned puntos para tu álbum',
      excludeSemantics: true,
      child: _Rise(
        animation: enter,
        distance: 8,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: CQColors.mostaza, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: count,
                builder: (context, _) => Text('+${(earned * count.value).round()}', style: CQType.number(16)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  prize != null ? 'puntos · $prize' : 'puntos para tu álbum',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CQType.body(16, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
