import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';

/// Espera mientras se envía el SMS; a los 3 s pasa a confirmar el código.
class OtpLoadingScreen extends StatefulWidget {
  const OtpLoadingScreen({super.key, this.phone});

  final String? phone;

  @override
  State<OtpLoadingScreen> createState() => _OtpLoadingScreenState();
}

class _OtpLoadingScreenState extends State<OtpLoadingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final phone = widget.phone ?? '300 000 0000';
    // Reemplaza la espera: al volver desde el código se llega al registro.
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) context.pushReplacement('/confirm-otp', extra: phone);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const WaitScreen(
        tone: FacadeTone.mostaza,
        image: 'assets/brand/ventana-amarilla.webp',
        title: 'Enviando tu código.',
        description: 'Llega por SMS en unos segundos.',
      );
}
