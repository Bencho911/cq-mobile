import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/config.dart';
import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';

/// Respuesta al toque: se encoge un poco (0,97) mientras se presiona.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97, this.haptic = false, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  /// Vibración leve al tocar (acciones que confirman algo).
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.lightImpact();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: CQMotion.press,
          curve: CQMotion.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

enum CQButtonVariant { primary, secondary, mostaza, danger }

/// Botón de la casa: 54 px de alto, rectangular con radio discreto.
class CQButton extends StatelessWidget {
  const CQButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CQButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.trailing,
    this.height = 54,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final CQButtonVariant variant;
  final bool loading;
  final IconData? icon;

  /// Texto a la derecha (p. ej. el total), separado del label.
  final String? trailing;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (bg, fg, border) = switch (variant) {
      CQButtonVariant.primary => (CQColors.ink, CQColors.white, null),
      CQButtonVariant.secondary => (Colors.transparent, CQColors.ink, CQColors.ink),
      CQButtonVariant.mostaza => (CQColors.mostaza, CQColors.ink, null),
      CQButtonVariant.danger => (CQColors.danger, CQColors.white, null),
    };
    final text = CQType.body(17, color: fg, weight: FontWeight.w600);
    return Opacity(
      opacity: enabled || loading ? 1 : 0.45,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: border == null ? null : Border.all(color: border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: trailing == null ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (loading) ...[
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
                  const SizedBox(width: 10),
                ] else if (icon != null) ...[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 10),
                ],
                Text(label, style: text),
              ]),
              if (trailing != null) Text(trailing!, style: CQType.number(17, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera de pantalla: título en Bricolage, sin logo ni sombra.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.onBack, this.action});

  final String title;

  /// Sin `onBack` el título se alinea al borde (pantallas de pestaña).
  final VoidCallback? onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack != null ? 4 : 20, MediaQuery.paddingOf(context).top + 8, 8, 8),
      child: Row(children: [
        if (onBack != null)
          Pressable(
            onTap: onBack,
            semanticLabel: 'Volver',
            child: const SizedBox(width: 44, height: 44, child: Icon(LucideIcons.chevronLeft, size: 26, color: CQColors.ink)),
          ),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: CQType.title(26, height: 1.1))),
        ?action,
      ]),
    );
  }
}

/// Fila de lista plana con separador inferior. Mínimo 52 px de alto.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.label, this.description, this.icon, this.value, this.onTap, this.chevron, this.danger = false});

  final String label;
  final String? description;
  final IconData? icon;
  final String? value;
  final VoidCallback? onTap;
  final bool? chevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? CQColors.danger : CQColors.ink;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CQColors.line))),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: CQType.body(16, color: color)),
            if (description != null) Text(description!, style: CQType.body(14, color: CQColors.muted)),
          ]),
        ),
        if (value != null) Text(value!, style: CQType.body(15, color: CQColors.muted)),
        if (chevron ?? onTap != null) const Icon(LucideIcons.chevronRight, size: 18, color: CQColors.muted),
      ]),
    );
    return onTap == null ? row : Pressable(onTap: onTap, scale: 0.99, child: row);
  }
}

/// Selector de 2–3 opciones sobre fondo teal suave.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: CQColors.tealSoft, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        for (final (v, label) in options)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: CQMotion.fast,
                curve: CQMotion.easeOut,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == value ? CQColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: v == value ? const [BoxShadow(color: Color(0x1418303C), blurRadius: 2, offset: Offset(0, 1))] : null,
                ),
                child: Text(label, style: CQType.body(15, color: v == value ? CQColors.ink : CQColors.muted, weight: FontWeight.w600)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Da un pequeño salto cuando [value] sube (contador del carrito). No salta
/// al aparecer ni cuando el valor baja.
class Bump extends StatefulWidget {
  const Bump({super.key, required this.value, required this.child});
  final int value;
  final Widget child;

  @override
  State<Bump> createState() => _BumpState();
}

class _BumpState extends State<Bump> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: CQMotion.easeOut)), weight: 65),
  ]).animate(_c);

  @override
  void didUpdateWidget(Bump old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value && !CQMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}

