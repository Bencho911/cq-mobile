import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';

/// Registro: nombre, celular y cédula. Antes de enviar el SMS se confirma
/// el número en una hoja inferior.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _id = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _phone, _id]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _id.dispose();
    super.dispose();
  }

  bool get _isValid => _name.text.trim().isNotEmpty && _phone.text.length >= phoneLength && _id.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid) return;
    FocusScope.of(context).unfocus();
    final phone = _phone.text;
    final confirmed = await showCQSheet<bool>(context, (_) => _ConfirmPhoneSheet(phone: phone));
    if (confirmed == true && mounted) context.push('/otp-loading', extra: phone);
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      tone: FacadeTone.mostaza,
      image: 'assets/brand/ventana-amarilla.webp',
      title: 'Crea tu cuenta.',
      subtitle: const Text('Con ella sumas puntos en cada pedido.'),
      onBack: () => context.go('/login'),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        CQButton(label: 'Crear cuenta', onPressed: _isValid ? _submit : null),
        if (!keyboardOpen(context)) ...[
          const SizedBox(height: 8),
          AuthPrompt(question: '¿Ya tienes cuenta?', link: 'Entra', onTap: () => context.go('/login')),
        ],
      ]),
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AuthField(
            label: 'Nombre',
            controller: _name,
            hint: 'Como quieres que te llamemos',
            autofillHints: const [AutofillHints.givenName],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Número de celular',
            controller: _phone,
            hint: '300 000 0000',
            helper: 'Te enviaremos un código por SMS.',
            numeric: true,
            keyboardType: TextInputType.phone,
            inputFormatters: digitsOnly(phoneLength),
            autofillHints: const [AutofillHints.telephoneNumberNational],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Cédula',
            controller: _id,
            hint: 'Solo números',
            numeric: true,
            keyboardType: TextInputType.number,
            inputFormatters: digitsOnly(),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          const _Terms(),
        ]),
      ),
    );
  }
}

/// Aviso legal bajo el formulario.
class _Terms extends StatelessWidget {
  const _Terms();

  @override
  Widget build(BuildContext context) {
    final link = CQType.body(13, weight: FontWeight.w600, height: 1.6).copyWith(decoration: TextDecoration.underline, decorationColor: CQColors.ink);
    return Text.rich(
      TextSpan(style: CQType.body(13, color: CQColors.muted, height: 1.6), children: [
        const TextSpan(text: 'Al crear tu cuenta aceptas los '),
        TextSpan(text: 'Términos de uso', style: link),
        const TextSpan(text: ' y la '),
        TextSpan(text: 'Política de privacidad', style: link),
        const TextSpan(text: '.'),
      ]),
    );
  }
}

/// Hoja para confirmar el número antes de enviar el SMS (OTPModal en la web).
/// Devuelve `true` si el cliente confirma.
class _ConfirmPhoneSheet extends StatelessWidget {
  const _ConfirmPhoneSheet({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Agarradera: la hoja se cierra arrastrando hacia abajo.
        Center(
          child: Container(width: 36, height: 4, decoration: BoxDecoration(color: CQColors.line, borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: 18),
        Semantics(header: true, child: Text('¿Este es tu número?', style: CQType.title(26, height: 1.15))),
        const SizedBox(height: 8),
        Text('+57 ${phone.isEmpty ? '—' : phone}', style: CQType.number(22)),
        const SizedBox(height: 8),
        Text('Te enviaremos un código por SMS para confirmar que es tuyo.', style: CQType.body(15, color: CQColors.muted, height: 1.6)),
        const SizedBox(height: 24),
        CQButton(
          label: 'Sí, enviar código',
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop(true);
          },
        ),
        const SizedBox(height: 6),
        Pressable(
          onTap: () => Navigator.of(context).pop(false),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: Center(child: Text('Corregir número', style: CQType.body(16, weight: FontWeight.w600))),
          ),
        ),
      ]),
    );
  }
}
