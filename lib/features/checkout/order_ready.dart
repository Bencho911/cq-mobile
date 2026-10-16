import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../state/loyalty.dart';
import '../../widgets/controls.dart';
import '../../widgets/stamp.dart';
import '../../widgets/zocalo.dart';
import 'common.dart';

/// "Tu pedido está listo": pantalla completa en verde de fachada. Es un
/// momento de pocas veces al día, así que aquí sí cabe una entrada con
/// presencia. Los callbacks reciben el contexto ya cerrado el aviso.
Future<void> showOrderReady(
  BuildContext context, {
  int? orderId,
  String? storeName,
  int earned = 0,
  bool haptics = true,
  VoidCallback? onPickedUp,
  VoidCallback? onReceipt,
}) {
  if (haptics) HapticFeedback.mediumImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Tu pedido está listo',
    barrierColor: Colors.transparent,
    transitionDuration: CQMotion.fast,
    transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
    pageBuilder: (context, _, _) =>
        _OrderReady(orderId: orderId, storeName: storeName, earned: earned, onPickedUp: onPickedUp, onReceipt: onReceipt),
  );
}

class _OrderReady extends ConsumerStatefulWidget {
  const _OrderReady({this.orderId, this.storeName, this.earned = 0, this.onPickedUp, this.onReceipt});

  final int? orderId;
  final String? storeName;

  /// Puntos que ya sumó el pedido (se suman al pagar).
  final int earned;
  final VoidCallback? onPickedUp;
  final VoidCallback? onReceipt;

  @override
  ConsumerState<_OrderReady> createState() => _OrderReadyState();
}

class _OrderReadyState extends ConsumerState<_OrderReady> with SingleTickerProviderStateMixin {
  // Titular: 450 ms con 50 ms de espera.
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final _title = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.1, 1, curve: CQMotion.easeOut),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (CQMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _close([VoidCallback? then]) {
    Navigator.of(context).pop();
    then?.call();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final earned = widget.earned;
    final book = ref.watch(loyaltyProvider);
    final summary = summarize(book.account);
    // Sello: la última ave ganada de la tarjeta o, si no hay, la siguiente.
    final lastEarned = summary.slots.where((s) => s.earned).lastOrNull?.bird;
    final bird = lastEarned ?? summary.nextBird;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: CQColors.verde,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, pad.top.clamp(28, double.infinity), 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.orderId != null) OrderPill(orderId: widget.orderId!),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _title,
                    builder: (context, child) => Opacity(
                      opacity: _title.value,
                      child: Transform.translate(offset: Offset(0, 12 * (1 - _title.value)), child: child),
                    ),
                    child: Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text('Tu pedido está listo.', style: facadeTitle(CQColors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Recógelo en la barra'),
                        if (widget.storeName != null) ...[
                          const TextSpan(text: ' de la '),
                          TextSpan(
                            text: 'Tienda ${widget.storeName}',
                            style: const TextStyle(color: CQColors.white, fontWeight: FontWeight.w700),
                          ),
                        ],
                        const TextSpan(text: '.'),
                      ],
                    ),
                    style: CQType.body(17, color: CQColors.onDark, height: 1.35),
                  ),
                ],
              ),
            ),

            Positioned(
              right: 24,
              bottom: 310,
              child: ExcludeSemantics(child: Image.asset('assets/brand/puerta-capibara.webp', width: 170)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 160 + pad.bottom,
              child: const ColoredBox(color: CQColors.mostaza),
            ),
            Positioned(left: 0, right: 0, bottom: 160 + pad.bottom, child: const Zocalo()),

            if (earned > 0 && bird != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 186 + pad.bottom,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: CQColors.white, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Stamp(bird: bird, state: lastEarned != null ? StampState.earned : StampState.next, height: 78),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: '+'),
                                  TextSpan(text: '$earned', style: CQType.number(17)),
                                  TextSpan(text: earned == 1 ? ' punto con este pedido' : ' puntos con este pedido'),
                                ],
                              ),
                              style: CQType.body(17, weight: FontWeight.w700),
                            ),
                            Text(
                              'Llevas ${book.account.points} de $pointsPerReward puntos'
                              '${book.freeDrinks > 0 ? ' y ${book.freeDrinks == 1 ? 'una bebida gratis' : '${book.freeDrinks} bebidas gratis'}' : ''}.',
                              style: CQType.body(14, color: CQColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Positioned(
              left: 20,
              right: 20,
              bottom: pad.bottom + 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CQButton(label: 'Ya lo recogí', onPressed: () => _close(widget.onPickedUp)),
                  if (widget.onReceipt != null) ...[
                    const SizedBox(height: 6),
                    Pressable(
                      onTap: () => _close(widget.onReceipt),
                      child: SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: Center(
                          child: Text('Ver recibo', style: CQType.body(16, weight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
