import 'package:flutter/material.dart';

import '../../data/history.dart';

// PENDIENTE: pantalla por portar desde la web.
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key, required this.id, this.order});

  final int id;

  /// Pedido ya cargado desde el historial (si viene de Pedidos).
  final PastOrder? order;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('InvoiceScreen')));
}
