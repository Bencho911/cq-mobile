import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';

const _pinLength = 6;

/// PIN de la cuenta del número que se escribió en Entrar.
class InputPinScreen extends StatefulWidget {
  const InputPinScreen({super.key, this.phone});

  final String? phone;

  @override
  State<InputPinScreen> createState() => _InputPinScreenState();
}

class _InputPinScreenState extends State<InputPinScreen> {
  String _pin = '';

  bool get _isComplete => _pin.length == _pinLength;

  @override
  Widget build(BuildContext context) {
    final phone = widget.phone;
    return AuthShell(
      tone: FacadeTone.verde,
      image: 'assets/brand/ventana-tucan.webp',
      title: 'Escribe tu PIN.',
      subtitle: phone != null && phone.isNotEmpty
          ? PhoneSubtitle(before: 'Para la cuenta ', phone: phone)
          : const Text('Son los 6 números que elegiste al crear tu cuenta.'),
      onBack: () => goBack(context),
      footer: CQButton(label: 'Entrar', onPressed: _isComplete ? () => context.go('/home') : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CodeInput(
            autofillHints: const [AutofillHints.password],
            length: _pinLength,
            value: _pin,
            onChanged: (v) => setState(() => _pin = v),
            secret: true,
            label: 'PIN de 6 dígitos',
          ),
          const SizedBox(height: 12),
          // Igual que en la web, la recuperación del PIN aún no hace nada.
          AuthLink('Olvidé mi PIN', onTap: () {}),
        ],
      ),
    );
  }
}
