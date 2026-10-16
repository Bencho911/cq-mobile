import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';
import 'confirm_otp.dart';

/// Espera mientras se «envía» el SMS; a los 3 s pasa a confirmar el código.
class OtpLoadingScreen extends StatefulWidget {
  const OtpLoadingScreen({super.key, this.phone, this.code, this.recover = false});

  final String? phone;
  final String? code;
  final bool recover;

  @override
  State<OtpLoadingScreen> createState() => _OtpLoadingScreenState();
}

class _OtpLoadingScreenState extends State<OtpLoadingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final args = OtpArgs(phone: widget.phone, code: widget.code, recover: widget.recover);
    // Reemplaza la espera: al volver desde el código se llega a la pantalla anterior.
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) context.pushReplacement('/confirm-otp', extra: args);
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
