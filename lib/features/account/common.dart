import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../data/history.dart';
import '../../state/reorder.dart';
import '../../widgets/controls.dart';

/// Tonos de la insignia (components/ui/Badge.tsx).
enum BadgeTone { brand, accent, success, danger, neutral, warning }

/// Insignia de estado: rectángulo pequeño con texto semibold.
class CQBadge extends StatelessWidget {
  const CQBadge(this.label, {super.key, this.tone = BadgeTone.neutral});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.brand => (CQColors.tealSoft, CQColors.ink),
      BadgeTone.accent => (CQColors.mostaza, CQColors.ink),
      BadgeTone.success => (CQColors.successSoft, CQColors.success),
      BadgeTone.danger => (CQColors.dangerSoft, CQColors.danger),
      BadgeTone.neutral => (CQColors.creamDeep, CQColors.ink),
      BadgeTone.warning => (CQColors.mostazaSoft, CQColors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: CQType.body(13, color: fg, weight: FontWeight.w600)),
    );
  }
}

/// Estado vacío: una ilustración de marca o un ícono de línea, sin círculo.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.image, this.icon, this.description, this.action});

  final String title;

  /// Ilustración corporativa (tiene prioridad sobre [icon]).
  final String? image;
  final IconData? icon;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (image != null)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: ExcludeSemantics(child: Image.asset(image!, height: 120)))
        else if (icon != null)
          Icon(icon, size: 36, color: CQColors.muted),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: CQType.title(22, height: 1.1)),
        if (description != null) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(description!, textAlign: TextAlign.center, style: CQType.body(15, color: CQColors.muted, height: 1.6)),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

/// Botón con borde tinta (secundario compacto de 44 px, como en la web).
class OutlineAction extends StatelessWidget {
  const OutlineAction({super.key, required this.label, required this.icon, this.onTap, this.busy = false, this.height = 44, this.expand = false});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: busy,
      child: AnimatedOpacity(
        opacity: busy ? 0.6 : 1,
        duration: const Duration(milliseconds: 150),
        child: Pressable(
          onTap: busy ? null : onTap,
          child: Container(
            height: height,
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: CQColors.ink, width: 1.5),
            ),
            child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 17, color: CQColors.ink),
              const SizedBox(width: 8),
              Text(label, style: CQType.body(height > 48 ? 16 : 15, weight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Barra fija inferior blanca con borde superior (acciones de pantalla).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: CQColors.white, border: Border(top: BorderSide(color: CQColors.line))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 14),
      child: child,
    );
  }
}

/// "Café Quindío · Centro" → "Tienda Centro".
String shortStore(String name) => 'Tienda ${name.replaceFirst(RegExp(r'^Café Quindío\s*[·-]\s*', caseSensitive: false), '')}';

/// Métodos de pago como los guarda el backend → como los lee el cliente.
const paymentLabels = {
  'wompi': 'Tarjeta (Wompi)',
  'efectivo': 'Efectivo en tienda',
  'kiosco': 'Pago en kiosco',
};

const _monthsShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _monthsLong = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "10 sep 2026, 2:15 p. m."
String formatShortDate(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]} ${d.year}, ${formatClock(d)}';

/// "10 de septiembre de 2026, 2:15 p. m."
String formatLongDate(DateTime d) => '${d.day} de ${_monthsLong[d.month - 1]} de ${d.year}, ${formatClock(d)}';

/// Etiqueta y tono de cada estado del historial.
(String, BadgeTone) statusBadgeFor(PastOrderStatus s) => switch (s) {
      PastOrderStatus.pendiente => ('Recibido', BadgeTone.warning),
      PastOrderStatus.preparando => ('Preparando', BadgeTone.accent),
      PastOrderStatus.listo => ('Listo', BadgeTone.brand),
      PastOrderStatus.completada => ('Entregado', BadgeTone.neutral),
      PastOrderStatus.cancelada => ('Cancelado', BadgeTone.danger),
    };

List<ReorderLine> reorderLinesOf(PastOrder o) =>
    [for (final i in o.items) ReorderLine(codProd: i.codProd, name: i.name, quantity: i.quantity, size: i.size)];

/// "Repetir pedido": agrega al carrito, avisa y lleva al checkout.
Future<void> repeatOrder(BuildContext context, WidgetRef ref, List<ReorderLine> lines) async {
  if (lines.isEmpty) return;
  try {
    final r = await reorder(ref, lines);
    if (!context.mounted) return;
    if (r.added.isEmpty) {
      showToast(context, 'Ninguno de esos productos está disponible hoy.', detail: 'Elige algo parecido en el menú.', error: true);
      return;
    }
    HapticFeedback.lightImpact();
    showToast(context, r.title, detail: r.detail);
    context.push('/checkout');
  } catch (_) {
    if (!context.mounted) return;
    showToast(context, 'No pudimos cargar el menú.', detail: 'Revisa tu conexión e inténtalo de nuevo.', error: true);
  }
}

/// Fila etiqueta–valor con separador (detalle y recibo).
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.child, this.minHeight = 48, this.center = true});

  final String label;
  final Widget child;
  final double minHeight;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.symmetric(vertical: center ? 0 : 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
      child: Row(crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
        Text(label, style: CQType.body(15, color: CQColors.muted)),
        const SizedBox(width: 16),
        Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
      ]),
    );
  }
}

/// Fila de acción sin separador (última de una lista: cerrar sesión, eliminar cuenta).
class PlainRow extends StatelessWidget {
  const PlainRow({super.key, required this.icon, required this.label, this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? CQColors.danger : CQColors.ink;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: CQType.body(16, color: color))),
        ]),
      ),
    );
  }
}
