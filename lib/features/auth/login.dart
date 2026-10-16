import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';

/// Entrada con el celular; el PIN se pide en la siguiente pantalla.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phone.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  int get _missing => phoneLength - _phone.text.length;
  bool get _isValid => _missing <= 0;

  String get _helper {
    if (_phone.text.isEmpty) return 'Sin espacios ni guiones.';
    if (_isValid) return 'Listo.';
    return 'Faltan $_missing ${_missing == 1 ? 'dígito' : 'dígitos'}.';
  }

  void _submit() {
    if (_isValid) context.push('/input-pin', extra: _phone.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      tone: FacadeTone.verde,
      image: 'assets/brand/ventana-tucan.webp',
      title: 'Entra con tu celular.',
      subtitle: const Text('Te pediremos tu PIN de 6 dígitos.'),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        CQButton(label: 'Continuar', onPressed: _isValid ? _submit : null),
        if (!keyboardOpen(context)) ...[
          const SizedBox(height: 8),
          AuthPrompt(question: '¿Primera vez?', link: 'Crea tu cuenta', onTap: () => context.push('/register')),
        ],
      ]),
      child: AutofillGroup(
        child: AuthField(
          label: 'Número de celular',
          controller: _phone,
          prefix: '+57',
          hint: '300 000 0000',
          helper: _helper,
          numeric: true,
          height: 52,
          borderColor: Colors.transparent,
          keyboardType: TextInputType.phone,
          inputFormatters: digitsOnly(phoneLength),
          autofillHints: const [AutofillHints.telephoneNumberNational],
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
        ),
      ),
    );
  }
}
