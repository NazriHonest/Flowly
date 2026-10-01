import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

const automaticDetectionEnabledKey = 'automaticDetectionEnabled';
const _nativeChannel = MethodChannel('com.flowly/sms_permissions');

class AutomaticDetectionController extends StateNotifier<bool> {
  AutomaticDetectionController() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(automaticDetectionEnabledKey) ?? false;
    try {
      await _nativeChannel.invokeMethod<void>('setAutomaticDetection', state);
    } on PlatformException {
      // The Android receiver still defaults to disabled if the bridge is unavailable.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(automaticDetectionEnabledKey, enabled);
    try {
      await _nativeChannel.invokeMethod<void>('setAutomaticDetection', enabled);
    } on PlatformException {
      // Persistence in SharedPreferences remains authoritative for Flutter.
    }
  }
}

final automaticDetectionProvider = StateNotifierProvider<AutomaticDetectionController, bool>((ref) => AutomaticDetectionController());
