import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/preferences_service.dart';

enum AppThemeMode { light, dark, system }

final themeModeProvider = StateNotifierProvider<ThemeController, AppThemeMode>((ref) {
  return ThemeController();
});

class ThemeController extends StateNotifier<AppThemeMode> {
  final _prefsService = PreferencesService();

  ThemeController() : super(AppThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final saved = await _prefsService.getThemeMode();
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    await _prefsService.saveThemeMode(mode);
  }

  ThemeMode toThemeMode() {
    switch (state) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

