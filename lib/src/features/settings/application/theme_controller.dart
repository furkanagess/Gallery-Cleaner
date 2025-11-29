import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/preferences_service.dart';

enum AppThemeMode { light, dark, system }

class ThemeCubit extends Cubit<AppThemeMode> {
  final _prefsService = PreferencesService();

  ThemeCubit() : super(AppThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final saved = await _prefsService.getThemeMode();
    if (saved != null) {
      emit(saved);
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    emit(mode);
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
