import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../state/loyalty.dart';
import '../../widgets/stamp.dart';

// MOCK: beneficios e historial (el backend aún no expone el programa).
const _benefits = [
  ('Bebida gratis', 'Cada $pointsPerReward puntos.'),
  ('Prioridad en tienda', 'Tus pedidos pasan primero en la barra.'),
  ('Regalo de cumpleaños', 'Un postre gratis en tu mes.'),
];

const _history = [
  ('Compra en Tienda Centro', 12, 'Hoy, 2:15 p. m.'),
  ('Bebida gratis canjeada', -50, '4 sep, 10:00 a. m.'),
  ('Compra en Tienda Norte', 15, '28 ago, 4:30 p. m.'),
];

const _stampHeight = 128.0;

/// Lealtad: los puntos son el sistema oficial y el álbum los ilustra.
/// Cada 10 puntos se gana un ave; 5 aves (50 puntos) = bebida gratis.
class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> with SingleTickerProviderStateMixin {
  late final LoyaltyAccount _account = ref.read(loyaltyAccountProvider);
  late final LoyaltySummary _s = summarize(_account);
  late final AnimationController _c = AnimationController(vsync: this);
  late Animation<double> _progress = AlwaysStoppedAnimation(_s.points.toDouble());

  bool _started = false;
  bool _reduced = false;
  int _birdsAtStart = 0;
  int _birdsShown = 0;
  Timer? _delay;
  AudioPlayer? _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Los puntos suben desde lo que se vio la última vez y cada ave nueva se
    // sella justo cuando el contador cruza su decena.
    _reduced = CQMotion.reduced(context);
    final seen = ref.read(loyaltySeenProvider);
    final from = _reduced ? _s.points : seen.pointsFrom(_account);
    seen.write(_account);

    _birdsAtStart = from ~/ pointsPerBird;
    _birdsShown = _birdsAtStart;
    final delta = _s.points - from;
    if (delta <= 0) return;

    _progress = Tween(begin: from.toDouble(), end: _s.points.toDouble())
        .animate(CurvedAnimation(parent: _c, curve: CQMotion.easeOut))
      ..addListener(_onProgress);
    _c.duration = Duration(milliseconds: (math.min(1.1, 0.6 + delta * 0.012) * 1000).round());
    _delay = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _c.forward();
    });
  }

  void _onProgress() {
    final birds = math.min(_s.birdsEarned, _progress.value ~/ pointsPerBird);
    if (birds > _birdsShown) {
      setState(() => _birdsShown = birds);
      _playStamp();
      HapticFeedback.lightImpact();
    }
  }

  /// Sello de las aves nuevas; el reproductor se crea al primer uso.
  Future<void> _playStamp() async {
    try {
      final p = _player ??= AudioPlayer();
      await p.stop();
      await p.play(AssetSource('sfx/stamp.wav'), volume: 0.5, mode: PlayerMode.lowLatency);
    } catch (_) {
      // Sin audio.
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final nextIndex = _birdsShown < birdsPerCard ? _birdsShown : -1;
    final top = math.max(MediaQuery.paddingOf(context).top, 20.0);

    return Scaffold(
      body: ListView(padding: EdgeInsets.fromLTRB(20, top, 20, 40), children: [
        Text('Tu álbum', style: CQType.title(34, height: 1)),
        const SizedBox(height: 16),
        Row(children: [
          Semantics(
            label: '${s.points} puntos',
            excludeSemantics: true,
            child: AnimatedBuilder(
              animation: _progress,
              builder: (_, _) => Text('${_progress.value.round()}', style: CQType.title(56, height: 0.9).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('puntos', style: CQType.body(17, weight: FontWeight.w700)),
              Text(
                s.pointsToReward > 0 ? 'Te faltan ${s.pointsToReward} para tu bebida gratis' : 'Tienes una bebida gratis para canjear',
                style: CQType.body(14, color: CQColors.muted),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        // Un tramo por ave: 5 tramos de 10 puntos.
        Semantics(
          label: '${s.points} de $pointsPerReward puntos',
          value: '${s.points}',
          excludeSemantics: true,
          child: Row(children: [
            for (var i = 0; i < s.slots.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _Segment(progress: _progress, index: i)),
            ],
          ]),
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: Row(children: [
            for (var i = 0; i < s.slots.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  i == birdsPerCard - 1 ? '${s.slots[i].at} = bebida' : '${s.slots[i].at}',
                  textAlign: TextAlign.right,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: CQType.number(12, color: i == birdsPerCard - 1 ? CQColors.ink : CQColors.muted).copyWith(fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ]),
        ),

        // Tarjeta actual
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text('Tarjeta actual', style: CQType.title(20, height: 1.1))),
          Text('Cada $pointsPerBird puntos, un ave', style: CQType.body(14, color: CQColors.muted)),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 2 * 10) / 3;
          return Wrap(spacing: 10, runSpacing: 12, children: [
            for (var i = 0; i < s.slots.length; i++)
              SizedBox(width: w, child: _SlotTile(
                slot: s.slots[i],
                earned: i < _birdsShown,
                isNext: i == nextIndex,
                sealing: i < _birdsShown && i >= _birdsAtStart,
                reduced: _reduced,
              )),
          ]);
        }),
        if (s.completedCards > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: CQColors.line, width: 1.5),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${s.completedCards} ${s.completedCards == 1 ? 'tarjeta completa' : 'tarjetas completas'}. ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: '${s.completedCards} ${s.completedCards == 1 ? 'bebida canjeada' : 'bebidas canjeadas'}.',
                  style: const TextStyle(color: CQColors.muted),
                ),
              ]),
              style: CQType.body(15),
            ),
          ),
        ],

        // Movimientos de puntos
        const SizedBox(height: 28),
        Text('Movimientos de puntos', style: CQType.title(20, height: 1.1)),
        const SizedBox(height: 4),
        for (final (action, points, date) in _history)
          _Row(
            title: Text(action, style: CQType.body(16)),
            subtitle: Text(date, style: CQType.body(13, color: CQColors.muted)),
            trailing: Text(
              points > 0 ? '+$points' : '$points',
              style: CQType.number(16, color: points > 0 ? CQColors.success : CQColors.ink).copyWith(fontWeight: FontWeight.w400),
            ),
          ),

        // Beneficios
        const SizedBox(height: 28),
        Text('Beneficios', style: CQType.title(20, height: 1.1)),
        const SizedBox(height: 4),
        for (final (title, desc) in _benefits)
          _Row(
            title: Text(title, style: CQType.body(16, weight: FontWeight.w700)),
            subtitle: Text(desc, style: CQType.body(14, color: CQColors.muted)),
          ),
      ]),
    );
  }
}

