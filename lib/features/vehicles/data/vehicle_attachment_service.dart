import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import 'vehicle_attachment_repository.dart';

class VehicleAttachmentIntegrity {
  const VehicleAttachmentIntegrity({
    required this.attachment,
    required this.exists,
    required this.sizeMatches,
    required this.hashMatches,
  });

  final VehicleAttachment attachment;
  final bool exists;
  final bool sizeMatches;
  final bool hashMatches;

  bool get isValid => exists && sizeMatches && hashMatches;
}

class VehicleAttachmentScanResult {
  const VehicleAttachmentScanResult({
    required this.missing,
    required this.orphanPaths,
  });

  final List<VehicleAttachment> missing;
  final List<String> orphanPaths;
}

class VehicleAttachmentService {
  const VehicleAttachmentService(this._repository);

  final VehicleAttachmentRepository _repository;

  Future<VehicleAttachment> importFile({
    required int vehicleId,
    required File sourceFile,
    required String originalFileName,
    required VehicleAttachmentCategory category,
    int? repairOrderId,
    String? remark,
  }) {
    return _repository.importFile(
      vehicleId: vehicleId,
      sourceFile: sourceFile,
      originalFileName: originalFileName,
      category: category.name,
      repairOrderId: repairOrderId,
      remark: remark,
    );
  }

  Future<VehicleAttachmentIntegrity> checkIntegrity(
    VehicleAttachment attachment,
  ) async {
    final file = await _repository.resolveFile(attachment);
    if (!await file.exists()) {
      return VehicleAttachmentIntegrity(
        attachment: attachment,
        exists: false,
        sizeMatches: false,
        hashMatches: false,
      );
    }
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    return VehicleAttachmentIntegrity(
      attachment: attachment,
      exists: true,
      sizeMatches: bytes.length == attachment.fileSize,
      hashMatches: attachment.fileHash == null || attachment.fileHash == hash,
    );
  }

  Future<File> resolveFile(VehicleAttachment attachment) =>
      _repository.resolveFile(attachment);

  Future<VehicleAttachmentScanResult> scanVehicle(int vehicleId) async {
    final attachments = await _repository.listForVehicle(
      vehicleId,
      includeDeleted: true,
    );
    final missing = <VehicleAttachment>[];
    final registered = <String>{};
    for (final attachment in attachments) {
      final file = await _repository.resolveFile(attachment);
      registered.add(_relativePath(await _repository.attachmentsRoot(), file));
      if (!await file.exists()) missing.add(attachment);
    }
    final directory = Directory(
      '${(await _repository.attachmentsRoot()).path}${Platform.pathSeparator}'
      'vehicles${Platform.pathSeparator}$vehicleId',
    );
    final orphanPaths = <String>[];
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final relative = _relativePath(
          await _repository.attachmentsRoot(),
          entity,
        );
        if (!registered.contains(relative)) orphanPaths.add(relative);
      }
    }
    orphanPaths.sort();
    return VehicleAttachmentScanResult(
      missing: missing,
      orphanPaths: orphanPaths,
    );
  }

  Future<void> exportFile(VehicleAttachment attachment, File target) async {
    final source = await resolveFile(attachment);
    if (!await source.exists()) throw StateError('附件文件已丢失');
    await source.copy(target.path);
  }

  String _relativePath(Directory root, File file) {
    final prefix = '${root.path}${Platform.pathSeparator}';
    return file.path.startsWith(prefix)
        ? file.path.substring(prefix.length).replaceAll('\\', '/')
        : file.path.replaceAll('\\', '/');
  }
}
