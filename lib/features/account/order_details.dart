import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../data/models.dart';
import '../../state/cart.dart';
import '../../state/providers.dart';
import '../../widgets/controls.dart';
import 'common.dart';

/// Detalle de un pedido recién hecho (o del carrito, en la demo).
class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({super.key, this.orderId});

  final int? orderId;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

(String, BadgeTone) _statusBadge(String? estado) => switch (estado) {
      'completada' => ('Entregado', BadgeTone.neutral),
      'cancelada' => ('Cancelado', BadgeTone.danger),
      'reembolsada' => ('Reembolsado', BadgeTone.danger),
      _ => ('Preparando', BadgeTone.accent),
    };

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  Order? _order;

  @override
  void initState() {
    super.initState();
    final id = widget.orderId;
    if (id == null) return;
    ref.read(orderServiceProvider).getOrderById(id).then((o) {
      if (mounted) setState(() => _order = o);
    }, onError: (_) {
      if (mounted) setState(() => _order = null);
    });
  }

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final store = ref.watch(selectedStoreProvider);
    final order = _order;

    // Fallback con el carrito si no hay orden (demo).
    final fallback = [
      for (final i in cart.items)
        OrderLine(codProd: i.product.codProd, quantity: i.quantity, unitPrice: i.unitPrice, name: i.product.name, imageUrl: i.product.imageUrl),
    ];
    final lines = order != null && order.items.isNotEmpty ? order.items : fallback;
    final total = (order?.total ?? 0) > 0 ? order!.total : lines.fold(0, (s, l) => s + l.quantity * l.unitPrice);
    final count = lines.fold(0, (s, l) => s + l.quantity);
    final (statusLabel, statusTone) = _statusBadge(order?.status);
    final payment = order?.paymentMethod == null ? 'Pago en kiosco' : paymentLabels[order!.paymentMethod] ?? order.paymentMethod!;
    final delivery = order?.deliveryType == 'domicilio';

    if (widget.orderId == null && lines.isEmpty) {
      return Scaffold(
        body: Column(children: [
          PageHeader(title: 'Detalle del pedido', onBack: _back),
          EmptyState(
            image: 'assets/brand/ave-colibri-rosa.webp',
            title: 'No encontramos este pedido',
            description: 'Búscalo en tu lista de pedidos.',
            action: CQButton(label: 'Ver mis pedidos', expand: false, onPressed: () => context.go('/orders')),
          ),
        ]),
      );
    }

    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        PageHeader(title: 'Detalle del pedido', onBack: _back),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Pedido '),
                    TextSpan(text: '${order?.id ?? widget.orderId ?? '—'}', style: CQType.number(30, height: 1)),
                  ]),
                  style: CQType.title(30, height: 1),
                ),
              ),
              // Sin datos del backend no se inventa un estado.
              AnimatedOpacity(
                opacity: order != null ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: CQBadge(statusLabel, tone: statusTone),
              ),
            ]),
            if (order?.date != null) ...[
              const SizedBox(height: 6),
              Text(formatLongDate(order!.date!), style: CQType.body(15, color: CQColors.muted)),
            ],
            const SizedBox(height: 16),
            InfoRow(label: 'Entrega', child: _value(delivery ? 'Domicilio' : 'Recoger en tienda')),
            if (!delivery && store != null) InfoRow(label: 'Tienda', child: _value('Tienda ${store.shortName}')),
            InfoRow(label: 'Método de pago', child: _value(payment)),
            const SizedBox(height: 24),
            Text('Productos', style: CQType.title(20, height: 1.1)),
            const SizedBox(height: 4),
            if (lines.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
                child: Text('No encontramos los productos de este pedido.', style: CQType.body(15, color: CQColors.muted)),
              )
            else
              for (final l in lines) _LineRow(line: l),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Total ('),
                    TextSpan(text: '$count', style: CQType.number(16)),
                    TextSpan(text: ' ${count == 1 ? 'producto' : 'productos'})'),
                  ]), style: CQType.body(16)),
                ),
                Text(formatCOP(total), style: CQType.number(22)),
              ]),
            ),
            if (widget.orderId != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Pressable(
                  onTap: () => context.push('/invoice/${widget.orderId}'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1,
                      child: Text('Ver recibo',
                          style: CQType.body(15, weight: FontWeight.w600)
                              .copyWith(decoration: TextDecoration.underline, decorationColor: CQColors.ink)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
      bottomNavigationBar: BottomActionBar(
        child: CQButton(
          label: 'Descargar comprobante',
          icon: LucideIcons.download,
          // MOCK: la web imprime la página; la app aún no genera el PDF.
          onPressed: () => showToast(context, 'Muy pronto podrás descargar el comprobante.'),
        ),
      ),
    );
  }

  Widget _value(String v) => Text(v, textAlign: TextAlign.right, style: CQType.body(15));
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: CQColors.creamMid, shape: BoxShape.circle),
          clipBehavior: Clip.antiAlias,
          child: line.imageUrl == null ? null : ProductImage(line.imageUrl, width: 40, height: 40),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.name ?? 'Producto ${line.codProd}', style: CQType.body(16)),
            Text('${line.quantity} × ${formatCOP(line.unitPrice)}', style: CQType.number(14, color: CQColors.muted).copyWith(fontWeight: FontWeight.w400)),
          ]),
        ),
        const SizedBox(width: 12),
        Text(formatCOP(line.quantity * line.unitPrice), style: CQType.number(16).copyWith(fontWeight: FontWeight.w400)),
      ]),
    );
  }
}
