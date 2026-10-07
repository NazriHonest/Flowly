import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/sms_permission_bridge.dart';

const automaticDetectionEnabledKey = 'automaticDetectionEnabled';
const _nativeChannel = MethodChannel('com.flowly/sms_permissions');

abstract interface class AutomaticDetectionStore {
  Future<bool> readEnabled();
  Future<bool> writeEnabled(bool enabled);
}

abstract interface class LegacyAutomaticDetectionStore {
  Future<void> clearLegacyEnabled();
}

class SharedPreferencesAutomaticDetectionStore
    implements AutomaticDetectionStore, LegacyAutomaticDetectionStore {
  const SharedPreferencesAutomaticDetectionStore();

  @override
  Future<bool> readEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(automaticDetectionEnabledKey) ?? false;
  }

  @override
  Future<bool> writeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(automaticDetectionEnabledKey, enabled);
  }

  @override
  Future<void> clearLegacyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(automaticDetectionEnabledKey);
  }
}

abstract interface class AutomaticDetectionPlatform {
  Future<bool> permissionGranted();
  Future<bool> requestPermission();
  Future<void> synchronizeReceiver(bool enabled);
}

abstract interface class NativeAutomaticDetectionState {
  Future<bool> restoreNativeState(bool legacyEnabled);
  Future<bool> readNativeState();
}

class MethodChannelAutomaticDetectionPlatform
    implements AutomaticDetectionPlatform, NativeAutomaticDetectionState {
  const MethodChannelAutomaticDetectionPlatform();

  @override
  Future<bool> permissionGranted() => const SmsPermissionBridge().isGranted();

  @override
  Future<bool> requestPermission() => const SmsPermissionBridge().request();

  @override
  Future<void> synchronizeReceiver(bool enabled) =>
      _nativeChannel.invokeMethod<void>('setAutomaticDetection', enabled);

  @override
  Future<bool> restoreNativeState(bool legacyEnabled) async =>
      await _nativeChannel.invokeMethod<bool>('automaticDetectionState', {
        'legacyEnabled': legacyEnabled,
      }) ??
      false;

  @override
  Future<bool> readNativeState() async =>
      await _nativeChannel.invokeMethod<bool>('automaticDetectionState') ??
      false;
}

/// The single owner of the persisted, native and runtime automatic-detection
/// state. A true state is published only after permission, receiver sync and
/// persistence have all succeeded; the application-scoped live provider uses
/// that state to attach its EventChannel listener.
class AutomaticDetectionController extends StateNotifier<bool> {
  AutomaticDetectionController({
    AutomaticDetectionStore store =
        const SharedPreferencesAutomaticDetectionStore(),
    AutomaticDetectionPlatform platform =
        const MethodChannelAutomaticDetectionPlatform(),
    bool restoreOnCreate = true,
  }) : _store = store,
       _platform = platform,
       super(false) {
    _restoration = restoreOnCreate
        ? _restoreAutomaticDetection()
        : Future<bool>.value(false);
  }

  final AutomaticDetectionStore _store;
  final AutomaticDetectionPlatform _platform;
  late final Future<bool> _restoration;

  Future<bool> get restored => _restoration;

  Future<bool> _restoreAutomaticDetection() async {
    try {
      final legacyEnabled = await _store.readEnabled();
      final enabled = _platform is NativeAutomaticDetectionState
          ? await (_platform as NativeAutomaticDetectionState)
                .restoreNativeState(legacyEnabled)
          : legacyEnabled;
      if (_store is LegacyAutomaticDetectionStore &&
          _platform is NativeAutomaticDetectionState) {
        await (_store as LegacyAutomaticDetectionStore).clearLegacyEnabled();
      }
      developer.log('startup_restore enabled=$enabled', name: 'FlowlySMS');
      if (!enabled) return _applyDisabledState(persist: false);

      final granted = await _platform.permissionGranted();
      developer.log('permission_granted=$granted', name: 'FlowlySMS');
      if (!granted) {
        await _platform.synchronizeReceiver(false);
        await _writeLegacyState(false);
        state = false;
        developer.log('native_receiver_synced=false', name: 'FlowlySMS');
        return false;
      }
      await _platform.synchronizeReceiver(true);
      developer.log('native_receiver_synced=true', name: 'FlowlySMS');
      state = true;
      return true;
    } catch (_) {
      try {
        await _platform.synchronizeReceiver(false);
      } catch (_) {
        // Best-effort rollback; state still remains disabled.
      }
      state = false;
      developer.log('native_receiver_synced=false', name: 'FlowlySMS');
      return false;
    }
  }

  Future<bool> restoreAutomaticDetection() => _restoration;

  Future<bool> enableAutomaticDetection() async {
    await _restoration;
    try {
      final alreadyGranted = await _platform.permissionGranted();
      final granted = alreadyGranted || await _platform.requestPermission();
      developer.log('permission_granted=$granted', name: 'FlowlySMS');
      if (!granted) {
        await _applyDisabledState(persist: true);
        return false;
      }

      await _platform.synchronizeReceiver(true);
      developer.log('native_receiver_synced=true', name: 'FlowlySMS');
      if (!await _writeLegacyState(true)) {
        await _platform.synchronizeReceiver(false);
        developer.log('native_receiver_synced=false', name: 'FlowlySMS');
        return false;
      }
      state = true;
      return true;
    } catch (_) {
      try {
        await _platform.synchronizeReceiver(false);
      } catch (_) {
        // Native rollback is best effort after an enable failure.
      }
      state = false;
      developer.log('native_receiver_synced=false', name: 'FlowlySMS');
      return false;
    }
  }

  Future<bool> disableAutomaticDetection() async {
    await _restoration;
    return _applyDisabledState(persist: true);
  }

  Future<bool> _applyDisabledState({required bool persist}) async {
    state = false;
    try {
      await _platform.synchronizeReceiver(false);
      developer.log('native_receiver_synced=false', name: 'FlowlySMS');
      if (persist && !await _writeLegacyState(false)) return false;
      state = false;
      return true;
    } catch (_) {
      developer.log('native_receiver_synced=false', name: 'FlowlySMS');
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) =>
      enabled ? enableAutomaticDetection() : disableAutomaticDetection();

  Future<bool> reconcileOnResume() async {
    await _restoration;
    if (_platform is! NativeAutomaticDetectionState) return state;
    try {
      final enabled = await (_platform as NativeAutomaticDetectionState)
          .readNativeState();
      if (!enabled) {
        state = false;
        return false;
      }
      final granted = await _platform.permissionGranted();
      developer.log('permission_granted=$granted', name: 'FlowlySMS');
      if (!granted) return _applyDisabledState(persist: false);
      await _platform.synchronizeReceiver(true);
      state = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _writeLegacyState(bool enabled) async {
    if (_store is LegacyAutomaticDetectionStore &&
        _platform is NativeAutomaticDetectionState) {
      await (_store as LegacyAutomaticDetectionStore).clearLegacyEnabled();
      return true;
    }
    return _store.writeEnabled(enabled);
  }
}

final automaticDetectionProvider =
    StateNotifierProvider<AutomaticDetectionController, bool>(
      (ref) => AutomaticDetectionController(),
    );
