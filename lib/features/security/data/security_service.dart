import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static const _hashKey = 'security.pinHash';
  static const _saltKey = 'security.pinSalt';
  Future<bool> get enabled async => await _storage.read(key: _hashKey) != null;

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,12}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain 4–12 digits.');
    }
    final salt = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    await _storage.write(key: _saltKey, value: base64UrlEncode(salt));
    await _storage.write(key: _hashKey, value: _hash(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final hash = await _storage.read(key: _hashKey);
    return salt != null &&
        hash != null &&
        _hash(pin, base64Url.decode(salt)) == hash;
  }

  Future<void> disable() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }

  Future<void> setTimeoutMinutes(int value) async =>
      (await SharedPreferences.getInstance()).setInt('security.timeout', value);
  Future<int> timeoutMinutes() async =>
      (await SharedPreferences.getInstance()).getInt('security.timeout') ?? 0;
  Future<bool> authenticateBiometric() async =>
      LocalAuthentication().authenticate(
        localizedReason: 'Unlock Flowly',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
  String _hash(String pin, List<int> salt) =>
      sha256.convert([...salt, ...utf8.encode(pin)]).toString();
}
