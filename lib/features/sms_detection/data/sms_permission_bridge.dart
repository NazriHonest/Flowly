import 'package:flutter/services.dart';

class SmsPermissionBridge {
  const SmsPermissionBridge();
  static const _channel = MethodChannel('com.flowly/sms_permissions');
  Future<bool> isGranted() async =>
      await _channel.invokeMethod<bool>('status') ?? false;
  Future<bool> request() async =>
      await _channel.invokeMethod<bool>('request') ?? false;
  Future<void> openAppSettings() => _channel.invokeMethod<void>('openSettings');
}