/// Imagen de producto: asset local (mocks), URL absoluta o ruta /uploads del gateway.
class ProductImage extends StatelessWidget {
  const ProductImage(this.path, {super.key, this.width, this.height, this.fit = BoxFit.contain});

  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final p = path;
    final fallback = SizedBox(width: width, height: height, child: const Icon(LucideIcons.coffee, color: CQColors.muted));
    if (p == null || p.isEmpty) return fallback;
    if (p.startsWith('assets/')) return Image.asset(p, width: width, height: height, fit: fit);
    final url = p.startsWith('http') ? p : '${AppConfig.apiOrigin}$p';
    return Image.network(url, width: width, height: height, fit: fit, errorBuilder: (_, _, _) => fallback);
  }
}

enum ArchTone { teal, rosa, mostaza }

/// Tono estable por producto, para que conserve su color.
ArchTone archToneFor(int id) => ArchTone.values[id.abs() % 3 == 0 ? 0 : (id.abs() % 3 == 1 ? 2 : 1)];

extension ArchToneColor on ArchTone {
  Color get color => switch (this) {
        ArchTone.teal => CQColors.tealSoft,
        ArchTone.rosa => CQColors.rosaSoft,
        ArchTone.mostaza => CQColors.mostazaSoft,
      };
}

/// Arco de ventana colonial. Forma reservada para armar el pedido.
class Arch extends StatelessWidget {
  const Arch({super.key, required this.tone, required this.child, this.width, this.height});
  final ArchTone tone;
  final Widget child;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = width ?? c.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(w / 2)),
          child: Container(width: w, height: height, color: tone.color, alignment: Alignment.bottomCenter, child: child),
        );
      });
}

enum DoorTone { teal, rosa, verde, mostaza }

/// Puerta pintada de fachada: entrada a una categoría.
class Door extends StatelessWidget {
  const Door({super.key, required this.title, required this.tone, this.subtitle, this.image, this.imageTint, this.onTap, this.height = 150});

  final String title;
  final String? subtitle;
  final String? image;
  final DoorTone tone;

  /// Tiñe la ilustración de una sola tinta cuando su color se confunde con
  /// el de la puerta (la heliconia rosada sobre la puerta rosa).
  final Color? imageTint;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      DoorTone.teal => CQColors.teal,
      DoorTone.rosa => CQColors.rosa,
      DoorTone.verde => CQColors.verde,
      DoorTone.mostaza => CQColors.mostaza,
    };
    final fg = tone == DoorTone.verde ? CQColors.white : CQColors.ink;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(52), topRight: Radius.circular(52), bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (image != null)
            Center(
              child: imageTint == null
                  ? Image.asset(image!, height: 64)
                  : ColorFiltered(colorFilter: ColorFilter.mode(imageTint!, BlendMode.srcIn), child: Image.asset(image!, height: 64)),
            ),
          const Spacer(),
          Text(title, style: CQType.title(18, color: fg, height: 1)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: CQType.body(13, color: fg, height: 1.15)),
          ],
        ]),
      ),
    );
  }
}

/// Aviso breve en azul tinta (equivalente a los toasts de la web).
void showToast(BuildContext context, String title, {String? detail, bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    backgroundColor: error ? CQColors.danger : CQColors.ink,
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: CQType.body(15, color: CQColors.white, weight: FontWeight.w600)),
      if (detail != null) Text(detail, style: CQType.body(14, color: CQColors.onDark)),
    ]),
  ));
}

/// Hoja inferior con el estilo de la casa (esquinas superiores redondeadas).
Future<T?> showCQSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: CQColors.white,
      barrierColor: CQColors.ink.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: builder,
    );
