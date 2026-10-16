import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../data/models.dart';
import '../../state/cart.dart';
import '../../state/customization.dart';
import '../../widgets/controls.dart';
import 'shop_widgets.dart';

/// Abre el detalle de producto a pantalla completa, subiendo desde abajo
/// (por encima de la barra de pestañas). Con [heroTag] la foto viaja desde
/// la fila de la lista hasta el arco. Se cierra con "Volver", el gesto de
/// atrás o arrastrando hacia abajo desde el tope.
Future<void> showProductDetail(BuildContext context, Product product, {Object? heroTag}) {
  final reduced = CQMotion.reduced(context);
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: CQColors.ink.withValues(alpha: 0.4),
    barrierLabel: product.name,
    transitionDuration: CQMotion.medium,
    reverseTransitionDuration: CQMotion.medium,
    pageBuilder: (context, _, _) => ProductDetailScreen(product: product, heroTag: reduced ? null : heroTag),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: CQMotion.drawer);
      // Reducir movimiento: solo fundido.
      if (reduced) return FadeTransition(opacity: curved, child: child);
      return SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved), child: child);
    },
  ));
}

/// Detalle de producto: armar el pedido. El arco de ventana colonial
/// enmarca la foto; es la única pantalla, junto con el carrito, que lo usa.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.product, this.heroTag});

  final Product product;
  final Object? heroTag;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> with SingleTickerProviderStateMixin {
  // MOCK: personalización de bebida (el backend no expone variantes/toppings aún).
  int _quantity = 1;
  String _variant = 'Frío';
  String _size = 'Mediano';
  String _sugar = 'Normal';
  String _ice = 'Normal';
  final List<String> _toppings = [];
  final _notes = TextEditingController();

  // Arrastre para cerrar: desplazamiento de la hoja y regreso suave si no se cierra.
  final _scroll = ScrollController();
  double _drag = 0;
  VelocityTracker? _tracker;
  double _slop = 0;
  bool _closing = false;
  late final AnimationController _settle = AnimationController(vsync: this, duration: CQMotion.fast)
    ..addListener(() => setState(() => _drag = _settleFrom * (1 - CQMotion.easeOut.transform(_settle.value))));
  double _settleFrom = 0;

  @override
  void dispose() {
    _notes.dispose();
    _scroll.dispose();
    _settle.dispose();
    super.dispose();
  }

  Product get _product => widget.product;

  int get _total => (discountedPrice(_product.price, _product.discount) + toppingsPrice(_toppings)) * _quantity;

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _add() {
    HapticFeedback.lightImpact();
    ref.read(cartProvider.notifier).add(CartItem(
          product: _product,
          quantity: _quantity,
          size: _size,
          variant: _variant,
          sugar: _sugar,
          ice: _ice,
          toppings: [..._toppings],
          notes: _notes.text,
        ));
    _close();
  }

  void _onPointerDown(PointerDownEvent e) {
    _settle.stop();
    _slop = 0;
    _tracker = VelocityTracker.withKind(e.kind);
  }

  void _onPointerMove(PointerMoveEvent e) {
    _tracker?.addPosition(e.timeStamp, e.position);
    final atTop = !_scroll.hasClients || _scroll.position.pixels <= 0;
    final dy = e.delta.dy;
    // Umbral de toque: un tap no mueve la hoja.
    if (_drag == 0 && dy > 0 && atTop && _slop < kTouchSlop) {
      _slop += dy;
      return;
    }
    if (dy > 0 && (atTop || _drag > 0)) {
      setState(() => _drag += dy);
    } else if (dy < 0 && _drag > 0) {
      setState(() => _drag = math.max(0, _drag + dy));
    }
  }

  void _onPointerUp(PointerEvent e) {
    final v = _tracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    _tracker = null;
    if (_drag <= 0) return;
    if (_drag > 140 || v > 800) {
      _close();
    } else {
      _settleFrom = _drag;
      _settle.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = math.max(MediaQuery.paddingOf(context).top, 12.0);
    return Transform.translate(
      offset: Offset(0, _drag),
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: Scaffold(
          backgroundColor: CQColors.white,
          body: Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            namesRoute: true,
            label: _product.name,
            child: Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  // Sin rebote: el tirón hacia abajo desde el tope es para cerrar.
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _ArchHeader(product: _product, top: top, heroTag: widget.heroTag, onBack: _close),
                    Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: _options()),
                  ]),
                ),
              ),
              _ActionBar(
                quantity: _quantity,
                total: _total,
                onQuantity: (q) => setState(() => _quantity = q),
                onAdd: _add,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _options() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(_product.name, style: CQType.title(30, height: 1))),
        if (_product.hasDiscount) ...[
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(top: 4), child: DiscountTag(_product.discount!, size: 13)),
        ],
      ]),
      const SizedBox(height: 8),
      Text(_product.description, style: CQType.body(16, color: CQColors.muted, height: 1.6)),
      _Group(
        title: 'Tamaño',
        child: Row(children: [
          for (final (i, (name, detail)) in sizes.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _SizeOption(name: name, detail: detail, selected: _size == name, onTap: () => setState(() => _size = name))),
          ],
        ]),
      ),
      _Group(
        title: 'Temperatura',
        child: _Chips(options: const ['Frío', 'Caliente'], value: _variant, onChanged: (v) => setState(() => _variant = v)),
      ),
      _Group(
        title: 'Azúcar',
        child: _Chips(options: const ['Normal', 'Poca', 'Sin azúcar'], value: _sugar, onChanged: (v) => setState(() => _sugar = v)),
      ),
      _Group(
        title: 'Hielo',
        child: _Chips(options: const ['Normal', 'Poco', 'Sin hielo'], value: _ice, onChanged: (v) => setState(() => _ice = v)),
      ),
      _Group(
        title: 'Adiciones',
        child: Column(children: [
          for (final t in toppings)
            _ToppingRow(
              topping: t,
              selected: _toppings.contains(t.id),
              onTap: () => setState(() => _toppings.contains(t.id) ? _toppings.remove(t.id) : _toppings.add(t.id)),
            ),
        ]),
      ),
      _Group(
        title: 'Notas para la barra',
        child: TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: CQType.body(16),
          scrollPadding: const EdgeInsets.only(bottom: 120),
          decoration: InputDecoration(
            hintText: 'Opcional',
            hintStyle: CQType.body(16, color: CQColors.mutedSoft),
            filled: true,
            fillColor: CQColors.creamDeep,
            isDense: true,
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: CQColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: CQColors.ink)),
          ),
        ),
      ),
    ]);
  }
}

