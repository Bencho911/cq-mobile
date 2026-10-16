import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../data/models.dart';
import '../../state/cart.dart';
import '../../state/providers.dart';
import '../../widgets/controls.dart';
import 'product_detail.dart';
import 'shop_widgets.dart';

const _all = 'Todos';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key, this.category});

  /// Categoría preseleccionada (desde las puertas del inicio).
  final String? category;

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  // Las puertas de Inicio abren el menú ya filtrado por su categoría.
  late String _category = widget.category ?? _all;
  final _search = TextEditingController();
  String _query = '';

  @override
  void didUpdateWidget(MenuScreen old) {
    super.didUpdateWidget(old);
    // La pestaña sigue viva: una puerta nueva cambia el filtro; volver por la barra (sin categoría) lo conserva.
    final next = widget.category;
    if (next != null && next != old.category) setState(() => _category = next);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _retry() {
    ref.invalidate(productsProvider);
    ref.invalidate(categoriesProvider);
  }

  List<Product> _filter(List<Product> products, List<ProductCategory> categories) {
    var list = products;
    if (_category != _all) {
      final cat = categories.where((c) => c.name == _category).firstOrNull;
      if (cat != null) list = list.where((p) => p.categoryIds.contains(cat.codCat)).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cart = ref.watch(cartProvider);

    final products = productsAsync.value ?? const <Product>[];
    final categories = categoriesAsync.value ?? const <ProductCategory>[];
    final loading = (productsAsync.isLoading && !productsAsync.hasValue) || (categoriesAsync.isLoading && !categoriesAsync.hasValue);
    final error = productsAsync.hasError || categoriesAsync.hasError;
    final shown = _filter(products, categories);

    final Widget body;
    if (loading) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
        children: [for (var i = 0; i < 4; i++) const ProductRowSkeleton(withPrice: true)],
      );
    } else if (error) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
        children: [ErrorState(onRetry: _retry)],
      );
    } else if (shown.isEmpty) {
      body = ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
        children: const [
          EmptyState(icon: LucideIcons.search, title: 'Sin resultados', description: 'Prueba con otra categoría o búsqueda.'),
        ],
      );
    } else {
      body = ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
        itemCount: shown.length,
        itemBuilder: (context, i) {
          final p = shown[i];
          final tag = productHeroTag('menu', p);
          return ProductRow(
            product: p,
            heroTag: tag,
            onTap: () => showProductDetail(context, p, heroTag: tag),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: CQColors.white,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(
                count: cart.count,
                search: _search,
                onQuery: (q) => setState(() => _query = q),
                categories: [_all, ...categories.map((c) => c.name)],
                active: _category,
                onCategory: (c) => setState(() => _category = c),
              ),
              Expanded(child: body),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: ViewOrderButton(count: cart.count, subtotal: cart.subtotal, onTap: () => context.push('/checkout')),
          ),
        ],
      ),
    );
  }
}

/// Cabecera fija: título, carrito, búsqueda y pestañas de categoría.
class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.search,
    required this.onQuery,
    required this.categories,
    required this.active,
    required this.onCategory,
  });

  final int count;
  final TextEditingController search;
  final ValueChanged<String> onQuery;
  final List<String> categories;
  final String active;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: CQColors.line),
    );
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 12, bottom: 12),
      decoration: const BoxDecoration(
        color: CQColors.white,
        border: Border(bottom: BorderSide(color: CQColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(header: true, child: Text('Menú', style: CQType.title(28, height: 1.1))),
                    ),
                    Pressable(
                      onTap: () => context.push('/checkout'),
                      semanticLabel: count > 0 ? 'Ver carrito, $count productos' : 'Ver carrito',
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: const BoxDecoration(color: CQColors.creamDeep, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const Icon(LucideIcons.shoppingBag, size: 20, color: CQColors.ink),
                            ),
                            if (count > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: ExcludeSemantics(
                                  child: Bump(
                                    value: count,
                                    child: Container(
                                      height: 20,
                                      constraints: const BoxConstraints(minWidth: 20),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(color: CQColors.mostaza, borderRadius: BorderRadius.circular(10)),
                                      child: Text('$count', style: CQType.number(12, height: 1).copyWith(fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: TextField(
                    controller: search,
                    onChanged: onQuery,
                    textInputAction: TextInputAction.search,
                    style: CQType.body(16),
                    decoration: InputDecoration(
                      hintText: '¿Qué se te antoja hoy?',
                      hintStyle: CQType.body(16, color: CQColors.mutedSoft),
                      filled: true,
                      fillColor: CQColors.creamDeep,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      suffixIcon: const ExcludeSemantics(child: Icon(LucideIcons.search, size: 18, color: CQColors.mutedSoft)),
                      enabledBorder: border,
                      focusedBorder: border.copyWith(borderSide: const BorderSide(color: CQColors.ink)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Las pestañas corren hasta el borde de la pantalla.
          _CategoryTabs(categories: categories, active: active, onSelect: onCategory),
        ],
      ),
    );
  }
}

/// Pestañas de categoría en píldora. Se tocan a menudo: solo un cambio de
/// color corto, sin desplazamiento de la píldora.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.categories, required this.active, required this.onSelect});

  final List<String> categories;
  final String active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          for (final (i, c) in categories.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Semantics(
              selected: c == active,
              child: Pressable(
                onTap: () => onSelect(c),
                child: AnimatedContainer(
                  duration: CQMotion.fast,
                  curve: CQMotion.easeOut,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c == active ? CQColors.ink : CQColors.white.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    c,
                    style: CQType.body(14, color: c == active ? CQColors.white : CQColors.muted, weight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
