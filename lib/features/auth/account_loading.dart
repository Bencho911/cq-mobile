import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/shells.dart';
import '../../widgets/zocalo.dart';

/// Espera breve al terminar el registro (el PIN ya quedó guardado y la
/// sesión abierta); luego va al inicio.
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
    // `go` limpia la pila: «volver» desde el inicio no regresa al registro.
    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) context.go('/home');
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
        description: 'Ya casi: estamos abriendo tu álbum de aves.',
      );
}
