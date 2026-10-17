import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flowly/features/backup/data/secure_container_service.dart';

void main() {
  final service = SecureContainerService();
  final payload = utf8.encode('sensitive financial data');

  test('encrypts and decrypts an authenticated payload', () async {
    final encrypted = await service.encrypt(
      bytes: payload,
      password: 'correct horse battery staple',
      purpose: 'backup',
      originalFilename: 'backup.zip',
    );
    expect(service.isEncrypted(encrypted), isTrue);
    expect(encrypted, isNot(containsAllInOrder(payload)));

    final result = await service.decrypt(
      encrypted,
      password: 'correct horse battery staple',
      expectedPurpose: 'backup',
    );
    expect(result.bytes, payload);
    expect(result.originalFilename, 'backup.zip');
  });

  test('wrong password is rejected', () async {
    final encrypted = await service.encrypt(
      bytes: payload,
      password: 'correct horse battery staple',
      purpose: 'backup',
      originalFilename: 'backup.zip',
    );
    await expectLater(
      service.decrypt(
        encrypted,
        password: 'wrong password',
        expectedPurpose: 'backup',
      ),
      throwsFormatException,
    );
  });

  test('ciphertext corruption is rejected', () async {
    final encrypted = await service.encrypt(
      bytes: payload,
      password: 'correct horse battery staple',
      purpose: 'backup',
      originalFilename: 'backup.zip',
    );
    final envelope = jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
    final cipher = envelope['cipher'] as Map<String, dynamic>;
    final text = cipher['ciphertext'] as String;
    cipher['ciphertext'] = '${text.substring(0, text.length - 2)}AA';
    await expectLater(
      service.decrypt(
        utf8.encode(jsonEncode(envelope)),
        password: 'correct horse battery staple',
      ),
      throwsFormatException,
    );
  });

  test('modified authentication tag is rejected', () async {
    final encrypted = await service.encrypt(
      bytes: payload,
      password: 'correct horse battery staple',
      purpose: 'backup',
      originalFilename: 'backup.zip',
    );
    final envelope = jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
    final cipher = envelope['cipher'] as Map<String, dynamic>;
    final tag = cipher['tag'] as String;
    cipher['tag'] = '${tag.substring(0, tag.length - 2)}AA';
    await expectLater(
      service.decrypt(
        utf8.encode(jsonEncode(envelope)),
        password: 'correct horse battery staple',
      ),
      throwsFormatException,
    );
  });

  test('salt and nonce are unique', () async {
    Future<Map<String, dynamic>> make() async => jsonDecode(
      utf8.decode(
        await service.encrypt(
          bytes: payload,
          password: 'same password',
          purpose: 'export',
          originalFilename: 'report.pdf',
        ),
      ),
    ) as Map<String, dynamic>;
    final first = await make();
    final second = await make();
    expect(
      (first['kdf'] as Map<String, dynamic>)['salt'],
      isNot((second['kdf'] as Map<String, dynamic>)['salt']),
    );
    expect(
      (first['cipher'] as Map<String, dynamic>)['nonce'],
      isNot((second['cipher'] as Map<String, dynamic>)['nonce']),
    );
  });

  test('unsupported container version is rejected', () async {
    final encrypted = await service.encrypt(
      bytes: payload,
      password: 'correct horse battery staple',
      purpose: 'backup',
      originalFilename: 'backup.zip',
    );
    final envelope = jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
    envelope['version'] = 99;
    await expectLater(
      service.decrypt(
        utf8.encode(jsonEncode(envelope)),
        password: 'correct horse battery staple',
      ),
      throwsFormatException,
    );
  });
}
