import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/typography.dart';
import '../../widgets/controls.dart';

const _slotMinutes = 15;

/// MOCK: la tienda aún no informa su horario ni su capacidad, así que se
/// ofrecen franjas de 15 minutos durante las próximas 3 horas.
const _slotCount = 12;
const _leadMinutes = 15;

List<DateTime> _buildSlots(DateTime now) {
  final lead = now.add(const Duration(minutes: _leadMinutes));
  final base = DateTime(lead.year, lead.month, lead.day, lead.hour);
  final rounded = (lead.minute / _slotMinutes).ceil() * _slotMinutes;
  final start = base.add(Duration(minutes: rounded));
  return List.generate(_slotCount, (i) => start.add(Duration(minutes: i * _slotMinutes)));
}

/// Hoja inferior para elegir la hora de recogida. [onConfirm] recibe la
/// franja elegida o `null` ("lo antes posible").
Future<void> showPickupTimeSheet(
  BuildContext context, {
  DateTime? value,
  int? readyMinutes,
  required ValueChanged<DateTime?> onConfirm,
}) => showCQSheet<void>(context, (context) => _TimePickerSheet(value: value, readyMinutes: readyMinutes, onConfirm: onConfirm));

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({this.value, this.readyMinutes, required this.onConfirm});

  final DateTime? value;
  final int? readyMinutes;
  final ValueChanged<DateTime?> onConfirm;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late final List<DateTime> _slots = _buildSlots(DateTime.now());

  /// `null` = lo antes posible. Si la hora guardada ya no está entre las
  /// franjas (pasó o es de otro día), abre en "lo antes posible".
  late DateTime? _selected = _slots.contains(widget.value) ? widget.value : null;

  void _confirm() {
    widget.onConfirm(_selected);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final rows = [for (var i = 0; i < _slots.length; i += 3) _slots.sublist(i, (i + 3).clamp(0, _slots.length))];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text('¿A qué hora lo recoges?', style: CQType.title(26, height: 1.1))),
                      const SizedBox(height: 4),
                      Text(
                        'Hoy. Lo preparamos para que esté listo cuando llegues.',
                        style: CQType.body(15, color: CQColors.muted),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(8, -4),
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: 'Cerrar',
                    child: const SizedBox(width: 44, height: 44, child: Icon(LucideIcons.x, size: 24, color: CQColors.ink)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Option(
              selected: _selected == null,
              onTap: () => setState(() => _selected = null),
              height: 56,
              child: (fg, sub) => Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lo antes posible',
                      style: CQType.body(16, color: fg, weight: FontWeight.w600),
                    ),
                  ),
                  if (widget.readyMinutes != null)
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Listo en unos '),
                          TextSpan(
                            text: '${widget.readyMinutes}',
                            style: CQType.number(14, color: sub),
                          ),
                          const TextSpan(text: ' min'),
                        ],
                      ),
                      style: CQType.body(14, color: sub),
                    ),
                ],
              ),
            ),
            for (final row in rows) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: i < row.length
                          ? _Option(
                              selected: _selected == row[i],
                              onTap: () => setState(() => _selected = row[i]),
                              height: 48,
                              center: true,
                              child: (fg, _) => Text(formatClock(row[i]), style: CQType.number(16, color: fg)),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),
            CQButton(
              label: _selected == null ? 'Recoger lo antes posible' : 'Recoger a las ${formatClock(_selected!)}',
              onPressed: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

/// Opción tipo radio: borde gris; marcada, fondo tinta.
class _Option extends StatelessWidget {
  const _Option({required this.selected, required this.onTap, required this.height, required this.child, this.center = false});

  final bool selected;
  final VoidCallback onTap;
  final double height;
  final bool center;
  final Widget Function(Color fg, Color sub) child;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? CQColors.white : CQColors.ink;
    final sub = selected ? CQColors.onDark : CQColors.muted;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CQMotion.press,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: center ? 0 : 16),
          alignment: center ? Alignment.center : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: selected ? CQColors.ink : CQColors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? CQColors.ink : CQColors.line, width: 1.5),
          ),
          child: child(fg, sub),
        ),
      ),
    );
  }
}
