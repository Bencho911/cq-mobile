import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../state/account.dart';
import '../../state/preferences.dart';
import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import 'common.dart';

/// Editar perfil: nombre, celular, cédula y correo (guardados en el teléfono).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final UserAccount? _initial = ref.read(authProvider).account;
  late final _name = TextEditingController(text: _initial?.name ?? '');
  late final _phone = TextEditingController(text: _initial?.phone ?? '');
  late final _cedula = TextEditingController(text: _initial?.cedula ?? '');
  late final _email = TextEditingController(text: _initial?.email ?? '');

  /// Errores visibles solo después de intentar guardar.
  bool _tried = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _cedula, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? get _nameError => _name.text.trim().length < 2 ? 'Escribe tu nombre.' : null;

  String? get _phoneError {
    final p = _phone.text;
    if (p.isEmpty) return null;
    return p.length != 10 || !p.startsWith('3') ? 'El celular tiene 10 dígitos y empieza por 3.' : null;
  }

  String? get _cedulaError {
    final c = _cedula.text;
    if (c.isEmpty) return null;
    return c.length < 6 || c.length > 10 ? 'La cédula tiene entre 6 y 10 dígitos.' : null;
  }

  String? get _emailError {
    final e = _email.text.trim();
    if (e.isEmpty) return null;
    return _emailRe.hasMatch(e) ? null : 'Revisa el correo.';
  }

  bool get _valid => _nameError == null && _phoneError == null && _cedulaError == null && _emailError == null;

  void _save() {
    setState(() => _tried = true);
    if (!_valid) return;
    FocusScope.of(context).unfocus();
    String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
    ref.read(authProvider.notifier).updateProfile(
          name: _name.text.trim(),
          phone: orNull(_phone.text),
          cedula: orNull(_cedula.text),
          email: orNull(_email.text),
        );
    if (ref.read(preferencesProvider).haptics) HapticFeedback.lightImpact();
    showToast(context, 'Guardamos tus datos.');
    _back();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/profile');

  @override
  Widget build(BuildContext context) {
    void changed(String _) => setState(() {});
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            PageHeader(title: 'Editar perfil', onBack: _back),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Field(
                    error: _tried ? _nameError : null,
                    child: CQTextField(
                      label: 'Nombre completo',
                      controller: _name,
                      hint: 'Como quieres que te llamemos',
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      onChanged: changed,
                    ),
                  ),
                  _Field(
                    error: _tried ? _phoneError : null,
                    child: CQTextField(
                      label: 'Celular',
                      controller: _phone,
                      hint: '300 000 0000',
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumberNational],
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 8),
                        child: Text('+57', style: CQType.number(17, color: CQColors.muted).copyWith(fontWeight: FontWeight.w400)),
                      ),
                      onChanged: changed,
                    ),
                  ),
                  _Field(
                    error: _tried ? _cedulaError : null,
                    child: CQTextField(
                      label: 'Cédula',
                      controller: _cedula,
                      hint: 'Solo números',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      onChanged: changed,
                    ),
                  ),
                  _Field(
                    error: _tried ? _emailError : null,
                    child: CQTextField(
                      label: 'Correo',
                      controller: _email,
                      hint: 'tu@correo.com',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.done,
                      onChanged: changed,
                    ),
                  ),
                  Text(
                    'Tus datos se guardan en este teléfono. Los usamos en tus recibos y para reconocerte en la tienda.',
                    style: CQType.body(14, color: CQColors.muted, height: 1.5),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: BottomActionBar(child: CQButton(label: 'Guardar cambios', onPressed: _save)),
      ),
    );
  }
}

/// Campo con su mensaje de error debajo.
class _Field extends StatelessWidget {
  const _Field({required this.child, this.error});
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Semantics(liveRegion: true, child: Text(error!, style: CQType.body(14, color: CQColors.danger))),
          ),
      ]),
    );
  }
}
