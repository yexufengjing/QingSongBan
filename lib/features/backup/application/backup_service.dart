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
  const BackupService(
    this._database, {
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectoryLoader = documentsDirectory;

  final AppDatabase _database;
  final Future<Directory> Function()? _documentsDirectoryLoader;

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
    final attachmentsRoot = await _attachmentsRoot();
    var attachmentCount = 0;
    var attachmentBytes = 0;
    if (await attachmentsRoot.exists()) {
      await for (final entity in attachmentsRoot.list(recursive: true)) {
        if (entity is! File) continue;
        final relative = _relativePath(attachmentsRoot.path, entity.path);
        final bytes = await entity.readAsBytes();
        archive.addFile(
          ArchiveFile('attachments/$relative', bytes.length, bytes),
        );
        attachmentCount++;
        attachmentBytes += bytes.length;
      }
    }
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'qingsongban-backup',
        'formatVersion': 2,
        'schemaVersion': _database.schemaVersion,
        'databaseName': DatabaseConstants.databaseName,
        'createdAt': DateTime.now().toIso8601String(),
        'attachmentCount': attachmentCount,
        'attachmentBytes': attachmentBytes,
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
    final formatVersion = manifest['formatVersion'];
    if (formatVersion is! int || formatVersion < 1 || formatVersion > 2) {
      throw const FormatException('备份格式版本不受支持');
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
    for (final entry in archive.files) {
      if (!entry.name.startsWith('attachments/')) continue;
      _safeArchivePath(entry.name.substring('attachments/'.length));
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
    final attachmentsRoot = await _attachmentsRoot();
    if (await attachmentsRoot.exists()) {
      await attachmentsRoot.delete(recursive: true);
    }
    await attachmentsRoot.create(recursive: true);
    for (final entry in archive.files) {
      if (!entry.name.startsWith('attachments/')) continue;
      final relative = _safeArchivePath(
        entry.name.substring('attachments/'.length),
      );
      final target = File(
        '${attachmentsRoot.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}',
      );
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.content as List<int>, flush: true);
    }
    return BackupRestoreResult(safetyBackup: safetyBackup);
  }

  Future<File> _databaseFile() async {
    final directory = await _documentsDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}${DatabaseConstants.databaseName}.sqlite',
    );
  }

  Future<Directory> _documentsDirectory() =>
      _documentsDirectoryLoader?.call() ?? getApplicationDocumentsDirectory();

  Future<Directory> _attachmentsRoot() async {
    final directory = await _documentsDirectory();
    return Directory('${directory.path}${Platform.pathSeparator}attachments');
  }

  String _relativePath(String root, String file) {
    final prefix = '$root${Platform.pathSeparator}';
    return file.startsWith(prefix)
        ? file.substring(prefix.length).replaceAll('\\', '/')
        : _safeArchivePath(file);
  }

  String _safeArchivePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.contains('../') ||
        normalized.contains('/..') ||
        normalized.contains(':')) {
      throw const FormatException('备份中的附件路径无效');
    }
    return normalized;
  }

  String _timestamp() => DateTime.now().toIso8601String().replaceAll(':', '-');
}
