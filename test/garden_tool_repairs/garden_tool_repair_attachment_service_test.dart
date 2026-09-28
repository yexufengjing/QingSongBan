import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/garden_tool_repairs/data/garden_tool_repair_attachment_service.dart';
import 'package:qingsongban/features/garden_tool_repairs/data/garden_tool_repair_repository.dart';
import 'package:qingsongban/features/garden_tool_repairs/domain/repair_models.dart';

void main() {
  late AppDatabase database;
  late Directory temporaryDirectory;

  setUp(() async {
    database = AppDatabase.forTesting();
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'garden-repair-',
    );
  });

  tearDown(() async {
    await database.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'copies a picked photo into app storage and resolves it for preview',
    () async {
      final source = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}ticket.jpg',
      );
      await source.writeAsBytes([1, 2, 3, 4]);
      final repository = GardenToolRepairRepository(database);
      final unit = await repository.saveUnit(
        name: '特钢',
        sortOrder: 0,
        isActive: true,
      );
      final group = await repository.saveGroup(
        GardenToolRepairGroupDraft(
          repairMonth: '2026-09',
          repairDate: DateTime(2026, 9, 3),
          unitId: unit.id,
          repairerName: '张三',
          items: const [
            GardenToolRepairItemDraft(
              projectName: '刀片',
              countUnit: '片',
              quantity: 1,
              unitPriceCents: 800,
            ),
          ],
        ),
      );
      final service = GardenToolRepairAttachmentService(
        repository,
        documentsDirectory: () async => temporaryDirectory,
      );

      final attachment = await service.storePhoto(
        groupId: group.id,
        photo: XFile(source.path, name: 'ticket.jpg'),
        attachmentType: 'receipt',
      );
      final storedFile = await service.resolveFile(attachment);
      expect(
        attachment.filePath,
        startsWith('garden_tool_repairs/${group.id}/'),
      );
      expect(await storedFile.exists(), isTrue);
      expect(await storedFile.readAsBytes(), [1, 2, 3, 4]);

      await repository.softDeleteGroup(group.id);
      expect(await storedFile.exists(), isTrue);
      expect(
        (await repository.loadMonth(DateTime(2026, 9)))
            .map((item) => item.group.id),
        isNot(contains(group.id)),
      );
    },
  );
}
