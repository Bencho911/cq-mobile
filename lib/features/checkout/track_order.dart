import 'package:flutter/material.dart';

// PENDIENTE: pantalla por portar desde la web.
class TrackOrderScreen extends StatelessWidget {
  const TrackOrderScreen({super.key, this.orderId});

  final int? orderId;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('TrackOrderScreen')));
}
