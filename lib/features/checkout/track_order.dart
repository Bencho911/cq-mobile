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
import '../../data/history.dart';
import '../../state/orders.dart';
import '../../state/preferences.dart';
import '../../state/providers.dart';
import '../../widgets/controls.dart';
import 'common.dart';
import 'discounts.dart';
import 'order_ready.dart';

const _steps = [
  (label: 'Tomado', title: 'Recibimos tu pedido', desc: 'La barra ya lo tiene en la fila.'),
  (label: 'Preparando', title: 'Preparando tu pedido', desc: 'Estará listo en unos $mockReadyMinutes minutos.'),
  (label: 'Listo', title: 'Tu pedido está listo', desc: 'Recógelo en la barra.'),
];

/// Paso de la barra (1..3) para cada estado.
int _stepFor(PastOrderStatus s) => switch (s) {
  PastOrderStatus.pendiente => 1,
  PastOrderStatus.preparando => 2,
  _ => 3,
};

/// Orden de avance, para no retroceder nunca un estado.
int _rank(PastOrderStatus s) => PastOrderStatus.values.indexOf(s);

// MOCK: tiempos del avance simulado desde que se creó el pedido.
const _toPreparing = Duration(seconds: 3);
const _toReady = Duration(seconds: 6);

/// Seguimiento del pedido guardado en el teléfono (ordersProvider).
class TrackOrderScreen extends ConsumerStatefulWidget {
  const TrackOrderScreen({super.key, this.orderId});

  final int? orderId;

  @override
  ConsumerState<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends ConsumerState<TrackOrderScreen> {
  final _timers = <Timer>[];

  OrdersNotifier get _orders => ref.read(ordersProvider.notifier);

  @override
  void initState() {
    super.initState();
    final id = widget.orderId;
    final order = id == null ? null : _orders.byId(id);
    if (id == null || order == null || !order.status.isActive) return;

    if (AppConfig.useMocks) {
      // MOCK: el backend no emite "preparando". Se retoma según el tiempo
      // que pasó desde que se creó el pedido, sin retroceder lo ya avanzado.
      final elapsed = DateTime.now().difference(order.createdAt);
      if (elapsed < _toPreparing) {
        _timers.add(Timer(_toPreparing - elapsed, () => _advance(id, PastOrderStatus.preparando)));
      }
      if (elapsed < _toReady) {
        _timers.add(Timer(_toReady - elapsed, () => _advance(id, PastOrderStatus.listo)));
      }
      // Lo ya vencido se guarda tras el primer cuadro (no durante la construcción).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (elapsed >= _toReady) {
          _advance(id, PastOrderStatus.listo);
        } else if (elapsed >= _toPreparing) {
          _advance(id, PastOrderStatus.preparando);
        }
      });
    } else {
      // Real: sondeo del estado de la orden.
      _poll(id);
      _timers.add(Timer.periodic(const Duration(milliseconds: 2500), (_) => _poll(id)));
    }

    // Si ya estaba listo al abrir, el aviso sale una vez (si no se vio antes).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_orders.byId(id)?.status == PastOrderStatus.listo) _showReady();
    });
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  /// Avanza el estado guardado solo si es un paso adelante.
  void _advance(int id, PastOrderStatus next) {
    final o = _orders.byId(id);
    if (o == null || _rank(next) <= _rank(o.status)) return;
    _orders.setStatus(id, next);
  }

  Future<void> _poll(int id) async {
    try {
      final order = await ref.read(orderServiceProvider).getOrderById(id);
      if (mounted && order.status == 'completada') _advance(id, PastOrderStatus.listo);
    } catch (_) {
      // Mantener el estado.
    }
  }

  void _pickedUp() {
    final id = widget.orderId;
    if (id != null) _orders.setStatus(id, PastOrderStatus.completada);
    if (mounted) context.go('/orders');
  }

  void _showReady() {
    final id = widget.orderId;
    if (!mounted || id == null) return;
    final shown = ref.read(readyShownProvider);
    if (shown.contains(id)) return;
    shown.add(id);
    final order = _orders.byId(id);
    showOrderReady(
      context,
      orderId: id,
      storeName: order == null ? null : _shortStore(order.store),
      earned: order?.earnedPoints ?? 0,
      haptics: ref.read(preferencesProvider).haptics,
      onPickedUp: _pickedUp,
      onReceipt: () => context.push('/invoice/$id', extra: _orders.byId(id)),
    );
  }

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final id = widget.orderId;
    final order = ref.watch(ordersProvider.select((list) => list.where((o) => o.id == id).firstOrNull));

    // Aviso de listo cuando el estado cambia mientras se mira la pantalla.
    ref.listen(ordersProvider.select((list) => list.where((o) => o.id == id).firstOrNull?.status), (prev, next) {
      if (next == PastOrderStatus.listo && prev != next) _showReady();
    });

    if (order == null) {
      return Scaffold(
        backgroundColor: CQColors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(title: 'Tu pedido', onBack: _back),
            _NotFound(onOrders: () => context.go('/orders')),
          ],
        ),
      );
    }

    final reduced = CQMotion.reduced(context);
    final done = order.status == PastOrderStatus.completada;
    final cancelled = order.status == PastOrderStatus.cancelada;
    final step = _stepFor(order.status);
    final current = done
        ? (label: 'Entregado', title: 'Ya recogiste tu pedido', desc: '¡Que lo disfrutes!')
        : cancelled
        ? (label: 'Cancelado', title: 'Pedido cancelado', desc: 'Este pedido no se va a preparar.')
        : _steps[step - 1];
    final domicilio = order.deliveryType == 'Domicilio';

    return Scaffold(
      backgroundColor: CQColors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: 'Tu pedido', onBack: _back),
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
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Pedido '),
                            TextSpan(text: '${order.id}', style: CQType.number(15)),
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
                          key: ValueKey(order.status),
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
                if (!cancelled) ...[
                  const SizedBox(height: 20),
                  _Progress(step: step, label: current.label, reduced: reduced),
                ],

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
                            Text(domicilio ? 'Prepara la tienda' : 'Recoges en', style: CQType.body(14, color: CQColors.muted)),
                            Text('Tienda ${_shortStore(order.store)}', style: CQType.body(16, weight: FontWeight.w700)),
                            if (order.address != null && order.address!.isNotEmpty)
                              Text(order.address!, style: CQType.body(14, color: CQColors.muted, height: 1.25)),
                            if (order.pickupTime != null)
                              Text('A las ${formatClock(order.pickupTime!)}', style: CQType.body(14, color: CQColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Productos
                const SizedBox(height: 24),
                Semantics(header: true, child: Text('Lo que pediste', style: CQType.title(20, height: 1.1))),
                const SizedBox(height: 4),
                for (final item in order.items) _Line(item: item),
                if (order.discount > 0)
                  _TotalRow(label: 'Descuento', value: '−${formatCOP(order.discount)}', color: CQColors.success),
                _TotalRow(label: 'Total', value: formatCOP(order.total), strong: true),
                if (step >= 3 && !cancelled)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Pressable(
                      onTap: () => context.push('/rating-review', extra: widget.orderId),
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
        child: order.status == PastOrderStatus.listo
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CQButton(label: 'Ya lo recogí', onPressed: _pickedUp),
                  Pressable(
                    onTap: () => context.push('/order-details', extra: order.id),
                    child: SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: Center(child: Text('Detalle del pedido', style: CQType.body(15, weight: FontWeight.w600))),
                    ),
                  ),
                ],
              )
            : CQButton(
                label: 'Detalle del pedido',
                onPressed: () => context.push('/order-details', extra: order.id),
              ),
      ),
    );
  }
}

