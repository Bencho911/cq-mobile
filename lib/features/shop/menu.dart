import 'package:flutter/material.dart';

// PENDIENTE: pantalla por portar desde la web.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, this.category});

  /// Categoría preseleccionada (desde las puertas del inicio).
  final String? category;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('MenuScreen')));
}