/// Un tramo de la barra: se llena con el mismo valor que mueve el contador.
class _Segment extends StatelessWidget {
  const _Segment({required this.progress, required this.index});
  final Animation<double> progress;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 10,
        color: CQColors.line,
        child: AnimatedBuilder(
          animation: progress,
          builder: (_, _) => Transform.scale(
            scaleX: ((progress.value - index * pointsPerBird) / pointsPerBird).clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: const ColoredBox(color: CQColors.ink, child: SizedBox.expand()),
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.earned, required this.isNext, required this.sealing, required this.reduced});

  final CardSlot slot;
  final bool earned;
  final bool isNext;
  final bool sealing;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final state = earned ? StampState.earned : (isNext ? StampState.next : StampState.locked);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (sealing)
        // La silueta queda debajo y el ave a color cae encima.
        SizedBox(
          height: _stampHeight,
          child: Stack(fit: StackFit.expand, children: [
            Stamp(bird: slot.bird, state: StampState.next, height: _stampHeight),
            _SealedStamp(reduced: reduced, child: Stamp(bird: slot.bird, height: _stampHeight)),
          ]),
        )
      else
        Stamp(bird: slot.bird, state: state, height: _stampHeight),
      const SizedBox(height: 6),
      Text(state == StampState.locked ? 'Por descubrir' : slot.bird.name, style: CQType.body(14, weight: FontWeight.w700)),
      if (!earned) Text('A los ${slot.at} puntos', style: CQType.body(12, color: CQColors.muted)),
    ]);
  }
}

/// El ave nueva cae sobre su silueta como un sello: algo grande y ladeada,
/// con un rebote corto (resorte 0,45 s, rebote 0,25). Con "reducir
/// movimiento", solo un fundido.
class _SealedStamp extends StatefulWidget {
  const _SealedStamp({required this.reduced, required this.child});
  final bool reduced;
  final Widget child;

  @override
  State<_SealedStamp> createState() => _SealedStampState();
}

class _SealedStampState extends State<_SealedStamp> with TickerProviderStateMixin {
  late final _spring = AnimationController.unbounded(vsync: this);
  late final _fade = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.reduced ? 200 : 120),
  );

  @override
  void initState() {
    super.initState();
    _fade.forward();
    if (widget.reduced) {
      _spring.value = 1;
    } else {
      final spring = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 450), bounce: 0.25);
      _spring.animateWith(SpringSimulation(spring, 0, 1, 0));
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _spring,
        child: widget.child,
        builder: (_, child) {
          final t = _spring.value;
          return Transform.rotate(
            angle: -8 * math.pi / 180 * (1 - t),
            child: Transform.scale(scale: 1.18 - 0.18 * t, child: child),
          );
        },
      ),
    );
  }
}

/// Fila de lista con separador inferior.
class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, this.trailing});
  final Widget title;
  final Widget subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, subtitle])),
        ?trailing,
      ]),
    );
  }
}
