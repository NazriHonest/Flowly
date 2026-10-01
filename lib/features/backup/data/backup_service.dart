import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../domain/backup_manifest.dart';

/// A portable, versioned archive. It deliberately contains only the SQLite
/// database and user settings; SMS source text and transient caches never
/// enter a backup.
class BackupService {
  BackupService(this._database);
  final AppDatabase _database;
  static const supportedVersion = 1;

  Future<File> create() async {
    final output = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        output.path,
        'flowly-backup-${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    final archive = Archive();
    final dbFile = File(await _database.databasePath);
    if (await dbFile.exists()) {
      archive.addFile(
        ArchiveFile(
          'database/flowly.db',
          await dbFile.length(),
          await dbFile.readAsBytes(),
        ),
      );
    }
    final preferences = await SharedPreferences.getInstance();
    final settings = <String, Object?>{};
    for (final key in preferences.getKeys()) {
      // PIN material is stored separately by the security service and should
      // never be copied by a general backup.
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
    final encoded = ZipEncoder().encode(archive);
    await file.writeAsBytes(encoded, flush: true);
    return file;
  }

  Future<BackupManifest> validate(File archiveFile) async {
    try {
      final archive = ZipDecoder().decodeBytes(
        await archiveFile.readAsBytes(),
        verify: true,
      );
      final manifestFile = archive.findFile('manifest.json');
      final database = archive.findFile('database/flowly.db');
      if (manifestFile == null || database == null || database.size == 0) {
        throw const FormatException('Missing required backup files.');
      }
      final json = jsonDecode(utf8.decode(manifestFile.content as List<int>));
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Invalid manifest.');
      }
      final manifest = BackupManifest.fromJson(json);
      if (manifest.version != supportedVersion) {
        throw FormatException(
          'Unsupported backup version ${manifest.version}.',
        );
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

  Future<void> restore(File archiveFile) async {
    await validate(archiveFile); // Never touch current data before validation.
    final archive = ZipDecoder().decodeBytes(
      await archiveFile.readAsBytes(),
      verify: true,
    );
    final databaseFile = archive.findFile('database/flowly.db')!;
    final target = File(await _database.databasePath);
    final staged = File('${target.path}.restore');
    await staged.writeAsBytes(databaseFile.content as List<int>, flush: true);
    // Ensure the staged database is genuinely SQLite before replacement.
    final header = await staged
        .openRead(0, 16)
        .fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    if (utf8.decode(header, allowMalformed: true) != 'SQLite format 3\u0000') {
      await staged.delete();
      throw const FormatException('Backup database is invalid.');
    }
    await _database.close();
    await File(await _database.databasePath).delete();
    await staged.rename(await _database.databasePath);
    final settingsFile = archive.findFile('settings.json');
    if (settingsFile != null) {
      final values = jsonDecode(
        utf8.decode(settingsFile.content as List<int>),
      ) as Map<String, dynamic>;
      final preferences = await SharedPreferences.getInstance();
      for (final entry in values.entries) {
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
    await _database.reopen();
  }
}
