import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'core/theme/motion.dart';
import 'core/theme/theme.dart';
import 'features/splash.dart';
import 'state/cart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const CafeQuindioApp()));
}

class CafeQuindioApp extends StatefulWidget {
  const CafeQuindioApp({super.key});

  @override
  State<CafeQuindioApp> createState() => _CafeQuindioAppState();
}

class _CafeQuindioAppState extends State<CafeQuindioApp> {
  bool _splash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Café Quindío',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: appRouter,
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
