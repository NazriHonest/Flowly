import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Versioned, authenticated container used by encrypted backups and exports.
///
/// The UTF-8 JSON envelope is intentionally self-describing. Its payload is
/// AES-256-GCM ciphertext and its password key is derived with
/// PBKDF2-HMAC-SHA256. This is a SpenFlo container, not a ZIP file.
class SecureContainerService {
  SecureContainerService({Random? random}) : _random = random ?? Random.secure();

  static const format = 'spenflo-secure-container';
  static const version = 1;
  static const iterations = 310000;
  static const extension = 'spenflo';

  final Random _random;
  final AesGcm _cipher = AesGcm.with256bits();
  final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );

  bool isEncrypted(List<int> bytes) {
    try {
      final value = jsonDecode(utf8.decode(bytes));
      return value is Map && value['format'] == format;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> encrypt({
    required List<int> bytes,
    required String password,
    required String purpose,
    required String originalFilename,
  }) async {
    if (password.isEmpty) throw ArgumentError('A password is required.');
    final salt = _randomBytes(32);
    final nonce = _randomBytes(12);
    final aad = _associatedData(
      purpose: purpose,
      originalFilename: originalFilename,
      salt: salt,
      nonce: nonce,
    );
    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final box = await _cipher.encrypt(
      bytes,
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );
    final envelope = <String, Object>{
      'format': format,
      'version': version,
      'purpose': purpose,
      'originalFilename': originalFilename,
      'kdf': <String, Object>{
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': iterations,
        'salt': base64Encode(salt),
      },
      'cipher': <String, Object>{
        'name': 'AES-256-GCM',
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(box.cipherText),
        'tag': base64Encode(box.mac.bytes),
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  Future<DecryptedContainer> decrypt(
    List<int> bytes, {
    required String password,
    String? expectedPurpose,
  }) async {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> || decoded['format'] != format) {
        throw const FormatException('This is not a SpenFlo secure file.');
      }
      if (decoded['version'] != version) {
        throw FormatException(
          'Unsupported secure file version ${decoded['version']}.',
        );
      }
      final purpose = decoded['purpose'] as String;
      if (expectedPurpose != null && purpose != expectedPurpose) {
        throw FormatException('This secure file contains $purpose data.');
      }
      final originalFilename = decoded['originalFilename'] as String;
      final kdf = decoded['kdf'] as Map<String, dynamic>;
      final cipher = decoded['cipher'] as Map<String, dynamic>;
      if (kdf['name'] != 'PBKDF2-HMAC-SHA256' ||
          kdf['iterations'] != iterations ||
          cipher['name'] != 'AES-256-GCM') {
        throw const FormatException('Unsupported encryption parameters.');
      }
      final salt = base64Decode(kdf['salt'] as String);
      final nonce = base64Decode(cipher['nonce'] as String);
      if (salt.length != 32 || nonce.length != 12) {
        throw const FormatException('Invalid encryption parameters.');
      }
      final aad = _associatedData(
        purpose: purpose,
        originalFilename: originalFilename,
        salt: salt,
        nonce: nonce,
      );
      final key = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      final cleartext = await _cipher.decrypt(
        SecretBox(
          base64Decode(cipher['ciphertext'] as String),
          nonce: nonce,
          mac: Mac(base64Decode(cipher['tag'] as String)),
        ),
        secretKey: key,
        aad: aad,
      );
      return DecryptedContainer(
        bytes: Uint8List.fromList(cleartext),
        purpose: purpose,
        originalFilename: originalFilename,
      );
    } on FormatException {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const FormatException('Incorrect password or damaged secure file.');
    } catch (_) {
      throw const FormatException('The secure file is corrupt or unreadable.');
    }
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  List<int> _associatedData({
    required String purpose,
    required String originalFilename,
    required List<int> salt,
    required List<int> nonce,
  }) => utf8.encode(
    jsonEncode(<String, Object>{
      'format': format,
      'version': version,
      'purpose': purpose,
      'originalFilename': originalFilename,
      'kdf': <String, Object>{
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': iterations,
        'salt': base64Encode(salt),
      },
      'cipher': <String, Object>{
        'name': 'AES-256-GCM',
        'nonce': base64Encode(nonce),
      },
    }),
  );
}

class DecryptedContainer {
  const DecryptedContainer({
    required this.bytes,
    required this.purpose,
    required this.originalFilename,
  });

  final Uint8List bytes;
  final String purpose;
  final String originalFilename;
}
