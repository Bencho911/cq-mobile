import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../data/history.dart';
import '../../state/notifications.dart';
import '../../state/orders.dart';
import '../../widgets/controls.dart';
import 'shop_widgets.dart';

IconData _iconFor(NotificationKind k) => switch (k) {
      NotificationKind.orderReady => LucideIcons.circleCheck,
      NotificationKind.orderPlaced => LucideIcons.coffee,
      NotificationKind.points => LucideIcons.star,
      NotificationKind.bird => LucideIcons.bird,
      NotificationKind.reward => LucideIcons.gift,
      NotificationKind.promo => LucideIcons.tag,
      NotificationKind.welcome => LucideIcons.info,
    };

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Grupo por fecha relativa: Hoy, Ayer, Esta semana, Anteriores.
String _groupFor(DateTime d, DateTime now) {
  final diff = _day(now).difference(_day(d)).inDays;
  if (diff <= 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  if (diff < 7) return 'Esta semana';
  return 'Anteriores';
}

/// Hora relativa corta: "Ahora", "Hace 5 min", "Hace 2 h" o la fecha.
String _timeFor(DateTime d, DateTime now) {
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (_day(d) == _day(now)) return 'Hace ${diff.inHours} h';
  return formatOrderDate(d, now);
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  /// Marca leída y, si es de un pedido, abre su seguimiento (en curso) o su recibo.
  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationsProvider.notifier).markRead(n.id);
    final id = n.orderId;
    if (id == null) return;
    final order = ref.read(ordersProvider.notifier).byId(id);
    if (order == null) {
      showToast(context, 'Ese pedido ya no está en este teléfono.', error: true);
    } else if (order.status.isActive) {
      context.push('/track-order', extra: id);
    } else {
      context.push('/invoice/$id', extra: order);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final now = DateTime.now();

    // Agrupa conservando el orden (la más reciente primero).
    final groups = <String, List<AppNotification>>{};
    for (final n in items) {
      groups.putIfAbsent(_groupFor(n.date, now), () => []).add(n);
    }

    return Scaffold(
      backgroundColor: CQColors.white,
      body: ListView(
        padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          PageHeader(
            title: 'Notificaciones',
            onBack: () => context.canPop() ? context.pop() : context.go('/home'),
            action: unread > 0
                ? Pressable(
                    onTap: () => ref.read(notificationsProvider.notifier).markAllRead(),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44, maxWidth: 116),
                      padding: const EdgeInsets.only(right: 12),
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Marcar todas como leídas',
                        textAlign: TextAlign.right,
                        style: CQType.body(14, weight: FontWeight.w600, height: 1.2).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  )
                : null,
          ),
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(unread == 1 ? 'Tienes 1 sin leer' : 'Tienes $unread sin leer', style: CQType.body(14, color: CQColors.muted)),
            ),
          if (items.isEmpty)
            EmptyState(
              image: 'assets/brand/ventana-ave.webp',
              title: 'Sin notificaciones',
              description: 'Cuando hagas un pedido, sumes puntos o ganes un ave, te avisamos aquí.',
              action: CQButton(label: 'Ver el menú', variant: CQButtonVariant.secondary, onPressed: () => context.go('/menu')),
            )
          else
            for (final MapEntry(key: label, value: list) in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Semantics(
                  header: true,
                  child: Text(label.toUpperCase(),
                      style: CQType.body(13, weight: FontWeight.w700, color: CQColors.muted).copyWith(letterSpacing: 0.8)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  for (final n in list)
                    // Deslizar a la izquierda la borra.
                    Dismissible(
                      key: ValueKey(n.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => ref.read(notificationsProvider.notifier).remove(n.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: CQColors.danger,
                        child: const Icon(LucideIcons.trash2, color: CQColors.white, semanticLabel: 'Borrar'),
                      ),
                      child: _NoticeRow(notice: n, time: _timeFor(n.date, now), onTap: () => _open(context, ref, n)),
                    ),
                ]),
              ),
            ],
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice, required this.time, required this.onTap});
  final AppNotification notice;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    final duration = CQMotion.reduced(context) ? Duration.zero : CQMotion.fast;
    return Semantics(
      label: n.read ? null : 'Sin leer',
      hint: n.orderId != null ? 'Abre el pedido' : null,
      child: Pressable(
        onTap: onTap,
        scale: 0.99,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(color: CQColors.white, border: Border(bottom: BorderSide(color: CQColors.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(_iconFor(n.kind), size: 22, color: n.read ? CQColors.muted : CQColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(n.title, style: CQType.body(16, weight: n.read ? FontWeight.w400 : FontWeight.w700, height: 1.35)),
                  ),
                  const SizedBox(width: 8),
                  // El punto se apaga al leerla.
                  AnimatedScale(
                    scale: n.read ? 0 : 1,
                    duration: duration,
                    curve: CQMotion.easeOut,
                    child: Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(color: CQColors.mostaza, shape: BoxShape.circle),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(n.body, style: CQType.body(15, color: CQColors.muted, height: 1.35)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(time, style: CQType.body(13, color: CQColors.muted)),
                  if (n.orderId != null) ...[
                    const Spacer(),
                    Text('Ver pedido', style: CQType.body(13, weight: FontWeight.w600).copyWith(decoration: TextDecoration.underline)),
                  ],
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