/// Foto del producto dentro del arco, con la rama de café al pie.
class _ArchHeader extends StatelessWidget {
  const _ArchHeader({required this.product, required this.top, required this.heroTag, required this.onBack});

  final Product product;
  final double top;
  final Object? heroTag;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final hasImage = (product.imageUrl ?? '').isNotEmpty;
    Widget photo = hasImage
        ? ProductImage(product.imageUrl, height: 210)
        : Padding(
            padding: const EdgeInsets.only(bottom: 64),
            child: Text('Sin imagen', style: CQType.body(14, color: CQColors.muted)),
          );
    if (hasImage && heroTag != null) photo = Hero(tag: heroTag!, child: photo);

    return SizedBox(
      height: 328 + top,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 32,
          right: 32,
          top: top + 44,
          bottom: 0,
          child: ExcludeSemantics(
            child: Arch(
              tone: archToneFor(product.codProd),
              child: Padding(padding: const EdgeInsets.only(bottom: 8), child: photo),
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: -6,
          child: Image.asset('assets/brand/cafe-rama.webp', width: 110, excludeFromSemantics: true),
        ),
        Positioned(
          left: 12,
          top: top,
          child: Pressable(
            onTap: onBack,
            semanticLabel: 'Volver',
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: CQColors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x1F18303C), blurRadius: 12, offset: Offset(0, 2))],
              ),
              child: const Icon(LucideIcons.chevronLeft, size: 24, color: CQColors.ink),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(title, style: CQType.body(15, weight: FontWeight.w600))),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({required this.name, required this.detail, required this.selected, required this.onTap});
  final String name;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        onTap: onTap,
        semanticLabel: '$name, $detail',
        child: AnimatedContainer(
          duration: CQMotion.fast,
          curve: CQMotion.easeOut,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? CQColors.ink : CQColors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? CQColors.ink : CQColors.line, width: 1.5),
          ),
          child: ExcludeSemantics(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(name, style: CQType.body(15, color: selected ? CQColors.white : CQColors.ink, weight: FontWeight.w600, height: 1.15)),
              Text(detail, style: CQType.body(12, color: selected ? const Color(0xFFBFD0D6) : CQColors.muted, height: 1.15)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final o in options)
        Semantics(
          selected: value == o,
          inMutuallyExclusiveGroup: true,
          child: Pressable(
            onTap: () => onChanged(o),
            child: AnimatedContainer(
              duration: CQMotion.fast,
              curve: CQMotion.easeOut,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: value == o ? CQColors.ink : CQColors.line, width: 1.5),
              ),
              child: Text(o, style: CQType.body(15, weight: value == o ? FontWeight.w700 : FontWeight.w400)),
            ),
          ),
        ),
    ]);
  }
}

