import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart.dart';

/// Preferencias del cliente guardadas en el teléfono.
class Preferences {
  const Preferences({this.favoriteStores = const {}, this.orderAlerts = true, this.promoAlerts = true, this.sounds = true, this.haptics = true});

  final Set<int> favoriteStores;

  /// Avisos de pedido listo y cambios de estado.
  final bool orderAlerts;

  /// Promociones y novedades.
  final bool promoAlerts;

  /// Sonido del sello en el álbum.
  final bool sounds;

  /// Vibraciones leves al confirmar.
  final bool haptics;

  Preferences copyWith({Set<int>? favoriteStores, bool? orderAlerts, bool? promoAlerts, bool? sounds, bool? haptics}) => Preferences(
        favoriteStores: favoriteStores ?? this.favoriteStores,
        orderAlerts: orderAlerts ?? this.orderAlerts,
        promoAlerts: promoAlerts ?? this.promoAlerts,
        sounds: sounds ?? this.sounds,
        haptics: haptics ?? this.haptics,
      );

  Map<String, dynamic> toJson() => {
        'favoriteStores': favoriteStores.toList(),
        'orderAlerts': orderAlerts,
        'promoAlerts': promoAlerts,
        'sounds': sounds,
        'haptics': haptics,
      };

  factory Preferences.fromJson(Map<String, dynamic> j) => Preferences(
        favoriteStores: ((j['favoriteStores'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet(),
        orderAlerts: j['orderAlerts'] as bool? ?? true,
        promoAlerts: j['promoAlerts'] as bool? ?? true,
        sounds: j['sounds'] as bool? ?? true,
        haptics: j['haptics'] as bool? ?? true,
      );
}

class PreferencesNotifier extends Notifier<Preferences> {
  static const _key = 'cq.preferences';

  @override
  Preferences build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const Preferences();
    try {
      return Preferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Preferences();
    }
  }

  void _set(Preferences p) {
    state = p;
    ref.read(prefsProvider).setString(_key, jsonEncode(p.toJson()));
  }

  void toggleFavoriteStore(int id) {
    final s = {...state.favoriteStores};
    s.contains(id) ? s.remove(id) : s.add(id);
    _set(state.copyWith(favoriteStores: s));
  }

  void update(Preferences Function(Preferences) change) => _set(change(state));
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, Preferences>(PreferencesNotifier.new);
