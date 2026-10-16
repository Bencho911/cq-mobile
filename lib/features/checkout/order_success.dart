import 'package:flutter/material.dart';

// PENDIENTE: pantalla por portar desde la web.
class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, this.orderId, this.earned = 0});

  final int? orderId;

  /// Puntos estimados que sumó el pedido.
  final int earned;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('OrderSuccessScreen')));
}
