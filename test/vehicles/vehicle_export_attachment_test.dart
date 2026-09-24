import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/excel/application/excel_service.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_attachment_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_attachment_service.dart';
import 'package:qingsongban/features/vehicles/data/repair_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/repair_options.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';

void main() {
  late AppDatabase database;
  late Directory documents;
  late int vehicleId;

  setUp(() async {
    database = AppDatabase.forTesting();
    documents = await Directory.systemTemp.createTemp(
      'qingsongban-vehicle-test',
    );
    vehicleId = (await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '5号清扫车',
        vehicleNo: 'SW-005',
        vehicleType: VehicleType.sweeper,
      ),
    )).id;
  });

  tearDown(() async {
    await database.close();
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  test(
    'vehicle attachment resolves from the backed-up relative path',
    () async {
      final source = File(
        '${documents.path}${Platform.pathSeparator}repair.pdf',
      );
      await source.writeAsBytes(<int>[1, 2, 3, 4]);
      final repository = VehicleAttachmentRepository(
        database,
        documentsDirectory: () async => documents,
      );
      final attachment = await repository.importFile(
        vehicleId: vehicleId,
        sourceFile: source,
        originalFileName: 'repair.pdf',
        category: 'repair',
      );
      final resolved = await repository.resolveFile(attachment);
      expect(await resolved.readAsBytes(), <int>[1, 2, 3, 4]);
      expect(attachment.relativePath, startsWith('vehicles/$vehicleId/'));
      expect(attachment.storedFileName, isNotEmpty);
      expect(attachment.fileHash, isNotEmpty);
      expect(attachment.mimeType, 'application/pdf');
      final integrity = await VehicleAttachmentService(repository)
          .checkIntegrity(attachment);
      expect(integrity.isValid, isTrue);

      await repository.softDelete(attachment);
      expect((await repository.listForVehicle(vehicleId)).isEmpty, isTrue);
      expect(
        (await repository.listForVehicle(vehicleId, includeDeleted: true)),
        hasLength(1),
      );
      await repository.restore(attachment);
      expect(
        (await repository.listForVehicle(vehicleId)).single.id,
        attachment.id,
      );
    },
  );

  test(
    'vehicle attachments cannot reference another vehicle repair order',
    () async {
      final otherVehicle = (await VehicleRepository(database).save(
        draft: const VehicleDraft(
          name: '6号清扫车',
          vehicleNo: 'SW-006',
          vehicleType: VehicleType.sweeper,
        ),
      )).id;
      final repair = await RepairRepository(database).save(
        draft: RepairOrderDraft(
          vehicleId: otherVehicle,
          reportDate: DateTime(2026, 9, 20),
          faultFoundAt: DateTime(2026, 9, 20),
          symptom: '其他车辆故障',
          ticketStatus: RepairTicketStatus.notRequired,
        ),
      );
      final source = File(
        '${documents.path}${Platform.pathSeparator}cross.pdf',
      );
      await source.writeAsBytes(<int>[1, 2]);
      final repository = VehicleAttachmentRepository(
        database,
        documentsDirectory: () async => documents,
      );

      expect(
        repository.importFile(
          vehicleId: vehicleId,
          sourceFile: source,
          originalFileName: 'cross.pdf',
          repairOrderId: repair.id,
        ),
        throwsStateError,
      );
      expect(await repository.listForVehicle(vehicleId), isEmpty);
    },
  );

  test(
    'same-name vehicle attachments keep independent physical files',
    () async {
      final first = File('${documents.path}${Platform.pathSeparator}photo.pdf');
      final second = File(
        '${documents.path}${Platform.pathSeparator}photo-2.pdf',
      );
      await first.writeAsBytes(<int>[1]);
      await second.writeAsBytes(<int>[2]);
      final repository = VehicleAttachmentRepository(
        database,
        documentsDirectory: () async => documents,
      );
      final a = await repository.importFile(
        vehicleId: vehicleId,
        sourceFile: first,
        originalFileName: 'same.pdf',
        category: VehicleAttachmentCategory.repair.name,
      );
      final b = await repository.importFile(
        vehicleId: vehicleId,
        sourceFile: second,
        originalFileName: 'same.pdf',
        category: VehicleAttachmentCategory.repair.name,
      );
      expect(a.relativePath, isNot(b.relativePath));
      expect(a.fileHash, isNot(b.fileHash));
      expect(a.storedFileName, matches(RegExp(r'^[0-9a-f-]{36}\.pdf$')));
    },
  );

  test('scans missing and orphan vehicle attachment files', () async {
    final source = File('${documents.path}${Platform.pathSeparator}photo.jpg');
    await source.writeAsBytes(<int>[9, 8, 7]);
    final repository = VehicleAttachmentRepository(
      database,
      documentsDirectory: () async => documents,
    );
    final attachment = await repository.importFile(
      vehicleId: vehicleId,
      sourceFile: source,
      originalFileName: 'photo.jpg',
      category: VehicleAttachmentCategory.vehiclePhoto.name,
    );
    final resolved = await repository.resolveFile(attachment);
    await resolved.delete();
    final directory = Directory(
      '${documents.path}/attachments/vehicles/$vehicleId',
    );
    await File('${directory.path}/orphan.jpg').writeAsBytes(<int>[1]);

    final result = await VehicleAttachmentService(repository)
        .scanVehicle(vehicleId);
    expect(result.missing.single.id, attachment.id);
    expect(result.orphanPaths, contains('vehicles/$vehicleId/orphan.jpg'));
  });

  test(
    'exports vehicle workbook bytes without creating a manual expense table',
    () async {
      final bytes = await ExcelService(database)
          .exportVehiclesBytes(year: 2026);
      expect(bytes, isNotEmpty);
      final workbook = Excel.decodeBytes(bytes);
      expect(
        workbook.tables.keys,
        containsAll(<String>['年度油耗费用汇总', '油耗明细', '异常与缺失数据']),
      );
    },
  );
}
