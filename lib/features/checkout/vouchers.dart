import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../state/cart.dart';
import '../../widgets/controls.dart';
import 'common.dart';
import 'discounts.dart';

/// Pasa el texto a mayúsculas mientras se escribe.
class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Bonos y cupones: el elegido se aplica al total del carrito.
class VouchersScreen extends ConsumerStatefulWidget {
  const VouchersScreen({super.key});

  @override
  ConsumerState<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends ConsumerState<VouchersScreen> {
  final _code = TextEditingController();
  late int? _selectedId = ref.read(appliedVoucherProvider)?.id;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  /// Con el carrito vacío no se valida el mínimo: se valida al pagar.
  int _missing(Voucher v) {
    final cart = ref.read(cartProvider);
    return cart.items.isEmpty ? 0 : v.missing(cart.subtotal);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  // MOCK: sin endpoint de validación, el código se busca en la lista local.
  void _applyCode() {
    if (_code.text.trim().isEmpty) return;
    final v = voucherByCode(_code.text);
    if (v == null) {
      setState(() => _codeError = 'No encontramos ese código. Revisa que esté bien escrito e intenta de nuevo.');
      return;
    }
    final missing = _missing(v);
    if (missing > 0) {
      setState(() => _codeError = 'Te faltan ${formatCOP(missing)} para usar este cupón.');
      return;
    }
    FocusScope.of(context).unfocus();
    _code.clear();
    setState(() {
      _codeError = null;
      _selectedId = v.id;
    });
    showToast(context, 'Cupón ${v.code} listo', detail: '${v.title}. Toca «Usar cupón» para aplicarlo.');
  }

  void _confirm() {
    final v = voucherById(_selectedId);
    final applied = ref.read(appliedVoucherProvider.notifier);
    if (v == null) {
      applied.clear();
    } else {
      applied.apply(v);
    }
    _back();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cartProvider.select((c) => c.subtotal));
    final selected = voucherById(_selectedId);
    final shown = [for (final v in vouchers) if (v.listed || v.id == _selectedId) v];
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
                for (final v in shown)
                  _VoucherRow(
                    voucher: v,
                    missing: _missing(v),
                    selected: _selectedId == v.id,
                    // Tocar el elegido lo desmarca.
                    onTap: _missing(v) > 0 ? null : () => setState(() => _selectedId = _selectedId == v.id ? null : v.id),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Un descuento por pedido: el cupón reemplaza la bebida gratis del álbum.',
                  style: CQType.body(13, color: CQColors.muted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: CQButton(
          label: selected != null ? 'Usar cupón' : 'Seguir sin cupón',
          trailing: selected?.label,
          onPressed: _confirm,
        ),
      ),
    );
  }
}

class _VoucherRow extends StatelessWidget {
  const _VoucherRow({required this.voucher, required this.missing, required this.selected, this.onTap});

  final Voucher voucher;
  final int missing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final disabled = missing > 0;
    final error = disabled ? 'Te faltan ${formatCOP(missing)} para usar este cupón.' : null;
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CQColors.line)),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: disabled ? 0.5 : 1,
            child: Container(
              width: 92,
              height: 68,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: CQColors.mostazaSoft, borderRadius: BorderRadius.circular(6)),
              child: Text(v.label, style: CQType.title(v.label.length > 4 ? 19 : 30, height: 1)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.title,
                  style: CQType.body(16, weight: FontWeight.w700, color: disabled ? CQColors.muted : CQColors.ink),
                ),
                Text(v.subtitle, style: CQType.body(14, color: CQColors.muted, height: 1.25)),
                if (error != null) ...[
                  const SizedBox(height: 2),
                  Text(error, style: CQType.body(14, color: CQColors.danger, height: 1.25)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 24,
            child: disabled
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
      enabled: !disabled,
      child: onTap == null ? row : Pressable(onTap: onTap, scale: 0.99, child: row),
    );
  }
}
