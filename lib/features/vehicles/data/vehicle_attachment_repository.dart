import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../attachments/data/attachment_repository.dart';
import '../../attachments/domain/attachment_options.dart';
import 'vehicle_scope.dart';

class VehicleAttachmentRepository {
  VehicleAttachmentRepository(this._database, {this.documentsDirectory});

  final AppDatabase _database;
  final DocumentsDirectoryLoader? documentsDirectory;

  Stream<List<VehicleAttachment>> watchForVehicle(
    int vehicleId, {
    bool includeDeleted = false,
  }) {
    final query = _database.select(_database.vehicleAttachments)
      ..where((table) => table.vehicleId.equals(vehicleId))
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    return query.watch();
  }

  Future<List<VehicleAttachment>> listForVehicle(
    int vehicleId, {
    bool includeDeleted = false,
  }) {
    final query = _database.select(_database.vehicleAttachments)
      ..where((table) => table.vehicleId.equals(vehicleId))
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    return query.get();
  }

  Future<VehicleAttachment> importFile({
    required int vehicleId,
    required File sourceFile,
    required String originalFileName,
    String category = 'other',
    int? repairOrderId,
    String? remark,
  }) async {
    final vehicle =
        await (_database.select(_database.vehicles)..where(
              (table) =>
                  table.id.equals(vehicleId) & table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (vehicle == null) throw StateError('车辆档案不存在或已删除');
    if (repairOrderId != null) {
      await VehicleScope.requireRepairForVehicle(
        _database,
        repairOrderId: repairOrderId,
        vehicleId: vehicleId,
      );
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
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}vehicles${Platform.pathSeparator}$vehicleId',
    );
    await directory.create(recursive: true);
    final generated = '${_uuidV4()}.$extension';
    final target = File('${directory.path}${Platform.pathSeparator}$generated');
    await sourceFile.copy(target.path);
    final relativePath = 'vehicles/$vehicleId/$generated';
    final hash = sha256.convert(await target.readAsBytes()).toString();
    try {
      final id = await _database.transaction(() async {
        await VehicleScope.requireVehicle(_database, vehicleId);
        if (repairOrderId != null) {
          await VehicleScope.requireRepairForVehicle(
            _database,
            repairOrderId: repairOrderId,
            vehicleId: vehicleId,
          );
        }
        return _database
            .into(_database.vehicleAttachments)
            .insert(
              VehicleAttachmentsCompanion.insert(
                vehicleId: vehicleId,
                repairOrderId: Value(repairOrderId),
                category: Value(category),
                originalFileName: originalFileName,
                storedFileName: Value(generated),
                relativePath: relativePath,
                mimeType: Value(_mimeType(extension)),
                extension: extension,
                fileSize: fileSize,
                fileHash: Value(hash),
                remark: Value(_nullable(remark)),
              ),
            );
      });
      return await (_database.select(
        _database.vehicleAttachments,
      )..where((table) => table.id.equals(id))).getSingle();
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<File> resolveFile(VehicleAttachment attachment) async {
    final safe = _safeRelativePath(attachment.relativePath);
    final root = await attachmentsRoot();
    return File(
      '${root.path}${Platform.pathSeparator}${safe.replaceAll('/', Platform.pathSeparator)}',
    );
  }

  Future<void> softDelete(VehicleAttachment attachment) async {
    await _database.transaction(() async {
      final current =
          await (_database.select(_database.vehicleAttachments)..where(
                (table) =>
                    table.id.equals(attachment.id) &
                    table.vehicleId.equals(attachment.vehicleId) &
                    table.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      if (current == null) {
        throw StateError('附件不属于当前车辆或已删除：${attachment.id}');
      }
      await (_database.update(_database.vehicleAttachments)..where(
            (table) =>
                table.id.equals(attachment.id) &
                table.vehicleId.equals(attachment.vehicleId) &
                table.isDeleted.equals(false),
          ))
          .write(
            VehicleAttachmentsCompanion(
              isDeleted: const Value(true),
              deletedAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );
    });
  }

  Future<void> restore(VehicleAttachment attachment) async {
    final current =
        await (_database.select(_database.vehicleAttachments)..where(
              (table) =>
                  table.id.equals(attachment.id) &
                  table.vehicleId.equals(attachment.vehicleId) &
                  table.isDeleted.equals(true),
            ))
            .getSingleOrNull();
    if (current == null) {
      throw StateError('附件不属于当前车辆或未被删除：${attachment.id}');
    }
    final file = await resolveFile(attachment);
    if (!await file.exists()) throw StateError('附件文件已丢失，无法恢复');
    await _database.transaction(() async {
      final affected =
          await (_database.update(_database.vehicleAttachments)..where(
                (table) =>
                    table.id.equals(attachment.id) &
                    table.vehicleId.equals(attachment.vehicleId) &
                    table.isDeleted.equals(true),
              ))
              .write(
                VehicleAttachmentsCompanion(
                  isDeleted: const Value(false),
                  deletedAt: const Value(null),
                  updatedAt: Value(DateTime.now()),
                ),
              );
      await VehicleScope.requireAffectedRows(
        affected,
        '附件不属于当前车辆或未被删除：${attachment.id}',
      );
    });
  }

  Future<Directory> attachmentsRoot() async {
    final documents =
        await (documentsDirectory ?? getApplicationDocumentsDirectory)();
    return Directory('${documents.path}${Platform.pathSeparator}attachments');
  }

  String _extensionOf(String name) {
    final index = name.lastIndexOf('.');
    return index < 0 ? '' : name.substring(index + 1).toLowerCase();
  }

  String? _mimeType(String extension) => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => null,
  };

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

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
