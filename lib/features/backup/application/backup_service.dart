import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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

  static const _encryptedMagic = <int>[0x51, 0x53, 0x42, 0x4b]; // QSBK
  static const _encryptedFormatVersion = 3;
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _macLength = 16;
  static const _pbkdf2Iterations = 210000;
  static const _minPbkdf2Iterations = 10000;
  static const _maxPbkdf2Iterations = 1000000;
  static const _maxBackupBytes = 512 * 1024 * 1024;
  static const _maxDatabaseBytes = 256 * 1024 * 1024;
  static const _maxAttachmentBytes = 20 * 1024 * 1024;
  static const _maxAttachmentTotalBytes = 512 * 1024 * 1024;
  static const _maxAttachmentCount = 2000;

  final AppDatabase _database;
  final Future<Directory> Function()? _documentsDirectoryLoader;

  static bool isEncryptedBytes(List<int> bytes) {
    if (bytes.length < _encryptedMagic.length) return false;
    for (var i = 0; i < _encryptedMagic.length; i++) {
      if (bytes[i] != _encryptedMagic[i]) return false;
    }
    return true;
  }

  Future<File> createBackup({required String password}) async {
    _validatePassword(password);
    final directory = await _documentsDirectory();
    final backupDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}backups',
    );
    await backupDirectory.create(recursive: true);
    final file = File(
      '${backupDirectory.path}${Platform.pathSeparator}qingsongban_${_timestamp()}.qsbak',
    );
    await file.writeAsBytes(
      await createBackupBytes(password: password),
      flush: true,
    );
    return file;
  }

  Future<Uint8List> createBackupBytes({required String password}) async {
    _validatePassword(password);
    final databaseFile = await _databaseFile();
    if (!await databaseFile.exists()) {
      throw StateError('数据库文件尚未创建');
    }
    await _database.customStatement('PRAGMA wal_checkpoint(FULL)');
    final configRows = await _database.select(_database.appSettings).get();
    final config = utf8.encode(
      jsonEncode({
        for (final row in configRows) row.settingKey: row.settingValue,
      }),
    );
    final archive = Archive();
    final databaseBytes = await databaseFile.readAsBytes();
    if (databaseBytes.length > _maxDatabaseBytes) {
      throw StateError('数据库文件超过备份大小限制');
    }
    archive.addFile(
      ArchiveFile('database.sqlite', databaseBytes.length, databaseBytes),
    );
    archive.addFile(ArchiveFile('config.json', config.length, config));

    final attachmentsRoot = await _attachmentsRoot();
    var attachmentCount = 0;
    var attachmentBytes = 0;
    final attachmentManifest = <Map<String, dynamic>>[];
    if (await attachmentsRoot.exists()) {
      await for (final entity in attachmentsRoot.list(recursive: true)) {
        if (entity is! File) continue;
        final relative = _relativePath(attachmentsRoot.path, entity.path);
        final bytes = await entity.readAsBytes();
        if (bytes.length > _maxAttachmentBytes ||
            attachmentCount >= _maxAttachmentCount ||
            attachmentBytes + bytes.length > _maxAttachmentTotalBytes) {
          throw StateError('附件超过备份大小或数量限制');
        }
        archive.addFile(
          ArchiveFile('attachments/$relative', bytes.length, bytes),
        );
        attachmentManifest.add({
          'path': relative,
          'size': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
        });
        attachmentCount++;
        attachmentBytes += bytes.length;
      }
    }
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'qingsongban-backup',
        'formatVersion': _encryptedFormatVersion,
        'schemaVersion': _database.schemaVersion,
        'databaseName': DatabaseConstants.databaseName,
        'createdAt': DateTime.now().toIso8601String(),
        'attachmentCount': attachmentCount,
        'attachmentBytes': attachmentBytes,
        'attachments': attachmentManifest,
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    if (zipBytes.length > _maxBackupBytes) {
      throw StateError('备份压缩包超过大小限制');
    }
    return _encrypt(zipBytes, password);
  }

  Future<Map<String, dynamic>> validateBackupBytes(
    Uint8List bytes, {
    String? password,
  }) async {
    final unpacked = await _unpack(bytes, password: password);
    return unpacked.manifest;
  }

  Future<BackupRestoreResult> restoreFromFile(
    File backupFile, {
    String? password,
  }) async {
    final bytes = await backupFile.readAsBytes();
    final unpacked = await _unpack(bytes, password: password);
    final directory = await _documentsDirectory();
    final stage = Directory(
      '${directory.path}${Platform.pathSeparator}.qsb-restore-stage-${DateTime.now().microsecondsSinceEpoch}',
    );
    final rollback = Directory(
      '${directory.path}${Platform.pathSeparator}.qsb-restore-rollback-${DateTime.now().microsecondsSinceEpoch}',
    );
    final current = await _databaseFile();
    final attachmentsRoot = await _attachmentsRoot();
    if (password == null || password.length < 8) {
      throw StateError('恢复前安全备份需要至少 8 个字符的密码');
    }
    final safetyBackup = await createBackup(password: password);
    var databaseClosed = false;
    var currentDatabaseMoved = false;
    var currentAttachmentsMoved = false;

    try {
      await stage.create(recursive: true);
      final stagedDatabase = File(
        '${stage.path}${Platform.pathSeparator}database.sqlite',
      );
      await stagedDatabase.writeAsBytes(unpacked.databaseBytes, flush: true);
      final stagedAttachments = Directory(
        '${stage.path}${Platform.pathSeparator}attachments',
      );
      await stagedAttachments.create(recursive: true);
      for (final entry in unpacked.archive.files) {
        if (!entry.name.startsWith('attachments/')) continue;
        final relative = _safeArchivePath(
          entry.name.substring('attachments/'.length),
        );
        final target = File(
          '${stagedAttachments.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}',
        );
        await target.parent.create(recursive: true);
        await target.writeAsBytes(entry.content as List<int>, flush: true);
      }

      await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      await _database.close();
      databaseClosed = true;
      await rollback.create(recursive: true);
      await _moveIfExists(
        current,
        File('${rollback.path}${Platform.pathSeparator}database.sqlite'),
      );
      currentDatabaseMoved = true;
      await _moveIfExists(
        File('${current.path}-wal'),
        File('${rollback.path}${Platform.pathSeparator}database.sqlite-wal'),
      );
      await _moveIfExists(
        File('${current.path}-shm'),
        File('${rollback.path}${Platform.pathSeparator}database.sqlite-shm'),
      );
      await _moveIfExists(
        attachmentsRoot,
        Directory('${rollback.path}${Platform.pathSeparator}attachments'),
      );
      currentAttachmentsMoved = true;
      await stagedDatabase.rename(current.path);
      await stagedAttachments.rename(attachmentsRoot.path);
      await _deleteIfExists(rollback);
      await _deleteIfExists(stage);
      return BackupRestoreResult(safetyBackup: safetyBackup);
    } catch (error) {
      if (!databaseClosed) {
        await _deleteIfExists(stage);
        await _deleteIfExists(rollback);
        throw StateError('恢复失败，当前数据未修改：$error');
      }
      if (!currentDatabaseMoved) {
        await _deleteIfExists(stage);
        await _deleteIfExists(rollback);
        throw StateError('恢复失败，当前数据未修改：$error');
      }
      await _deleteIfExists(current);
      await _deleteIfExists(File('${current.path}-wal'));
      await _deleteIfExists(File('${current.path}-shm'));
      if (currentAttachmentsMoved) await _deleteIfExists(attachmentsRoot);
      await _moveIfExists(
        File('${rollback.path}${Platform.pathSeparator}database.sqlite'),
        current,
      );
      await _moveIfExists(
        File('${rollback.path}${Platform.pathSeparator}database.sqlite-wal'),
        File('${current.path}-wal'),
      );
      await _moveIfExists(
        File('${rollback.path}${Platform.pathSeparator}database.sqlite-shm'),
        File('${current.path}-shm'),
      );
      if (currentAttachmentsMoved) {
        await _moveIfExists(
          Directory('${rollback.path}${Platform.pathSeparator}attachments'),
          attachmentsRoot,
        );
      }
      await _deleteIfExists(rollback);
      await _deleteIfExists(stage);
      throw StateError('恢复失败，已保留当前数据：$error');
    }
  }

  Future<_UnpackedBackup> _unpack(Uint8List input, {String? password}) async {
    if (input.isEmpty || input.length > _maxBackupBytes) {
      throw const FormatException('备份文件大小无效');
    }
    final encrypted = isEncryptedBytes(input);
    final zipBytes = encrypted ? await _decrypt(input, password) : input;
    if (zipBytes.length > _maxBackupBytes) {
      throw const FormatException('解压后的备份超过大小限制');
    }
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final manifestFile = archive.findFile('manifest.json');
    final databaseFile = archive.findFile('database.sqlite');
    if (manifestFile == null ||
        databaseFile == null ||
        archive.findFile('config.json') == null) {
      throw const FormatException('备份包缺少必要文件');
    }
    final rawManifest = jsonDecode(
      utf8.decode(manifestFile.content as List<int>),
    );
    if (rawManifest is! Map) {
      throw const FormatException('备份 manifest 无效');
    }
    final manifest = Map<String, dynamic>.from(rawManifest);
    if (manifest['format'] != 'qingsongban-backup') {
      throw const FormatException('不是轻松办备份包');
    }
    final formatVersion = manifest['formatVersion'];
    if (formatVersion is! int ||
        (encrypted && formatVersion != _encryptedFormatVersion) ||
        (!encrypted && (formatVersion < 1 || formatVersion > 2))) {
      throw const FormatException('备份格式版本不受支持');
    }
    final schemaVersion = manifest['schemaVersion'];
    if (schemaVersion is! int ||
        schemaVersion < 1 ||
        schemaVersion > _database.schemaVersion) {
      throw StateError('备份版本高于当前应用，请先升级应用');
    }
    final databaseBytes = List<int>.from(databaseFile.content as List<int>);
    if (databaseBytes.length > _maxDatabaseBytes) {
      throw const FormatException('备份数据库超过大小限制');
    }
    const sqliteHeader = 'SQLite format 3\u0000';
    if (databaseBytes.length < 16 ||
        utf8.decode(databaseBytes.sublist(0, 16), allowMalformed: true) !=
            sqliteHeader) {
      throw const FormatException('备份中的 SQLite 文件无效');
    }
    await _validateSqlite(databaseBytes);

    final attachmentManifest = manifest['attachments'] ?? const <dynamic>[];
    final expectedCount =
        manifest['attachmentCount'] ?? attachmentManifest.length;
    final expectedBytes = manifest['attachmentBytes'] ?? 0;
    if (attachmentManifest is! List ||
        expectedCount is! int ||
        expectedBytes is! int ||
        expectedCount != attachmentManifest.length) {
      throw const FormatException('备份附件 manifest 无效');
    }
    if (expectedCount > _maxAttachmentCount ||
        expectedBytes < 0 ||
        expectedBytes > _maxAttachmentTotalBytes) {
      throw const FormatException('备份附件数量或大小超限');
    }
    final expectedPaths = <String>{};
    var totalBytes = 0;
    for (final item in attachmentManifest) {
      if (item is! Map) throw const FormatException('备份附件 manifest 无效');
      final relative = item['path'];
      final expectedSize = item['size'];
      final expectedHash = item['sha256'];
      if (relative is! String ||
          expectedSize is! int ||
          expectedHash is! String ||
          expectedHash.length != 64 ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedHash)) {
        throw const FormatException('备份附件 manifest 无效');
      }
      _safeArchivePath(relative);
      if (!expectedPaths.add(relative) ||
          expectedSize < 0 ||
          expectedSize > _maxAttachmentBytes) {
        throw const FormatException('备份附件重复或大小无效');
      }
      final entry = archive.findFile('attachments/$relative');
      if (entry == null) throw StateError('备份缺少附件：$relative');
      final content = entry.content as List<int>;
      if (content.length != expectedSize ||
          sha256.convert(content).toString() != expectedHash) {
        throw StateError('备份附件校验失败：$relative');
      }
      totalBytes += content.length;
    }
    if (totalBytes != expectedBytes) {
      throw const FormatException('备份附件总大小校验失败');
    }
    final requiredEntryCounts = <String, int>{
      'database.sqlite': 0,
      'config.json': 0,
      'manifest.json': 0,
    };
    for (final entry in archive.files) {
      if (requiredEntryCounts.containsKey(entry.name)) {
        requiredEntryCounts[entry.name] = requiredEntryCounts[entry.name]! + 1;
      }
    }
    if (requiredEntryCounts.values.any((count) => count != 1)) {
      throw const FormatException('备份包含重复或缺失的必要文件');
    }
    final actualAttachmentPaths = <String>{};
    for (final entry in archive.files) {
      final name = entry.name;
      if (name == 'database.sqlite' ||
          name == 'config.json' ||
          name == 'manifest.json') {
        continue;
      }
      if (!name.startsWith('attachments/')) {
        throw const FormatException('备份包含未知文件');
      }
      final relative = _safeArchivePath(name.substring('attachments/'.length));
      if (!actualAttachmentPaths.add(relative)) {
        throw FormatException('备份包含重复附件：$relative');
      }
      if (!expectedPaths.contains(relative)) {
        throw StateError('备份包含未声明附件：$relative');
      }
    }
    return _UnpackedBackup(
      archive: archive,
      manifest: manifest,
      databaseBytes: databaseBytes,
    );
  }

  Future<Uint8List> _encrypt(List<int> zipBytes, String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    final nonce = List<int>.generate(_nonceLength, (_) => random.nextInt(256));
    final key = await Pbkdf2.hmacSha256(
      iterations: _pbkdf2Iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    final box = await AesGcm.with256bits().encrypt(
      zipBytes,
      secretKey: key,
      nonce: nonce,
    );
    return Uint8List.fromList([
      ..._encryptedMagic,
      _encryptedFormatVersion,
      ..._uint32(_pbkdf2Iterations),
      ...salt,
      ...box.concatenation(),
    ]);
  }

  Future<Uint8List> _decrypt(List<int> input, String? password) async {
    if (password == null || password.isEmpty) {
      throw StateError('加密备份需要密码');
    }
    const headerLength = 4 + 1 + 4 + _saltLength;
    if (input.length < headerLength + _nonceLength + _macLength ||
        !isEncryptedBytes(input)) {
      throw const FormatException('加密备份头无效');
    }
    final version = input[4];
    final iterations = _readUint32(input, 5);
    if (version != _encryptedFormatVersion ||
        iterations < _minPbkdf2Iterations ||
        iterations > _maxPbkdf2Iterations) {
      throw const FormatException('加密备份参数无效');
    }
    final salt = input.sublist(9, headerLength);
    final box = SecretBox.fromConcatenation(
      input.sublist(headerLength),
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    try {
      final key = await Pbkdf2.hmacSha256(
        iterations: iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);
      return Uint8List.fromList(
        await AesGcm.with256bits().decrypt(box, secretKey: key),
      );
    } catch (_) {
      throw StateError('备份密码错误或备份内容已损坏');
    }
  }

  Future<void> _validateSqlite(List<int> bytes) async {
    final directory = await _documentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}.qsb-sqlite-check-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    await file.writeAsBytes(bytes, flush: true);
    final probe = NativeDatabase(file, enableMigrations: false);
    try {
      await probe.ensureOpen(_SqliteProbeUser());
      await probe.runCustom('PRAGMA foreign_keys = ON');
      final integrity = await probe.runSelect(
        'PRAGMA integrity_check',
        const [],
      );
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw StateError('备份数据库 integrity_check 未通过');
      }
      final foreignKeys = await probe.runSelect(
        'PRAGMA foreign_key_check',
        const [],
      );
      if (foreignKeys.isNotEmpty) {
        throw StateError('备份数据库 foreign_key_check 未通过');
      }
      final version = await probe.runSelect('PRAGMA user_version', const []);
      final userVersion = version.first.values.first;
      if (userVersion is! int ||
          userVersion < 1 ||
          userVersion > _database.schemaVersion) {
        throw StateError('备份数据库 schema 版本无效');
      }
    } finally {
      await probe.close();
      await _deleteIfExists(file);
      await _deleteIfExists(File('${file.path}-wal'));
      await _deleteIfExists(File('${file.path}-shm'));
    }
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
        ? _safeArchivePath(file.substring(prefix.length).replaceAll('\\', '/'))
        : _safeArchivePath(file);
  }

  String _safeArchivePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.contains('../') ||
        normalized.contains('/..') ||
        normalized.contains(':') ||
        normalized.split('/').contains('.')) {
      throw const FormatException('备份中的附件路径无效');
    }
    return normalized;
  }

  void _validatePassword(String password) {
    if (password.length < 8) throw StateError('备份密码至少需要 8 个字符');
  }

  Future<void> _moveIfExists(FileSystemEntity from, FileSystemEntity to) async {
    if (!await from.exists()) return;
    await to.parent.create(recursive: true);
    await from.rename(to.path);
  }

  Future<void> _deleteIfExists(FileSystemEntity entity) async {
    if (await entity.exists()) await entity.delete(recursive: true);
  }

  List<int> _uint32(int value) => <int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];

  int _readUint32(List<int> bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  String _timestamp() => DateTime.now().toIso8601String().replaceAll(':', '-');
}

class _UnpackedBackup {
  const _UnpackedBackup({
    required this.archive,
    required this.manifest,
    required this.databaseBytes,
  });

  final Archive archive;
  final Map<String, dynamic> manifest;
  final List<int> databaseBytes;
}

class _SqliteProbeUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
