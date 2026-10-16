import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../data/history.dart';
import '../../state/providers.dart';
import '../../widgets/controls.dart';
import '../../widgets/zocalo.dart';
import 'common.dart';

/// Recibo de un pedido: comprobante, detalle y "Repetir pedido".
class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key, required this.id, this.order});

  final int id;

  /// Pedido ya cargado desde el historial (si viene de Pedidos).
  final PastOrder? order;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  PastOrder? _fetched;
  bool _busy = false;

  /// Pedido del historial MOCK con ese id (enlaces directos a /invoice/:id).
  PastOrder? get _fromHistory => [...mockActiveOrders, ...mockOrderHistory].where((o) => o.id == widget.id).firstOrNull;

  @override
  void initState() {
    super.initState();
    if (widget.order != null || _fromHistory != null || widget.id <= 0) return;
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final o = await ref.read(orderServiceProvider).getOrderById(widget.id);
      if (!mounted || o.items.isEmpty) return;
      final store = ref.read(selectedStoreProvider);
      setState(() => _fetched = PastOrder(
            id: o.id,
            status: PastOrderStatus.values.where((s) => s.name == o.status).firstOrNull ?? PastOrderStatus.pendiente,
            date: o.date == null ? '' : formatShortDate(o.date!),
            store: store?.name ?? '',
            address: store?.address,
            paymentMethod: o.paymentMethod == null ? 'Pago en kiosco' : paymentLabels[o.paymentMethod] ?? o.paymentMethod!,
            deliveryType: o.deliveryType == 'domicilio' ? 'Domicilio' : 'Recoger en tienda',
            items: [
              for (final l in o.items)
                PastOrderItem(codProd: l.codProd, name: l.name ?? 'Producto ${l.codProd}', quantity: l.quantity, unitPrice: l.unitPrice),
            ],
          ));
    } catch (_) {
      // Sin conexión: se queda el recibo de ejemplo.
    }
  }

  Future<void> _share(PastOrder invoice) async {
    // La app no trae el diálogo nativo de compartir: se copia el resumen.
    await Clipboard.setData(ClipboardData(text: 'Recibo del pedido ${invoice.id}. Mi pedido en Café Quindío por ${formatCOP(invoice.total)}'));
    if (mounted) showToast(context, 'Copiamos el resumen del recibo.');
  }

  Future<void> _reorder(PastOrder invoice) async {
    if (_busy) return;
    setState(() => _busy = true);
    await repeatOrder(context, ref, reorderLinesOf(invoice));
    if (mounted) setState(() => _busy = false);
  }

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedStoreProvider);
    final invoice = widget.order ?? _fromHistory ?? _fetched ?? mockInvoice;
    final storeName = invoice.store.isNotEmpty ? invoice.store : (selected?.name ?? '');
    final address = invoice.address ?? (selected != null && storeName == selected.name ? selected.address : null);
    final cancelled = invoice.status == PastOrderStatus.cancelada;

    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        PageHeader(
          title: 'Recibo',
          onBack: _back,
          action: Pressable(
            onTap: () => _share(invoice),
            semanticLabel: 'Compartir recibo',
            child: const SizedBox(width: 44, height: 44, child: Icon(LucideIcons.share2, size: 21, color: CQColors.ink)),
          ),
        ),
        const Zocalo(),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.paddingOf(context).bottom + 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Encabezado del comprobante
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Pedido '),
                    TextSpan(text: '${invoice.id}', style: CQType.number(15).copyWith(fontWeight: FontWeight.w400)),
                  ]), style: CQType.body(15, color: CQColors.muted)),
                  if (invoice.date.isNotEmpty) Text(invoice.date, style: CQType.body(15, color: CQColors.muted)),
                ]),
              ),
              CQBadge(cancelled ? 'Cancelado' : 'Pagado', tone: cancelled ? BadgeTone.danger : BadgeTone.brand),
            ]),
            const SizedBox(height: 12),
            Text(formatCOP(invoice.total), style: CQType.number(44, height: 1).copyWith(fontWeight: FontWeight.w800)),

            // Lugar y pago
            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 1, color: CQColors.line),
            if (storeName.isNotEmpty)
              InfoRow(
                label: invoice.deliveryType == 'Domicilio' ? 'Preparado en' : 'Recogida',
                center: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(shortStore(storeName), textAlign: TextAlign.right, style: CQType.body(15)),
                  if (address != null) Text(address, textAlign: TextAlign.right, style: CQType.body(14, color: CQColors.muted)),
                ]),
              ),
            InfoRow(
              label: 'Pago',
              center: false,
              child: Text(invoice.paymentMethod, textAlign: TextAlign.right, style: CQType.body(15)),
            ),

            // Detalle
            const SizedBox(height: 24),
            Text('Detalle', style: CQType.title(20, height: 1.1)),
            const SizedBox(height: 4),
            for (final item in invoice.items) _ItemRow(item: item),
            const SizedBox(height: 12),
            _TotalLine(label: 'Subtotal', value: formatCOP(invoice.subtotal)),
            if (invoice.discount > 0) _TotalLine(label: 'Descuento', value: '−${formatCOP(invoice.discount)}', color: CQColors.success),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: CQColors.ink, width: 2))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Expanded(child: Text('Total', style: CQType.body(17, weight: FontWeight.w700))),
                Text(formatCOP(invoice.total), style: CQType.number(22)),
              ]),
            ),

            // Acciones
            const SizedBox(height: 32),
            CQButton(
              label: 'Repetir pedido',
              icon: LucideIcons.rotateCcw,
              loading: _busy,
              onPressed: () => _reorder(invoice),
            ),
            const SizedBox(height: 8),
            OutlineAction(
              label: 'Descargar PDF',
              icon: LucideIcons.download,
              height: 52,
              expand: true,
              // MOCK: la web imprime la página; la app aún no genera el PDF.
              onTap: () => showToast(context, 'Muy pronto podrás descargar el PDF.'),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final PastOrderItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '${item.quantity}×  ', style: CQType.number(16, color: CQColors.muted).copyWith(fontWeight: FontWeight.w400)),
              TextSpan(text: item.name),
            ]), style: CQType.body(16)),
            if (item.size != null) Text(item.size!, style: CQType.body(14, color: CQColors.muted)),
          ]),
        ),
        const SizedBox(width: 16),
        Text(formatCOP(item.unitPrice * item.quantity), style: CQType.number(16).copyWith(fontWeight: FontWeight.w400)),
      ]),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value, this.color = CQColors.ink});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: CQType.body(15, color: CQColors.muted))),
        Text(value, style: CQType.number(15, color: color).copyWith(fontWeight: FontWeight.w400)),
      ]),
    );
  }
}
