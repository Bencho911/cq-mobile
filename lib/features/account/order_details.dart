import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../data/history.dart';
import '../../state/orders.dart';
import '../../widgets/controls.dart';
import 'common.dart';
import 'receipt_pdf.dart';

/// Detalle de un pedido guardado en el teléfono.
class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({super.key, this.orderId});

  final int? orderId;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _pdfBusy = false;

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  Future<void> _pdf(PastOrder order) async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      await openReceiptPdf(order);
    } catch (_) {
      if (mounted) showToast(context, 'No pudimos generar el comprobante.', detail: 'Inténtalo de nuevo en un momento.', error: true);
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.orderId;
    final order = id == null ? null : ref.watch(ordersProvider).where((o) => o.id == id).firstOrNull;

    if (order == null) {
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

    final count = order.items.fold(0, (s, l) => s + l.quantity);
    final (statusLabel, statusTone) = statusBadgeFor(order.status);
    final delivery = order.deliveryType == 'Domicilio';

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
                    TextSpan(text: '${order.id}', style: CQType.number(30, height: 1)),
                  ]),
                  style: CQType.title(30, height: 1),
                ),
              ),
              CQBadge(statusLabel, tone: statusTone),
            ]),
            const SizedBox(height: 6),
            Text(formatLongDate(order.createdAt), style: CQType.body(15, color: CQColors.muted)),
            const SizedBox(height: 16),
            InfoRow(label: 'Entrega', child: _value(order.deliveryType ?? 'Recoger en tienda')),
            if (!delivery && order.store.isNotEmpty) InfoRow(label: 'Tienda', child: _value(shortStore(order.store))),
            if (order.pickupTime != null) InfoRow(label: 'Hora', child: _value(formatClock(order.pickupTime!))),
            InfoRow(label: 'Método de pago', child: _value(order.paymentMethod)),
            const SizedBox(height: 24),
            Text('Productos', style: CQType.title(20, height: 1.1)),
            const SizedBox(height: 4),
            if (order.items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
                child: Text('No encontramos los productos de este pedido.', style: CQType.body(15, color: CQColors.muted)),
              )
            else
              for (final l in order.items) _LineRow(line: l),
            if (order.discount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(children: [
                  Expanded(child: Text('Descuento', style: CQType.body(15, color: CQColors.muted))),
                  Text('−${formatCOP(order.discount)}', style: CQType.number(15, color: CQColors.success).copyWith(fontWeight: FontWeight.w400)),
                ]),
              ),
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
                Text(formatCOP(order.total), style: CQType.number(22)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Pressable(
                onTap: () => context.push('/invoice/${order.id}', extra: order),
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
          label: 'Descargar recibo',
          icon: LucideIcons.download,
          loading: _pdfBusy,
          onPressed: () => _pdf(order),
        ),
      ),
    );
  }

  Widget _value(String v) => Text(v, textAlign: TextAlign.right, style: CQType.body(15));
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final PastOrderItem line;

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
            Text(line.name, style: CQType.body(16)),
            if (itemDetail(line).isNotEmpty) Text(itemDetail(line), style: CQType.body(14, color: CQColors.muted)),
            Text('${line.quantity} × ${formatCOP(line.unitPrice)}', style: CQType.number(14, color: CQColors.muted).copyWith(fontWeight: FontWeight.w400)),
          ]),
        ),
        const SizedBox(width: 12),
        Text(formatCOP(line.quantity * line.unitPrice), style: CQType.number(16).copyWith(fontWeight: FontWeight.w400)),
      ]),
    );
  }
}
