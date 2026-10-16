import 'package:cafe_quindio/features/auth/account_loading.dart';
import 'package:cafe_quindio/features/auth/auth_widgets.dart';
import 'package:cafe_quindio/features/auth/confirm_otp.dart';
import 'package:cafe_quindio/features/auth/create_pin.dart';
import 'package:cafe_quindio/features/auth/input_pin.dart';
import 'package:cafe_quindio/features/auth/login.dart';
import 'package:cafe_quindio/features/auth/onboarding.dart';
import 'package:cafe_quindio/features/auth/otp_loading.dart';
import 'package:cafe_quindio/features/auth/register.dart';
import 'package:cafe_quindio/features/auth/unlock.dart';
import 'package:cafe_quindio/state/account.dart';
import 'package:cafe_quindio/state/cart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

/// Rutas de acceso como en el router de la app; el inicio es un marcador.
GoRouter _router(String initial) => GoRouter(initialLocation: initial, routes: [
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/input-pin', builder: (c, s) => InputPinScreen(phone: s.extra as String?)),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/otp-loading', builder: (c, s) {
        final a = OtpArgs.from(s.extra);
        return OtpLoadingScreen(phone: a.phone, code: a.code, recover: a.recover);
      }),
      GoRoute(path: '/confirm-otp', builder: (c, s) {
        final a = OtpArgs.from(s.extra);
        return ConfirmOtpScreen(phone: a.phone, code: a.code, recover: a.recover);
      }),
      GoRoute(path: '/create-pin', builder: (c, s) => CreatePinScreen(recover: OtpArgs.from(s.extra).recover)),
      GoRoute(path: '/account-loading', builder: (c, s) => const AccountLoadingScreen()),
      GoRoute(path: '/unlock', builder: (c, s) => const UnlockScreen()),
      GoRoute(path: '/home', builder: (c, s) => const Scaffold(body: Text('INICIO'))),
    ]);

Future<void> _pump(WidgetTester tester, ProviderContainer c, String initial, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: _router(initial))));
  await tester.pump();
}

/// Desmonta el árbol para cancelar las cuentas regresivas pendientes.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

/// Cuenta con PIN 123456 y la sesión cerrada.
Future<void> _seedAccount(ProviderContainer c) async {
  final auth = c.read(authProvider.notifier);
  auth.startRegistration(name: 'Ana María Gómez', phone: '3001234567', cedula: '1094000000');
  await auth.setPin('123456');
  await auth.logout();
}

Future<void> _typeCode(WidgetTester tester, String code) async {
  // `last`: durante un cambio animado puede haber dos campos.
  await tester.enterText(find.byType(TextField).last, code);
  await tester.pump();
  await tester.pump();
}

