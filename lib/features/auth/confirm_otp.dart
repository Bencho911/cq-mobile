import 'package:flutter/material.dart';

// PENDIENTE: pantalla por portar desde la web.
class ConfirmOtpScreen extends StatelessWidget {
  const ConfirmOtpScreen({super.key, this.phone});

  final String? phone;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('ConfirmOtpScreen')));
}
