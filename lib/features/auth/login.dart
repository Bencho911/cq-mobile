import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/motion.dart';
import '../../state/account.dart';
import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';

/// Entrada con el celular (el PIN se pide en la siguiente pantalla) o con
/// Apple / Google.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();

  /// Número que se buscó y no tiene cuenta en este teléfono.
  String? _notFound;

  @override
  void initState() {
    super.initState();
    _phone.addListener(() => setState(() {
          if (_phone.text != _notFound) _notFound = null;
        }));
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
    if (!_isValid) return;
    final phone = _phone.text;
    if (ref.read(authProvider.notifier).hasAccountFor(phone)) {
      setState(() => _notFound = null);
      context.push('/input-pin', extra: phone);
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _notFound = phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = keyboardOpen(context);
    return AuthShell(
      tone: FacadeTone.verde,
      image: 'assets/brand/ventana-tucan.webp',
      title: 'Entra con tu celular.',
      subtitle: const Text('Te pediremos tu PIN de 6 dígitos.'),
      onBack: GoRouter.maybeOf(context)?.canPop() == true ? () => context.pop() : null,
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        CQButton(label: 'Continuar', onPressed: _isValid ? _submit : null),
        if (!keyboard) ...[
          const SocialSignIn(),
          const SizedBox(height: 4),
          AuthPrompt(question: '¿Primera vez?', link: 'Crea tu cuenta', onTap: () => context.push('/register')),
        ],
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AutofillGroup(
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
        AnimatedSize(
          duration: CQMotion.reduced(context) ? Duration.zero : CQMotion.fast,
          curve: CQMotion.easeOut,
          alignment: Alignment.topCenter,
          child: _notFound == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AuthNotice(
                    title: 'No encontramos una cuenta con ese número en este teléfono.',
                    detail: 'Por ahora tu cuenta vive en el teléfono donde la creaste.',
                    action: 'Crear cuenta',
                    onAction: () => context.push('/register'),
                  ),
                ),
        ),
      ]),
    );
  }
}
