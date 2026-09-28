import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import 'garden_tool_repair_repository.dart';

class GardenToolRepairAttachmentService {
  GardenToolRepairAttachmentService(
    this._repository, {
    this.documentsDirectory,
  });

  final GardenToolRepairRepository _repository;
  final Future<Directory> Function()? documentsDirectory;

  Future<GardenToolRepairAttachment> storePhoto({
    required int groupId,
    required XFile photo,
    required String attachmentType,
  }) async {
    final source = File(photo.path);
    if (!await source.exists()) throw StateError('所选照片不存在');
    final extension = _extension(photo.name, photo.path);
    final root = await attachmentsRoot();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}garden_tool_repairs'
      '${Platform.pathSeparator}$groupId',
    );
    await directory.create(recursive: true);
    final fileName = '${_uuidV4()}.$extension';
    final destination = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    await source.copy(destination.path);
    try {
      return await _repository.addAttachment(
        groupId: groupId,
        attachmentType: attachmentType,
        filePath: 'garden_tool_repairs/$groupId/$fileName',
      );
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  Future<File> resolveFile(GardenToolRepairAttachment attachment) async {
    final safePath = _safeRelativePath(attachment.filePath);
    final root = await attachmentsRoot();
    return File(
      '${root.path}${Platform.pathSeparator}'
      '${safePath.replaceAll('/', Platform.pathSeparator)}',
    );
  }

  Future<Directory> attachmentsRoot() async {
    final documents =
        await (documentsDirectory ?? getApplicationDocumentsDirectory)();
    return Directory('${documents.path}${Platform.pathSeparator}attachments');
  }

  String _extension(String name, String path) {
    final candidate = name.contains('.') ? name : path;
    final dot = candidate.lastIndexOf('.');
    if (dot < 0 || dot == candidate.length - 1) return 'jpg';
    final extension = candidate.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension) ? extension : 'jpg';
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
