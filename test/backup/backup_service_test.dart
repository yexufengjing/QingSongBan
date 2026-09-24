import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/backup/application/backup_service.dart';

void main() {
  late AppDatabase database;
  late BackupService service;
  late Directory root;
  late File databaseFile;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('qingsongban-backup-');
    databaseFile = File(
      '${root.path}${Platform.pathSeparator}qingsongban.sqlite',
    );
    database = AppDatabase.forTesting(executor: NativeDatabase(databaseFile));
    service = BackupService(database, documentsDirectory: () async => root);
    await database.select(database.appSettings).get();
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'creates encrypted v3 backup and rejects wrong password or tampering',
    () async {
      final bytes = await service.createBackupBytes(password: 'backup-123');

      expect(BackupService.isEncryptedBytes(bytes), isTrue);
      final manifest = await service.validateBackupBytes(
        bytes,
        password: 'backup-123',
      );
      expect(manifest['formatVersion'], 3);
      expect(manifest['attachmentCount'], 0);
      expect(
        service.validateBackupBytes(bytes, password: 'wrong-123'),
        throwsA(isA<StateError>()),
      );

      final tampered = Uint8List.fromList(bytes);
      tampered[tampered.length - 1] ^= 1;
      expect(
        service.validateBackupBytes(tampered, password: 'backup-123'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('checks attachment manifest, size and hash', () async {
    final attachment = File(
      '${root.path}${Platform.pathSeparator}attachments${Platform.pathSeparator}employees${Platform.pathSeparator}1${Platform.pathSeparator}id.png',
    );
    await attachment.parent.create(recursive: true);
    await attachment.writeAsBytes([9, 8, 7]);

    final bytes = await service.createBackupBytes(password: 'backup-123');
    final manifest = await service.validateBackupBytes(
      bytes,
      password: 'backup-123',
    );
    expect(manifest['attachmentCount'], 1);
    expect(manifest['attachmentBytes'], 3);
  });

  test('keeps read-only compatibility with a legacy v1 backup', () async {
    final databaseBytes = await databaseFile.readAsBytes();
    final archive = Archive();
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'qingsongban-backup',
        'formatVersion': 1,
        'schemaVersion': database.schemaVersion,
        'attachmentCount': 0,
        'attachmentBytes': 0,
        'attachments': <Object>[],
      }),
    );
    final config = utf8.encode('{}');
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    archive.addFile(ArchiveFile('config.json', config.length, config));
    archive.addFile(
      ArchiveFile('database.sqlite', databaseBytes.length, databaseBytes),
    );

    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final result = await service.validateBackupBytes(bytes);
    expect(result['formatVersion'], 1);
  });

  test(
    'restores through staged files and creates an encrypted safety backup',
    () async {
      final backupBytes = await service.createBackupBytes(
        password: 'backup-123',
      );
      final backupFile = File(
        '${root.path}${Platform.pathSeparator}incoming.qsbak',
      );
      await backupFile.writeAsBytes(backupBytes, flush: true);

      final result = await service.restoreFromFile(
        backupFile,
        password: 'backup-123',
      );
      expect(await result.safetyBackup.exists(), isTrue);
      expect(
        BackupService.isEncryptedBytes(await result.safetyBackup.readAsBytes()),
        isTrue,
      );
      expect(await databaseFile.exists(), isTrue);
      expect(
        Directory('${root.path}${Platform.pathSeparator}.qsb-restore-stage-')
            .exists(),
        completion(isFalse),
      );
    },
  );

  test('rejects path traversal in legacy attachment entries', () async {
    final databaseBytes = await databaseFile.readAsBytes();
    final archive = Archive();
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'qingsongban-backup',
        'formatVersion': 2,
        'schemaVersion': database.schemaVersion,
        'attachmentCount': 1,
        'attachmentBytes': 1,
        'attachments': [
          {
            'path': '../escape.txt',
            'size': 1,
            'sha256': List.filled(64, '0').join(),
          },
        ],
      }),
    );
    final config = utf8.encode('{}');
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    archive.addFile(ArchiveFile('config.json', config.length, config));
    archive.addFile(
      ArchiveFile('database.sqlite', databaseBytes.length, databaseBytes),
    );
    archive.addFile(ArchiveFile('attachments/../escape.txt', 1, [1]));

    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    expect(service.validateBackupBytes(bytes), throwsA(isA<FormatException>()));
  });
}
