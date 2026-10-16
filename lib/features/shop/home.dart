import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../state/cart.dart';
import '../../state/loyalty.dart';
import '../../state/providers.dart';
import '../../state/reorder.dart';
import '../../widgets/controls.dart';
import '../../widgets/stamp.dart';
import '../../widgets/zocalo.dart';
import 'product_detail.dart';
import 'shop_widgets.dart';

/// Cada categoría es una puerta pintada; el orden de tonos se repite.
const _doorStyles = [
  (DoorTone.teal, 'assets/brand/cafe-rama.webp'),
  (DoorTone.rosa, 'assets/brand/heliconia.webp'),
  (DoorTone.verde, 'assets/brand/palma.webp'),
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

  Future<void> _repeat(List<Product> lastOrder) async {
    if (_reordering || lastOrder.isEmpty) return;
    setState(() => _reordering = true);
    try {
      final result = await reorder(ref, [
        for (final p in lastOrder) ReorderLine(codProd: p.codProd, name: p.name, quantity: 1),
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

    final products = productsAsync.value ?? const <Product>[];
    final categories = categoriesAsync.value ?? const <ProductCategory>[];
    final loading = (productsAsync.isLoading && !productsAsync.hasValue) || (categoriesAsync.isLoading && !categoriesAsync.hasValue);
    final error = productsAsync.hasError || categoriesAsync.hasError;

    final lastOrder = [
      for (final id in mockLastOrderProductIds) ?products.where((p) => p.codProd == id).firstOrNull,
    ];
    final lastOrderTotal = lastOrder.fold(0, (sum, p) => sum + discountedPrice(p.price, p.discount));
    final part = _now.hour < 12 ? 'mañana' : (_now.hour < 18 ? 'tarde' : 'noche');

    return Scaffold(
      backgroundColor: CQColors.white,
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 112),
          children: [
            _TopBar(store: store),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${greetingFor(_now)},\n'),
                    TextSpan(text: '$mockUserFirstName.', style: const TextStyle(color: CQColors.muted)),
                  ]),
                  style: CQType.title(34, height: 0.98),
                ),
              ),
            ),

            // ── Lo de siempre: la puerta mostaza ──
            if (lastOrder.isNotEmpty) ...[
              const SizedBox(height: 20),
              _UsualOrder(products: lastOrder, total: lastOrderTotal, busy: _reordering, onOrder: () => _repeat(lastOrder)),
              const Zocalo(),
            ],

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
            if (loyalty.nextBird != null) _LoyaltyCard(summary: loyalty),

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
    final (tone, image) = _doorStyles[i % _doorStyles.length];
    return Door(
      title: cat.name,
      subtitle: cat.description ?? _doorSubtitles[cat.name.toLowerCase()],
      tone: tone,
      image: image,
      onTap: () => context.go('/menu', extra: cat.name),
    );
  }
}

/// Barra superior: marca, tienda y cuenta.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.store});
  final Store? store;

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
        Pressable(
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(s?.shortName ?? 'Tienda',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: CQType.body(15, weight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                const Icon(LucideIcons.chevronDown, size: 15, color: CQColors.ink),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Pressable(
          onTap: () => context.push('/profile'),
          semanticLabel: 'Mi cuenta',
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: CQColors.mostaza, shape: BoxShape.circle),
            child: ExcludeSemantics(
              child: Text(mockUserFirstName.characters.first, style: CQType.body(16, weight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// "¿Lo de siempre?": el último pedido, listo para repetir.
class _UsualOrder extends StatelessWidget {
  const _UsualOrder({required this.products, required this.total, required this.busy, required this.onOrder});

  final List<Product> products;
  final int total;
  final bool busy;
  final VoidCallback onOrder;

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
              Semantics(header: true, child: Text('¿Lo de siempre?', style: CQType.title(25, height: 1))),
              const SizedBox(height: 6),
              Text(
                '${products.map((p) => p.name).join(' y ')}, listos en $mockReadyMinutes minutos.',
                style: CQType.body(15, height: 1.35),
              ),
              const SizedBox(height: 14),
              Opacity(
                opacity: busy ? 0.6 : 1,
                child: Pressable(
                  onTap: busy ? null : onOrder,
                  semanticLabel: 'Pedir por ${formatCOP(total)}',
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
            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              // La segunda bebida se monta 20 px sobre la primera.
              for (final (i, p) in products.take(2).indexed)
                Transform.translate(
                  offset: Offset(products.length > 1 ? (i == 0 ? 10 : -10) : 0, 0),
                  child: ProductImage(p.imageUrl, width: 60),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Tarjeta de lealtad: puntos y la próxima ave por ganar.
class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({required this.summary});
  final LoyaltySummary summary;

  @override
  Widget build(BuildContext context) {
    final bird = summary.nextBird!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Pressable(
        onTap: () => context.go('/album'),
        semanticLabel: 'Te faltan ${summary.pointsToReward} puntos para el ${bird.name} y tu bebida gratis. '
            'Tienes ${summary.points} puntos',
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: CQColors.ink, width: 1.5)),
          child: ExcludeSemantics(
            child: Row(children: [
              SizedBox(width: 60, height: 72, child: Stamp(bird: bird, state: StampState.next, height: 72)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Te faltan '),
                      TextSpan(text: '${summary.pointsToReward}', style: CQType.number(16).copyWith(fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' puntos'),
                    ]),
                    style: CQType.body(16, weight: FontWeight.w700),
                  ),
                  Text('Para el ${bird.name} y tu bebida gratis', style: CQType.body(14, color: CQColors.muted, height: 1.35)),
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
          ),
        ),
      ),
    );
  }
}
