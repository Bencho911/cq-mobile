import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../state/account.dart';
import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';

const _otpLength = 5;
const _resendSeconds = 30;

/// Argumentos del flujo del código (/otp-loading, /confirm-otp, /create-pin).
/// Por compatibilidad, la ruta también acepta un String con el teléfono.
class OtpArgs {
  const OtpArgs({this.phone, this.code, this.recover = false});

  final String? phone;

  /// Código de prueba (MOCK: aún no hay SMS y la app lo muestra).
  final String? code;

  /// `true` en «Olvidé mi PIN»; `false` en el registro.
  final bool recover;

  static OtpArgs from(Object? extra) => switch (extra) {
        OtpArgs a => a,
        String phone => OtpArgs(phone: phone),
        _ => const OtpArgs(),
      };
}

/// Aviso honesto al «enviar» el código: aún no hay SMS.
void showTestCode(BuildContext context, String code) =>
    showToast(context, 'Te enviamos un código.', detail: 'Aún no hay SMS: tu código de prueba es $code.');

/// Código de 5 dígitos que «llegó por SMS». En el registro sigue a elegir el
/// PIN de la cuenta nueva; en «Olvidé mi PIN», a elegir uno nuevo.
class ConfirmOtpScreen extends ConsumerStatefulWidget {
  const ConfirmOtpScreen({super.key, this.phone, this.code, this.recover = false});

  final String? phone;
  final String? code;
  final bool recover;

  @override
  ConsumerState<ConfirmOtpScreen> createState() => _ConfirmOtpScreenState();
}

class _ConfirmOtpScreenState extends ConsumerState<ConfirmOtpScreen> with Countdown {
  String _otp = '';
  String? _error;
  int _shakes = 0;
  late String _code;
  late DateTime _resendAt;

  bool get _isComplete => _otp.length == _otpLength;

  int _resendLeft() {
    final left = _resendAt.difference(DateTime.now()).inMilliseconds;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    // Si se llega sin código (p. ej. enlace directo), se genera uno.
    _code = widget.code ?? ref.read(authProvider.notifier).resendOtp();
    _resendAt = DateTime.now().add(const Duration(seconds: _resendSeconds));
    startCountdown(_resendLeft);
  }

  void _changed(String v) {
    setState(() {
      _otp = v;
      _error = null;
    });
    if (_isComplete) _confirm();
  }

  void _confirm() {
    if (!_isComplete) return;
    if (!ref.read(authProvider.notifier).verifyOtp(_otp)) {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = 'El código no coincide. Revísalo e inténtalo de nuevo.';
        _otp = '';
        _shakes++;
      });
      return;
    }
    HapticFeedback.lightImpact();
    // El aviso del código ya no hace falta y taparía el botón del PIN.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // Reemplaza el código: al volver desde el PIN no se pide otra vez.
    context.pushReplacement('/create-pin', extra: OtpArgs(phone: widget.phone, recover: widget.recover));
  }

  void _resend() {
    final code = ref.read(authProvider.notifier).resendOtp();
    setState(() {
      _code = code;
      _otp = '';
      _error = null;
      _resendAt = DateTime.now().add(const Duration(seconds: _resendSeconds));
    });
    startCountdown(_resendLeft);
    showTestCode(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.phone ?? ref.watch(authProvider).account?.phone ?? '';
    final left = _resendLeft();
    return AuthShell(
      tone: FacadeTone.mostaza,
      image: 'assets/brand/ventana-amarilla.webp',
      title: widget.recover ? 'Confirma que eres tú.' : 'Revisa tus mensajes.',
      subtitle: phone.isEmpty
          ? const Text('Enviamos un código de 5 dígitos a tu celular.')
          : PhoneSubtitle(before: 'Enviamos un código de 5 dígitos al ', phone: phone),
      onBack: () => goBack(context, fallback: widget.recover ? '/login' : '/register'),
      footer: CQButton(label: 'Confirmar código', onPressed: _isComplete ? _confirm : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Shake(
          trigger: _shakes,
          child: CodeInput(length: _otpLength, value: _otp, onChanged: _changed, label: 'Código de 5 dígitos'),
        ),
        AuthError(_error),
        const SizedBox(height: 12),
        // MOCK: sin SMS real, el código se muestra aquí de forma discreta.
        Text('Código de prueba: $_code', style: CQType.number(14, color: CQColors.muted)),
        if (left > 0)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Puedes pedir otro código en $left s', style: CQType.body(15, color: CQColors.muted)),
            ),
          )
        else
          AuthPrompt(question: '¿No te llegó?', link: 'Enviar otro código', onTap: _resend, center: false),
      ]),
    );
  }
}
