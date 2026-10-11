import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as legacy_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  SecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuthentication,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _localAuthentication = localAuthentication ?? LocalAuthentication();

  static const _hashKey = 'security.pinHash';
  static const _saltKey = 'security.pinSalt';
  static const _schemeKey = 'security.pinScheme';
  static const _pinLengthKey = 'security.pinLength';
  static const _biometricKey = 'security.biometricEnabled';
  static const _failedAttemptsKey = 'security.failedAttempts';
  static const _lockedUntilKey = 'security.lockedUntil';
  static const _pbkdf2Scheme = 'pbkdf2-hmac-sha256-v1';
  static const _iterations = 210000;

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuthentication;

  Future<bool> get enabled async => await _storage.read(key: _hashKey) != null;

  Future<int> pinLength() async =>
      int.tryParse(await _storage.read(key: _pinLengthKey) ?? '') ?? 4;

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,12}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain 4–12 digits.');
    }
    final salt = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final hash = await _derive(pin, salt);
    await _storage.write(key: _saltKey, value: base64UrlEncode(salt));
    await _storage.write(key: _hashKey, value: base64UrlEncode(hash));
    await _storage.write(key: _schemeKey, value: _pbkdf2Scheme);
    await _storage.write(key: _pinLengthKey, value: pin.length.toString());
    await _resetFailures();
  }

  Future<bool> verifyPin(String pin) async {
    if (await lockoutRemaining() != null) return false;

    final encodedSalt = await _storage.read(key: _saltKey);
    final encodedHash = await _storage.read(key: _hashKey);
    if (encodedSalt == null || encodedHash == null) return false;

    final salt = base64Url.decode(encodedSalt);
    final scheme = await _storage.read(key: _schemeKey);
    final valid = scheme == _pbkdf2Scheme
        ? _constantTimeEquals(
            await _derive(pin, salt),
            base64Url.decode(encodedHash),
          )
        : _constantTimeStringEquals(_legacyHash(pin, salt), encodedHash);

    if (!valid) {
      await _recordFailure();
      return false;
    }

    await _resetFailures();
    if (scheme != _pbkdf2Scheme) {
      await setPin(pin);
    }
    return true;
  }

  Future<Duration?> lockoutRemaining() async {
    final raw = await _storage.read(key: _lockedUntilKey);
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null) return null;
    final remaining = until.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      await _storage.delete(key: _lockedUntilKey);
      return null;
    }
    return remaining;
  }

  Future<void> disable() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _schemeKey);
    await _storage.delete(key: _pinLengthKey);
    await _storage.delete(key: _biometricKey);
    await _resetFailures();
  }

  Future<void> setTimeoutMinutes(int value) async =>
      (await SharedPreferences.getInstance()).setInt('security.timeout', value);

  Future<int> timeoutMinutes() async =>
      (await SharedPreferences.getInstance()).getInt('security.timeout') ?? 0;

  Future<bool> biometricEnabled() async =>
      await _storage.read(key: _biometricKey) == 'true';

  Future<void> setBiometricEnabled(bool value) async =>
      _storage.write(key: _biometricKey, value: value.toString());

  Future<bool> authenticateBiometric({bool requireEnabled = true}) async {
    if (requireEnabled && !await biometricEnabled()) return false;
    return _localAuthentication.authenticate(
      localizedReason: 'Unlock SpenFlo',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }

  Future<List<int>> _derive(String pin, List<int> salt) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  Future<void> _recordFailure() async {
    final failures =
        (int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '') ??
            0) +
        1;
    await _storage.write(key: _failedAttemptsKey, value: failures.toString());
    if (failures >= 5) {
      final exponent = min(failures - 5, 4);
      final seconds = 30 * (1 << exponent);
      await _storage.write(
        key: _lockedUntilKey,
        value: DateTime.now()
            .toUtc()
            .add(Duration(seconds: seconds))
            .toIso8601String(),
      );
    }
  }

  Future<void> _resetFailures() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockedUntilKey);
  }

  String _legacyHash(String pin, List<int> salt) =>
      legacy_crypto.sha256.convert([...salt, ...utf8.encode(pin)]).toString();

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  bool _constantTimeStringEquals(String left, String right) =>
      _constantTimeEquals(utf8.encode(left), utf8.encode(right));
}
