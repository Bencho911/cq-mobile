import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../state/account.dart';
import '../../widgets/controls.dart';

/// Celulares de Colombia: 10 dígitos, sin espacios ni guiones.
const phoneLength = 10;

/// Solo dígitos, con tope opcional.
List<TextInputFormatter> digitsOnly([int? max]) =>
    [FilteringTextInputFormatter.digitsOnly, if (max != null) LengthLimitingTextInputFormatter(max)];

/// Vuelve a la pantalla anterior; si no hay, va a [fallback].
void goBack(BuildContext context, {String fallback = '/login'}) =>
    context.canPop() ? context.pop() : context.go(fallback);

/// Con el teclado abierto se esconden los textos secundarios del pie para
/// que la acción principal siga a la vista.
bool keyboardOpen(BuildContext context) => MediaQuery.viewInsetsOf(context).bottom > 0;

/// Campo de las pantallas de acceso (equivale a `Input` de la web):
/// fondo gris claro, borde tinta al enfocar, ayuda debajo.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.prefix,
    this.keyboardType,
    this.inputFormatters,
    this.autofillHints,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.numeric = false,
    this.height = 48,
    this.borderColor = CQColors.line,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;

  /// Texto de ayuda bajo el campo; se anuncia al cambiar.
  final String? helper;

  /// Prefijo fijo separado por una línea (p. ej. «+57»).
  final String? prefix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  /// Cifras tabulares (teléfonos, documentos).
  final bool numeric;
  final double height;
  final Color borderColor;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.numeric ? CQType.number(16, height: 1.2) : CQType.body(16);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: CQType.body(14, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: _focus.requestFocus,
        child: AnimatedContainer(
          duration: CQMotion.fast,
          height: widget.height,
          decoration: BoxDecoration(
            color: CQColors.creamDeep,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _focus.hasFocus ? CQColors.ink : widget.borderColor, width: 1.5),
          ),
          child: Row(children: [
            if (widget.prefix != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: CQColors.line))),
                child: Text(widget.prefix!, style: CQType.number(16, height: 1.2)),
              ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                autofillHints: widget.autofillHints,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                onSubmitted: widget.onSubmitted,
                style: style,
                cursorColor: CQColors.ink,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: style.copyWith(color: CQColors.mutedSoft),
                  contentPadding: EdgeInsets.symmetric(horizontal: widget.prefix != null ? 14 : 16),
                ),
              ),
            ),
          ]),
        ),
      ),
      if (widget.helper != null) ...[
        const SizedBox(height: 6),
        Semantics(liveRegion: true, child: Text(widget.helper!, style: CQType.body(13, color: CQColors.muted))),
      ],
    ]);
  }
}

/// Enlace de texto subrayado con área táctil de 44 px.
class AuthLink extends StatelessWidget {
  const AuthLink(this.label, {super.key, required this.onTap, this.size = 15});

  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              style: CQType.body(size, weight: FontWeight.w600).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: CQColors.ink,
              ),
            ),
          ),
        ),
      );
}

/// Pregunta con enlace al final: «¿Primera vez? Crea tu cuenta».
class AuthPrompt extends StatelessWidget {
  const AuthPrompt({super.key, required this.question, required this.link, required this.onTap, this.center = true});

  final String question;
  final String link;
  final VoidCallback onTap;
  final bool center;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: center ? WrapAlignment.center : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$question ', style: CQType.body(15, color: CQColors.muted)),
          AuthLink(link, onTap: onTap),
        ],
      );
}

/// Subtítulo con el número resaltado: «… al +57 3001234567.»
class PhoneSubtitle extends StatelessWidget {
  const PhoneSubtitle({super.key, required this.before, required this.phone});

  final String before;
  final String phone;

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(text: before),
        // Espacio no separable para que el número no se parta.
        TextSpan(text: '+57 $phone', style: CQType.number(16, height: 1.5)),
        const TextSpan(text: '.'),
      ]));
}

/// Largo del PIN de la cuenta.
const pinLength = 6;

/// Nombre de la biometría del teléfono para los botones.
String get biometricName => defaultTargetPlatform == TargetPlatform.iOS ? 'Face ID' : 'huella';
IconData get biometricIcon => defaultTargetPlatform == TargetPlatform.iOS ? LucideIcons.scanFace : LucideIcons.fingerprint;

/// Sacudida horizontal suave cuando algo no coincide (PIN, código). Se
/// dispara cada vez que cambia [trigger]; con «reducir movimiento» no se mueve.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && !CQMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // Tres vaivenes que se apagan.
          final t = _c.value;
          final dx = math.sin(t * math.pi * 6) * 8 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: widget.child,
      );
}

/// Mensaje de error bajo un campo; se anuncia al aparecer.
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: CQMotion.reduced(context) ? Duration.zero : CQMotion.fast,
        curve: CQMotion.easeOut,
        alignment: Alignment.topLeft,
        child: message == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Semantics(
                  liveRegion: true,
                  child: Row(children: [
                    const Icon(LucideIcons.circleAlert, size: 18, color: CQColors.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(message!, style: CQType.body(15, weight: FontWeight.w600, color: CQColors.danger))),
                  ]),
                ),
              ),
      );
}

