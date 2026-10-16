import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../widgets/controls.dart';
import 'common.dart';

/// Privacidad y seguridad: PIN, biometría, documentos legales y baja.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  // MOCK: preferencia local hasta que exista el ajuste en el backend.
  bool _biometrics = true;

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.paddingOf(context).bottom + 80), children: [
        PageHeader(title: 'Privacidad y seguridad', onBack: _back),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Seguridad de la cuenta', style: CQType.title(20, height: 1.1)),
            const SizedBox(height: 4),
            ListRow(icon: LucideIcons.lock, label: 'Cambiar PIN', description: 'Actualiza tu código de acceso', onTap: () {}),
            _SwitchRow(
              icon: LucideIcons.fingerprint,
              label: 'Entrar con biometría',
              description: 'Face ID o huella',
              value: _biometrics,
              onChanged: (v) => setState(() => _biometrics = v),
            ),
            const SizedBox(height: 28),
            Text('Legal y políticas', style: CQType.title(20, height: 1.1)),
            const SizedBox(height: 4),
            ListRow(icon: LucideIcons.fileText, label: 'Términos y condiciones', onTap: () {}),
            ListRow(icon: LucideIcons.shieldAlert, label: 'Política de privacidad', onTap: () {}),
            const SizedBox(height: 28),
            PlainRow(icon: LucideIcons.trash2, label: 'Eliminar mi cuenta', danger: true, onTap: () {}),
            Text(
              'Se borran tus datos, tu historial de pedidos y tus puntos. No se puede deshacer.',
              style: CQType.body(14, color: CQColors.muted, height: 1.6),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Fila con interruptor: toda la fila lo cambia.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.label, required this.description, required this.value, required this.onChanged});

  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = CQMotion.reduced(context) ? Duration.zero : CQMotion.fast;
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
          child: Row(children: [
            Icon(icon, size: 20, color: CQColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: CQType.body(16)),
                Text(description, style: CQType.body(14, color: CQColors.muted)),
              ]),
            ),
            SizedBox(
              width: 56,
              height: 44,
              child: Center(
                child: AnimatedContainer(
                  duration: duration,
                  width: 50,
                  height: 30,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: value ? CQColors.ink : CQColors.mutedSoft, borderRadius: BorderRadius.circular(15)),
                  child: AnimatedAlign(
                    duration: duration,
                    curve: CQMotion.easeOut,
                    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: CQColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 2, offset: Offset(0, 1))],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
