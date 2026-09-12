import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/database_constants.dart';
import '../../../core/database/app_database.dart';

class BackupRestoreResult {
  const BackupRestoreResult({required this.safetyBackup});

  final File safetyBackup;
}

class BackupService {
  const BackupService(this._database);

  final AppDatabase _database;

  Future<File> createBackup() async {
    final directory = await _documentsDirectory();
    final backupDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}backups',
    );
    await backupDirectory.create(recursive: true);
    final file = File(
      '${backupDirectory.path}${Platform.pathSeparator}qingsongban_${_timestamp()}.qsbak',
    );
    await file.writeAsBytes(await createBackupBytes(), flush: true);
    return file;
  }

  Future<Uint8List> createBackupBytes() async {
    final databaseFile = await _databaseFile();
    if (!await databaseFile.exists()) {
      throw StateError('数据库文件尚未创建');
    }
    await _database.customStatement('PRAGMA wal_checkpoint(FULL)');
    final configRows = await _database.select(_database.appSettings).get();
    final archive = Archive();
    final databaseBytes = await databaseFile.readAsBytes();
    archive.addFile(
      ArchiveFile('database.sqlite', databaseBytes.length, databaseBytes),
    );
    archive.addFile(
      ArchiveFile(
        'config.json',
        utf8
            .encode(
              jsonEncode({
                for (final row in configRows) row.settingKey: row.settingValue,
              }),
            )
            .length,
        utf8.encode(
          jsonEncode({
            for (final row in configRows) row.settingKey: row.settingValue,
          }),
        ),
      ),
    );
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'qingsongban-backup',
        'formatVersion': 1,
        'schemaVersion': _database.schemaVersion,
        'databaseName': DatabaseConstants.databaseName,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  Future<Map<String, dynamic>> validateBackupBytes(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.findFile('manifest.json');
    final databaseFile = archive.findFile('database.sqlite');
    if (manifestFile == null || databaseFile == null) {
      throw const FormatException('备份包缺少 manifest.json 或 database.sqlite');
    }
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    if (manifest is! Map<String, dynamic> ||
        manifest['format'] != 'qingsongban-backup') {
      throw const FormatException('不是轻松办备份包');
    }
    final schemaVersion = manifest['schemaVersion'];
    if (schemaVersion is! int || schemaVersion > _database.schemaVersion) {
      throw StateError('备份版本高于当前应用，请先升级应用');
    }
    final databaseBytes = databaseFile.content as List<int>;
    const sqliteHeader = 'SQLite format 3\u0000';
    if (databaseBytes.length < 16 ||
        utf8.decode(databaseBytes.sublist(0, 16), allowMalformed: true) !=
            sqliteHeader) {
      throw const FormatException('备份中的 SQLite 文件无效');
    }
    return manifest;
  }

  Future<BackupRestoreResult> restoreFromFile(File backupFile) async {
    final bytes = await backupFile.readAsBytes();
    await validateBackupBytes(bytes);
    final archive = ZipDecoder().decodeBytes(bytes);
    final databaseEntry = archive.findFile('database.sqlite')!;
    final current = await _databaseFile();
    final safetyBackup = await createBackup();
    await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await _database.close();
    final wal = File('${current.path}-wal');
    final shm = File('${current.path}-shm');
    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();
    await current.writeAsBytes(databaseEntry.content as List<int>, flush: true);
    return BackupRestoreResult(safetyBackup: safetyBackup);
  }

  Future<File> _databaseFile() async {
    final directory = await _documentsDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}${DatabaseConstants.databaseName}.sqlite',
    );
  }

  Future<Directory> _documentsDirectory() => getApplicationDocumentsDirectory();

  String _timestamp() => DateTime.now().toIso8601String().replaceAll(':', '-');
}
