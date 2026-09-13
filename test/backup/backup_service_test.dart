import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/backup/application/backup_service.dart';

void main() {
  late AppDatabase database;
  late BackupService service;
  late Directory root;

  setUp(() {
    database = AppDatabase.forTesting();
    root = Directory.systemTemp.createTempSync('qingsongban-backup-');
    service = BackupService(database, documentsDirectory: () async => root);
  });

  tearDown(() => database.close());

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('packages attachments and reports format version two', () async {
    final databaseFile = File(
      '${root.path}${Platform.pathSeparator}qingsongban.sqlite',
    );
    await databaseFile.writeAsBytes([
      ...utf8.encode('SQLite format 3\u0000'),
      ...List<int>.filled(32, 0),
    ]);
    final attachment = File(
      '${root.path}${Platform.pathSeparator}attachments${Platform.pathSeparator}employees${Platform.pathSeparator}1${Platform.pathSeparator}id.png',
    );
    await attachment.parent.create(recursive: true);
    await attachment.writeAsBytes([9, 8, 7]);

    final bytes = await service.createBackupBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifest = jsonDecode(
      utf8.decode(archive.findFile('manifest.json')!.content as List<int>),
    ) as Map<String, dynamic>;

    expect(manifest['formatVersion'], 2);
    expect(manifest['attachmentCount'], 1);
    expect(archive.findFile('attachments/employees/1/id.png'), isNotNull);
  });

  test('validates a compatible backup manifest and SQLite header', () async {
    final archive = Archive();
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'qingsongban-backup',
        'formatVersion': 1,
        'schemaVersion': 7,
      }),
    );
    final databaseBytes = Uint8List.fromList([
      ...utf8.encode('SQLite format 3\u0000'),
      ...List<int>.filled(32, 0),
    ]);
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    archive.addFile(
      ArchiveFile('database.sqlite', databaseBytes.length, databaseBytes),
    );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

    final result = await service.validateBackupBytes(bytes);
    expect(result['schemaVersion'], 7);
  });

  test('rejects a backup from a newer schema', () async {
    final archive = Archive();
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'qingsongban-backup',
        'formatVersion': 1,
        'schemaVersion': 99,
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    archive.addFile(
      ArchiveFile('database.sqlite', 16, utf8.encode('SQLite format 3\u0000')),
    );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

    expect(service.validateBackupBytes(bytes), throwsA(isA<StateError>()));
  });

  test('rejects attachment paths that escape the archive directory', () async {
    final archive = Archive();
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'qingsongban-backup',
        'formatVersion': 2,
        'schemaVersion': 8,
      }),
    );
    final databaseBytes = utf8.encode('SQLite format 3\u0000');
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    archive.addFile(
      ArchiveFile('database.sqlite', databaseBytes.length, databaseBytes),
    );
    archive.addFile(ArchiveFile('attachments/../escape.txt', 1, [1]));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

    expect(service.validateBackupBytes(bytes), throwsA(isA<FormatException>()));
  });
}
