import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// Barra blanca fija al pie, con borde superior, para la acción principal.
class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: CQColors.white,
      border: Border(top: BorderSide(color: CQColors.line)),
    ),
    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 14),
    child: child,
  );
}

/// Píldora "Pedido 1234" sobre la fachada verde.
class OrderPill extends StatelessWidget {
  const OrderPill({super.key, required this.orderId});
  final int orderId;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: CQColors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: CQColors.mostaza, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Pedido '),
              TextSpan(
                text: '$orderId',
                style: CQType.number(14, color: CQColors.white),
              ),
            ],
          ),
          style: CQType.body(14, color: CQColors.white, weight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// Titular grande de las fachadas de confirmación.
TextStyle facadeTitle(Color color) => CQType.title(54, color: color, height: 0.92).copyWith(letterSpacing: 54 * -0.045);
