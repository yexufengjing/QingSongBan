import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../domain/attachment_options.dart';

typedef DocumentsDirectoryLoader = Future<Directory> Function();

class AttachmentRepository {
  AttachmentRepository(
    this._database, {
    DocumentsDirectoryLoader? documentsDirectory,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final AppDatabase _database;
  final DocumentsDirectoryLoader _documentsDirectory;

  Stream<List<EmployeeAttachment>> watchForEmployee(
    int employeeId, {
    bool includeDeleted = false,
  }) {
    final query = _database.select(_database.employeeAttachments)
      ..where((table) => table.employeeId.equals(employeeId))
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    return query.watch();
  }

  Future<List<EmployeeAttachment>> listForEmployee(
    int employeeId, {
    bool includeDeleted = false,
  }) async {
    final query = _database.select(_database.employeeAttachments)
      ..where((table) => table.employeeId.equals(employeeId))
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    return query.get();
  }

  Future<EmployeeAttachment> importFile({
    required int employeeId,
    required File sourceFile,
    required String originalFileName,
    required String category,
    String sourceEntityType = 'personnel',
    int? sourceEntityId,
    String? remark,
  }) async {
    final employee = await _database.findEmployeeById(employeeId);
    if (employee == null || employee.isDeleted) {
      throw StateError('人员档案不存在或已删除');
    }
    if (!await sourceFile.exists()) throw StateError('所选文件不存在');
    final extension = _extensionOf(originalFileName);
    if (!AttachmentOptions.allowedExtensions.contains(extension)) {
      throw FormatException('不支持 .$extension 文件');
    }
    final fileSize = await sourceFile.length();
    if (fileSize > AttachmentOptions.maxFileSize) {
      throw const FileSystemException('单个附件不能超过 20MB');
    }
    final root = await attachmentsRoot();
    final employeeDirectory = Directory(
      '${root.path}${Platform.pathSeparator}employees${Platform.pathSeparator}$employeeId',
    );
    await employeeDirectory.create(recursive: true);
    final generatedName =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}.$extension';
    final target = File(
      '${employeeDirectory.path}${Platform.pathSeparator}$generatedName',
    );
    await sourceFile.copy(target.path);
    final relativePath = 'employees/$employeeId/$generatedName';
    final now = DateTime.now();
    try {
      final id = await _database.transaction(() async {
        final attachmentId = await _database
            .into(_database.employeeAttachments)
            .insert(
              EmployeeAttachmentsCompanion.insert(
                employeeId: employeeId,
                sourceEntityType: Value(sourceEntityType),
                sourceEntityId: Value(sourceEntityId),
                category: Value(category),
                originalFileName: originalFileName,
                relativePath: relativePath,
                extension: extension,
                fileSize: fileSize,
                remark: Value(_nullable(remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await _log('attachment.add', attachmentId, originalFileName);
        return attachmentId;
      });
      return await (_database.select(
        _database.employeeAttachments,
      )..where((table) => table.id.equals(id))).getSingle();
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<void> importPending({
    required int employeeId,
    required Iterable<PendingAttachment> files,
    required String category,
    required String sourceEntityType,
    required int sourceEntityId,
  }) async {
    for (final file in files) {
      await importFile(
        employeeId: employeeId,
        sourceFile: File(file.path),
        originalFileName: file.name,
        category: category,
        sourceEntityType: sourceEntityType,
        sourceEntityId: sourceEntityId,
      );
    }
  }

  Future<File> resolveFile(EmployeeAttachment attachment) async {
    final safePath = _safeRelativePath(attachment.relativePath);
    final root = await attachmentsRoot();
    return File(
      '${root.path}${Platform.pathSeparator}${safePath.replaceAll('/', Platform.pathSeparator)}',
    );
  }

  Future<void> softDelete(EmployeeAttachment attachment) async {
    await _setDeleted(attachment, true, 'attachment.delete');
  }

  Future<void> restore(EmployeeAttachment attachment) async {
    final file = await resolveFile(attachment);
    if (!await file.exists()) throw StateError('附件文件已丢失，无法恢复');
    await _setDeleted(attachment, false, 'attachment.restore');
  }

  Future<Directory> attachmentsRoot() async {
    final documents = await _documentsDirectory();
    return Directory('${documents.path}${Platform.pathSeparator}attachments');
  }

  Future<void> _setDeleted(
    EmployeeAttachment attachment,
    bool deleted,
    String operation,
  ) async {
    await _database.transaction(() async {
      await (_database.update(
        _database.employeeAttachments,
      )..where((table) => table.id.equals(attachment.id))).write(
        EmployeeAttachmentsCompanion(
          isDeleted: Value(deleted),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _log(operation, attachment.id, attachment.originalFileName);
    });
  }

  Future<void> _log(String type, int id, String detail) async {
    await _database
        .into(_database.operationLogs)
        .insert(
          OperationLogsCompanion.insert(
            operationType: type,
            entityType: 'employee_attachment',
            entityId: Value(id),
            detail: Value(detail),
          ),
        );
  }

  String _extensionOf(String name) {
    final index = name.lastIndexOf('.');
    return index < 0 ? '' : name.substring(index + 1).toLowerCase();
  }

  String _safeRelativePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        normalized.contains('../') ||
        normalized.contains('/..') ||
        normalized.contains(':')) {
      throw const FormatException('附件路径无效');
    }
    return normalized;
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
