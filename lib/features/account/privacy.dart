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
import 'common.dart';

const _pinLength = 6;

/// Privacidad y seguridad: PIN, biometría, documentos legales y baja.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  /// ¿El teléfono tiene Face ID / huella? `null` mientras se consulta.
  bool? _available;
  bool _bioBusy = false;

  @override
  void initState() {
    super.initState();
    ref.read(authProvider.notifier).biometricsAvailable().then((v) {
      if (mounted) setState(() => _available = v);
    });
  }

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  Future<void> _setBiometric(bool v) async {
    setState(() => _bioBusy = true);
    try {
      await ref.read(authProvider.notifier).setBiometric(v);
      if (mounted) showToast(context, v ? 'Listo: entras con biometría.' : 'Desactivamos la biometría.');
    } on AuthCancelled {
      // El cliente canceló: no cambia nada.
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message, detail: e.detail, error: true);
    } catch (_) {
      if (mounted) showToast(context, 'No pudimos usar la biometría.', detail: 'Inténtalo de nuevo en un momento.', error: true);
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  Future<void> _changePin(bool hasPin) async {
    final changed = await showCQSheet<bool>(context, (_) => _ChangePinSheet(hasPin: hasPin));
    if ((changed ?? false) && mounted) showToast(context, hasPin ? 'Cambiamos tu PIN.' : 'Listo: ya tienes PIN.');
  }

  Future<void> _deleteAccount() async {
    final ok = await confirmSheet(
      context,
      title: '¿Eliminar tu cuenta?',
      message: 'Se borran de este teléfono tus datos, tu PIN, tu historial de pedidos y tus puntos. No se puede deshacer.',
      confirmLabel: 'Sí, eliminar mi cuenta',
      danger: true,
    );
    // El router lleva a la bienvenida al quedar sin sesión.
    if (ok) await ref.read(authProvider.notifier).deleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final unavailable = _available == false;

    return Scaffold(
      body: ListView(padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.paddingOf(context).bottom + 80), children: [
        PageHeader(title: 'Privacidad y seguridad', onBack: _back),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Seguridad de la cuenta', style: CQType.title(20, height: 1.1)),
            const SizedBox(height: 4),
            ListRow(
              icon: LucideIcons.lock,
              label: auth.hasPin ? 'Cambiar PIN' : 'Crear PIN',
              description: auth.hasPin ? 'Actualiza tu código de acceso' : 'Un código de 6 números para entrar',
              onTap: () => _changePin(auth.hasPin),
            ),
            SwitchRow(
              icon: LucideIcons.fingerprint,
              label: 'Entrar con biometría',
              description: unavailable ? 'Este teléfono no tiene Face ID ni huella configurados' : 'Face ID o huella',
              value: auth.biometricEnabled && !unavailable,
              busy: _bioBusy || _available == null,
              onChanged: unavailable ? null : _setBiometric,
            ),
            const SizedBox(height: 28),
            Text('Legal y políticas', style: CQType.title(20, height: 1.1)),
            const SizedBox(height: 4),
            ListRow(
              icon: LucideIcons.fileText,
              label: 'Términos y condiciones',
              onTap: () => showCQSheet<void>(context, (_) => const _LegalSheet(title: 'Términos y condiciones', paragraphs: _terms)),
            ),
            ListRow(
              icon: LucideIcons.shieldAlert,
              label: 'Política de privacidad',
              onTap: () => showCQSheet<void>(context, (_) => const _LegalSheet(title: 'Política de privacidad', paragraphs: _privacy)),
            ),
            const SizedBox(height: 28),
            PlainRow(icon: LucideIcons.trash2, label: 'Eliminar mi cuenta', danger: true, onTap: _deleteAccount),
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

// PENDIENTE (legal): textos breves provisionales hasta tener los documentos oficiales.
const _terms = [
  'Café Quindío te permite pedir en nuestras tiendas desde la app, pagar y recoger tu pedido en la barra.',
  'Los precios y la disponibilidad de los productos pueden cambiar sin previo aviso. El precio que pagas es el que ves al confirmar el pedido.',
  'Los puntos del álbum de aves son personales, no se pueden cambiar por dinero y se canjean por bebidas según las reglas del programa.',
  'Si tienes un problema con tu pedido, acércate a la tienda o escríbenos por nuestros canales de atención.',
];

const _privacy = [
  'Guardamos tu nombre, celular, cédula y correo para identificarte, emitir tus recibos y darte tus puntos.',
  'Tu PIN se guarda cifrado en el llavero seguro de tu teléfono; nunca lo vemos. Face ID y la huella los maneja tu teléfono: Café Quindío no recibe tus datos biométricos.',
  'Tu historial de pedidos, tus puntos y tus preferencias viven en este teléfono. Puedes borrarlos cuando quieras con "Eliminar mi cuenta".',
  'No vendemos tus datos. Puedes pedir que los corrijamos o eliminemos según la Ley 1581 de 2012 de protección de datos personales.',
];

/// Hoja con un texto legal breve.
class _LegalSheet extends StatelessWidget {
  const _LegalSheet({required this.title, required this.paragraphs});
  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Text(title, style: CQType.title(26, height: 1.05)),
          const SizedBox(height: 4),
          Text('Versión resumida', style: CQType.body(14, color: CQColors.muted)),
          const SizedBox(height: 16),
          for (final p in paragraphs)
            Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(p, style: CQType.body(16, height: 1.55))),
          const SizedBox(height: 8),
          CQButton(label: 'Entendido', variant: CQButtonVariant.secondary, onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

enum _PinStep { current, fresh, confirm }

/// Cambiar PIN en tres pasos: actual, nuevo y confirmación. Sin PIN
/// (cuenta de Google o Apple) arranca en el nuevo.
class _ChangePinSheet extends ConsumerStatefulWidget {
  const _ChangePinSheet({required this.hasPin});
  final bool hasPin;

  @override
  ConsumerState<_ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends ConsumerState<_ChangePinSheet> {
  late var _step = widget.hasPin ? _PinStep.current : _PinStep.fresh;
  String _pin = '';
  String _fresh = '';
  String? _error;
  bool _busy = false;

  (String, String) get _texts => switch (_step) {
        _PinStep.current => ('Escribe tu PIN actual', 'Para confirmar que eres tú.'),
        _PinStep.fresh => ('Elige tu nuevo PIN', 'Seis números que recuerdes fácil.'),
        _PinStep.confirm => ('Repite el nuevo PIN', 'Para estar seguros.'),
      };

  Future<void> _onChanged(String v) async {
    setState(() {
      _pin = v;
      _error = null;
    });
    if (v.length < _pinLength || _busy) return;
    switch (_step) {
      case _PinStep.current:
        setState(() => _busy = true);
        final ok = await ref.read(authProvider.notifier).checkPin(v);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _pin = '';
          if (ok) {
            _step = _PinStep.fresh;
          } else {
            _error = 'El PIN no coincide. Inténtalo de nuevo.';
            HapticFeedback.mediumImpact();
          }
        });
      case _PinStep.fresh:
        setState(() {
          _fresh = v;
          _pin = '';
          _step = _PinStep.confirm;
        });
      case _PinStep.confirm:
        if (v != _fresh) {
          HapticFeedback.mediumImpact();
          setState(() {
            _pin = '';
            _fresh = '';
            _step = _PinStep.fresh;
            _error = 'Los PIN no coinciden. Elige uno nuevo otra vez.';
          });
          return;
        }
        setState(() => _busy = true);
        await ref.read(authProvider.notifier).setPin(v);
        if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _texts;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom + 24),
      child: AnimatedSwitcher(
        duration: CQMotion.reduced(context) ? Duration.zero : CQMotion.fast,
        child: Column(
          key: ValueKey(_step),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: CQType.title(26, height: 1.05)),
            const SizedBox(height: 6),
            Text(subtitle, style: CQType.body(15, color: CQColors.muted)),
            const SizedBox(height: 20),
            CodeInput(
              length: _pinLength,
              value: _pin,
              secret: true,
              label: title,
              autofillHints: [_step == _PinStep.current ? AutofillHints.password : AutofillHints.newPassword],
              onChanged: _onChanged,
            ),
            SizedBox(
              height: 36,
              child: Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error ?? '', style: CQType.body(14, color: CQColors.danger)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
