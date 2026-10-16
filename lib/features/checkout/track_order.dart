import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../state/cart.dart';
import '../../state/providers.dart';
import '../../widgets/controls.dart';
import 'common.dart';
import 'order_ready.dart';

const _steps = [
  (label: 'Tomado', title: 'Recibimos tu pedido', desc: 'La barra ya lo tiene en la fila.'),
  (label: 'Preparando', title: 'Preparando tu pedido', desc: 'Estará listo en unos $mockReadyMinutes minutos.'),
  (label: 'Listo', title: 'Tu pedido está listo', desc: 'Recógelo en la barra.'),
];

/// Seguimiento del pedido. Paso: 1 = tomado, 2 = preparando, 3 = listo.
class TrackOrderScreen extends ConsumerStatefulWidget {
  const TrackOrderScreen({super.key, this.orderId});

  final int? orderId;

  @override
  ConsumerState<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends ConsumerState<TrackOrderScreen> {
  int _step = 1;
  int _orderTotal = 0;
  List<OrderLine> _orderLines = const [];
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    final id = widget.orderId;
    if (id != null) _load(id);

    if (AppConfig.useMocks) {
      // MOCK: avance simulado (el backend no emite "preparando").
      _timers
        ..add(Timer(const Duration(seconds: 3), () => _setStep(2)))
        ..add(
          Timer(const Duration(seconds: 6), () {
            _setStep(3);
            _showReady();
          }),
        );
    } else if (id != null) {
      // Real: sondeo del estado de la orden.
      _poll(id);
      _timers.add(Timer.periodic(const Duration(milliseconds: 2500), (_) => _poll(id)));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _load(int id) async {
    try {
      final o = await ref.read(orderServiceProvider).getOrderById(id);
      if (mounted) {
        setState(() {
          _orderTotal = o.total;
          _orderLines = o.items;
        });
      }
    } catch (_) {}
  }

  Future<void> _poll(int id) async {
    try {
      final order = await ref.read(orderServiceProvider).getOrderById(id);
      _setStep(order.status == 'completada' ? 3 : 1);
    } catch (_) {
      // Mantener el estado.
    }
  }

  void _setStep(int step) {
    if (mounted && step != _step) setState(() => _step = step);
  }

  void _showReady() {
    if (!mounted) return;
    final store = ref.read(selectedStoreProvider);
    final id = widget.orderId;
    showOrderReady(
      context,
      orderId: id,
      storeName: store?.shortName,
      total: _orderTotal,
      onPickedUp: () => context.push('/rating-review'),
      onReceipt: id != null ? () => context.push('/invoice/$id') : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(selectedStoreProvider);
    final cartItems = ref.watch(cartProvider.select((c) => c.items));
    final reduced = CQMotion.reduced(context);
    final current = _steps[_step - 1];

    // El carrito se vacía al pagar: las líneas salen de la orden y, si no hay, del carrito.
    final lines = _orderLines.isNotEmpty
        ? _orderLines
        : [
            for (final i in cartItems)
              OrderLine(
                codProd: i.product.codProd,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                name: i.product.name,
                imageUrl: i.product.imageUrl,
              ),
          ];

    return Scaffold(
      backgroundColor: CQColors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: 'Tu pedido', onBack: () => context.canPop() ? context.pop() : context.go('/home')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                // Estado actual
                Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.orderId != null)
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Pedido '),
                              TextSpan(text: '${widget.orderId}', style: CQType.number(15)),
                            ],
                          ),
                          style: CQType.body(15, color: CQColors.muted),
                        ),
                      // El estado nuevo entra con un fundido corto; el anterior sale sin esperar.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        reverseDuration: Duration.zero,
                        layoutBuilder: (current, previous) =>
                            Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                        transitionBuilder: (child, animation) {
                          final a = CurvedAnimation(parent: animation, curve: CQMotion.easeOut);
                          return FadeTransition(
                            opacity: a,
                            child: reduced
                                ? child
                                : AnimatedBuilder(
                                    animation: a,
                                    builder: (context, child) =>
                                        Transform.translate(offset: Offset(0, 6 * (1 - a.value)), child: child),
                                    child: child,
                                  ),
                          );
                        },
                        child: Column(
                          key: ValueKey(_step),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            // Alto reservado de dos renglones para que nada salte.
                            SizedBox(
                              height: 40 * 0.95 * 2 + 4,
                              width: double.infinity,
                              child: Text(current.title, style: CQType.title(40)),
                            ),
                            const SizedBox(height: 8),
                            Text(current.desc, style: CQType.body(16, color: CQColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _Progress(step: _step, label: current.label, reduced: reduced),

                // Tienda
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: CQColors.tealSoft, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(LucideIcons.store, size: 20, color: CQColors.ink),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Recoges en', style: CQType.body(14, color: CQColors.muted)),
                            Text(
                              store != null ? 'Tienda ${store.shortName}' : 'Tu tienda',
                              style: CQType.body(16, weight: FontWeight.w700),
                            ),
                            if (store != null && store.address.isNotEmpty)
                              Text(store.address, style: CQType.body(14, color: CQColors.muted, height: 1.25)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Productos
                const SizedBox(height: 24),
                Semantics(header: true, child: Text('Lo que pediste', style: CQType.title(20, height: 1.1))),
                if (lines.isEmpty)
                  Container(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: CQColors.line)),
                    ),
                    child: Text('Tu pedido ya está en la barra.', style: CQType.body(15, color: CQColors.muted)),
                  )
                else ...[
                  const SizedBox(height: 4),
                  for (final line in lines) _Line(line: line),
                ],
                if (_step >= 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Pressable(
                      onTap: () => context.push('/rating-review'),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        margin: const EdgeInsets.only(top: 8),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Calificar el pedido',
                          style: CQType.body(15, weight: FontWeight.w600).copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: CQButton(
          label: 'Detalle del pedido',
          onPressed: () => context.push('/order-details', extra: widget.orderId),
        ),
      ),
    );
  }
}

/// Barra de tres tramos: el tramo nuevo se llena de izquierda a derecha.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.label, required this.reduced});
  final int step;
  final String label;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Avance del pedido',
      value: label,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 10,
                        color: CQColors.line,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: i < step ? 1 : 0),
                          duration: reduced ? Duration.zero : const Duration(milliseconds: 400),
                          curve: CQMotion.easeOut,
                          builder: (context, v, child) =>
                              Transform.scale(scaleX: v, alignment: Alignment.centerLeft, child: child),
                          child: const ColoredBox(color: CQColors.ink, child: SizedBox.expand()),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: CQType.body(
                        13,
                        color: i < step ? CQColors.ink : CQColors.muted,
                        weight: i < step ? FontWeight.w600 : FontWeight.w400,
                      ),
                      child: Text(_steps[i].label),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line});
  final OrderLine line;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: CQColors.line)),
    ),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: CQColors.creamMid, shape: BoxShape.circle),
          child: ProductImage(line.imageUrl, width: 46, height: 46),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name ?? 'Producto ${line.codProd}', style: CQType.body(16, weight: FontWeight.w700)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${line.quantity}',
                      style: CQType.number(14, color: CQColors.muted),
                    ),
                    TextSpan(text: line.quantity == 1 ? ' unidad' : ' unidades'),
                  ],
                ),
                style: CQType.body(14, color: CQColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(formatCOP(line.quantity * line.unitPrice), style: CQType.number(16)),
      ],
    ),
  );
}
