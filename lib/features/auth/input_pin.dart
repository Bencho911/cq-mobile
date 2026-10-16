import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/account.dart';
import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';
import 'confirm_otp.dart';

/// PIN de la cuenta del número que se escribió en Entrar. Si la cuenta
/// tiene biometría, la ofrece al abrir.
class InputPinScreen extends ConsumerStatefulWidget {
  const InputPinScreen({super.key, this.phone});

  final String? phone;

  @override
  ConsumerState<InputPinScreen> createState() => _InputPinScreenState();
}

class _InputPinScreenState extends ConsumerState<InputPinScreen> with Countdown {
  String _pin = '';
  String? _error;
  int _shakes = 0;
  bool _busy = false;

  bool get _isComplete => _pin.length == pinLength;
  bool get _blocked => PinGuard.secondsLeft > 0;

  @override
  void initState() {
    super.initState();
    startCountdown(() => PinGuard.secondsLeft);
    // Con biometría activa se ofrece de una vez.
    if (ref.read(authProvider).biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _biometrics();
      });
    }
  }

  void _changed(String v) {
    setState(() {
      _pin = v;
      _error = null;
    });
    if (_isComplete) _submit();
  }

  Future<void> _submit() async {
    if (!_isComplete || _busy || _blocked) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).loginWithPin(_pin);
      PinGuard.reset();
      HapticFeedback.lightImpact();
      if (mounted) context.go('/home');
    } on AuthException {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final locked = PinGuard.fail();
      setState(() {
        _pin = '';
        _shakes++;
        _error = locked
            ? null
            : 'El PIN no coincide. ${PinGuard.attemptsLeft == 1 ? 'Te queda 1 intento.' : 'Te quedan ${PinGuard.attemptsLeft} intentos.'}';
      });
      if (locked) startCountdown(() => PinGuard.secondsLeft);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometrics() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await ref.read(authProvider.notifier).unlockWithBiometrics();
      if (ok && mounted) {
        PinGuard.reset();
        context.go('/home');
      }
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message, detail: e.detail, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// «Olvidé mi PIN»: se envía un código al celular de la cuenta y luego
  /// se elige uno nuevo.
  void _forgot() {
    final account = ref.read(authProvider).account;
    final phone = account?.phone ?? widget.phone;
    if (account == null || phone == null) {
      showToast(context, 'No hay una cuenta en este teléfono.', detail: 'Crea una para empezar.');
      context.go('/register');
      return;
    }
    final code = ref.read(authProvider.notifier).resendOtp();
    showTestCode(context, code);
    context.push('/otp-loading', extra: OtpArgs(phone: phone, code: code, recover: true));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final phone = widget.phone ?? auth.account?.phone;
    final wait = PinGuard.secondsLeft;
    return AuthShell(
      tone: FacadeTone.verde,
      image: 'assets/brand/ventana-tucan.webp',
      title: 'Escribe tu PIN.',
      subtitle: phone != null && phone.isNotEmpty
          ? PhoneSubtitle(before: 'Para la cuenta ', phone: phone)
          : const Text('Son los 6 números que elegiste al crear tu cuenta.'),
      onBack: () => goBack(context),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        CQButton(label: 'Entrar', loading: _busy && _isComplete, onPressed: _isComplete && wait == 0 ? _submit : null),
        if (auth.biometricEnabled) ...[
          const SizedBox(height: 10),
          CQButton(
            label: 'Entrar con $biometricName',
            icon: biometricIcon,
            variant: CQButtonVariant.secondary,
            onPressed: _busy ? null : _biometrics,
          ),
        ],
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  autofocus: !auth.biometricEnabled,
                  label: 'PIN de 6 dígitos',
                ),
              ),
            ),
          ),
          AuthError(wait > 0 ? 'Demasiados intentos. Espera $wait s para volver a intentar.' : _error),
          const SizedBox(height: 12),
          AuthLink('Olvidé mi PIN', onTap: _forgot),
        ],
      ),
    );
  }
}
