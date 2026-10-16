import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/colors.dart';
import '../core/theme/typography.dart';

/// Pestañas principales con la barra inferior en azul tinta. Sin animación
/// ni indicador deslizante: se tocan decenas de veces al día y deben
/// responder al instante.
class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _items = [
    (LucideIcons.house, 'Inicio'),
    (LucideIcons.coffee, 'Menú'),
    (LucideIcons.bookOpen, 'Álbum'),
    (LucideIcons.clipboardList, 'Pedidos'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: ColoredBox(
        color: CQColors.ink,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: shell.currentIndex == i,
                    button: true,
                    label: _items[i].$2,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                      child: _TabItem(icon: _items[i].$1, label: _items[i].$2, active: shell.currentIndex == i),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.active});
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? CQColors.white : CQColors.navInactive;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 22, color: color),
      const SizedBox(height: 4),
      Text(label, style: CQType.body(12, color: color, weight: active ? FontWeight.w700 : FontWeight.w400, height: 1)),
      const SizedBox(height: 4),
      Container(
        width: 18,
        height: 3,
        decoration: BoxDecoration(color: active ? CQColors.mostaza : Colors.transparent, borderRadius: BorderRadius.circular(2)),
      ),
    ]);
  }
}
