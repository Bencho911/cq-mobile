import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../state/account.dart';
import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';

/// Sesión bloqueada: saluda por el nombre y pide Face ID / huella al
/// entrar; el PIN queda como alternativa. Al desbloquear, el router lleva
/// solo al inicio.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> with Countdown {
  bool _usePin = false;
  bool _busy = false;
  String _pin = '';
  String? _error;
  int _shakes = 0;

  @override
  void initState() {
    super.initState();
    startCountdown(() => PinGuard.secondsLeft);
    final auth = ref.read(authProvider);
    if (auth.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _biometrics();
      });
    } else {
      _usePin = true;
    }
  }

  Future<void> _biometrics() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await ref.read(authProvider.notifier).unlockWithBiometrics();
      if (ok) {
        PinGuard.reset();
        HapticFeedback.lightImpact();
      }
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message, detail: e.detail, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changed(String v) {
    setState(() {
      _pin = v;
      _error = null;
    });
    if (v.length == pinLength) _submitPin();
  }

  Future<void> _submitPin() async {
    if (_busy || PinGuard.secondsLeft > 0) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).unlockWithPin(_pin);
      PinGuard.reset();
      HapticFeedback.lightImpact();
    } on AuthException {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final locked = PinGuard.fail();
      setState(() {
        _pin = '';
        _shakes++;
        _error = locked ? null : 'El PIN no coincide.';
      });
      if (locked) startCountdown(() => PinGuard.secondsLeft);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showCQSheet<bool>(context, (_) => const _LogoutSheet());
    if (ok == true) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final name = auth.account?.firstName ?? '';
    final wait = PinGuard.secondsLeft;
    final canPin = auth.hasPin;
    final showPin = _usePin && canPin;
    return AuthShell(
      tone: FacadeTone.verde,
      image: 'assets/brand/ventana-tucan.webp',
      title: name.isEmpty ? 'Hola de nuevo.' : 'Hola, $name.',
      subtitle: Text(showPin ? 'Escribe tu PIN de 6 dígitos para seguir.' : 'Confirma que eres tú para seguir.'),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        if (auth.biometricEnabled)
          CQButton(
            label: 'Entrar con $biometricName',
            icon: biometricIcon,
            loading: _busy && !showPin,
            variant: showPin ? CQButtonVariant.secondary : CQButtonVariant.primary,
            onPressed: _biometrics,
          ),
        if (canPin && !showPin) ...[
          const SizedBox(height: 10),
          CQButton(label: 'Usar mi PIN', variant: CQButtonVariant.secondary, onPressed: () => setState(() => _usePin = true)),
        ],
        const SizedBox(height: 4),
        AuthPrompt(question: '¿No eres tú?', link: 'Cerrar sesión', onTap: _logout),
      ]),
      child: AnimatedSwitcher(
        duration: CQMotion.reduced(context) ? Duration.zero : CQMotion.fast,
        child: !showPin
            ? const SizedBox(key: ValueKey('bio'), width: double.infinity)
            : Column(key: const ValueKey('pin'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                Shake(
                  trigger: _shakes,
                  child: IgnorePointer(
                    ignoring: wait > 0,
                    child: Opacity(
                      opacity: wait > 0 ? 0.5 : 1,
                      child: CodeInput(
                        autofillHints: const [AutofillHints.password],
                        length: pinLength,
                        value: _pin,
                        onChanged: _changed,
                        secret: true,
                        label: 'PIN de 6 dígitos',
                      ),
                    ),
                  ),
                ),
                AuthError(wait > 0 ? 'Demasiados intentos. Espera $wait s para volver a intentar.' : _error),
              ]),
      ),
    );
  }
}

/// Confirma el cierre de sesión; la cuenta y sus datos quedan en el teléfono.
class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(width: 36, height: 4, decoration: BoxDecoration(color: CQColors.line, borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: 18),
        Semantics(header: true, child: Text('¿Cerrar sesión?', style: CQType.title(26, height: 1.15))),
        const SizedBox(height: 8),
        Text('Tu cuenta y tus pedidos quedan guardados en este teléfono para cuando vuelvas.',
            style: CQType.body(15, color: CQColors.muted, height: 1.6)),
        const SizedBox(height: 24),
        CQButton(label: 'Cerrar sesión', variant: CQButtonVariant.danger, onPressed: () => Navigator.of(context).pop(true)),
        const SizedBox(height: 6),
        Pressable(
          onTap: () => Navigator.of(context).pop(false),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: Center(child: Text('Cancelar', style: CQType.body(16, weight: FontWeight.w600))),
          ),
        ),
      ]),
    );
  }
}
