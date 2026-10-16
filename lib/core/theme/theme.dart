import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: CQType.sans,
    scaffoldBackgroundColor: CQColors.white,
    colorScheme: const ColorScheme.light(
      primary: CQColors.ink,
      onPrimary: CQColors.white,
      secondary: CQColors.mostaza,
      onSecondary: CQColors.ink,
      surface: CQColors.white,
      onSurface: CQColors.ink,
      error: CQColors.danger,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: CQColors.ink, displayColor: CQColors.ink),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: CQColors.ink, selectionColor: CQColors.tealSoft),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CQColors.ink,
      contentTextStyle: CQType.body(15, color: CQColors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}