void main() {
  // El bloqueo por intentos vive en memoria: cada prueba arranca limpia.
  setUp(PinGuard.reset);

  final screens = <String, Widget>{
    'onboarding': const OnboardingScreen(),
    'login': const LoginScreen(),
    'input-pin': const InputPinScreen(phone: '3001234567'),
    'register': const RegisterScreen(),
    'confirm-otp': const ConfirmOtpScreen(phone: '3001234567', code: '12345'),
    'create-pin': const CreatePinScreen(),
    'unlock': const UnlockScreen(),
  };

  for (final MapEntry(:key, :value) in screens.entries) {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('$key se dibuja sin desbordes en un teléfono pequeño (${platform.name})', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        final c = await _container();
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: value)));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        expect(find.text('Continuar con Apple'), platform == TargetPlatform.iOS && (key == 'login' || key == 'register') ? findsOneWidget : findsNothing);
        await _unmount(tester);
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }

  testWidgets('el último paso de la bienvenida ofrece Google', (tester) async {
    final c = await _container();
    await _pump(tester, c, '/onboarding', size: const Size(375, 667));
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Crear mi cuenta'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el botón de Entrar se habilita con 10 dígitos', (tester) async {
    final c = await _container();
    await _pump(tester, c, '/login');
    await tester.enterText(find.byType(TextField), '300123');
    await tester.pump();
    expect(find.text('Faltan 4 dígitos.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '3001234567');
    await tester.pump();
    expect(find.text('Listo.'), findsOneWidget);
  });

  testWidgets('registro → código → PIN deja la sesión abierta', (tester) async {
    final c = await _container();
    await _pump(tester, c, '/register');

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana María Gómez');
    await tester.enterText(fields.at(1), '3001234567');
    await tester.enterText(fields.at(2), '1094000000');
    await tester.pump();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, enviar código'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Aviso honesto: aún no hay SMS.
    expect(find.textContaining('Aún no hay SMS'), findsOneWidget);

    // Espera del SMS (3 s) y confirmación del código.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    final codeText = tester.widget<Text>(find.textContaining('Código de prueba: ')).data!;
    final code = codeText.split(': ').last;
    expect(code, hasLength(5));

    // Código incorrecto: error y el campo se limpia.
    await _typeCode(tester, '00000');
    expect(find.textContaining('El código no coincide'), findsOneWidget);
    await _typeCode(tester, code);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Elige un PIN.'), findsOneWidget);

    // PIN y confirmación distinta: error.
    await _typeCode(tester, '123456');
    await tester.tap(find.text('Continuar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Confirma tu PIN.'), findsOneWidget);
    await _typeCode(tester, '654321');
    await tester.tap(find.text('Guardar PIN'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Los PIN no coinciden. Escríbelo otra vez.'), findsOneWidget);
    expect(c.read(authProvider).loggedIn, isFalse);

    await _typeCode(tester, '123456');
    await tester.tap(find.text('Guardar PIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Creando tu cuenta.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('INICIO'), findsOneWidget);

    final auth = c.read(authProvider);
    expect(auth.loggedIn, isTrue);
    expect(auth.hasPin, isTrue);
    expect(auth.account?.firstName, 'Ana');
    expect(auth.account?.cedula, '1094000000');
    expect(await c.read(authProvider.notifier).checkPin('123456'), isTrue);
    await _unmount(tester);
  });

  testWidgets('registro con un celular que ya tiene cuenta ofrece entrar', (tester) async {
    final c = await _container();
    await _seedAccount(c);
    await _pump(tester, c, '/register');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Otra persona');
    await tester.enterText(fields.at(1), '3001234567');
    await tester.enterText(fields.at(2), '123');
    await tester.pump();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Ya tienes una cuenta con este número.'), findsOneWidget);
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu PIN.'), findsOneWidget);
    // La cuenta guardada no se tocó.
    expect(c.read(authProvider).account?.name, 'Ana María Gómez');
    await _unmount(tester);
  });

  testWidgets('PIN incorrecto: avisa, limpia y no abre sesión; el correcto entra', (tester) async {
    final c = await _container();
    await _seedAccount(c);
    await _pump(tester, c, '/login');
    await tester.enterText(find.byType(TextField), '3001234567');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu PIN.'), findsOneWidget);

    await _typeCode(tester, '000000');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('El PIN no coincide.'), findsOneWidget);
    expect(find.textContaining('Te quedan 4 intentos.'), findsOneWidget);
    expect(c.read(authProvider).loggedIn, isFalse);

    await _typeCode(tester, '123456');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('INICIO'), findsOneWidget);
    expect(c.read(authProvider).loggedIn, isTrue);
    await _unmount(tester);
  });

  testWidgets('cinco PIN incorrectos bloquean 30 s', (tester) async {
    final c = await _container();
    await _seedAccount(c);
    await _pump(tester, c, '/input-pin');
    for (var i = 0; i < 5; i++) {
      await _typeCode(tester, '000000');
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Demasiados intentos'), findsOneWidget);
    // Bloqueado: ni el PIN correcto entra.
    await _typeCode(tester, '123456');
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(authProvider).loggedIn, isFalse);
    await _unmount(tester);
  });

  testWidgets('login con un número desconocido ofrece crear cuenta', (tester) async {
    final c = await _container();
    await _pump(tester, c, '/login');
    await tester.enterText(find.byType(TextField), '3009999999');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('No encontramos una cuenta con ese número en este teléfono.'), findsOneWidget);
    expect(find.text('Escribe tu PIN.'), findsNothing);
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta.'), findsOneWidget);
  });

  testWidgets('olvidé mi PIN: código y PIN nuevo abren la sesión', (tester) async {
    final c = await _container();
    await _seedAccount(c);
    await _pump(tester, c, '/input-pin');
    await tester.tap(find.text('Olvidé mi PIN'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Confirma que eres tú.'), findsOneWidget);
    final code = tester.widget<Text>(find.textContaining('Código de prueba: ')).data!.split(': ').last;
    await _typeCode(tester, code);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Elige un PIN nuevo.'), findsOneWidget);
    await _typeCode(tester, '246810');
    await tester.tap(find.text('Continuar'));
    await tester.pump(const Duration(milliseconds: 300));
    await _typeCode(tester, '246810');
    await tester.tap(find.text('Guardar PIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('INICIO'), findsOneWidget);
    expect(c.read(authProvider).loggedIn, isTrue);
    expect(await c.read(authProvider.notifier).checkPin('246810'), isTrue);
    await _unmount(tester);
  });

  testWidgets('desbloqueo: saluda por el nombre y cierra sesión', (tester) async {
    final c = await _container();
    await _seedAccount(c);
    await c.read(authProvider.notifier).loginWithPin('123456');
    await _pump(tester, c, '/unlock');
    expect(find.text('Hola, Ana.'), findsOneWidget);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();
    expect(c.read(authProvider).loggedIn, isFalse);
    await _unmount(tester);
  });
}
