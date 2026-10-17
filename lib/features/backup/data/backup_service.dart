import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/backup_manifest.dart';
import 'secure_container_service.dart';

class BackupService {
  BackupService(this._database, {SecureContainerService? secureContainer})
    : secureContainer = secureContainer ?? SecureContainerService();

  final AppDatabase _database;
  final SecureContainerService secureContainer;
  static const supportedVersion = 1;

  Future<Uint8List> createArchiveBytes() async {
    await (await _database.db).rawQuery('PRAGMA wal_checkpoint(FULL)');
    final archive = Archive();
    final dbFile = File(await _database.databasePath);
    if (!await dbFile.exists()) {
      throw StateError('The local database could not be found.');
    }
    final databaseBytes = await dbFile.readAsBytes();
    archive.addFile(
      ArchiveFile('database/flowly.db', databaseBytes.length, databaseBytes),
    );
    final preferences = await SharedPreferences.getInstance();
    final settings = <String, Object?>{};
    for (final key in preferences.getKeys()) {
      if (!key.startsWith('security.')) settings[key] = preferences.get(key);
    }
    final manifest = BackupManifest(
      version: supportedVersion,
      createdAt: DateTime.now(),
      includesReceipts: false,
    );
    final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    final settingsBytes = utf8.encode(jsonEncode(settings));
    archive.addFile(
      ArchiveFile('settings.json', settingsBytes.length, settingsBytes),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  Future<Uint8List> createEncrypted(String password) async {
    final archive = await createArchiveBytes();
    return secureContainer.encrypt(
      bytes: archive,
      password: password,
      purpose: 'backup',
      originalFilename: 'spenflo-backup.zip',
    );
  }

  Future<Uint8List> encryptLegacy(List<int> archive, String password) async {
    await validateBytes(archive);
    return secureContainer.encrypt(
      bytes: archive,
      password: password,
      purpose: 'backup',
      originalFilename: 'spenflo-backup.zip',
    );
  }

  Future<Uint8List> decryptEncrypted(List<int> bytes, String password) async {
    final result = await secureContainer.decrypt(
      bytes,
      password: password,
      expectedPurpose: 'backup',
    );
    await validateBytes(result.bytes);
    return result.bytes;
  }

  bool isEncrypted(List<int> bytes) => secureContainer.isEncrypted(bytes);

  /// Legacy plaintext creator retained for compatibility. New UI creation is
  /// always encrypted and uses [createEncrypted].
  Future<File> create() async {
    final output = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        output.path,
        'flowly-backup-${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    await file.writeAsBytes(await createArchiveBytes(), flush: true);
    return file;
  }

  Future<BackupManifest> validate(File archiveFile) async =>
      validateBytes(await archiveFile.readAsBytes());

  Future<BackupManifest> validateBytes(List<int> bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final manifestFile = archive.findFile('manifest.json');
      final database = archive.findFile('database/flowly.db');
      if (manifestFile == null || database == null || database.size < 16) {
        throw const FormatException('Missing required backup files.');
      }
      final json = jsonDecode(utf8.decode(manifestFile.content as List<int>));
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup manifest.');
      }
      final manifest = BackupManifest.fromJson(json);
      if (manifest.version != supportedVersion) {
        throw FormatException('Unsupported backup version ${manifest.version}.');
      }
      final header = (database.content as List<int>).take(16).toList();
      if (utf8.decode(header, allowMalformed: true) != 'SQLite format 3\u0000') {
        throw const FormatException('Backup database is invalid.');
      }
      return manifest;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'The selected backup is corrupt or unreadable.',
      );
    }
  }

  Future<void> restore(File archiveFile) async =>
      restoreBytes(await archiveFile.readAsBytes());

  Future<void> restoreBytes(List<int> bytes) async {
    await validateBytes(bytes);
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final databaseFile = archive.findFile('database/flowly.db')!;
    final target = File(await _database.databasePath);
    final staged = File('${target.path}.restore');
    final rollback = File('${target.path}.before-restore');
    if (await staged.exists()) await staged.delete();
    await staged.writeAsBytes(databaseFile.content as List<int>, flush: true);

    try {
      final check = await openDatabase(staged.path, readOnly: true);
      final integrity = await check.rawQuery('PRAGMA quick_check');
      final userVersion = Sqflite.firstIntValue(
        await check.rawQuery('PRAGMA user_version'),
      );
      await check.close();
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const FormatException(
          'Backup database failed its integrity check.',
        );
      }
      if ((userVersion ?? 0) > AppDatabase.schemaVersion) {
        throw const FormatException(
          'This backup requires a newer SpenFlo version.',
        );
      }
    } catch (error) {
      if (await staged.exists()) await staged.delete();
      if (error is FormatException) rethrow;
      throw const FormatException(
        'Backup database is corrupt or incompatible.',
      );
    }

    await _database.close();
    if (await rollback.exists()) await rollback.delete();
    try {
      if (await target.exists()) await target.rename(rollback.path);
      await staged.rename(target.path);
      await _database.reopen();
      await _restoreSettings(archive);
      if (await rollback.exists()) await rollback.delete();
    } catch (_) {
      await _database.close();
      if (await target.exists()) await target.delete();
      if (await rollback.exists()) await rollback.rename(target.path);
      await _database.reopen();
      rethrow;
    }
  }

  Future<void> _restoreSettings(Archive archive) async {
    final settingsFile = archive.findFile('settings.json');
    if (settingsFile == null) return;
    final decoded = jsonDecode(utf8.decode(settingsFile.content as List<int>));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup settings are invalid.');
    }
    final preferences = await SharedPreferences.getInstance();
    for (final entry in decoded.entries) {
      if (entry.key.startsWith('security.')) continue;
      final value = entry.value;
      if (value is String) await preferences.setString(entry.key, value);
      if (value is bool) await preferences.setBool(entry.key, value);
      if (value is int) await preferences.setInt(entry.key, value);
      if (value is double) await preferences.setDouble(entry.key, value);
      if (value is List) {
        await preferences.setStringList(entry.key, value.cast<String>());
      }
    }
  }
}