/// Aviso con una acción (p. ej. «No encontramos una cuenta… · Crear cuenta»).
class AuthNotice extends StatelessWidget {
  const AuthNotice({super.key, required this.title, this.detail, required this.action, required this.onAction});

  final String title;
  final String? detail;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          decoration: BoxDecoration(color: CQColors.mostazaSoft, borderRadius: BorderRadius.circular(6)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: CQType.body(15, weight: FontWeight.w600, height: 1.35)),
            if (detail != null) ...[
              const SizedBox(height: 2),
              Text(detail!, style: CQType.body(14, color: CQColors.muted, height: 1.4)),
            ],
            AuthLink(action, onTap: onAction),
          ]),
        ),
      );
}

/// Intentos fallidos de PIN: tras 5 seguidos se bloquea 30 s. Vive en memoria
/// y lo comparten el ingreso y el desbloqueo.
abstract final class PinGuard {
  static const maxAttempts = 5;
  static const lockout = Duration(seconds: 30);

  static int _failures = 0;
  static DateTime? _until;

  /// Segundos que faltan del bloqueo (0 si se puede intentar).
  static int get secondsLeft {
    final u = _until;
    if (u == null) return 0;
    final left = u.difference(DateTime.now()).inMilliseconds;
    if (left <= 0) {
      _until = null;
      return 0;
    }
    return (left / 1000).ceil();
  }

  /// Registra un fallo; devuelve `true` si con él se bloquea.
  static bool fail() {
    _failures++;
    if (_failures >= maxAttempts) {
      _failures = 0;
      _until = DateTime.now().add(lockout);
      return true;
    }
    return false;
  }

  static int get attemptsLeft => maxAttempts - _failures;

  static void reset() {
    _failures = 0;
    _until = null;
  }
}

/// Cuenta regresiva de un bloqueo o de un reenvío: llama [onTick] cada
/// segundo mientras [secondsLeft] sea mayor que 0.
mixin Countdown<T extends StatefulWidget> on State<T> {
  Timer? _ticker;

  void startCountdown(int Function() secondsLeft) {
    _ticker?.cancel();
    if (secondsLeft() <= 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {});
      if (secondsLeft() <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Separador «o» entre el ingreso con celular y Apple / Google.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          const Expanded(child: Divider(color: CQColors.line, height: 1)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('o', style: CQType.body(14, color: CQColors.muted))),
          const Expanded(child: Divider(color: CQColors.line, height: 1)),
        ]),
      );
}

/// «Continuar con Apple» (solo iOS) y «Continuar con Google». Con éxito
/// abre la sesión y va al inicio; si el cliente cancela no muestra nada.
class SocialSignIn extends ConsumerStatefulWidget {
  const SocialSignIn({super.key, this.divider = true});

  /// Muestra el separador «o» encima.
  final bool divider;

  /// Apple solo se ofrece en iPhone / iPad.
  static bool get appleAvailable => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

  @override
  ConsumerState<SocialSignIn> createState() => _SocialSignInState();
}

enum _Social { apple, google }

class _SocialSignInState extends ConsumerState<SocialSignIn> {
  _Social? _busy;

  Future<void> _signIn(_Social which) async {
    if (_busy != null) return;
    setState(() => _busy = which);
    final auth = ref.read(authProvider.notifier);
    try {
      which == _Social.apple ? await auth.signInWithApple() : await auth.signInWithGoogle();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      context.go('/home');
    } on AuthCancelled {
      // El cliente cerró la ventana: no se muestra nada.
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message, detail: e.detail, error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.divider) const OrDivider(),
        if (SocialSignIn.appleAvailable) ...[
          _SocialButton(
            label: 'Continuar con Apple',
            logo: SvgPicture.string(_appleLogo, width: 18, height: 18, colorFilter: const ColorFilter.mode(CQColors.white, BlendMode.srcIn)),
            dark: true,
            loading: _busy == _Social.apple,
            onTap: _busy == null ? () => _signIn(_Social.apple) : null,
          ),
          const SizedBox(height: 10),
        ],
        _SocialButton(
          label: 'Continuar con Google',
          logo: SvgPicture.string(_googleLogo, width: 18, height: 18),
          dark: false,
          loading: _busy == _Social.google,
          onTap: _busy == null ? () => _signIn(_Social.google) : null,
        ),
      ]);
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.logo, required this.dark, required this.loading, required this.onTap});

  final String label;
  final Widget logo;
  final bool dark;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? CQColors.white : CQColors.ink;
    return Opacity(
      opacity: onTap == null && !loading ? 0.6 : 1,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 48,
          width: double.infinity,
          decoration: BoxDecoration(
            color: dark ? Colors.black : CQColors.white,
            borderRadius: BorderRadius.circular(6),
            border: dark ? null : Border.all(color: CQColors.line, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: 18,
              height: 18,
              child: loading ? CircularProgressIndicator(strokeWidth: 2, color: fg) : logo,
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: CQType.body(16, weight: FontWeight.w600, color: fg))),
          ]),
        ),
      ),
    );
  }
}

/// Manzana de Apple (24 × 24).
const _appleLogo = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/></svg>';

/// «G» de Google a color (48 × 48).
const _googleLogo = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
    '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
    '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
    '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
    '</svg>';
