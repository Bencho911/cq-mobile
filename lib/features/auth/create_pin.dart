import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../state/account.dart';
import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';

/// Elegir el PIN de 6 números (último paso del registro o de «Olvidé mi
/// PIN»): se escribe y se confirma; al guardarlo se abre la sesión.
class CreatePinScreen extends ConsumerStatefulWidget {
  const CreatePinScreen({super.key, this.recover = false});

  /// `true` si viene de «Olvidé mi PIN».
  final bool recover;

  @override
  ConsumerState<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends ConsumerState<CreatePinScreen> {
  String _pin = '';
  String _confirm = '';

  /// Segundo paso: repetir el PIN.
  bool _confirming = false;
  bool _showPin = false;
  bool _saving = false;
  String? _error;
  int _shakes = 0;

  String get _value => _confirming ? _confirm : _pin;
  bool get _isComplete => _value.length == pinLength;

  void _changed(String v) => setState(() {
        if (_confirming) {
          _confirm = v;
        } else {
          _pin = v;
        }
        _error = null;
      });

  void _next() {
    if (!_isComplete) return;
    if (!_confirming) {
      setState(() {
        _confirming = true;
        _confirm = '';
      });
      return;
    }
    if (_confirm != _pin) {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = 'Los PIN no coinciden. Escríbelo otra vez.';
        _confirm = '';
        _shakes++;
      });
      return;
    }
    _save();
  }

  Future<void> _save() async {
    if (ref.read(authProvider).account == null) {
      showToast(context, 'No encontramos tu registro.', detail: 'Vuelve a crear tu cuenta.', error: true);
      context.go('/register');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).setPin(_pin);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, 'No pudimos guardar tu PIN.', detail: 'Inténtalo de nuevo.', error: true);
      return;
    }
    if (!mounted) return;
    PinGuard.reset();
    HapticFeedback.lightImpact();
    if (widget.recover) {
      showToast(context, 'Listo, tu PIN nuevo quedó guardado.');
      context.go('/home');
    } else {
      context.go('/account-loading');
    }
  }

  void _back() {
    // En la confirmación, «volver» regresa a elegir el PIN.
    if (_confirming) {
      setState(() {
        _confirming = false;
        _confirm = '';
        _error = null;
      });
    } else {
      goBack(context, fallback: widget.recover ? '/login' : '/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = CQMotion.reduced(context);
    return AuthShell(
      tone: FacadeTone.rosa,
      image: 'assets/brand/capibara-palmas.webp',
      title: _confirming ? 'Confirma tu PIN.' : (widget.recover ? 'Elige un PIN nuevo.' : 'Elige un PIN.'),
      subtitle: Text(_confirming
          ? 'Escríbelo otra vez para asegurarnos.'
          : '6 números que solo tú conozcas. Los usarás para entrar.'),
      onBack: _back,
      footer: CQButton(
        label: _confirming ? 'Guardar PIN' : 'Continuar',
        loading: _saving,
        onPressed: _isComplete ? _next : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shake(
            trigger: _shakes,
            child: AnimatedSwitcher(
              duration: reduced ? Duration.zero : CQMotion.fast,
              child: CodeInput(
                key: ValueKey(_confirming),
                autofillHints: const [AutofillHints.newPassword],
                length: pinLength,
                value: _value,
                onChanged: _changed,
                secret: !_showPin,
                label: _confirming ? 'Confirma el PIN de 6 dígitos' : 'Nuevo PIN de 6 dígitos',
              ),
            ),
          ),
          AuthError(_error),
          const SizedBox(height: 12),
          Pressable(
            onTap: () => setState(() => _showPin = !_showPin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: reduced ? Duration.zero : CQMotion.fast,
                    child: Icon(_showPin ? LucideIcons.eyeOff : LucideIcons.eye, key: ValueKey(_showPin), size: 20, color: CQColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Text(_showPin ? 'Ocultar PIN' : 'Mostrar PIN', style: CQType.body(15, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
