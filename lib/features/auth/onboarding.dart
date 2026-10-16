import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../state/loyalty.dart';
import '../../widgets/controls.dart';
import '../../widgets/stamp.dart';
import '../../widgets/zocalo.dart';

class _Step {
  const _Step({required this.tone, required this.title, required this.description, this.image});
  final FacadeTone tone;
  final String title;
  final String description;
  final String? image;
}

const _steps = [
  _Step(
    tone: FacadeTone.verde,
    title: 'Pide antes de llegar.',
    description: 'Elige, paga y recoge en la barra, sin hacer fila.',
    image: 'assets/brand/ventana-tucan.webp',
  ),
  _Step(
    tone: FacadeTone.mostaza,
    title: 'Como te gusta.',
    description: 'Tamaño, leche, azúcar y adiciones: cada bebida a tu manera.',
    image: 'assets/brand/tucan-flora.webp',
  ),
  _Step(
    tone: FacadeTone.rosa,
    title: 'Cada 10 puntos, un ave.',
    description: 'Suma puntos en cada pedido y completa tu álbum. Con 50, tu bebida va por nuestra cuenta.',
  ),
];

/// Oscurece el logo teal sobre fachadas claras (brightness 0.45 en la web).
const _darkenLogo = ColorFilter.matrix([
  0.45, 0, 0, 0, 0, //
  0, 0.45, 0, 0, 0, //
  0, 0, 0.45, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Tres fachadas, una por idea. Se pasan deslizando (o con «Siguiente»);
/// la ilustración se desplaza un poco más lento que el muro.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _current = 0;

  bool get _isLast => _current == _steps.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Posición continua del carrusel (sigue el dedo).
  double get _page => _pages.hasClients && _pages.position.haveDimensions ? _pages.page ?? _current.toDouble() : _current.toDouble();

  void _goTo(int i) {
    if (CQMotion.reduced(context)) {
      _pages.jumpToPage(i);
    } else {
      _pages.animateToPage(i, duration: CQMotion.medium, curve: CQMotion.easeOut);
    }
  }

  void _next() => _isLast ? context.push('/register') : _goTo(_current + 1);

  @override
  Widget build(BuildContext context) {
    final tone = _steps[_current].tone;
    final pad = MediaQuery.paddingOf(context);
    final reduced = CQMotion.reduced(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: tone.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: CQColors.white,
        body: Column(children: [
          Expanded(
            child: Stack(children: [
              PageView.builder(
                controller: _pages,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => AnimatedBuilder(
                  animation: _pages,
                  builder: (context, child) => _StepPage(step: _steps[i], offset: reduced ? 0 : i - _page, topInset: pad.top),
                ),
              ),
              // Cabecera fija: el logo y el enlace cambian de color con la fachada.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, pad.top + 12, 12, 0),
                  child: Row(children: [
                    AnimatedSwitcher(
                      duration: CQMotion.fast,
                      child: _Logo(key: ValueKey(tone.isDark), tone: tone),
                    ),
                    const Spacer(),
                    Pressable(
                      onTap: () => context.push('/login'),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            widthFactor: 1,
                            child: AnimatedDefaultTextStyle(
                              duration: CQMotion.fast,
                              style: CQType.body(15, weight: FontWeight.w600, color: tone.onWall),
                              child: const Text('Ya tengo cuenta'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, pad.bottom + 20),
            child: Row(children: [
              AnimatedBuilder(
                animation: _pages,
                builder: (context, _) => _Dots(page: _page, count: _steps.length, onTap: _goTo),
              ),
              const Spacer(),
              CQButton(
                label: _isLast ? 'Crear mi cuenta' : 'Siguiente',
                onPressed: _next,
                expand: false,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({super.key, required this.tone});
  final FacadeTone tone;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(tone.logo, height: 24, semanticLabel: 'Café Quindío');
    return tone.isDark ? img : ColorFiltered(colorFilter: _darkenLogo, child: img);
  }
}

/// Una fachada del carrusel. [offset] es la distancia a la página visible
/// (-1..1) y mueve la ilustración con paralaje.
class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, required this.offset, required this.topInset});

  final _Step step;
  final double offset;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final tone = step.tone;
    return ColoredBox(
      color: tone.wall,
      child: LayoutBuilder(builder: (context, c) {
        final parallax = Offset(offset * c.maxWidth * 0.3, 0);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Espacio de la cabecera fija.
          SizedBox(height: topInset + 12 + 44),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(step.title, style: CQType.title(44, color: tone.onWall))),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(step.description, style: CQType.body(17, color: tone.isDark ? CQColors.onDark : CQColors.ink, height: 1.35)),
              ),
            ]),
          ),
          // La ilustración ocupa lo que sobre (hasta 300 px) y se encoge en pantallas bajas.
          Expanded(
            child: Transform.translate(
              offset: parallax,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: step.image != null
                    ? Transform.translate(
                        offset: const Offset(0, 4),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 300, maxWidth: c.maxWidth * 0.86),
                          child: Image.asset(step.image!, fit: BoxFit.contain, excludeFromSemantics: true),
                        ),
                      )
                    : const FittedBox(fit: BoxFit.scaleDown, child: _Stamps(height: 170)),
              ),
            ),
          ),
          const Zocalo(),
        ]);
      }),
    );
  }
}

/// Tres estampillas de muestra; la del centro un poco más alta.
class _Stamps extends StatelessWidget {
  const _Stamps({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final picks = [birds[1], birds[4], birds[2]];
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < picks.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Transform.translate(
              offset: Offset(0, i == 1 ? -20 : 0),
              child: SizedBox(width: height * 118 / 170, child: Stamp(bird: picks[i], height: height)),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Indicadores de paso: el activo se estira y sigue el arrastre.
class _Dots extends StatelessWidget {
  const _Dots({required this.page, required this.count, required this.onTap});

  final double page;
  final int count;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < count; i++)
        Builder(builder: (context) {
          final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
          return Semantics(
            button: true,
            selected: page.round() == i,
            label: 'Paso ${i + 1} de $count',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Center(
                    child: Container(
                      width: 8 + 16 * t,
                      height: 8,
                      decoration: BoxDecoration(color: Color.lerp(CQColors.line, CQColors.ink, t), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
    ]);
  }
}
