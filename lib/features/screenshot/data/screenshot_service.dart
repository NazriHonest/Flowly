import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NativeScreenshotModeState {
  const NativeScreenshotModeState({
    required this.requestedEnabled,
    required this.secureEnabled,
    required this.screenshotAllowed,
    required this.activityResumed,
  });

  final bool requestedEnabled;
  final bool secureEnabled;
  final bool screenshotAllowed;
  final bool activityResumed;
}

class ScreenshotService {
  ScreenshotService._();
  static final instance = ScreenshotService._();

  static const _channel = MethodChannel('com.flowly/screenshot_security');

  Future<NativeScreenshotModeState> setNativeScreenshotMode(
    bool enabled, {
    required String reason,
  }) async {
    if (kDebugMode) {
      debugPrint(
        'SpenFloScreenshot: native request enabled=$enabled reason=$reason',
      );
    }
    final response = await _channel.invokeMethod<Object?>(
      'setScreenshotMode',
      <String, Object>{'enabled': enabled, 'reason': reason},
    );
    if (response is! Map) {
      throw PlatformException(
        code: 'invalid_screenshot_mode_response',
        message: 'Android returned an invalid screenshot protection response.',
      );
    }
    final state = NativeScreenshotModeState(
      requestedEnabled: response['requestedEnabled'] == true,
      secureEnabled: response['secureEnabled'] == true,
      screenshotAllowed: response['screenshotAllowed'] == true,
      activityResumed: response['activityResumed'] == true,
    );
    if (kDebugMode) {
      debugPrint(
        'SpenFloScreenshot: native response reason=$reason '
        'requested=${state.requestedEnabled}, '
        'secure=${state.secureEnabled}, allowed=${state.screenshotAllowed}, '
        'resumed=${state.activityResumed}',
      );
    }
    return state;
  }
}
