import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/attachments/data/attachment_repository.dart';

void main() {
  late AppDatabase database;
  late Directory root;
  late AttachmentRepository repository;
  late int employeeId;

  setUp(() async {
    database = AppDatabase.forTesting();
    root = await Directory.systemTemp.createTemp('qingsongban-attachments-');
    repository = AttachmentRepository(
      database,
      documentsDirectory: () async => root,
    );
    employeeId = await database.insertEmployee(
      EmployeesCompanion.insert(
        employeeNo: 'EMP-ATT01',
        name: '附件测试员',
        hireDate: DateTime(2026, 1, 1),
      ),
    );
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('copies supported files and keeps only a relative path', () async {
    final source = File('${root.path}${Platform.pathSeparator}source.pdf');
    await source.writeAsBytes([1, 2, 3]);

    final attachment = await repository.importFile(
      employeeId: employeeId,
      sourceFile: source,
      originalFileName: '保险材料.pdf',
      category: 'insurance',
    );

    expect(
      attachment.relativePath,
      'employees/$employeeId/${attachment.relativePath.split('/').last}',
    );
    expect(attachment.relativePath, isNot(contains(root.path)));
    final stored = await repository.resolveFile(attachment);
    expect(await stored.readAsBytes(), [1, 2, 3]);
    expect(await repository.listForEmployee(employeeId), hasLength(1));
  });

  test('soft deletes, restores, and logs an attachment', () async {
    final source = File('${root.path}${Platform.pathSeparator}card.png');
    await source.writeAsBytes([4, 5]);
    final attachment = await repository.importFile(
      employeeId: employeeId,
      sourceFile: source,
      originalFileName: '银行卡.png',
      category: 'bankCard',
    );

    await repository.softDelete(attachment);
    expect(await repository.listForEmployee(employeeId), isEmpty);
    expect(
      (await repository.listForEmployee(
        employeeId,
        includeDeleted: true,
      )).single.isDeleted,
      isTrue,
    );
    await repository.restore(attachment);
    expect(await repository.listForEmployee(employeeId), hasLength(1));
    expect(await database.select(database.operationLogs).get(), hasLength(3));
  });

  test('rejects unsupported and oversized files', () async {
    final unsupported = File('${root.path}${Platform.pathSeparator}source.txt');
    await unsupported.writeAsString('not allowed');
    expect(
      repository.importFile(
        employeeId: employeeId,
        sourceFile: unsupported,
        originalFileName: 'source.txt',
        category: 'other',
      ),
      throwsA(isA<FormatException>()),
    );

    final oversized = File('${root.path}${Platform.pathSeparator}large.pdf');
    await oversized.writeAsBytes(List<int>.filled(20 * 1024 * 1024 + 1, 0));
    expect(
      repository.importFile(
        employeeId: employeeId,
        sourceFile: oversized,
        originalFileName: 'large.pdf',
        category: 'other',
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
