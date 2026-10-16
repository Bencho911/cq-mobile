import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../widgets/controls.dart';
import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'auth_widgets.dart';

const _pinLength = 6;

/// Último paso del registro: elegir el PIN de 6 números.
class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String _pin = '';
  bool _showPin = false;

  bool get _isComplete => _pin.length == _pinLength;

  void _save() {
    HapticFeedback.lightImpact();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      tone: FacadeTone.rosa,
      image: 'assets/brand/capibara-palmas.webp',
      title: 'Elige un PIN.',
      subtitle: const Text('6 números que solo tú conozcas. Los usarás para entrar.'),
      onBack: () => goBack(context, fallback: '/register'),
      footer: CQButton(label: 'Guardar PIN', onPressed: _isComplete ? _save : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CodeInput(
            autofillHints: const [AutofillHints.newPassword],
            length: _pinLength,
            value: _pin,
            onChanged: (v) => setState(() => _pin = v),
            secret: !_showPin,
            label: 'Nuevo PIN de 6 dígitos',
          ),
          const SizedBox(height: 12),
          Pressable(
            onTap: () => setState(() => _showPin = !_showPin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: CQMotion.reduced(context) ? Duration.zero : CQMotion.fast,
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
