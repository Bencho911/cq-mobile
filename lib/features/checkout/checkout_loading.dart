import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';

/// Espera breve mientras se envía el pedido; sigue sola a la confirmación.
class CheckoutLoadingScreen extends StatefulWidget {
  const CheckoutLoadingScreen({super.key});

  @override
  State<CheckoutLoadingScreen> createState() => _CheckoutLoadingScreenState();
}

class _CheckoutLoadingScreenState extends State<CheckoutLoadingScreen> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) context.go('/order-success');
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const WaitScreen(
    tone: FacadeTone.verde,
    image: 'assets/brand/ventana-ave.webp',
    title: 'Enviando tu pedido.',
    description: 'La tienda lo recibe en un momento.',
  );
}
