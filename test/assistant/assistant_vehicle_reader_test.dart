import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/assistant/application/assistant_answer_formatter.dart';
import 'package:qingsongban/features/assistant/data/assistant_attendance_reader.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_expense_repository.dart';

void main() {
  late AppDatabase database;
  late AssistantAttendanceReader reader;
  var nextRepairNo = 0;

  setUp(() {
    database = AppDatabase.forTesting();
    reader = AssistantAttendanceReader(
      database,
      random: Random(31),
      clock: () => DateTime(2026, 10, 18, 12),
    );
    nextRepairNo = 0;
  });

  tearDown(() async => database.close());

  Future<Vehicle> createVehicle(
    String name,
    String number, {
    VehicleStatus status = VehicleStatus.normal,
    bool isDeleted = false,
  }) async {
    final id = await database
        .into(database.vehicles)
        .insert(
          VehiclesCompanion.insert(
            name: name,
            vehicleNo: number,
            vehicleType: const Value(VehicleType.sweeper),
            status: Value(status),
            isDeleted: Value(isDeleted),
          ),
        );
    return (database.select(
      database.vehicles,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  Future<int> addRepair(
    int vehicleId, {
    required DateTime reportDate,
    required int amountCents,
    VehicleRepairStatus status = VehicleRepairStatus.completed,
    DateTime? completedAt,
    bool isDeleted = false,
  }) async {
    nextRepairNo++;
    return database
        .into(database.repairOrders)
        .insert(
          RepairOrdersCompanion.insert(
            repairNo: 'TEST-REPAIR-$nextRepairNo',
            vehicleId: vehicleId,
            reportDate: reportDate,
            faultFoundAt: reportDate,
            symptom: '隔离测试维修',
            ticketStatus: RepairTicketStatus.notRequired,
            actualAmountCents: Value(amountCents),
            status: Value(status),
            completedAt: Value(completedAt),
            isDeleted: Value(isDeleted),
          ),
        );
  }

  Future<Map<String, Object?>> snapshotTables() async {
    final snapshot = <String, Object?>{};
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    for (final table in tables) {
      final tableName = table.read<String>('name');
      final escapedName = tableName.replaceAll('"', '""');
      final rows = await database
          .customSelect('SELECT * FROM "$escapedName" ORDER BY rowid')
          .get();
      snapshot[tableName] = rows.map((row) => row.data).toList();
    }
    return snapshot;
  }

  test(
    'annual summary follows report year, completed status and deletion',
    () async {
      final vehicle = await createVehicle('一号车', 'V-001');
      await addRepair(
        vehicle.id,
        reportDate: DateTime(2025, 12, 31),
        completedAt: DateTime(2026, 1, 2),
        amountCents: 12345,
      );
      await addRepair(
        vehicle.id,
        reportDate: DateTime(2026, 1, 1),
        amountCents: 20000,
      );
      await addRepair(
        vehicle.id,
        reportDate: DateTime(2025, 8, 1),
        amountCents: 90000,
        status: VehicleRepairStatus.repairing,
      );
      await addRepair(
        vehicle.id,
        reportDate: DateTime(2025, 7, 1),
        amountCents: 80000,
        isDeleted: true,
      );

      final result = await reader.readVehicleAnnualRepairs(
        ResolvedVehicleAnnualRepairQuery(
          vehicle: ResolvedVehicle(
            vehicleId: vehicle.id,
            label: vehicle.name,
            vehicleNumber: vehicle.vehicleNo,
          ),
          year: 2025,
        ),
      );

      expect(result.status, VehicleAnnualRepairReadStatus.success);
      expect(result.completedRepairCount, 1);
      expect(result.actualAmountCents, 12345);
      expect(result.details.single.reportDate, DateTime(2025, 12, 31));
      expect(result.details.single.completedAt, DateTime(2026, 1, 2));
      expect(result.currency, 'CNY');

      final existingRepairExpenses =
          (await VehicleExpenseRepository(database).list(
            vehicle.id,
            year: 2025,
          )).where((item) => item.sourceType == 'repair');
      expect(result.completedRepairCount, existingRepairExpenses.length);
      expect(
        result.actualAmountCents,
        existingRepairExpenses.fold<int>(
          0,
          (sum, item) => sum + item.amountCents,
        ),
      );
      expect(
        result.details.map((detail) => detail.repairOrderId),
        existingRepairExpenses.map((item) => item.sourceId),
      );
    },
  );

  test(
    'ranking aggregates all vehicles before stable tie-aware pagination',
    () async {
      final a = await createVehicle('甲车', 'V-001');
      final b = await createVehicle(
        '乙车',
        'V-002',
        status: VehicleStatus.stopped,
      );
      final c = await createVehicle('丙车', 'V-003');
      final deleted = await createVehicle('删除车', 'V-004', isDeleted: true);
      await addRepair(
        a.id,
        reportDate: DateTime(2025, 5, 1),
        amountCents: 10000,
      );
      await addRepair(b.id, reportDate: DateTime(2025, 6, 1), amountCents: 0);
      await addRepair(
        deleted.id,
        reportDate: DateTime(2025, 6, 1),
        amountCents: 90000,
      );

      final firstPage = await reader.readAnnualVehicleRanking(
        const ResolvedVehicleRankingQuery(year: 2025, limit: 1),
      );
      expect(firstPage.totalVehicleCount, 3);
      expect(firstPage.returnedCount, 1);
      expect(firstPage.hasRepairRecords, isTrue);
      expect(firstPage.rows.single.vehicleId, a.id);
      expect(firstPage.rows.single.rank, 1);
      expect(firstPage.hasMore, isTrue);

      final secondPage = await reader.readNextVehicleRankingPage(
        resultRef: firstPage.resultRef,
        cursor: firstPage.nextCursor!,
      );
      expect(secondPage.rows.map((row) => row.vehicleId), [b.id]);
      expect(secondPage.rows.map((row) => row.rank), [2]);
      expect(secondPage.rows.first.completedRepairCount, 1);
      expect(secondPage.rows.first.actualAmountCents, 0);
      expect(secondPage.returnedCount, 2);
      expect(secondPage.hasMore, isTrue);
      expect(secondPage.hasRepairRecords, isTrue);

      final thirdPage = await reader.readNextVehicleRankingPage(
        resultRef: secondPage.resultRef,
        cursor: secondPage.nextCursor!,
      );
      expect(thirdPage.rows.map((row) => row.vehicleId), [c.id]);
      expect(thirdPage.rows.map((row) => row.rank), [2]);
      expect(thirdPage.returnedCount, 3);
      expect(thirdPage.hasMore, isFalse);

      final duplicatePage = await reader.readNextVehicleRankingPage(
        resultRef: firstPage.resultRef,
        cursor: firstPage.nextCursor!,
      );
      expect(duplicatePage.error, AssistantErrorCode.staleResult);
    },
  );

  test(
    'all vehicles without repairs are distinct from a zero amount repair',
    () async {
      await createVehicle('无维修甲', 'V-001');
      await createVehicle('无维修乙', 'V-002', status: VehicleStatus.stopped);
      final empty = await reader.readAnnualVehicleRanking(
        const ResolvedVehicleRankingQuery(year: 2025),
      );
      expect(empty.totalVehicleCount, 2);
      expect(empty.hasRepairRecords, isFalse);
      expect(
        const AssistantAnswerFormatter().formatVehicleRanking(empty).text,
        '2025 年没有可比较的车辆维修记录。',
      );

      final vehicle = await createVehicle('零金额有单', 'V-003');
      await addRepair(
        vehicle.id,
        reportDate: DateTime(2025, 1, 1),
        amountCents: 0,
      );
      final withZeroAmountOrder = await reader.readAnnualVehicleRanking(
        const ResolvedVehicleRankingQuery(year: 2025),
      );
      expect(withZeroAmountOrder.hasRepairRecords, isTrue);
      expect(
        withZeroAmountOrder.rows
            .firstWhere((row) => row.vehicleId == vehicle.id)
            .completedRepairCount,
        1,
      );
    },
  );

  test('exact vehicle number wins and name ambiguity requires a one-time local ref', () async {
    final first = await createVehicle('重名车辆', 'V-101');
    await createVehicle('重名车辆', 'V-102');

    final exact = await reader.resolveVehicle(
      const VehicleSelector(vehicleText: 'V-101'),
    );
    expect(exact.status, VehicleResolutionStatus.unique);
    expect(exact.vehicle!.vehicleId, first.id);

    final ambiguous = await reader.resolveVehicle(
      const VehicleSelector(vehicleText: '重名车辆'),
    );
    expect(ambiguous.status, VehicleResolutionStatus.candidates);
    expect(ambiguous.candidates, hasLength(2));
    final selected = await reader.resolveVehicleCandidate(
      ambiguous.candidates.first.candidateRef,
    );
    expect(selected.status, VehicleResolutionStatus.unique);
    expect(selected.vehicle!.vehicleId, ambiguous.candidates.first.vehicleId);
    final replay = await reader.resolveVehicleCandidate(
      ambiguous.candidates.first.candidateRef,
    );
    expect(replay.status, VehicleResolutionStatus.unavailable);
  });

  test('vehicle snapshot query changes no business-table content', () async {
    final vehicle = await createVehicle('只读车辆', 'V-201');
    await addRepair(
      vehicle.id,
      reportDate: DateTime(2025, 3, 1),
      amountCents: 7400,
    );
    final before = await snapshotTables();

    await reader.readVehicleAnnualRepairs(
      ResolvedVehicleAnnualRepairQuery(
        vehicle: ResolvedVehicle(
          vehicleId: vehicle.id,
          label: vehicle.name,
          vehicleNumber: vehicle.vehicleNo,
        ),
        year: 2025,
      ),
    );
    final page = await reader.readAnnualVehicleRanking(
      const ResolvedVehicleRankingQuery(year: 2025),
    );
    if (page.nextCursor case final cursor?) {
      await reader.readNextVehicleRankingPage(
        resultRef: page.resultRef,
        cursor: cursor,
      );
    }

    expect(await snapshotTables(), before);
  });

  test(
    'deleted vehicle ref and failed read remain controlled errors',
    () async {
      final vehicle = await createVehicle('即将删除', 'V-301');
      await database
          .into(database.repairOrders)
          .insert(
            RepairOrdersCompanion.insert(
              repairNo: 'TEST-REPAIR-DELETE',
              vehicleId: vehicle.id,
              reportDate: DateTime(2025, 2, 1),
              faultFoundAt: DateTime(2025, 2, 1),
              symptom: '隔离测试维修',
              ticketStatus: RepairTicketStatus.notRequired,
            ),
          );
      await (database.update(database.vehicles)
            ..where((table) => table.id.equals(vehicle.id)))
          .write(const VehiclesCompanion(isDeleted: Value(true)));
      final deletedResult = await reader.readVehicleAnnualRepairs(
        ResolvedVehicleAnnualRepairQuery(
          vehicle: ResolvedVehicle(
            vehicleId: vehicle.id,
            label: vehicle.name,
            vehicleNumber: vehicle.vehicleNo,
          ),
          year: 2025,
        ),
      );
      expect(deletedResult.status, VehicleAnnualRepairReadStatus.unavailable);
      expect(deletedResult.error, AssistantErrorCode.entityUnavailable);

      final activeVehicle = await createVehicle('有效测试车辆', 'V-302');
      await database.customStatement('DROP TABLE repair_orders');
      final failed = await reader.readVehicleAnnualRepairs(
        ResolvedVehicleAnnualRepairQuery(
          vehicle: ResolvedVehicle(
            vehicleId: activeVehicle.id,
            label: activeVehicle.name,
            vehicleNumber: activeVehicle.vehicleNo,
          ),
          year: 2025,
        ),
      );
      expect(failed.status, VehicleAnnualRepairReadStatus.failure);
      expect(failed.error, AssistantErrorCode.unknown);
      expect(failed.completedRepairCount, 0);
      expect(
        const AssistantAnswerFormatter().formatVehicleSummary(failed).text,
        '本地车辆维修汇总读取失败，请重试。',
      );
    },
  );
}
