import 'package:cafe_quindio/features/auth/confirm_otp.dart';
import 'package:cafe_quindio/features/auth/create_pin.dart';
import 'package:cafe_quindio/features/auth/input_pin.dart';
import 'package:cafe_quindio/features/auth/login.dart';
import 'package:cafe_quindio/features/auth/onboarding.dart';
import 'package:cafe_quindio/features/auth/register.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final screens = <String, Widget>{
    'onboarding': const OnboardingScreen(),
    'login': const LoginScreen(),
    'input-pin': const InputPinScreen(phone: '3001234567'),
    'register': const RegisterScreen(),
    'confirm-otp': const ConfirmOtpScreen(phone: '3001234567'),
    'create-pin': const CreatePinScreen(),
  };

  for (final MapEntry(:key, :value) in screens.entries) {
    testWidgets('$key se dibuja sin desbordes en un teléfono pequeño', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: value));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el botón de Entrar se habilita con 10 dígitos', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.enterText(find.byType(TextField), '300123');
    await tester.pump();
    expect(find.text('Faltan 4 dígitos.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '3001234567');
    await tester.pump();
    expect(find.text('Listo.'), findsOneWidget);
  });
}
