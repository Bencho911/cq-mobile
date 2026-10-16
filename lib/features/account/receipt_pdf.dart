import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../data/history.dart';
import '../../state/orders.dart';
import 'common.dart';

/// Recibo en PDF con la marca: Neutra Text, tinta y franja roja (zócalo).

const _ink = PdfColor.fromInt(0xFF18303C);
const _muted = PdfColor.fromInt(0xFF4E5F68);
const _line = PdfColor.fromInt(0xFFE3E7E9);
const _rojo = PdfColor.fromInt(0xFFC2391F);
const _success = PdfColor.fromInt(0xFF2B7A55);

pw.ThemeData? _theme;

Future<pw.ThemeData> _loadTheme() async {
  if (_theme != null) return _theme!;
  final book = pw.Font.ttf(await rootBundle.load('assets/fonts/NeutraText-Book.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NeutraText-Bold.ttf'));
  return _theme = pw.ThemeData.withFont(base: book, bold: bold);
}

/// Nombre del archivo: "recibo-cafe-quindio-1024.pdf".
String receiptFileName(PastOrder o) => 'recibo-cafe-quindio-${o.id}.pdf';

/// Resumen en texto para compartir.
String receiptText(PastOrder o) => [
      'Recibo Café Quindío · Pedido ${o.id}',
      formatLongDate(o.createdAt),
      if (o.store.isNotEmpty) shortStore(o.store),
      '',
      for (final i in o.items) '${i.quantity} x ${i.name}  ${formatCOP(i.quantity * i.unitPrice)}',
      '',
      if (o.discount > 0) 'Descuento: -${formatCOP(o.discount)}',
      'Total: ${formatCOP(o.total)}',
      if (o.earnedPoints > 0) 'Puntos ganados: ${o.earnedPoints}',
    ].join('\n');

/// Genera el PDF del recibo.
Future<Uint8List> buildReceiptPdf(PastOrder o) async {
  final theme = await _loadTheme();
  final doc = pw.Document(title: 'Recibo pedido ${o.id}', author: 'Café Quindío', theme: theme);
  final cancelled = o.status == PastOrderStatus.cancelada;

  pw.Widget totalLine(String label, String value, {PdfColor color = _ink, bool strong = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(label, style: pw.TextStyle(color: strong ? _ink : _muted, fontSize: strong ? 14 : 11, fontWeight: strong ? pw.FontWeight.bold : null))),
          pw.Text(value, style: pw.TextStyle(color: color, fontSize: strong ? 16 : 11, fontWeight: strong ? pw.FontWeight.bold : null)),
        ]),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 24),
    build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      // Encabezado
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Café Quindío', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.Text('Recibo de compra', style: const pw.TextStyle(fontSize: 11, color: _muted)),
          ]),
        ),
        pw.Text(cancelled ? 'CANCELADO' : 'PAGADO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: cancelled ? _rojo : _ink)),
      ]),
      pw.SizedBox(height: 10),
      pw.Container(height: 6, color: _rojo),
      pw.Container(height: 2, color: _ink),
      pw.SizedBox(height: 16),

      // Datos del pedido
      pw.Text('Pedido ${o.id}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _ink)),
      pw.Text(formatLongDate(o.createdAt), style: const pw.TextStyle(fontSize: 11, color: _muted)),
      pw.SizedBox(height: 8),
      if (o.store.isNotEmpty) totalLine(o.deliveryType == 'Domicilio' ? 'Preparado en' : 'Tienda', shortStore(o.store)),
      if (o.address != null) totalLine('Dirección', o.address!),
      if (o.paymentMethod.isNotEmpty) totalLine('Pago', o.paymentMethod),
      pw.SizedBox(height: 14),

      // Líneas
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1))),
        child: pw.Text('Detalle', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink)),
      ),
      for (final i in o.items)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line))),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(width: 24, child: pw.Text('${i.quantity} x', style: const pw.TextStyle(fontSize: 11, color: _muted))),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(i.name, style: const pw.TextStyle(fontSize: 11, color: _ink)),
                if (itemDetail(i).isNotEmpty) pw.Text(itemDetail(i), style: const pw.TextStyle(fontSize: 9, color: _muted)),
              ]),
            ),
            pw.Text(formatCOP(i.quantity * i.unitPrice), style: const pw.TextStyle(fontSize: 11, color: _ink)),
          ]),
        ),
      pw.SizedBox(height: 8),
      totalLine('Subtotal', formatCOP(o.subtotal)),
      if (o.discount > 0) totalLine('Descuento', '-${formatCOP(o.discount)}', color: _success),
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 4),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _ink, width: 2))),
        child: totalLine('Total', formatCOP(o.total), strong: true),
      ),
      if (o.earnedPoints > 0) ...[
        pw.SizedBox(height: 10),
        pw.Text('Sumaste ${o.earnedPoints} puntos en tu álbum de aves.', style: const pw.TextStyle(fontSize: 11, color: _ink)),
      ],
      pw.Spacer(),
      pw.Text('Gracias por tu compra. Este recibo no es una factura electrónica.', style: const pw.TextStyle(fontSize: 8, color: _muted)),
    ]),
  ));
  return doc.save();
}

/// Abre el PDF en la vista del sistema (guardar, imprimir o compartir).
Future<void> openReceiptPdf(PastOrder o) async {
  final bytes = await buildReceiptPdf(o);
  await Printing.layoutPdf(name: receiptFileName(o), onLayout: (_) async => bytes);
}

/// Comparte el resumen del recibo con la hoja nativa.
Future<void> shareReceipt(PastOrder o, {Rect? origin}) async {
  await SharePlus.instance.share(ShareParams(
    text: receiptText(o),
    subject: 'Recibo Café Quindío · Pedido ${o.id}',
    sharePositionOrigin: origin,
  ));
}
