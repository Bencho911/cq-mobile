import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'core/theme/motion.dart';
import 'core/theme/theme.dart';
import 'features/splash.dart';
import 'state/account.dart';
import 'state/cart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const CafeQuindioApp()));
}

class CafeQuindioApp extends ConsumerStatefulWidget {
  const CafeQuindioApp({super.key});

  @override
  ConsumerState<CafeQuindioApp> createState() => _CafeQuindioAppState();
}

class _CafeQuindioAppState extends ConsumerState<CafeQuindioApp> {
  bool _splash = true;
  DateTime? _pausedAt;
  late final AppLifecycleListener _lifecycle;

  /// Tras este tiempo en segundo plano, la sesión con biometría se bloquea.
  static const _lockAfter = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _pausedAt = DateTime.now(),
      onShow: () {
        final t = _pausedAt;
        if (t != null && DateTime.now().difference(t) > _lockAfter) ref.read(authProvider.notifier).lock();
        _pausedAt = null;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Café Quindío',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Stack(children: [
        ?child,
        IgnorePointer(
          ignoring: !_splash,
          child: AnimatedOpacity(
            opacity: _splash ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            curve: CQMotion.easeOut,
            // La app ya está montada debajo; la apertura se desvanece al terminar.
            child: SplashScreen(onDone: () => setState(() => _splash = false)),
          ),
        ),
      ]),
    );
  }
}
