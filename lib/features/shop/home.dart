import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../data/history.dart';
import '../../data/models.dart';
import '../../state/account.dart';
import '../../state/cart.dart';
import '../../state/customization.dart';
import '../../state/loyalty.dart';
import '../../state/notifications.dart';
import '../../state/orders.dart';
import '../../state/providers.dart';
import '../../state/reorder.dart';
import '../../widgets/controls.dart';
import '../../widgets/stamp.dart';
import '../../widgets/zocalo.dart';
import 'product_detail.dart';
import 'shop_widgets.dart';

/// Cada categoría es una puerta pintada; el orden de tonos se repite.
const _doorStyles = [
  (DoorTone.teal, 'assets/brand/cafe-rama.webp', null),
  // La heliconia es rosada como la puerta: va en blanco para que se vea.
  (DoorTone.rosa, 'assets/brand/heliconia.webp', CQColors.white),
  (DoorTone.verde, 'assets/brand/palma.webp', null),
];

/// Descripción corta por categoría cuando el backend no envía `desc_cat`.
const _doorSubtitles = {
  'café': 'Tintos, lattes y fríos',
  'sin café': 'Chocolates y aromáticas',
  'pastelería': 'Para acompañar',
};

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // `now` se refresca cada minuto para que el saludo cambie si la sesión
  // queda abierta cruzando de mañana a tarde o noche.
  DateTime _now = DateTime.now();
  Timer? _clock;
  bool _reordering = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _retry() {
    ref.invalidate(productsProvider);
    ref.invalidate(categoriesProvider);
  }

  void _open(Product p) => showProductDetail(context, p, heroTag: productHeroTag('home', p));

  Future<void> _repeat(PastOrder order) async {
    if (_reordering || order.items.isEmpty) return;
    setState(() => _reordering = true);
    try {
      final result = await reorder(ref, [
        for (final i in order.items)
          ReorderLine(codProd: i.codProd, name: i.name, quantity: i.quantity, size: i.size, variant: i.variant, toppings: i.toppings),
      ]);
      if (!mounted) return;
      if (result.added.isEmpty) {
        showToast(context, 'Ninguno de esos productos está disponible hoy.', detail: 'Elige algo parecido en el menú.', error: true);
        return;
      }
      showToast(context, result.title, detail: result.detail);
      context.push('/checkout');
    } catch (_) {
      if (mounted) showToast(context, 'No pudimos cargar el menú.', detail: 'Revisa tu conexión e inténtalo de nuevo.', error: true);
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cart = ref.watch(cartProvider);
    final store = ref.watch(selectedStoreProvider);
    final loyalty = summarize(ref.watch(loyaltyAccountProvider));
    final freeDrinks = ref.watch(loyaltyProvider.select((b) => b.freeDrinks));
    final account = ref.watch(authProvider.select((a) => a.account));
    final lastOrder = ref.watch(lastOrderProvider);
    final active = ref.watch(activeOrdersProvider).firstOrNull;
    final unread = ref.watch(unreadNotificationsProvider);

    final products = productsAsync.value ?? const <Product>[];
    final categories = categoriesAsync.value ?? const <ProductCategory>[];
    final loading = (productsAsync.isLoading && !productsAsync.hasValue) || (categoriesAsync.isLoading && !categoriesAsync.hasValue);
    final error = productsAsync.hasError || categoriesAsync.hasError;

    // Total del último pedido con los precios de hoy (si el producto ya no
    // está en el menú, con el precio que pagó).
    final lastOrderTotal = lastOrder?.items.fold(0, (sum, i) {
          final p = products.where((p) => p.codProd == i.codProd).firstOrNull;
          final unit = p != null ? discountedPrice(p.price, p.discount) + toppingsPrice(i.toppings) : i.unitPrice;
          return sum + unit * i.quantity;
        }) ??
        0;
    final part = _now.hour < 12 ? 'mañana' : (_now.hour < 18 ? 'tarde' : 'noche');

    return Scaffold(
      backgroundColor: CQColors.white,
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 112),
          children: [
            _TopBar(store: store, initial: account?.initial ?? '?', unread: unread),
            if (active != null) _ActiveOrderStrip(order: active),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(children: [
                    if (account != null && account.firstName.isNotEmpty) ...[
                      TextSpan(text: '${greetingFor(_now)},\n'),
                      TextSpan(text: '${account.firstName}.', style: const TextStyle(color: CQColors.muted)),
                    ] else
                      TextSpan(text: '${greetingFor(_now)}.'),
                  ]),
                  style: CQType.title(34, height: 0.98),
                ),
              ),
            ),

            // ── Lo de siempre: la puerta mostaza ──
            // Sin pedidos todavía: bienvenida que lleva al menú.
            const SizedBox(height: 20),
            if (lastOrder != null && lastOrder.items.isNotEmpty)
              _UsualOrder(order: lastOrder, total: lastOrderTotal, busy: _reordering, onOrder: () => _repeat(lastOrder))
            else
              const _FirstOrder(),
            const Zocalo(),

            // ── Categorías: puertas ──
            if (categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Semantics(
                  label: 'Categorías',
                  container: true,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: i < categories.length ? _door(categories[i], i) : const SizedBox.shrink()),
                    ],
                  ]),
                ),
              ),

            // ── Lealtad: puntos y próxima ave ──
            _LoyaltyCard(summary: loyalty, freeDrinks: freeDrinks),

            // ── Productos ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(header: true, child: Text('Para esta $part', style: CQType.title(22, height: 1.2))),
                const SizedBox(height: 4),
                if (loading)
                  for (var i = 0; i < 3; i++) const ProductRowSkeleton()
                else if (error)
                  ErrorState(onRetry: _retry)
                else if (products.isEmpty)
                  const EmptyState(
                    icon: LucideIcons.coffee,
                    title: 'El menú está vacío',
                    description: 'Vuelve en un momento: estamos actualizando los productos.',
                  )
                else
                  for (final p in products.take(4)) ProductRow(product: p, heroTag: productHeroTag('home', p), onTap: () => _open(p)),
                if (products.length > 4)
                  Pressable(
                    onTap: () => context.go('/menu'),
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.only(top: 8),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ver todo el menú',
                        style: CQType.body(16, weight: FontWeight.w600).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
              ]),
            ),
          ],
        ),

        // ── Carrito flotante ──
        Positioned(
          left: 20,
          right: 20,
          bottom: 16,
          child: ViewOrderButton(count: cart.count, subtotal: cart.subtotal, onTap: () => context.push('/checkout')),
        ),
      ]),
    );
  }

  Widget _door(ProductCategory cat, int i) {
    final (tone, image, tint) = _doorStyles[i % _doorStyles.length];
    return Door(
      title: cat.name,
      subtitle: cat.description ?? _doorSubtitles[cat.name.toLowerCase()],
      tone: tone,
      image: image,
      imageTint: tint,
      onTap: () => context.go('/menu', extra: cat.name),
    );
  }
}

