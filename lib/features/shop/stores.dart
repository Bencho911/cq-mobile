import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../data/models.dart';
import '../../state/cart.dart';
import '../../state/preferences.dart';
import '../../state/providers.dart';
import '../../widgets/controls.dart';
import 'shop_widgets.dart';

/// Elegir la tienda donde se prepara y se recoge el pedido.
class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  void _back(BuildContext context) => context.canPop() ? context.pop() : context.go('/home');

  static Future<void> _launch(BuildContext context, Uri uri, String error) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) showToast(context, error, error: true);
  }

  static Future<void> _call(BuildContext context, Store store) {
    final digits = (store.phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    return _launch(context, Uri(scheme: 'tel', path: digits), 'No pudimos abrir el marcador.');
  }

  /// Abre la app de mapas del teléfono con la dirección de la tienda.
  static Future<void> _directions(BuildContext context, Store store) {
    final query = '${store.name}, ${store.address}, Colombia';
    final uri = defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.https('maps.apple.com', '/', {'q': query})
        : Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query});
    return _launch(context, uri, 'No pudimos abrir los mapas.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(storesProvider);
    // Igual que selectedStoreProvider: sin elección explícita, se recoge en la primera abierta.
    final currentId = ref.watch(selectedStoreProvider)?.id;
    final favorites = ref.watch(preferencesProvider.select((p) => p.favoriteStores));

    final Widget content;
    if (storesAsync.isLoading && !storesAsync.hasValue) {
      content = Column(children: [
        for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(height: 10), const _StoreSkeleton()],
      ]);
    } else if (storesAsync.hasError) {
      content = ErrorState(onRetry: () => ref.invalidate(storesProvider));
    } else {
      // Favoritas arriba, conservando el orden del servidor.
      final all = storesAsync.value ?? const <Store>[];
      final stores = [...all.where((s) => favorites.contains(s.id)), ...all.where((s) => !favorites.contains(s.id))];
      content = stores.isEmpty
          ? const EmptyState(icon: LucideIcons.mapPin, title: 'Sin tiendas', description: 'No hay tiendas disponibles por ahora.')
          : Semantics(
              label: 'Tiendas',
              container: true,
              child: Column(children: [
                for (final (i, store) in stores.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _StoreCard(
                    store: store,
                    selected: store.id == currentId,
                    favorite: favorites.contains(store.id),
                    onFavorite: () => ref.read(preferencesProvider.notifier).toggleFavoriteStore(store.id),
                    onCall: () => _call(context, store),
                    onDirections: () => _directions(context, store),
                    onTap: () {
                      ref.read(cartProvider.notifier).setStore(store.id);
                      _back(context);
                    },
                  ),
                ],
              ]),
            );
    }

    return Scaffold(
      backgroundColor: CQColors.white,
      body: ListView(
        padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          PageHeader(title: 'Elige tu tienda', onBack: () => _back(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Aquí preparamos tu pedido y lo recoges.', style: CQType.body(15, color: CQColors.muted)),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: content),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
    required this.onCall,
    required this.onDirections,
  });

  final Store store;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final open = store.status.toUpperCase() == 'ABIERTO';
    final muted = CQType.body(15, color: CQColors.muted, height: 1.35);
    final hasPhone = (store.phone ?? '').isNotEmpty;
    final reduced = CQMotion.reduced(context);
    return AnimatedContainer(
      duration: CQMotion.press,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? CQColors.ink : CQColors.line, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          selected: selected,
          inMutuallyExclusiveGroup: true,
          button: true,
          child: Pressable(
            onTap: onTap,
            scale: 0.99,
            child: Container(
              color: CQColors.white.withValues(alpha: 0),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(store.shortName, style: CQType.title(22, height: 1.15)),
                      StatusBadge(open ? 'Abierta' : 'Cerrada', tone: open ? BadgeTone.brand : BadgeTone.danger),
                    ]),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.mapPin, size: 16, color: CQColors.muted)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(store.address, style: muted)),
                    ]),
                    if (hasPhone) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(LucideIcons.phone, size: 16, color: CQColors.muted),
                        const SizedBox(width: 8),
                        Text(store.phone!, style: CQType.number(15, color: CQColors.muted).copyWith(fontWeight: FontWeight.w400)),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? CQColors.ink : null,
                    border: selected ? null : Border.all(color: CQColors.line, width: 1.5),
                  ),
                  child: selected ? const Icon(LucideIcons.check, size: 15, color: CQColors.white) : null,
                ),
              ]),
            ),
          ),
        ),
        // Acciones: favorita, llamar y cómo llegar.
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: CQColors.line))),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            Semantics(
              button: true,
              toggled: favorite,
              label: favorite ? 'Quitar ${store.shortName} de favoritas' : 'Marcar ${store.shortName} como favorita',
              child: Pressable(
                onTap: onFavorite,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: ExcludeSemantics(
                    child: AnimatedSwitcher(
                      duration: reduced ? Duration.zero : CQMotion.fast,
                      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                      // Lucide no trae corazón relleno: el de Material ocupa su lugar.
                      child: Icon(
                        favorite ? Icons.favorite_rounded : LucideIcons.heart,
                        key: ValueKey(favorite),
                        size: favorite ? 22 : 20,
                        color: favorite ? CQColors.rosa : CQColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (hasPhone) _StoreAction(icon: LucideIcons.phone, label: 'Llamar', semantic: 'Llamar a ${store.shortName}', onTap: onCall),
            _StoreAction(icon: LucideIcons.navigation, label: 'Cómo llegar', semantic: 'Cómo llegar a ${store.shortName}', onTap: onDirections),
          ]),
        ),
      ]),
    );
  }
}

class _StoreAction extends StatelessWidget {
  const _StoreAction({required this.icon, required this.label, required this.semantic, required this.onTap});
  final IconData icon;
  final String label;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semantic,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: CQColors.ink),
            const SizedBox(width: 6),
            Text(label, style: CQType.body(15, weight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _StoreSkeleton extends StatelessWidget {
  const _StoreSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: CQColors.line, width: 1.5)),
      child: LayoutBuilder(
        builder: (context, c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Skeleton(width: c.maxWidth / 3, height: 20),
          const SizedBox(height: 8),
          Skeleton(width: c.maxWidth * 3 / 4, height: 12),
          const SizedBox(height: 8),
          Skeleton(width: c.maxWidth / 3, height: 12),
        ]),
      ),
    );
  }
}
