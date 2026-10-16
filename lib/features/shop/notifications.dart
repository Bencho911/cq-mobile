import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../widgets/controls.dart';
import 'shop_widgets.dart';

class _Notice {
  const _Notice(this.id, this.icon, this.title, this.body, this.time, {this.read = false});
  final int id;
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final bool read;

  _Notice markRead() => _Notice(id, icon, title, body, time, read: true);
}

// MOCK: datos de notificaciones para la demo de gerencia
const _mockNotifications = [
  _Notice(1, LucideIcons.circleCheck, 'Tu pedido está listo',
      'Pedido #1234: café con leche y Nitro Cold Brew listos para recoger en la Tienda Centro.', 'Hace 5 min'),
  _Notice(2, LucideIcons.gift, 'Descuento especial para ti',
      'Usa el código CAFE20 y obtén 20% de descuento en tu próximo pedido. Válido hoy.', 'Hace 1 h'),
  _Notice(3, LucideIcons.star, 'Te faltan 3 puntos para un café gratis',
      'Tienes 47 puntos. Llega a 50 y reclama tu bebida favorita sin costo.', 'Hace 3 h',
      read: true),
  _Notice(4, LucideIcons.coffee, 'Pedido confirmado', 'Tu pedido #1233 está en preparación. Tiempo estimado: 8 minutos.',
      'Ayer, 4:12 p. m.',
      read: true),
  _Notice(5, LucideIcons.info, 'Nueva tienda en Armenia Norte',
      'Abrimos en la Cra 19 #22-15. Visítanos y prueba el menú de temporada.', 'Hace 2 días',
      read: true),
  _Notice(6, LucideIcons.clock, 'Puntos dobles este fin de semana', 'Sábado y domingo duplicamos tus puntos en cada compra.',
      'Hace 3 días',
      read: true),
];

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<_Notice> _items = _mockNotifications;

  void _markAllRead() => setState(() => _items = [for (final n in _items) n.markRead()]);
  void _markRead(int id) => setState(() => _items = [for (final n in _items) n.id == id ? n.markRead() : n]);

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.read).length;
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
                    onTap: _markAllRead,
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
          if (_items.isEmpty)
            const EmptyState(
              icon: LucideIcons.bell,
              title: 'Sin notificaciones',
              description: 'Cuando tengas pedidos, promociones o novedades, aparecerán aquí.',
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(children: [for (final n in _items) _NoticeRow(notice: n, onTap: () => _markRead(n.id))]),
            ),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice, required this.onTap});
  final _Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    return Semantics(
      label: n.read ? null : 'Sin leer',
      child: Pressable(
        onTap: onTap,
        scale: 0.99,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(n.icon, size: 22, color: n.read ? CQColors.muted : CQColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(n.title, style: CQType.body(16, weight: n.read ? FontWeight.w400 : FontWeight.w700, height: 1.35)),
                  ),
                  if (!n.read) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(color: CQColors.mostaza, shape: BoxShape.circle),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(n.body, style: CQType.body(15, color: CQColors.muted, height: 1.35)),
                const SizedBox(height: 4),
                Text(n.time, style: CQType.body(13, color: CQColors.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
