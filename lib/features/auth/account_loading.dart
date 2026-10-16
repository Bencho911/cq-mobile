import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';

/// Espera mientras se crea la cuenta; a los 3 s pasa a elegir el PIN.
class AccountLoadingScreen extends StatefulWidget {
  const AccountLoadingScreen({super.key});

  @override
  State<AccountLoadingScreen> createState() => _AccountLoadingScreenState();
}

class _AccountLoadingScreenState extends State<AccountLoadingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Reemplaza la espera para que «volver» no la repita.
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) context.pushReplacement('/create-pin');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const WaitScreen(
        tone: FacadeTone.rosa,
        image: 'assets/brand/capibara-palmas.webp',
        title: 'Creando tu cuenta.',
        description: 'Ya casi: falta elegir tu PIN.',
      );
}
