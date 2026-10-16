import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../state/preferences.dart';
import '../../widgets/controls.dart';
import 'common.dart';

/// Preferencias: avisos, sonidos y vibraciones (guardadas en el teléfono).
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(preferencesProvider);
    void back() => context.canPop() ? context.pop() : context.go('/profile');

    void set(Preferences Function(Preferences) change) {
      ref.read(preferencesProvider.notifier).update(change);
      // El toque de confirmación respeta el ajuste recién guardado.
      if (ref.read(preferencesProvider).haptics) HapticFeedback.selectionClick();
    }

    return Scaffold(
      body: ListView(padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.paddingOf(context).bottom + 40), children: [
        PageHeader(title: 'Preferencias', onBack: back),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Avisos', style: CQType.title(20, height: 1.1)),
            const SizedBox(height: 4),
            SwitchRow(
              icon: LucideIcons.bellRing,
              label: 'Avisos de pedidos',
              description: 'Cuando tu pedido esté listo',
              value: p.orderAlerts,
              onChanged: (v) => set((x) => x.copyWith(orderAlerts: v)),
            ),
            SwitchRow(
              icon: LucideIcons.megaphone,
              label: 'Promociones',
              description: 'Novedades y bonos de Café Quindío',
              value: p.promoAlerts,
              onChanged: (v) => set((x) => x.copyWith(promoAlerts: v)),
            ),
            const SizedBox(height: 28),
            Text('Sonido y tacto', style: CQType.title(20, height: 1.1)),
            const SizedBox(height: 4),
            SwitchRow(
              icon: LucideIcons.volume2,
              label: 'Sonidos del álbum',
              description: 'El sello al ganar un ave',
              value: p.sounds,
              onChanged: (v) => set((x) => x.copyWith(sounds: v)),
            ),
            SwitchRow(
              icon: LucideIcons.vibrate,
              label: 'Vibraciones',
              description: 'Un toque leve al confirmar',
              value: p.haptics,
              onChanged: (v) => set((x) => x.copyWith(haptics: v)),
            ),
            const SizedBox(height: 16),
            Text(
              'Los avisos llegan dentro de la app, en Notificaciones.',
              style: CQType.body(14, color: CQColors.muted, height: 1.5),
            ),
          ]),
        ),
      ]),
    );
  }
}
