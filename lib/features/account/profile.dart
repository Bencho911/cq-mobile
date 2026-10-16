import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../state/account.dart';
import '../../state/loyalty.dart';
import '../../state/preferences.dart';
import '../../widgets/controls.dart';
import '../../widgets/stamp.dart';
import 'common.dart';

/// Destinos que son pestañas: se cambian con go(), el resto se apila.
const _tabs = {'/home', '/menu', '/album', '/orders'};

typedef _Item = ({IconData icon, String label, String to});

const List<(String, List<_Item>)> _menuGroups = [
  (
    'Mi cuenta',
    [
      (icon: LucideIcons.userPen, label: 'Editar perfil', to: '/edit-profile'),
      (icon: LucideIcons.history, label: 'Historial de pedidos', to: '/orders'),
      (icon: LucideIcons.mapPin, label: 'Mis tiendas favoritas', to: '/stores'),
      (icon: LucideIcons.creditCard, label: 'Métodos de pago', to: '/payment-method'),
    ],
  ),
  (
    'Beneficios',
    [
      (icon: LucideIcons.ticket, label: 'Bonos y cupones', to: '/vouchers'),
      (icon: LucideIcons.gift, label: 'Puntos y álbum de aves', to: '/album'),
    ],
  ),
  (
    'Configuración',
    [
      (icon: LucideIcons.shield, label: 'Privacidad y seguridad', to: '/privacy'),
      (icon: LucideIcons.settings, label: 'Preferencias', to: '/preferences'),
    ],
  ),
];

/// Perfil: identidad, puntos con la próxima ave y menú de la cuenta.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Con confirmación; el router lleva a la bienvenida al cerrar la sesión.
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: '¿Cerrar sesión?',
      message: 'Tus pedidos y puntos quedan guardados en este teléfono para cuando vuelvas.',
      confirmLabel: 'Cerrar sesión',
      danger: true,
    );
    if (ok) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).account;
    final favorites = ref.watch(preferencesProvider.select((p) => p.favoriteStores.length));
    final s = summarize(ref.watch(loyaltyAccountProvider));
    final name = account?.name.isNotEmpty ?? false ? account!.name : 'Cliente Café Quindío';
    final contact = account?.phoneLabel ?? account?.email;
    final provider = switch (account?.provider) {
      AuthProvider.google => 'Cuenta de Google',
      AuthProvider.apple => 'Cuenta de Apple',
      _ => null,
    };
    final stampBird = s.nextBird ?? s.slots.last.bird;
    final top = math.max(MediaQuery.paddingOf(context).top, 20.0);

    void open(String to) => _tabs.contains(to) ? context.go(to) : context.push(to);

    return Scaffold(
      body: ListView(padding: EdgeInsets.fromLTRB(20, top, 20, 40), children: [
        // Identidad
        Row(children: [
          // Pantalla apilada: en la app hace falta una salida visible.
          if (context.canPop())
            Pressable(
              onTap: () => context.pop(),
              semanticLabel: 'Volver',
              child: const SizedBox(width: 36, height: 44, child: Icon(LucideIcons.chevronLeft, size: 26, color: CQColors.ink)),
            ),
          ExcludeSemantics(
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: CQColors.mostaza, shape: BoxShape.circle),
              child: Text(account?.initial ?? 'C', style: CQType.title(28, height: 1)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: CQType.title(28, height: 1.15)),
              if (contact != null)
                Text(contact, maxLines: 1, overflow: TextOverflow.ellipsis, style: CQType.number(15, color: CQColors.muted).copyWith(fontWeight: FontWeight.w400)),
              if (provider != null) Text(provider, style: CQType.body(13, color: CQColors.muted)),
            ]),
          ),
        ]),

        // Puntos y próxima ave
        const SizedBox(height: 24),
        Pressable(
          onTap: () => context.go('/album'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: CQColors.line, width: 1.5),
            ),
            child: Row(children: [
              SizedBox(width: 64, child: Stamp(bird: stampBird, state: s.nextBird != null ? StampState.next : StampState.earned, height: 78)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${s.points}', style: CQType.number(17)),
                    const TextSpan(text: ' puntos'),
                  ]), style: CQType.body(17, weight: FontWeight.w700)),
                  Text(
                    s.pointsToReward > 0 ? 'Te faltan ${s.pointsToReward} para tu bebida gratis' : 'Tienes una bebida gratis para canjear',
                    style: CQType.body(14, color: CQColors.muted, height: 1.35),
                  ),
                  if (s.nextBird != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Próxima ave: ${s.nextBird!.name}', style: CQType.body(14, weight: FontWeight.w600)),
                    ),
                ]),
              ),
              const SizedBox(width: 12),
              const Icon(LucideIcons.chevronRight, size: 18, color: CQColors.muted),
            ]),
          ),
        ),

        // Menú
        for (final (title, items) in _menuGroups) ...[
          const SizedBox(height: 28),
          Text(title, style: CQType.title(20, height: 1.1)),
          const SizedBox(height: 4),
          for (final item in items)
            ListRow(
              icon: item.icon,
              label: item.label,
              value: item.to == '/stores' && favorites > 0 ? '$favorites' : null,
              onTap: () => open(item.to),
            ),
        ],

        const SizedBox(height: 16),
        PlainRow(icon: LucideIcons.logOut, label: 'Cerrar sesión', danger: true, onTap: () => _logout(context, ref)),
      ]),
    );
  }
}
