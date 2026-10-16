import 'package:flutter/material.dart';

// PENDIENTE: pantalla por portar desde la web.
class InputPinScreen extends StatelessWidget {
  const InputPinScreen({super.key, this.phone});

  final String? phone;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('InputPinScreen')));
}
