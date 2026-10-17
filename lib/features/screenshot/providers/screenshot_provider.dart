import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../data/screenshot_service.dart';

enum ScreenshotDisableReason {
  userDisabled('user_disabled'),
  appBackgrounded('app_backgrounded'),
  appLocked('app_locked'),
  protectedScreen('protected_screen'),
  activationFailed('activation_failed');

  const ScreenshotDisableReason(this.logValue);
  final String logValue;
}

class ScreenshotState {
  const ScreenshotState({this.enabled = false});

  final bool enabled;

  ScreenshotState copyWith({bool? enabled}) => ScreenshotState(
    enabled: enabled ?? this.enabled,
  );
}

class ScreenshotController extends StateNotifier<ScreenshotState> {
  ScreenshotController(this._service) : super(const ScreenshotState()) {
    _log('provider_created enabled=false');
  }

  final ScreenshotService _service;
  Future<void> _operationTail = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operationTail.then((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> enableAfterAuthentication() => _serialize(() async {
    _log('enable_started');
    final native = await _service.setNativeScreenshotMode(
      true,
      reason: 'authenticated_enable',
    );
    if (!native.requestedEnabled ||
        native.secureEnabled ||
        !native.screenshotAllowed ||
        !native.activityResumed) {
      _log(
        'enable_rejected requested=${native.requestedEnabled} '
        'secure=${native.secureEnabled} allowed=${native.screenshotAllowed} '
        'resumed=${native.activityResumed}',
      );
      throw PlatformException(
        code: 'screenshot_mode_enable_failed',
        message: !native.activityResumed
            ? 'SpenFlo is not active. Return to the app and try again.'
            : 'Android kept screenshot protection enabled.',
      );
    }
    state = state.copyWith(enabled: true);
    _log('enable_completed enabled=true');
  });

  Future<bool> disable(ScreenshotDisableReason reason) {
    return _serialize(() => _disableNative(reason));
  }

  Future<bool> _disableNative(ScreenshotDisableReason reason) async {
    _log(
      'disable_started reason=${reason.logValue} enabled=${state.enabled}',
    );
    if (!state.enabled) {
      _log('disable_skipped reason=${reason.logValue} already_disabled=true');
      return true;
    }
    try {
      final native = await _service.setNativeScreenshotMode(
        false,
        reason: reason.logValue,
      );
      if (native.screenshotAllowed || !native.secureEnabled) {
        _log(
          'disable_rejected reason=${reason.logValue} '
          'secure=${native.secureEnabled} allowed=${native.screenshotAllowed}',
        );
        state = state.copyWith(enabled: true);
        return false;
      }
      state = state.copyWith(enabled: false);
      _log('disable_completed reason=${reason.logValue} enabled=false');
      return true;
    } on PlatformException catch (error) {
      _log(
        'disable_failed reason=${reason.logValue} code=${error.code}',
      );
      return false;
    } catch (error) {
      _log(
        'disable_failed reason=${reason.logValue} '
        'type=${error.runtimeType}',
      );
      return false;
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('SpenFloScreenshot: $message');
  }

  @override
  void dispose() {
    _log('provider_disposed enabled=${state.enabled}');
    super.dispose();
  }
}

final screenshotControllerProvider =
    StateNotifierProvider<ScreenshotController, ScreenshotState>(
      (_) => ScreenshotController(ScreenshotService.instance),
    );
