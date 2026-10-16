import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../data/mock_data.dart';
import '../../data/services.dart';
import '../../state/cart.dart';
import '../../state/customization.dart';
import '../../state/loyalty.dart';
import '../../state/providers.dart';
import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/stamp.dart';
import 'common.dart';
import 'time_picker.dart';

const _paymentLabels = {'wompi': 'Tarjeta (Wompi)', 'efectivo': 'Efectivo en tienda', 'kiosco': 'Pago en kiosco'};

/// "Mediano, + espresso extra".
String _describe(CartItem item) => [
  item.size,
  item.variant?.toLowerCase(),
  if (item.sugar != null && item.sugar != 'Normal') item.sugar!.toLowerCase(),
  if (item.ice != null && item.ice != 'Normal') item.ice!.toLowerCase(),
  ...toppingNames(item.toppings).map((n) => '+ ${n.toLowerCase()}'),
].whereType<String>().where((s) => s.isNotEmpty).join(', ');

/// Carrito y pago: "Tu pedido".
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _submitting = false;

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  Future<void> _pay(int earned) async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty || _submitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      final service = ref.read(orderServiceProvider);
      final order = await service.createOrder(
        CreateOrderInput(
          items: cart.toOrderLines(),
          paymentMethod: cart.paymentMethod ?? 'kiosco',
          storeId: cart.storeId,
          deliveryType: cart.deliveryType.name,
        ),
      );

      // Con backend real y pasarela, abre el checkout de Wompi en el navegador.
      if (!AppConfig.useMocks && cart.paymentMethod == 'wompi') {
        // TODO: usar un deep link de la app como URL de retorno cuando exista.
        final url = await service.createCheckoutUrl(order.id, '${AppConfig.apiOrigin}/order-success?order=${order.id}');
        if (url.isNotEmpty) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }

      if (!mounted) return;
      ref.read(cartProvider.notifier).clear();
      context.go(
        '/order-success',
        extra: OrderSuccessArgs(orderId: order.id, earned: earned),
      );
    } catch (_) {
      if (mounted) {
        showToast(context, 'No se pudo crear el pedido', detail: 'Revisa tu conexión e intenta de nuevo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final store = ref.watch(selectedStoreProvider);
    final pickup = cart.upcomingPickup();
    final recoger = cart.deliveryType == DeliveryType.recoger;

    if (cart.items.isEmpty) {
      return Scaffold(
        backgroundColor: CQColors.white,
        body: Column(
          children: [
            PageHeader(title: 'Tu pedido', onBack: () => context.go('/home')),
            _EmptyState(onMenu: () => context.go('/menu')),
          ],
        ),
      );
    }

    final account = ref.watch(loyaltyAccountProvider);
    final earned = estimatePoints(cart.subtotal);
    final reward = preview(account, earned);
    final prizeBird = reward.newBirds.lastOrNull;
    final summary = summarize(account);

    return Scaffold(
      backgroundColor: CQColors.white,
      body: Column(
        children: [
          PageHeader(title: 'Tu pedido', onBack: _back),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                // Recogida
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  decoration: BoxDecoration(color: CQColors.tealSoft, borderRadius: BorderRadius.circular(6)),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'Tipo de entrega',
                        child: Segmented<DeliveryType>(
                          options: const [(DeliveryType.recoger, 'Recoger en tienda'), (DeliveryType.domicilio, 'Domicilio')],
                          value: cart.deliveryType,
                          onChanged: notifier.setDelivery,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 8, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recoger ? 'Recoges en' : 'Prepara la tienda',
                                    style: CQType.body(13, color: CQColors.muted),
                                  ),
                                  Text(
                                    [
                                      store != null ? 'Tienda ${store.shortName}' : 'Elige una tienda',
                                      if (recoger)
                                        pickup != null ? ', a las ${formatClock(pickup)}' : ', en $mockReadyMinutes min',
                                    ].join(),
                                    style: CQType.body(16, weight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            Pressable(
                              onTap: () => context.push('/stores'),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                alignment: Alignment.center,
                                child: Text(
                                  'Cambiar',
                                  style: CQType.body(15, weight: FontWeight.w600).copyWith(decoration: TextDecoration.underline),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Líneas: el arco solo aparece al armar el pedido
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: AnimatedSize(
                    duration: CQMotion.fast,
                    curve: CQMotion.easeOut,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        for (final item in cart.items)
                          _CartLine(
                            key: ValueKey(item.key),
                            item: item,
                            onMinus: () => item.quantity == 1
                                ? notifier.remove(item.key)
                                : notifier.setQuantity(item.key, item.quantity - 1),
                            onPlus: () => notifier.setQuantity(item.key, item.quantity + 1),
                          ),
                      ],
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, top: 4),
                    child: Pressable(
                      onTap: () => context.go('/menu'),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.plus, size: 17, color: CQColors.ink),
                            const SizedBox(width: 6),
                            Text('Agregar algo más', style: CQType.body(15, weight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Puntos que suma el pedido
                if (earned > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Stamp(
                            bird: prizeBird ?? summary.nextBird ?? summary.slots.first.bird,
                            state: prizeBird != null ? StampState.earned : StampState.next,
                            height: 78,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(text: 'Este pedido suma '),
                                    TextSpan(text: '$earned', style: CQType.number(16)),
                                    TextSpan(text: earned == 1 ? ' punto' : ' puntos'),
                                  ],
                                ),
                                style: CQType.body(16, weight: FontWeight.w700),
                              ),
                              Text(
                                reward.completesCard
                                    ? 'Completas la tarjeta: ganas ${prizeBird != null ? 'al ${prizeBird.name} y ' : ''}una bebida gratis.'
                                    : prizeBird != null
                                    ? 'Llegas a ${reward.total} y ganas al ${prizeBird.name}.'
                                    : 'Llegas a ${reward.total} de $pointsPerReward.',
                                style: CQType.body(14, color: CQColors.muted, height: 1.25),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Entrega a domicilio
                if (!recoger)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dirección de entrega', style: CQType.body(15, weight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        const CQTextField(
                          label: 'Dirección',
                          hint: 'Ej. Calle 12 #9-34',
                          textInputAction: TextInputAction.next,
                          autofillHints: [AutofillHints.streetAddressLine1],
                        ),
                        const SizedBox(height: 10),
                        const CQTextField(
                          label: 'Apartamento o piso (opcional)',
                          hint: 'Ej. Apto 301',
                          textInputAction: TextInputAction.next,
                          autofillHints: [AutofillHints.streetAddressLine2],
                        ),
                        const SizedBox(height: 10),
                        const CQTextField(
                          label: 'Referencias',
                          hint: 'Ej. Casa azul, portón blanco',
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                  ),

                // Horario y pago
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    children: [
                      if (recoger)
                        ListRow(
                          label: 'Hora de recogida',
                          value: pickup != null ? formatClock(pickup) : 'Lo antes posible',
                          onTap: () => showPickupTimeSheet(
                            context,
                            value: pickup,
                            readyMinutes: mockReadyMinutes,
                            onConfirm: notifier.setPickupTime,
                          ),
                        ),
                      ListRow(
                        label: 'Método de pago',
                        value: cart.paymentMethod == null ? 'Elegir' : _paymentLabels[cart.paymentMethod] ?? cart.paymentMethod,
                        onTap: () => context.push('/payment-method'),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(text: 'Total ('),
                                    TextSpan(text: '${cart.count}', style: CQType.number(16)),
                                    TextSpan(text: cart.count == 1 ? ' producto)' : ' productos)'),
                                  ],
                                ),
                                style: CQType.body(16),
                              ),
                            ),
                            Text(formatCOP(cart.subtotal), style: CQType.number(20)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Acción fija inferior
      bottomNavigationBar: BottomAction(
        child: CQButton(
          label: _submitting ? 'Enviando pedido…' : 'Pagar y pedir',
          trailing: formatCOP(cart.subtotal),
          loading: _submitting,
          onPressed: () => _pay(earned),
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({super.key, required this.item, required this.onMinus, required this.onPlus});

  final CartItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    final desc = _describe(item);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CQColors.line)),
      ),
      child: Row(
        children: [
          Arch(
            tone: archToneFor(p.codProd),
            width: 56,
            height: 68,
            child: Padding(padding: const EdgeInsets.only(bottom: 2), child: ProductImage(p.imageUrl, width: 46)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: CQType.body(16, weight: FontWeight.w700)),
                Text(desc.isEmpty ? 'Como viene' : desc, style: CQType.body(14, color: CQColors.muted, height: 1.25)),
                const SizedBox(height: 2),
                Text(formatCOP(item.quantity * item.unitPrice), style: CQType.number(15)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: CQColors.line, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepButton(
                  icon: item.quantity == 1 ? LucideIcons.trash2 : LucideIcons.minus,
                  label: item.quantity == 1 ? 'Quitar ${p.name}' : 'Quitar uno',
                  onTap: onMinus,
                ),
                SizedBox(
                  width: 22,
                  child: Bump(
                    value: item.quantity,
                    child: Text('${item.quantity}', textAlign: TextAlign.center, style: CQType.number(15)),
                  ),
                ),
                _StepButton(icon: LucideIcons.plus, label: 'Agregar uno', onTap: onPlus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    scale: 0.9,
    child: SizedBox(width: 40, height: 44, child: Icon(icon, size: 16, color: CQColors.ink)),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
    child: Column(
      children: [
        const Icon(LucideIcons.store, size: 36, color: CQColors.muted),
        const SizedBox(height: 12),
        Text('Tu pedido está vacío', textAlign: TextAlign.center, style: CQType.title(22, height: 1.1)),
        const SizedBox(height: 12),
        Text(
          'Elige algo del menú para empezar.',
          textAlign: TextAlign.center,
          style: CQType.body(15, color: CQColors.muted, height: 1.6),
        ),
        const SizedBox(height: 16),
        CQButton(label: 'Ver el menú', onPressed: onMenu, expand: false),
      ],
    ),
  );
}
