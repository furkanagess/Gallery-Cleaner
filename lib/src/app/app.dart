import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import '../features/settings/application/theme_controller.dart';
import '../features/settings/application/locale_controller.dart';
import '../../l10n/app_localizations.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final GoRouter _router = createAppRouter();
  static final AppThemeData _appTheme = buildAppTheme();

  @override
  Widget build(BuildContext context) {
    final themeModeState = context.watch<ThemeCubit>().state;
    final locale = context.watch<LocaleCubit>().state;

    final themeMode = themeModeState == AppThemeMode.light
        ? ThemeMode.light
        : themeModeState == AppThemeMode.dark
            ? ThemeMode.dark
            : ThemeMode.system;

    return MaterialApp.router(
      title: 'Gallery Cleaner',
      debugShowCheckedModeBanner: false,
      theme: _appTheme.light,
      darkTheme: _appTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('tr', 'TR'),
        Locale('es', 'ES'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}
