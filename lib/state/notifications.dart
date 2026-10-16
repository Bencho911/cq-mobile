import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart.dart';

enum NotificationKind { orderReady, orderPlaced, points, bird, reward, promo, welcome }

class AppNotification {
  const AppNotification({required this.id, required this.kind, required this.title, required this.body, required this.date, this.read = false, this.orderId});

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime date;
  final bool read;

  /// Pedido relacionado, para abrir su seguimiento o recibo.
  final int? orderId;

  AppNotification markRead() => AppNotification(id: id, kind: kind, title: title, body: body, date: date, read: true, orderId: orderId);

  Map<String, dynamic> toJson() =>
      {'id': id, 'kind': kind.name, 'title': title, 'body': body, 'date': date.toIso8601String(), 'read': read, 'orderId': orderId};

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        kind: NotificationKind.values.asNameMap()[j['kind']] ?? NotificationKind.promo,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
        read: j['read'] as bool? ?? false,
        orderId: (j['orderId'] as num?)?.toInt(),
      );
}

/// Bandeja de notificaciones de la app (guardada en el teléfono). Los
/// eventos de pedidos y puntos la alimentan.
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  static const _key = 'cq.notifications';

  @override
  List<AppNotification> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return const [];
    }
  }

  void _set(List<AppNotification> list) {
    state = list;
    ref.read(prefsProvider).setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  int get unread => state.where((n) => !n.read).length;

  /// Agrega arriba (la más reciente primero). Máximo 50.
  void add(NotificationKind kind, String title, String body, {int? orderId}) {
    final n = AppNotification(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      title: title,
      body: body,
      date: DateTime.now(),
      orderId: orderId,
    );
    _set([n, ...state].take(50).toList());
  }

  void markRead(String id) => _set([for (final n in state) n.id == id ? n.markRead() : n]);
  void markAllRead() => _set([for (final n in state) n.markRead()]);
  void remove(String id) => _set(state.where((n) => n.id != id).toList());
  void clear() => _set(const []);
}

final notificationsProvider = NotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);
final unreadNotificationsProvider = Provider<int>((ref) => ref.watch(notificationsProvider).where((n) => !n.read).length);
