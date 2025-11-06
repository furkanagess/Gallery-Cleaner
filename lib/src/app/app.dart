import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import '../features/settings/application/theme_controller.dart';
import '../features/settings/application/locale_controller.dart';
import '../../l10n/app_localizations.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final theme = ref.watch(appThemeProvider);
    final themeModeState = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    
    // Convert AppThemeMode to ThemeMode
    final themeMode = themeModeState == AppThemeMode.light
        ? ThemeMode.light
        : themeModeState == AppThemeMode.dark
            ? ThemeMode.dark
            : ThemeMode.system;
    
    return MaterialApp.router(
      title: 'Gallery Cleaner',
      debugShowCheckedModeBanner: false,
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
        Locale('es', 'ES'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

