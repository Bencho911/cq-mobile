import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../state/cart.dart';
import '../../widgets/controls.dart';

const _methods = [
  (
    id: 'wompi',
    label: 'Tarjeta débito o crédito',
    // MOCK: sin backend no se abre Wompi ni se cobra.
    description: AppConfig.useMocks
        ? 'Visa, Mastercard o Amex con Wompi. Modo de prueba: no se hace ningún cobro.'
        : 'Visa, Mastercard o Amex. Pago seguro con Wompi.',
    icon: LucideIcons.creditCard,
  ),
  (id: 'efectivo', label: 'Efectivo en tienda', description: 'Pagas al recoger tu pedido.', icon: LucideIcons.banknote),
  (id: 'kiosco', label: 'Pago en kiosco', description: 'Usas el terminal de la tienda al recoger.', icon: LucideIcons.store),
];

/// Elegir cómo pagar; al tocar una opción se guarda y vuelve.
class PaymentMethodScreen extends ConsumerWidget {
  const PaymentMethodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sin elección, el pedido se paga en el kiosco: se muestra marcado.
    final current = ref.watch(cartProvider.select((c) => c.paymentMethod)) ?? 'kiosco';
    void back() => context.canPop() ? context.pop() : context.go('/home');

    return Scaffold(
      backgroundColor: CQColors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: 'Método de pago', onBack: back),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 32),
              children: [
                Text('Elige cómo quieres pagar tu pedido.', style: CQType.body(15, color: CQColors.muted)),
                const SizedBox(height: 16),
                for (final m in _methods) ...[
                  _MethodCard(
                    icon: m.icon,
                    label: m.label,
                    description: m.description,
                    active: current == m.id,
                    onTap: () {
                      ref.read(cartProvider.notifier).setPaymentMethod(m.id);
                      back();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: active,
    child: Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CQMotion.press,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? CQColors.ink : CQColors.line, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: CQColors.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: CQType.body(16, weight: FontWeight.w700)),
                  Text(description, style: CQType.body(14, color: CQColors.muted, height: 1.25)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _Radio(active: active),
          ],
        ),
      ),
    ),
  );
}

class _Radio extends StatelessWidget {
  const _Radio({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: CQMotion.press,
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: active ? CQColors.ink : CQColors.mutedSoft, width: 1.5),
    ),
    child: AnimatedScale(
      scale: active ? 1 : 0,
      duration: CQMotion.fast,
      curve: CQMotion.easeOut,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(color: CQColors.ink, shape: BoxShape.circle),
      ),
    ),
  );
}
