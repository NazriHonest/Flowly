import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController({ThemeMode initialMode = ThemeMode.system})
    : super(initialMode);

  static ThemeMode modeFromStoredValue(String? value) {
    if (value == null) return ThemeMode.system;
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return ThemeMode.system;
  }

  Future<void> set(ThemeMode value) async {
    state = value;
    await (await SharedPreferences.getInstance()).setString(
      'theme',
      value.name,
    );
  }
}

final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>(
  (_) => ThemeController(),
);
