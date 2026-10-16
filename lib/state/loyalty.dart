import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart.dart';

/// Programa de lealtad: los puntos son el sistema oficial (regla de
/// gerencia: 50 puntos = 1 bebida gratis). El álbum de aves solo los
/// representa: cada 10 puntos se gana un ave de la tarjeta actual, 5 aves
/// por tarjeta. Las aves se derivan del saldo y de las tarjetas completas.

const pointsPerReward = 50;
const pointsPerBird = 10;
const birdsPerCard = pointsPerReward ~/ pointsPerBird;

enum StampTone { rosa, teal, mostaza, rosaSoft, mostazaSoft }

class Bird {
  const Bird(this.id, this.name, this.image, this.tone);
  final String id;

  /// Nombre provisional: validar con el equipo de marca.
  final String name;
  final String image;
  final StampTone tone;
}

/// Orden en que se ganan las aves; al terminar la lista se repite.
/// Las aves nuevas se agregan de a 5 (una tarjeta completa) para no cambiar
/// la tarjeta en curso de los clientes.
const birds = [
  Bird('tucan', 'Tucán', 'assets/brand/ave-tucan.webp', StampTone.rosa),
  Bird('toche', 'Toche', 'assets/brand/ave-toche.webp', StampTone.teal),
  Bird('loro', 'Loro', 'assets/brand/ave-loro.webp', StampTone.rosaSoft),
  Bird('martin', 'Martín pescador', 'assets/brand/ave-martin.webp', StampTone.mostazaSoft),
  Bird('barranquero', 'Barranquero', 'assets/brand/ave-barranquero.webp', StampTone.mostaza),
  // El carriquí es teal como la estampilla teal: va sobre rosa para que se vea.
  Bird('carriqui', 'Carriquí', 'assets/brand/ave-carriqui.webp', StampTone.rosa),
  Bird('colibri', 'Colibrí', 'assets/brand/ave-colibri-rosa.webp', StampTone.mostazaSoft),
  Bird('mirla', 'Mirla', 'assets/brand/ave-mirla.webp', StampTone.rosaSoft),
  Bird('azulejo', 'Azulejo', 'assets/brand/ave-azulejo.webp', StampTone.mostaza),
  Bird('cuco', 'Cuco', 'assets/brand/ave-cuco.webp', StampTone.rosa),
];

class LoyaltyAccount {
  const LoyaltyAccount({required this.points, required this.completedCards});

  /// Saldo de puntos de la tarjeta en curso.
  final int points;

  /// Tarjetas completadas (bebidas ganadas) en el historial.
  final int completedCards;

  Map<String, dynamic> toJson() => {'points': points, 'completedCards': completedCards};
  factory LoyaltyAccount.fromJson(Map<String, dynamic> j) =>
      LoyaltyAccount(points: (j['points'] as num).toInt(), completedCards: (j['completedCards'] as num).toInt());
}


/// MOCK: regla provisional (1 punto por cada $5.000) hasta que gerencia
/// confirme la real; se usa para anticipar cuántos puntos sumará un pedido.
int estimatePoints(int total) => total ~/ 5000;

class CardSlot {
  const CardSlot(this.bird, this.earned, this.at);
  final Bird bird;
  final bool earned;

  /// Puntos de la tarjeta en los que se gana esta ave (10, 20…50).
  final int at;
}

class LoyaltySummary {
  const LoyaltySummary({
    required this.points,
    required this.birdsEarned,
    required this.progressToNextBird,
    required this.nextBird,
    required this.slots,
    required this.completedCards,
  });

  final int points;
  final int birdsEarned;

  /// 0..1 de avance hacia la siguiente ave.
  final double progressToNextBird;
  final Bird? nextBird;
  final List<CardSlot> slots;
  final int completedCards;

  int get pointsToReward => pointsPerReward - points;
}

List<Bird> _cardBirds(int cardIndex) =>
    List.generate(birdsPerCard, (i) => birds[(cardIndex * birdsPerCard + i) % birds.length]);

LoyaltySummary summarize(LoyaltyAccount account) {
  final points = account.points.clamp(0, pointsPerReward);
  final earned = points ~/ pointsPerBird;
  final card = _cardBirds(account.completedCards);
  return LoyaltySummary(
    points: points,
    birdsEarned: earned,
    progressToNextBird: earned >= birdsPerCard ? 1 : (points % pointsPerBird) / pointsPerBird,
    nextBird: earned < birdsPerCard ? card[earned] : null,
    slots: [for (var i = 0; i < card.length; i++) CardSlot(card[i], i < earned, (i + 1) * pointsPerBird)],
    completedCards: account.completedCards,
  );
}

/// Lo que pasaría con la tarjeta si se suman [earned] puntos.
({int earned, int total, bool completesCard, List<Bird> newBirds}) preview(LoyaltyAccount account, int earned) {
  final before = summarize(account);
  final total = account.points + earned;
  final after = summarize(LoyaltyAccount(points: total, completedCards: account.completedCards));
  return (
    earned: earned,
    total: total,
    completesCard: total >= pointsPerReward,
    newBirds: [
      for (var i = 0; i < before.slots.length; i++)
        if (!before.slots[i].earned && after.slots[i].earned) before.slots[i].bird,
    ],
  );
}