class _ToppingRow extends StatelessWidget {
  const _ToppingRow({required this.topping, required this.selected, required this.onTap});
  final Topping topping;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      label: '${topping.name}, más ${formatCOP(topping.price)}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.99,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
          child: Row(children: [
            Expanded(child: Text(topping.name, style: CQType.body(16))),
            Text('+${formatCOP(topping.price)}', style: CQType.number(15, color: CQColors.muted).copyWith(fontWeight: FontWeight.w400)),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: CQMotion.fast,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? CQColors.ink : CQColors.white,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: selected ? CQColors.ink : CQColors.mutedSoft, width: 1.5),
              ),
              child: selected ? const Icon(LucideIcons.check, size: 15, color: CQColors.white) : null,
            ),
          ]),
        ),
      ),
    );
  }
}

/// Barra de acción fija: cantidad y "Agregar" con el total.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.quantity, required this.total, required this.onQuantity, required this.onAdd});
  final int quantity;
  final int total;
  final ValueChanged<int> onQuantity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 14),
      decoration: const BoxDecoration(color: CQColors.white, border: Border(top: BorderSide(color: CQColors.line))),
      child: Row(children: [
        Container(
          height: 54,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: CQColors.line, width: 1.5)),
          child: Row(children: [
            _StepButton(icon: LucideIcons.minus, label: 'Quitar uno', onTap: quantity > 1 ? () => onQuantity(quantity - 1) : null),
            SizedBox(
              width: 24,
              child: Semantics(
                liveRegion: true,
                label: 'Cantidad $quantity',
                excludeSemantics: true,
                child: Text('$quantity', textAlign: TextAlign.center, style: CQType.number(16).copyWith(fontWeight: FontWeight.w400)),
              ),
            ),
            _StepButton(icon: LucideIcons.plus, label: 'Agregar uno', onTap: () => onQuantity(quantity + 1)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: CQButton(label: 'Agregar', trailing: formatCOP(total), onPressed: onAdd)),
      ]),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        // Como en la web, "Quitar uno" en 1 no hace nada (no se desactiva visualmente).
        onTap: onTap ?? () {},
        semanticLabel: label,
        child: SizedBox(width: 44, height: 54, child: Icon(icon, size: 18, color: CQColors.ink)),
      );
}
