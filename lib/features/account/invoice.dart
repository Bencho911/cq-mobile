import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../data/history.dart';
import '../../state/orders.dart';
import '../../state/providers.dart';
import '../../widgets/controls.dart';
import '../../widgets/zocalo.dart';
import 'common.dart';
import 'receipt_pdf.dart';

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
  bool _loading = false;
  bool _busy = false;
  bool _pdfBusy = false;
  final _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Pedido que no está en el teléfono (enlace directo): se pide al servicio.
    if (widget.order != null || widget.id <= 0 || ref.read(ordersProvider.notifier).byId(widget.id) != null) return;
    _loading = true;
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final o = await ref.read(orderServiceProvider).getOrderById(widget.id);
      if (!mounted || o.items.isEmpty) return;
      final store = ref.read(selectedStoreProvider);
      _fetched = PastOrder(
        id: o.id,
        status: PastOrderStatus.values.where((s) => s.name == o.status).firstOrNull ?? PastOrderStatus.pendiente,
        createdAt: o.date ?? DateTime.now(),
        store: store?.name ?? '',
        storeId: store?.id,
        address: store?.address,
        paymentMethod: o.paymentMethod == null ? 'Pago en kiosco' : paymentLabels[o.paymentMethod] ?? o.paymentMethod!,
        deliveryType: o.deliveryType == 'domicilio' ? 'Domicilio' : 'Recoger en tienda',
        items: [
          for (final l in o.items)
            PastOrderItem(codProd: l.codProd, name: l.name ?? 'Producto ${l.codProd}', quantity: l.quantity, unitPrice: l.unitPrice, imageUrl: l.imageUrl),
        ],
      );
    } catch (_) {
      // Sin conexión: se muestra el estado vacío.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Rect? _origin() {
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share(PastOrder invoice) async {
    try {
      await shareReceipt(invoice, origin: _origin());
    } catch (_) {
      // Sin hoja de compartir: se copia el resumen.
      await Clipboard.setData(ClipboardData(text: receiptText(invoice)));
      if (mounted) showToast(context, 'Copiamos el resumen del recibo.');
    }
  }

  Future<void> _pdf(PastOrder invoice) async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      await openReceiptPdf(invoice);
    } catch (_) {
      if (mounted) showToast(context, 'No pudimos generar el PDF.', detail: 'Inténtalo de nuevo en un momento.', error: true);
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
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
    // La versión guardada manda (refleja la calificación más reciente).
    final saved = ref.watch(ordersProvider).where((o) => o.id == widget.id).firstOrNull;
    final invoice = saved ?? widget.order ?? _fetched;

    if (invoice == null) {
      return Scaffold(
        body: Column(children: [
          PageHeader(title: 'Recibo', onBack: _back),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 80), child: CircularProgressIndicator(color: CQColors.ink))
          else
            EmptyState(
              image: 'assets/brand/ave-colibri-rosa.webp',
              title: 'No encontramos este pedido',
              description: 'Búscalo en tu lista de pedidos.',
              action: CQButton(label: 'Ver mis pedidos', expand: false, onPressed: () => context.go('/orders')),
            ),
        ]),
      );
    }

    final selected = ref.watch(selectedStoreProvider);
    final storeName = invoice.store;
    final address = invoice.address ?? (selected != null && storeName == selected.name ? selected.address : null);
    final cancelled = invoice.status == PastOrderStatus.cancelada;
    final canRate = invoice.status == PastOrderStatus.completada && invoice.rating == null;

    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        PageHeader(
          title: 'Recibo',
          onBack: _back,
          action: Pressable(
            key: _shareKey,
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
                  Text(formatLongDate(invoice.createdAt), style: CQType.body(15, color: CQColors.muted)),
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
            if (invoice.earnedPoints > 0)
              InfoRow(
                label: 'Puntos ganados',
                child: Text('+${invoice.earnedPoints}', style: CQType.number(15, color: CQColors.success).copyWith(fontWeight: FontWeight.w400)),
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

            // Calificación
            if (invoice.rating != null) ...[
              const SizedBox(height: 24),
              Text('Tu calificación', style: CQType.title(20, height: 1.1)),
              const SizedBox(height: 8),
              Semantics(
                label: '${invoice.rating} de 5 estrellas',
                excludeSemantics: true,
                child: Row(children: [
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      // Lucide solo trae la estrella en línea: las ganadas van rellenas.
                      child: Icon(i < invoice.rating! ? Icons.star_rounded : Icons.star_outline_rounded, size: 24, color: i < invoice.rating! ? CQColors.mostaza : CQColors.line),
                    ),
                ]),
              ),
              if (invoice.review != null) ...[
                const SizedBox(height: 6),
                Text(invoice.review!, style: CQType.body(15, color: CQColors.muted, height: 1.5)),
              ],
            ],

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
              busy: _pdfBusy,
              onTap: () => _pdf(invoice),
            ),
            if (canRate) ...[
              const SizedBox(height: 8),
              OutlineAction(
                label: 'Calificar pedido',
                icon: LucideIcons.star,
                height: 52,
                expand: true,
                onTap: () => context.push('/rating-review', extra: invoice.id),
              ),
            ],
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
            if (itemDetail(item).isNotEmpty) Text(itemDetail(item), style: CQType.body(14, color: CQColors.muted)),
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