/// "Café Quindío · Centro" → "Centro".
String _shortStore(String name) => name.replaceFirst(RegExp(r'^Café Quindío\s*[·-]\s*', caseSensitive: false), '');

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onOrders});
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
    child: Column(
      children: [
        const Icon(LucideIcons.receipt, size: 36, color: CQColors.muted),
        const SizedBox(height: 12),
        Text('No encontramos este pedido', textAlign: TextAlign.center, style: CQType.title(22, height: 1.1)),
        const SizedBox(height: 12),
        Text(
          'Puede que se haya borrado de este teléfono. Tus pedidos guardados están en «Pedidos».',
          textAlign: TextAlign.center,
          style: CQType.body(15, color: CQColors.muted, height: 1.6),
        ),
        const SizedBox(height: 16),
        CQButton(label: 'Ver mis pedidos', onPressed: onOrders, expand: false),
      ],
    ),
  );
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.color = CQColors.ink, this.strong = false});
  final String label;
  final String value;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        Expanded(child: Text(label, style: CQType.body(strong ? 16 : 15, weight: strong ? FontWeight.w700 : FontWeight.w400))),
        Text(value, style: CQType.number(strong ? 17 : 15, color: color)),
      ],
    ),
  );
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
  const _Line({required this.item});
  final PastOrderItem item;

  @override
  Widget build(BuildContext context) {
    final detail = itemDetail(item);
    return Container(
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
            child: ProductImage(item.imageUrl, width: 46, height: 46),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: CQType.body(16, weight: FontWeight.w700)),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${item.quantity}', style: CQType.number(14, color: CQColors.muted)),
                      TextSpan(text: item.quantity == 1 ? ' unidad' : ' unidades'),
                      if (detail.isNotEmpty) TextSpan(text: ' · $detail'),
                    ],
                  ),
                  style: CQType.body(14, color: CQColors.muted, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(formatCOP(item.quantity * item.unitPrice), style: CQType.number(16)),
        ],
      ),
    );
  }
}
