import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../data/history.dart';
import '../../widgets/controls.dart';
import 'common.dart';

enum _Tab { activos, historial }

/// Pedidos (pestaña): en curso e historial, con "Repetir pedido".
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  var _tab = _Tab.activos;
  bool _busy = false;

  Future<void> _reorder(PastOrder o) async {
    if (_busy) return;
    setState(() => _busy = true);
    await repeatOrder(context, ref, reorderLinesOf(o));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final list = _tab == _Tab.activos ? mockActiveOrders : mockOrderHistory;
    final activeLabel = mockActiveOrders.isEmpty ? 'En curso' : 'En curso  ${mockActiveOrders.length}';

    return Scaffold(
      body: CustomScrollView(slivers: [
        const SliverToBoxAdapter(child: PageHeader(title: 'Pedidos')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          sliver: SliverToBoxAdapter(
            child: Semantics(
              label: 'Tipo de pedidos',
              child: Segmented<_Tab>(
                options: [(_Tab.activos, activeLabel), (_Tab.historial, 'Historial')],
                value: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          // Cambio de lista con un fundido corto; nada de deslizar (se usa a diario).
          child: AnimatedSwitcher(
            duration: CQMotion.reduced(context) ? Duration.zero : CQMotion.fast,
            switchInCurve: CQMotion.easeOut,
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: list.isEmpty
                  ? EmptyState(
                      image: 'assets/brand/ave-colibri-rosa.webp',
                      title: _tab == _Tab.activos ? 'No tienes pedidos en curso' : 'Aún no tienes pedidos',
                      description: _tab == _Tab.activos
                          ? 'Cuando hagas un pedido, aquí verás cómo va.'
                          : 'Tus pedidos anteriores aparecerán aquí para repetirlos rápido.',
                      action: CQButton(label: 'Ver el menú', height: 48, expand: false, onPressed: () => context.go('/menu')),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      child: Column(children: [
                        for (final o in list)
                          _OrderRow(
                            order: o,
                            busy: _busy,
                            onOpen: () => context.push('/invoice/${o.id}', extra: o),
                            onReorder: o.status == PastOrderStatus.completada || o.status == PastOrderStatus.cancelada
                                ? () => _reorder(o)
                                : null,
                          ),
                      ]),
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onOpen, this.onReorder, this.busy = false});

  final PastOrder order;
  final VoidCallback onOpen;
  final VoidCallback? onReorder;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = statusBadgeFor(order.status);
    final cancelled = order.status == PastOrderStatus.cancelada;
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Pressable(
          onTap: onOpen,
          scale: 0.99,
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Pedido '),
                        TextSpan(text: '${order.id}', style: CQType.number(16)),
                      ]),
                      style: CQType.body(16, weight: FontWeight.w700),
                    ),
                    CQBadge(label, tone: tone),
                  ]),
                  const SizedBox(height: 2),
                  Text('${order.date}, ${shortStore(order.store)}', style: CQType.body(14, color: CQColors.muted)),
                  const SizedBox(height: 4),
                  Text(order.items.map((i) => i.name).join(', '), style: CQType.body(15, height: 1.35)),
                ]),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    formatCOP(order.total),
                    style: CQType.number(16, color: cancelled ? CQColors.muted : CQColors.ink).copyWith(
                      fontWeight: FontWeight.w400,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                      decorationColor: CQColors.muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.chevronRight, size: 18, color: CQColors.muted),
                ]),
              ),
            ]),
          ),
        ),
        if (onReorder != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlineAction(
              label: cancelled ? 'Volver a pedir' : 'Repetir pedido',
              icon: LucideIcons.rotateCcw,
              busy: busy,
              onTap: onReorder,
            ),
          ),
      ]),
    );
  }
}
