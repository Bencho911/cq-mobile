import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';

const _otpLength = 5;

/// Código de 5 dígitos que llegó por SMS.
class ConfirmOtpScreen extends StatefulWidget {
  const ConfirmOtpScreen({super.key, this.phone});

  final String? phone;

  @override
  State<ConfirmOtpScreen> createState() => _ConfirmOtpScreenState();
}

class _ConfirmOtpScreenState extends State<ConfirmOtpScreen> {
  String _otp = '';

  bool get _isComplete => _otp.length == _otpLength;

  @override
  Widget build(BuildContext context) {
    final phone = (widget.phone == null || widget.phone!.isEmpty) ? '300 000 0000' : widget.phone!;
    return AuthShell(
      tone: FacadeTone.mostaza,
      image: 'assets/brand/ventana-amarilla.webp',
      title: 'Revisa tus mensajes.',
      subtitle: PhoneSubtitle(before: 'Enviamos un código de 5 dígitos al ', phone: phone),
      onBack: () => goBack(context, fallback: '/register'),
      footer: CQButton(
        label: 'Confirmar código',
        onPressed: _isComplete ? () => context.push('/account-loading') : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CodeInput(length: _otpLength, value: _otp, onChanged: (v) => setState(() => _otp = v), label: 'Código de 5 dígitos'),
        const SizedBox(height: 12),
        // Igual que en la web, el reenvío aún no hace nada.
        AuthPrompt(question: '¿No te llegó?', link: 'Enviar otro código', onTap: () {}, center: false),
      ]),
    );
  }
}
