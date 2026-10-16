import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../widgets/controls.dart';
import 'common.dart';

typedef _Voucher = ({int id, String amount, String title, String subtitle, bool disabled, String? error});

// MOCK: el backend no expone cupones/descuentos aún.
const List<_Voucher> _vouchers = [
  (id: 1, amount: '10%', title: 'Descuento del 10%', subtitle: 'En compras desde \$20.000', disabled: false, error: null),
  (id: 2, amount: '15%', title: 'Descuento del 15%', subtitle: 'En compras desde \$25.000', disabled: false, error: null),
  (
    id: 3,
    amount: '\$75.000',
    title: 'Descuento de \$75.000',
    subtitle: 'En compras desde \$280.000',
    disabled: true,
    error: 'Te faltan \$100.000 para usar este cupón.',
  ),
  (
    id: 4,
    amount: '\$20.000',
    title: 'Descuento de \$20.000',
    subtitle: 'En compras desde \$80.000',
    disabled: true,
    error: 'Te faltan \$60.000 para usar este cupón.',
  ),
  (
    id: 5,
    amount: '30%',
    title: 'Descuento del 30%',
    subtitle: 'En compras desde \$30.000',
    disabled: true,
    error: 'Te faltan \$20.000 para usar este cupón.',
  ),
];

/// Pasa el texto a mayúsculas mientras se escribe.
class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final _code = TextEditingController();
  int? _selectedId = 2;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  // MOCK: sin endpoint de validación, cualquier código se rechaza.
  void _applyCode() {
    if (_code.text.trim().isEmpty) return;
    setState(() => _codeError = 'No encontramos ese código. Revisa que esté bien escrito e intenta de nuevo.');
  }

  @override
  Widget build(BuildContext context) {
    final selected = _vouchers.where((v) => v.id == _selectedId).firstOrNull;
    final hasCode = _code.text.trim().isNotEmpty;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: _codeError != null ? CQColors.danger : CQColors.line),
    );

    return Scaffold(
      backgroundColor: CQColors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: 'Bonos y cupones', onBack: _back),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text('¿Tienes un código?', style: CQType.body(14, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        onChanged: (_) {
                          if (_codeError != null) setState(() => _codeError = null);
                        },
                        onSubmitted: (_) => _applyCode(),
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        inputFormatters: [_UpperCase()],
                        style: CQType.number(16),
                        decoration: InputDecoration(
                          hintText: 'Ej. CAFE20',
                          hintStyle: CQType.body(16, color: CQColors.mutedSoft),
                          filled: true,
                          fillColor: CQColors.creamDeep,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: border,
                          border: border,
                          focusedBorder: border.copyWith(
                            borderSide: BorderSide(color: _codeError != null ? CQColors.danger : CQColors.ink),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CQButton(label: 'Aplicar', onPressed: hasCode ? _applyCode : null, height: 48, expand: false),
                  ],
                ),
                AnimatedSize(
                  duration: CQMotion.fast,
                  curve: CQMotion.easeOut,
                  alignment: Alignment.topLeft,
                  child: _codeError == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(_codeError!, style: CQType.body(14, color: CQColors.danger)),
                          ),
                        ),
                ),
                const SizedBox(height: 28),
                Semantics(header: true, child: Text('Tus cupones', style: CQType.title(20, height: 1.1))),
                const SizedBox(height: 4),
                for (final v in _vouchers)
                  _VoucherRow(
                    voucher: v,
                    selected: _selectedId == v.id,
                    onTap: v.disabled ? null : () => setState(() => _selectedId = v.id),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: CQButton(
          label: selected != null ? 'Usar cupón' : 'Seguir sin cupón',
          trailing: selected?.amount,
          onPressed: _back,
        ),
      ),
    );
  }
}

class _VoucherRow extends StatelessWidget {
  const _VoucherRow({required this.voucher, required this.selected, this.onTap});

  final _Voucher voucher;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CQColors.line)),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: v.disabled ? 0.5 : 1,
            child: Container(
              width: 92,
              height: 68,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: CQColors.mostazaSoft, borderRadius: BorderRadius.circular(6)),
              child: Text(v.amount, style: CQType.title(v.amount.length > 4 ? 19 : 30, height: 1)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.title,
                  style: CQType.body(16, weight: FontWeight.w700, color: v.disabled ? CQColors.muted : CQColors.ink),
                ),
                Text(v.subtitle, style: CQType.body(14, color: CQColors.muted, height: 1.25)),
                if (v.error != null) ...[
                  const SizedBox(height: 2),
                  Text(v.error!, style: CQType.body(14, color: CQColors.danger, height: 1.25)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 24,
            child: v.disabled
                ? null
                : AnimatedContainer(
                    duration: CQMotion.press,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? CQColors.ink : Colors.transparent,
                      border: selected ? null : Border.all(color: CQColors.mutedSoft, width: 1.5),
                    ),
                    child: selected ? const Icon(LucideIcons.check, size: 15, color: CQColors.white) : null,
                  ),
          ),
        ],
      ),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: !v.disabled,
      child: onTap == null ? row : Pressable(onTap: onTap, scale: 0.99, child: row),
    );
  }
}
