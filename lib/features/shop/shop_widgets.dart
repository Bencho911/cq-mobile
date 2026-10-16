import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../data/models.dart';
import '../../widgets/controls.dart';

// Piezas compartidas de la tienda (Inicio, Menú, Tiendas, Notificaciones).

/// Bloque gris de carga con un brillo que recorre (equivale a `skeleton-shimmer`).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8, this.circle = false});

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "reducir movimiento" queda quieto.
    if (CQMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shape = widget.circle ? BoxShape.circle : BoxShape.rectangle;
    final radius = widget.circle ? null : BorderRadius.circular(widget.radius);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // background-position de -200 % a 200 %: la franja clara cruza de izquierda a derecha.
          final t = _c.value * 4 - 2;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: shape,
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment(-1 - t, 0),
                end: Alignment(1 - t, 0),
                colors: const [CQColors.creamDeep, CQColors.creamMid, CQColors.creamDeep],
                stops: const [0.25, 0.5, 0.75],
                tileMode: TileMode.mirror,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Fila de carga con la forma de [ProductRow].
class ProductRowSkeleton extends StatelessWidget {
  const ProductRowSkeleton({super.key, this.withPrice = false});
  final bool withPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
      child: Row(children: [
        const Skeleton(width: 64, height: 64, circle: true),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: c.maxWidth * 2 / 3, height: 16),
              const SizedBox(height: 8),
              const Skeleton(width: double.infinity, height: 12),
              if (withPrice) ...[
                const SizedBox(height: 8),
                Skeleton(width: c.maxWidth / 3, height: 16),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Estado vacío: una ilustración de marca o un ícono de línea, sin círculo.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.icon, this.image, this.description, this.action});

  final String title;
  final IconData? icon;

  /// Ilustración corporativa (tiene prioridad sobre [icon]).
  final String? image;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (image != null)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Image.asset(image!, height: 120, excludeFromSemantics: true))
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

/// Error con dirección: qué pasó y cómo seguir.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'No pudimos cargar esto',
    this.description = 'Revisa tu conexión e inténtalo de nuevo.',
    this.onRetry,
  });

  final String title;
  final String description;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/brand/ave-mirla.webp', height: 110, excludeFromSemantics: true),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: CQType.title(22, height: 1.1)),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: Text(description, textAlign: TextAlign.center, style: CQType.body(15, color: CQColors.muted, height: 1.6)),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          CQButton(
            label: 'Reintentar',
            icon: LucideIcons.rotateCcw,
            variant: CQButtonVariant.secondary,
            height: 44,
            expand: false,
            onPressed: onRetry,
          ),
        ],
      ]),
    );
  }
}

enum BadgeTone { brand, accent, success, danger, neutral, warning }

/// Etiqueta corta de estado (Abierta, Cerrada, -10 %).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral});
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: CQType.body(13, color: fg, weight: FontWeight.w600)),
    );
  }
}

/// Etiqueta de descuento en mostaza: "-10%".
class DiscountTag extends StatelessWidget {
  const DiscountTag(this.discount, {super.key, this.size = 12});
  final num discount;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: size > 12 ? 8 : 6, vertical: size > 12 ? 2 : 0),
        decoration: BoxDecoration(color: CQColors.mostaza, borderRadius: BorderRadius.circular(3)),
        child: Text('-${discount.round()}%', style: CQType.body(size, weight: FontWeight.w700)),
      );
}

/// Tag del Hero de la foto de producto. Inicio y Menú viven a la vez (pila
/// de pestañas), así que cada pantalla usa su propio ámbito.
Object productHeroTag(String scope, Product p) => ('product-image', scope, p.codProd);

/// Fila de producto plana (sin tarjeta ni sombra): foto redonda, nombre,
/// descripción y precio. El arco se reserva para el detalle y el carrito.
class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.product, required this.onTap, this.heroTag});

  final Product product;

  /// Tocar la fila o el "+" abre el detalle: tamaño y leche se eligen antes de agregar.
  final VoidCallback onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final finalPrice = discountedPrice(product.price, product.discount);
    final hasImage = (product.imageUrl ?? '').isNotEmpty;
    Widget photo = hasImage
        ? ProductImage(product.imageUrl, width: 52, height: 52)
        : Text('Sin imagen', textAlign: TextAlign.center, style: CQType.body(12, color: CQColors.muted));
    if (heroTag != null && hasImage) photo = Hero(tag: heroTag!, child: photo);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
      child: Row(children: [
        Expanded(
          child: Pressable(
            onTap: onTap,
            scale: 0.99,
            semanticLabel: product.name,
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: CQColors.creamMid, shape: BoxShape.circle),
                child: photo,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product.name, style: CQType.body(17, weight: FontWeight.w700, height: 1.2)),
                  const SizedBox(height: 2),
                  Text(product.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: CQType.body(14, color: CQColors.muted, height: 1.35)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(formatCOP(finalPrice), style: CQType.number(16)),
                    if (product.hasDiscount) ...[
                      Text(formatCOP(product.price),
                          style: CQType.number(13, color: CQColors.muted).copyWith(
                              fontWeight: FontWeight.w400, decoration: TextDecoration.lineThrough, decorationColor: CQColors.muted)),
                      DiscountTag(product.discount!),
                    ],
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Pressable(
          onTap: onTap,
          scale: 0.95,
          semanticLabel: 'Agregar ${product.name}',
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: CQColors.ink, width: 1.5)),
            child: const Icon(LucideIcons.plus, size: 18, color: CQColors.ink),
          ),
        ),
      ]),
    );
  }
}

/// Botón flotante "Ver pedido (n)  $ total". Sube y aparece con fundido
/// cuando hay productos; el número salta al sumar.
class ViewOrderButton extends StatefulWidget {
  const ViewOrderButton({super.key, required this.count, required this.subtotal, required this.onTap});

  final int count;
  final int subtotal;
  final VoidCallback onTap;

  @override
  State<ViewOrderButton> createState() => _ViewOrderButtonState();
}

class _ViewOrderButtonState extends State<ViewOrderButton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: CQMotion.fast, value: widget.count > 0 ? 1 : 0);
  late final _curve = CurvedAnimation(parent: _c, curve: CQMotion.easeOut);

  // Últimos valores con productos: se muestran mientras el botón sale.
  late int _count = widget.count;
  late int _subtotal = widget.subtotal;

  @override
  void didUpdateWidget(ViewOrderButton old) {
    super.didUpdateWidget(old);
    if (widget.count > 0) {
      _count = widget.count;
      _subtotal = widget.subtotal;
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = CQMotion.reduced(context);
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        if (_c.isDismissed) return const SizedBox.shrink();
        final t = _curve.value;
        return IgnorePointer(
          ignoring: widget.count == 0,
          child: Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, reduced ? 0 : 24 * (1 - t)), child: child),
          ),
        );
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Pressable(
            onTap: widget.onTap,
            semanticLabel: 'Ver pedido, $_count productos, ${formatCOP(_subtotal)}',
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: CQColors.mostaza,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [BoxShadow(color: Color(0x2E18303C), blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: ExcludeSemantics(
                child: Row(children: [
                  const Icon(LucideIcons.shoppingBag, size: 20, color: CQColors.ink),
                  const SizedBox(width: 10),
                  Text('Ver pedido (', style: CQType.body(16, weight: FontWeight.w700)),
                  Bump(value: _count, child: Text('$_count', style: CQType.number(16).copyWith(fontWeight: FontWeight.w700))),
                  Text(')', style: CQType.body(16, weight: FontWeight.w700)),
                  const Spacer(),
                  Text(formatCOP(_subtotal), style: CQType.number(16)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