/// Movimiento de puntos ("Compra en Tienda Centro +12", "Bebida gratis canjeada").
class LoyaltyMovement {
  const LoyaltyMovement({required this.label, required this.points, required this.date});
  final String label;
  final int points;
  final DateTime date;

  Map<String, dynamic> toJson() => {'label': label, 'points': points, 'date': date.toIso8601String()};
  factory LoyaltyMovement.fromJson(Map<String, dynamic> j) => LoyaltyMovement(
      label: j['label'] as String? ?? '', points: (j['points'] as num?)?.toInt() ?? 0, date: DateTime.tryParse('${j['date']}') ?? DateTime.now());
}

/// Libreta de lealtad guardada en el teléfono (el backend aún no expone puntos).
class LoyaltyBook {
  const LoyaltyBook({this.account = const LoyaltyAccount(points: 0, completedCards: 0), this.movements = const [], this.freeDrinks = 0});

  final LoyaltyAccount account;

  /// Más reciente primero.
  final List<LoyaltyMovement> movements;

  /// Bebidas gratis ganadas y aún sin canjear.
  final int freeDrinks;

  Map<String, dynamic> toJson() =>
      {'account': account.toJson(), 'movements': movements.map((e) => e.toJson()).toList(), 'freeDrinks': freeDrinks};

  factory LoyaltyBook.fromJson(Map<String, dynamic> j) => LoyaltyBook(
        account: LoyaltyAccount.fromJson(Map<String, dynamic>.from(j['account'] as Map)),
        movements: ((j['movements'] as List?) ?? const []).map((e) => LoyaltyMovement.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        freeDrinks: (j['freeDrinks'] as num?)?.toInt() ?? 0,
      );
}

/// Resultado de sumar puntos, para avisar al cliente.
class PointsResult {
  const PointsResult({required this.earned, required this.newBirds, required this.cardsCompleted});
  final int earned;
  final List<Bird> newBirds;

  /// Tarjetas que se completaron con esta suma (= bebidas gratis nuevas).
  final int cardsCompleted;
}

class LoyaltyNotifier extends Notifier<LoyaltyBook> {
  static const _key = 'cq.loyalty';

  @override
  LoyaltyBook build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const LoyaltyBook();
    try {
      return LoyaltyBook.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const LoyaltyBook();
    }
  }

  void _set(LoyaltyBook b) {
    state = b;
    ref.read(prefsProvider).setString(_key, jsonEncode(b.toJson()));
  }

  /// Suma puntos de un pedido. Cada 50 puntos se completa la tarjeta: queda
  /// una bebida gratis y la tarjeta siguiente arranca con el sobrante.
  PointsResult addPoints(int points, String label) {
    if (points <= 0) return const PointsResult(earned: 0, newBirds: [], cardsCompleted: 0);
    final before = state.account;
    final p = preview(before, points);
    var total = before.points + points;
    var cards = before.completedCards;
    var completed = 0;
    while (total >= pointsPerReward) {
      total -= pointsPerReward;
      cards++;
      completed++;
    }
    _set(LoyaltyBook(
      account: LoyaltyAccount(points: total, completedCards: cards),
      movements: [LoyaltyMovement(label: label, points: points, date: DateTime.now()), ...state.movements].take(100).toList(),
      freeDrinks: state.freeDrinks + completed,
    ));
    return PointsResult(earned: points, newBirds: p.newBirds, cardsCompleted: completed);
  }

  /// Canjea una bebida gratis (en el pago). Devuelve `false` si no hay.
  bool redeemFreeDrink() {
    if (state.freeDrinks <= 0) return false;
    _set(LoyaltyBook(
      account: state.account,
      movements: [LoyaltyMovement(label: 'Bebida gratis canjeada', points: 0, date: DateTime.now()), ...state.movements],
      freeDrinks: state.freeDrinks - 1,
    ));
    return true;
  }
}

final loyaltyProvider = NotifierProvider<LoyaltyNotifier, LoyaltyBook>(LoyaltyNotifier.new);

/// Saldo actual (atajo para las pantallas que solo necesitan los puntos).
final loyaltyAccountProvider = Provider<LoyaltyAccount>((ref) => ref.watch(loyaltyProvider).account);

/// Último saldo que el cliente vio en su álbum, para animar solo lo que
/// cambió desde la visita anterior.
class LoyaltySeen {
  LoyaltySeen(this._ref);
  final Ref _ref;
  static const _key = 'cq.loyalty.seen';

  LoyaltyAccount? read() {
    final raw = _ref.read(prefsProvider).getString(_key);
    if (raw == null) return null;
    try {
      return LoyaltyAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void write(LoyaltyAccount account) => _ref.read(prefsProvider).setString(_key, jsonEncode(account.toJson()));

  /// Puntos desde los que arranca la animación: la primera visita y una
  /// tarjeta nueva arrancan en 0; si el saldo bajó (canje), no se anima.
  int pointsFrom(LoyaltyAccount current) {
    final seen = read();
    if (seen == null || seen.completedCards != current.completedCards) return 0;
    return seen.points < current.points ? seen.points : current.points;
  }
}

final loyaltySeenProvider = Provider<LoyaltySeen>(LoyaltySeen.new);
