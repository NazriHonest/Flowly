import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowly/features/security/data/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'new PINs use PBKDF2 and successful verification resets failures',
    () async {
      const storage = FlutterSecureStorage();
      final service = SecurityService(storage: storage);

      await service.setPin('2468');

      expect(
        await storage.read(key: 'security.pinScheme'),
        'pbkdf2-hmac-sha256-v1',
      );
      expect(await storage.read(key: 'security.pinHash'), isNot('2468'));
      expect(await service.verifyPin('2468'), isTrue);
      expect(await service.verifyPin('1357'), isFalse);
    },
  );

  test(
    'legacy salted SHA-256 PIN migrates only after valid authentication',
    () async {
      final salt = List<int>.generate(24, (index) => index + 1);
      final legacyHash = sha256.convert([...salt, ...utf8.encode('4321')]);
      FlutterSecureStorage.setMockInitialValues({
        'security.pinSalt': base64UrlEncode(salt),
        'security.pinHash': legacyHash.toString(),
      });
      const storage = FlutterSecureStorage();
      final service = SecurityService(storage: storage);

      expect(await service.verifyPin('4321'), isTrue);
      expect(
        await storage.read(key: 'security.pinScheme'),
        'pbkdf2-hmac-sha256-v1',
      );
      expect(await service.verifyPin('4321'), isTrue);
    },
  );

  test('fifth failed attempt starts a temporary lockout', () async {
    const storage = FlutterSecureStorage();
    final service = SecurityService(storage: storage);
    await service.setPin('2468');
    await storage.write(key: 'security.failedAttempts', value: '4');

    expect(await service.verifyPin('0000'), isFalse);
    expect(await service.lockoutRemaining(), isNotNull);
    expect(await service.verifyPin('2468'), isFalse);
  });
}
