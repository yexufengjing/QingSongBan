import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/backup/application/backup_service.dart';

void main() {
  late AppDatabase database;
  late BackupService service;

  setUp(() {
    database = AppDatabase.forTesting();
    service = BackupService(database);
  });

  tearDown(() => database.close());

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
}
