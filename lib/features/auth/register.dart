import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../state/account.dart';
import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';
import 'confirm_otp.dart';

/// Registro: nombre, celular y cédula. Antes de enviar el SMS se confirma
/// el número en una hoja inferior. Si el número ya tiene cuenta en este
/// teléfono, lo avisa y ofrece entrar.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _id = TextEditingController();

  /// Número que ya tiene cuenta en este teléfono.
  String? _existing;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _phone, _id]) {
      c.addListener(() => setState(() {
            if (_phone.text != _existing) _existing = null;
          }));
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
    final auth = ref.read(authProvider);
    // Cuenta completa (con PIN) con este número: se ofrece entrar.
    if (auth.hasPin && ref.read(authProvider.notifier).hasAccountFor(phone)) {
      setState(() => _existing = phone);
      return;
    }
    final confirmed = await showCQSheet<bool>(context, (_) => _ConfirmPhoneSheet(phone: phone));
    if (confirmed != true || !mounted) return;
    final code = ref.read(authProvider.notifier).startRegistration(name: _name.text, phone: phone, cedula: _id.text.trim());
    showTestCode(context, code);
    context.push('/otp-loading', extra: OtpArgs(phone: phone, code: code));
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
          const SocialSignIn(),
          const SizedBox(height: 4),
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
          AnimatedSize(
            duration: CQMotion.reduced(context) ? Duration.zero : CQMotion.fast,
            curve: CQMotion.easeOut,
            alignment: Alignment.topCenter,
            child: _existing == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: AuthNotice(
                      title: 'Ya tienes una cuenta con este número.',
                      detail: 'Entra con tu PIN; si lo olvidaste, puedes elegir uno nuevo.',
                      action: 'Entrar',
                      onAction: () => context.push('/input-pin', extra: _existing),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          const _Terms(),
        ]),
      ),
    );
  }
}

/// Aviso legal bajo el formulario; los enlaces abren un resumen.
class _Terms extends StatefulWidget {
  const _Terms();

  @override
  State<_Terms> createState() => _TermsState();
}

class _TermsState extends State<_Terms> {
  late final _terms = TapGestureRecognizer()..onTap = () => _open(_LegalDoc.terms);
  late final _privacy = TapGestureRecognizer()..onTap = () => _open(_LegalDoc.privacy);

  void _open(_LegalDoc doc) => showCQSheet<void>(context, (_) => _LegalSheet(doc: doc));

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = CQType.body(13, weight: FontWeight.w600, height: 1.6).copyWith(decoration: TextDecoration.underline, decorationColor: CQColors.ink);
    return Text.rich(
      TextSpan(style: CQType.body(13, color: CQColors.muted, height: 1.6), children: [
        const TextSpan(text: 'Al crear tu cuenta aceptas los '),
        TextSpan(text: 'Términos de uso', style: link, recognizer: _terms),
        const TextSpan(text: ' y la '),
        TextSpan(text: 'Política de privacidad', style: link, recognizer: _privacy),
        const TextSpan(text: '.'),
      ]),
    );
  }
}

enum _LegalDoc { terms, privacy }

/// Resumen honesto de los documentos legales mientras se publica el texto completo.
class _LegalSheet extends StatelessWidget {
  const _LegalSheet({required this.doc});

  final _LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final (title, points) = switch (doc) {
      _LegalDoc.terms => (
          'Términos de uso',
          [
            'Pides y pagas en la app, y recoges en la tienda que elijas.',
            'Sumas puntos con cada pedido; con 50, tu bebida va por nuestra cuenta.',
            'Los precios y la disponibilidad dependen de cada tienda.',
          ],
        ),
      _LegalDoc.privacy => (
          'Política de privacidad',
          [
            'Tu nombre, celular y cédula se guardan en este teléfono para identificar tus pedidos.',
            'Tu PIN se guarda cifrado en el llavero del teléfono; nunca lo vemos.',
            'Puedes borrar tu cuenta y tus datos cuando quieras desde Privacidad y seguridad.',
          ],
        ),
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(width: 36, height: 4, decoration: BoxDecoration(color: CQColors.line, borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: 18),
        Semantics(header: true, child: Text(title, style: CQType.title(26, height: 1.15))),
        const SizedBox(height: 12),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('•  ', style: CQType.body(15, height: 1.5)),
              Expanded(child: Text(p, style: CQType.body(15, height: 1.5))),
            ]),
          ),
        const SizedBox(height: 4),
        Text('El documento completo estará disponible pronto en la app.', style: CQType.body(13, color: CQColors.muted, height: 1.5)),
        const SizedBox(height: 20),
        CQButton(label: 'Entendido', onPressed: () => Navigator.of(context).pop()),
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
