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
import 'shop_widgets.dart';

/// Elegir la tienda donde se prepara y se recoge el pedido.
class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  void _back(BuildContext context) => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(storesProvider);
    // Igual que selectedStoreProvider: sin elección explícita, se recoge en la primera abierta.
    final currentId = ref.watch(selectedStoreProvider)?.id;

    final Widget content;
    if (storesAsync.isLoading && !storesAsync.hasValue) {
      content = Column(children: [
        for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(height: 10), const _StoreSkeleton()],
      ]);
    } else if (storesAsync.hasError) {
      content = ErrorState(onRetry: () => ref.invalidate(storesProvider));
    } else {
      final stores = storesAsync.value ?? const <Store>[];
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
  const _StoreCard({required this.store, required this.selected, required this.onTap});

  final Store store;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = store.status.toUpperCase() == 'ABIERTO';
    final muted = CQType.body(15, color: CQColors.muted, height: 1.35);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CQMotion.press,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? CQColors.ink : CQColors.line, width: 1.5),
          ),
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
                if ((store.phone ?? '').isNotEmpty) ...[
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
