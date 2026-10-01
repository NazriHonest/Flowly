import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system) {
    _load();
  }
  Future<void> _load() async => state = ThemeMode.values.byName(
    (await SharedPreferences.getInstance()).getString('theme') ?? 'system',
  );
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