/// Barra superior: marca, tienda, notificaciones y cuenta.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.store, required this.initial, required this.unread});
  final Store? store;
  final String initial;
  final int unread;

  // brightness(0.55) de la web: el logo teal se oscurece para leerse sobre blanco.
  static const _darken = ColorFilter.matrix([
    0.55, 0, 0, 0, 0, //
    0, 0.55, 0, 0, 0, //
    0, 0, 0.55, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 20, 0),
      child: Row(children: [
        Semantics(
          image: true,
          label: 'Café Quindío',
          child: ColorFiltered(colorFilter: _darken, child: Image.asset('assets/brand/logo-teal.webp', height: 24)),
        ),
        const Spacer(),
        Flexible(
          child: Pressable(
            onTap: () => context.push('/stores'),
            semanticLabel: s != null ? 'Recoges en ${s.shortName}. Cambiar tienda' : 'Elegir tienda',
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: CQColors.creamDeep, borderRadius: BorderRadius.circular(22)),
              child: ExcludeSemantics(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.mapPin, size: 17, color: CQColors.ink),
                  const SizedBox(width: 6),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(s?.shortName ?? 'Tienda',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: CQType.body(15, weight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.chevronDown, size: 15, color: CQColors.ink),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Campana: el punto mostaza avisa que hay notificaciones sin leer.
        Pressable(
          onTap: () => context.push('/notifications'),
          semanticLabel: unread > 0 ? 'Notificaciones, $unread sin leer' : 'Notificaciones',
          child: SizedBox(
            width: 44,
            height: 44,
            child: ExcludeSemantics(
              child: Stack(alignment: Alignment.center, children: [
                const Icon(LucideIcons.bell, size: 22, color: CQColors.ink),
                Positioned(
                  top: 9,
                  right: 10,
                  child: AnimatedScale(
                    scale: unread > 0 ? 1 : 0,
                    duration: CQMotion.reduced(context) ? Duration.zero : CQMotion.fast,
                    curve: CQMotion.easeOut,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: CQColors.mostaza,
                        shape: BoxShape.circle,
                        border: Border.all(color: CQColors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Pressable(
          onTap: () => context.push('/profile'),
          semanticLabel: 'Mi cuenta',
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: CQColors.mostaza, shape: BoxShape.circle),
            child: ExcludeSemantics(child: Text(initial, style: CQType.body(16, weight: FontWeight.w700))),
          ),
        ),
      ]),
    );
  }
}

/// Franja del pedido en curso: "Tu pedido #N: Preparando · Ver".
class _ActiveOrderStrip extends StatelessWidget {
  const _ActiveOrderStrip({required this.order});
  final PastOrder order;

  static String _label(PastOrderStatus s) => switch (s) {
        PastOrderStatus.pendiente => 'Recibido',
        PastOrderStatus.preparando => 'Preparando',
        PastOrderStatus.listo => 'Listo para recoger',
        PastOrderStatus.completada => 'Entregado',
        PastOrderStatus.cancelada => 'Cancelado',
      };

  @override
  Widget build(BuildContext context) {
    final ready = order.status == PastOrderStatus.listo;
    final status = _label(order.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Pressable(
        onTap: () => context.push('/track-order', extra: order.id),
        scale: 0.99,
        semanticLabel: 'Tu pedido número ${order.id}: $status. Ver seguimiento',
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: ready ? CQColors.verde : CQColors.ink, borderRadius: BorderRadius.circular(6)),
          child: ExcludeSemantics(
            child: Row(children: [
              Icon(ready ? LucideIcons.circleCheck : LucideIcons.coffee, size: 18, color: CQColors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Tu pedido '),
                    TextSpan(text: '#${order.id}', style: CQType.number(15, color: CQColors.white)),
                    TextSpan(text: ': $status', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CQType.body(15, color: CQColors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text('Ver', style: CQType.body(15, color: CQColors.white, weight: FontWeight.w600).copyWith(decoration: TextDecoration.underline, decorationColor: CQColors.white)),
              const Icon(LucideIcons.chevronRight, size: 16, color: CQColors.white),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "¿Lo de siempre?": el último pedido, listo para repetir.
class _UsualOrder extends StatelessWidget {
  const _UsualOrder({required this.order, required this.total, required this.busy, required this.onOrder});

  final PastOrder order;
  final int total;
  final bool busy;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final items = order.items;
    final names = items.map((i) => i.quantity > 1 ? '${i.quantity}× ${i.name}' : i.name).toList();
    final summary = names.length <= 2 ? names.join(' y ') : '${names.take(names.length - 1).join(', ')} y ${names.last}';
    final detail = items.length == 1 ? itemDetail(items.first) : '';
    final images = [for (final i in items) ?i.imageUrl].take(2).toList();
    return Container(
      color: CQColors.mostaza,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text('¿Lo de siempre?', style: CQType.title(25, height: 1))),
              const SizedBox(height: 6),
              Text('$summary${detail.isNotEmpty ? ' ($detail)' : ''}.', style: CQType.body(15, height: 1.35)),
              const SizedBox(height: 2),
              Text('Tu último pedido · ${order.date}', style: CQType.body(13, height: 1.35, color: CQColors.ink.withValues(alpha: 0.7))),
              const SizedBox(height: 14),
              Opacity(
                opacity: busy ? 0.6 : 1,
                child: Pressable(
                  onTap: busy ? null : onOrder,
                  semanticLabel: 'Pedir de nuevo por ${formatCOP(total)}',
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: CQColors.ink, borderRadius: BorderRadius.circular(6)),
                    child: ExcludeSemantics(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Pedir por ', style: CQType.body(16, color: CQColors.white, weight: FontWeight.w600)),
                        Text(formatCOP(total), style: CQType.number(16, color: CQColors.white)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        // Ventana blanca con las bebidas, apoyada en el zócalo.
        ExcludeSemantics(
          child: Container(
            width: 120,
            height: 124,
            padding: const EdgeInsets.only(bottom: 6),
            decoration: const BoxDecoration(color: CQColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(56))),
            alignment: Alignment.bottomCenter,
            child: images.isEmpty
                ? Image.asset('assets/brand/cafe-rama.webp', height: 90)
                : Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    // La segunda bebida se monta 20 px sobre la primera.
                    for (final (i, img) in images.indexed)
                      Transform.translate(
                        offset: Offset(images.length > 1 ? (i == 0 ? 10 : -10) : 0, 0),
                        child: ProductImage(img, width: 60),
                      ),
                  ]),
          ),
        ),
      ]),
    );
  }
}

/// Cliente nuevo: en lugar de "¿Lo de siempre?", una bienvenida al menú.
class _FirstOrder extends StatelessWidget {
  const _FirstOrder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CQColors.mostaza,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text('Tu primer pedido', style: CQType.title(25, height: 1))),
              const SizedBox(height: 6),
              Text('Elige tu bebida, personalízala y recógela sin hacer fila. Con cada compra sumas aves a tu álbum.',
                  style: CQType.body(15, height: 1.35)),
              const SizedBox(height: 14),
              Pressable(
                onTap: () => context.go('/menu'),
                semanticLabel: 'Ver el menú',
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: CQColors.ink, borderRadius: BorderRadius.circular(6)),
                  child: ExcludeSemantics(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Ver el menú', style: CQType.body(16, color: CQColors.white, weight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.arrowRight, size: 18, color: CQColors.white),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        ExcludeSemantics(
          child: Container(
            width: 120,
            height: 124,
            padding: const EdgeInsets.only(bottom: 6),
            decoration: const BoxDecoration(color: CQColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(56))),
            alignment: Alignment.bottomCenter,
            child: Image.asset('assets/brand/cafe-rama.webp', height: 92),
          ),
        ),
      ]),
    );
  }
}

/// Tarjeta de lealtad: puntos, la próxima ave por ganar y bebidas gratis.
class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({required this.summary, required this.freeDrinks});
  final LoyaltySummary summary;
  final int freeDrinks;

  @override
  Widget build(BuildContext context) {
    final bird = summary.nextBird ?? summary.slots.last.bird;
    final fresh = summary.points == 0;
    final full = summary.nextBird == null;
    final title = full
        ? 'Tarjeta completa'
        : fresh
            ? 'Empieza tu álbum'
            : null;
    final subtitle = full
        ? 'Tu bebida gratis te espera'
        : fresh
            ? 'Cada \$ 5.000 suman 1 punto. Con ${summary.pointsToReward} ganas tu bebida gratis'
            : 'Para el ${bird.name} y tu bebida gratis';
    final gift = freeDrinks > 0 ? (freeDrinks == 1 ? 'Tienes 1 bebida gratis' : 'Tienes $freeDrinks bebidas gratis') : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Pressable(
        onTap: () => context.go('/album'),
        semanticLabel: [
          ?gift,
          if (title != null) title else 'Te faltan ${summary.pointsToReward} puntos',
          subtitle,
          'Tienes ${summary.points} puntos',
        ].join('. '),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: CQColors.ink, width: 1.5)),
          child: ExcludeSemantics(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (gift != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: CQColors.mostaza, borderRadius: BorderRadius.circular(4)),
                  child: Row(children: [
                    const Icon(LucideIcons.gift, size: 18, color: CQColors.ink),
                    const SizedBox(width: 8),
                    Expanded(child: Text(gift, style: CQType.body(15, weight: FontWeight.w700))),
                  ]),
                ),
              Row(children: [
                SizedBox(
                  width: 60,
                  height: 72,
                  child: Stamp(bird: bird, state: full ? StampState.earned : StampState.next, height: 72),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (title != null)
                      Text(title, style: CQType.body(16, weight: FontWeight.w700))
                    else
                      Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Te faltan '),
                          TextSpan(text: '${summary.pointsToReward}', style: CQType.number(16).copyWith(fontWeight: FontWeight.w700)),
                          const TextSpan(text: ' puntos'),
                        ]),
                        style: CQType.body(16, weight: FontWeight.w700),
                      ),
                    Text(subtitle, style: CQType.body(14, color: CQColors.muted, height: 1.35)),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${summary.points}', style: CQType.title(24, height: 1)),
                  Text('pts', style: CQType.body(13, color: CQColors.muted)),
                ]),
                const SizedBox(width: 12),
                const Icon(LucideIcons.chevronRight, size: 18, color: CQColors.muted),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
