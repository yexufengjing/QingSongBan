import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/assistant_business_demo_data_seeder.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/assistant/data/assistant_business_reader.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';

void main() {
  late AppDatabase database;
  final seedDate = DateTime(2026, 10, 19);

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() async => database.close());

  test(
    'assistant demo seed is additive and idempotent with reconciled positive business samples',
    () async {
      final oldEmployeeId = await database.into(database.employees).insert(
        EmployeesCompanion.insert(
          employeeNo: 'PRESERVED-EMP-001',
          name: '既有测试员工',
          hireDate: DateTime(2022, 3, 1),
        ),
      );
      final oldGroupId = await database.into(database.attendanceGroups).insert(
        AttendanceGroupsCompanion.insert(name: '既有测试考勤组'),
      );
      await database.into(database.attendanceRecords).insert(
        AttendanceRecordsCompanion.insert(
          employeeId: oldEmployeeId,
          attendanceDate: DateTime(2026, 9, 12),
          morningStatus: const Value(AttendanceHalfStatus.present),
          afternoonStatus: const Value(AttendanceHalfStatus.leave),
        ),
      );
      await database.into(database.monthlyAttendanceRosters).insert(
        MonthlyAttendanceRostersCompanion.insert(
          yearMonth: '2026-09',
          attendanceGroupId: oldGroupId,
          employeeId: oldEmployeeId,
        ),
      );

      final originalRows = await _rowSnapshots(database);
      expect(
        await AssistantBusinessDemoDataSeeder.seed(database, now: seedDate),
        isTrue,
      );

      final seededRows = await _rowSnapshots(database);
      for (final entry in originalRows.entries) {
        final after = seededRows[entry.key] ?? const <String>[];
        for (final original in entry.value) {
          expect(after, contains(original), reason: '既有表 ${entry.key} 的行被保留');
        }
      }
      expect(await _foreignKeyViolationCount(database), 0);

      final employee = await (database.select(database.employees)
            ..where((row) => row.employeeNo.equals(
              AssistantBusinessDemoDataSeeder.employeeNo,
            )))
          .getSingle();
      expect(employee.name, '演示员工林晓禾');
      expect(employee.remark, contains('DEMO-ASSISTANT-EMP-001'));

      final payrollItems = await (database.select(database.payrollItems)
            ..where((row) => row.employeeId.equals(employee.id)))
          .get();
      expect(payrollItems, hasLength(2));
      for (final item in payrollItems) {
        final month = await (database.select(database.payrollBatches)
              ..where((row) => row.id.equals(item.payrollBatchId)))
            .getSingle();
        final summary = await (database.select(database.monthlyAttendanceSummaries)
              ..where((row) => row.employeeId.equals(employee.id) &
                  row.yearMonth.equals(month.payrollMonth) &
                  row.isDeleted.equals(false)))
            .getSingle();
        final allEmployeeRecords = await (database.select(database.attendanceRecords)
              ..where((row) => row.employeeId.equals(employee.id)))
            .get();
        final dailyRecords = allEmployeeRecords.where((row) =>
            '${row.attendanceDate.year.toString().padLeft(4, '0')}-'
                    '${row.attendanceDate.month.toString().padLeft(2, '0')}' ==
                month.payrollMonth);
        final recordedPresentHalfDays = dailyRecords.fold<int>(
          0,
          (sum, row) => sum +
              (row.morningStatus == AttendanceHalfStatus.present ? 1 : 0) +
              (row.afternoonStatus == AttendanceHalfStatus.present ? 1 : 0),
        );

        expect(item.attendanceHalfDaysSnapshot, summary.attendanceDays * 2);
        expect(
          recordedPresentHalfDays,
          item.attendanceHalfDaysSnapshot,
          reason: '${month.payrollMonth}工资出勤快照必须与逐日考勤相符',
        );
        expect(item.baseWage, item.attendanceHalfDaysSnapshot / 2 * item.dailyWage);
        expect(
          item.finalWage,
          item.baseWage + item.subsidy - item.insuranceDeduction,
        );
        expect(item.finalWage, greaterThan(0));
      }
      final currentPayroll = payrollItems.singleWhere((item) =>
          item.remark!.contains('2026-10'));
      expect(currentPayroll.finalWage, 4500);
      expect(currentPayroll.subsidy, greaterThan(currentPayroll.baseWage));

      final material = await (database.select(database.inventoryMaterials)
            ..where((row) => row.materialCode.equals(
              AssistantBusinessDemoDataSeeder.materialCode,
            )))
          .getSingle();
      expect(material.currentStock, 6);
      expect(material.minStock, 8);
      expect(material.currentStock, greaterThan(0));

      final purchase = await (database.select(database.purchaseRequests)
            ..where((row) => row.title.contains('DEMO-ASSISTANT-PUR-001')))
          .getSingle();
      final purchaseItems = await (database.select(database.purchaseRequestItems)
            ..where((row) => row.requestId.equals(purchase.id)))
          .get();
      expect(purchaseItems, hasLength(1));
      expect(purchaseItems.single.inventoryMaterialId, material.id);
      expect(purchaseItems.single.requestQuantity, 10);
      final stockEntries = await (database.select(database.purchaseStockEntries)
            ..where((row) => row.requestItemId.equals(purchaseItems.single.id)))
          .get();
      expect(stockEntries.fold<double>(0, (sum, row) => sum + row.quantity), 4);

      final welfareRows = await database.customSelect(
        "SELECT status, quantity FROM item_distribution_entries WHERE note LIKE '%DEMO-ASSISTANT-WELFARE-%' AND is_deleted=0",
      ).get();
      expect(welfareRows, hasLength(2));
      expect(welfareRows.map((row) => row.read<String>('status')).toSet(), {
        'received',
        'not_received',
      });
      expect(
        welfareRows.every((row) => row.read<double>('quantity') > 0),
        isTrue,
      );

      final repairs = await (database.select(database.repairOrders)
            ..where((row) => row.repairNo.equals(
              AssistantBusinessDemoDataSeeder.repairNo,
            )))
          .get();
      expect(repairs, hasLength(1));
      expect(repairs.single.actualAmountCents, 12500);
      expect(repairs.single.status, VehicleRepairStatus.repairing);

      final gardens = await (database.select(database.gardenToolRepairItems)
            ..where((row) => row.projectName.equals(
              AssistantBusinessDemoDataSeeder.gardenProject,
            )))
          .get();
      expect(gardens, hasLength(2));
      final gardenByMonth = <String, GardenToolRepairItem>{};
      for (final item in gardens) {
        final group = await (database.select(database.gardenToolRepairGroups)
              ..where((row) => row.id.equals(item.groupId)))
            .getSingle();
        gardenByMonth[group.repairMonth] = item;
      }
      expect(gardenByMonth['2026-09']!.amountCents, 2000);
      expect(gardenByMonth['2026-10']!.amountCents, 2400);
      expect(gardenByMonth.values.every((item) => item.amountCents > 0), isTrue);

      final reader = AssistantBusinessReader(database);
      final businessCases = <(AssistantBusinessType, String, String?, String?, String)>[
        (AssistantBusinessType.personnel, '演示员工林晓禾人员档案', null,
          '演示员工林晓禾', '在职'),
        (AssistantBusinessType.payroll, '演示员工林晓禾工资实发', '2026-10',
          '演示员工林晓禾', '4500.00'),
        (AssistantBusinessType.inventory, '演示绿篱刀片低库存', null,
          AssistantBusinessDemoDataSeeder.materialCode, '现存 6 片'),
        (AssistantBusinessType.purchase, 'DEMO-ASSISTANT-PUR-001分批入库数量', null,
          AssistantBusinessDemoDataSeeder.purchaseId, '4/10 片'),
        (AssistantBusinessType.distribution, '2026年10月演示员工福利领取状态',
          '2026-10', '演示员工林晓禾', '已领取'),
        (AssistantBusinessType.vehicleMaintenance, '演示车辆维修金额和进度', null,
          AssistantBusinessDemoDataSeeder.repairNo, '125.00'),
        (AssistantBusinessType.vehicleReminders, '北区巡检车未处理提醒', null,
          AssistantBusinessDemoDataSeeder.vehicleNo, '北区'),
        (AssistantBusinessType.gardenRepair, '2026年10月园林维修登记金额',
          '2026-10', AssistantBusinessDemoDataSeeder.gardenProject, '24.00'),
      ];
      for (final (domain, question, month, subject, expectedFact) in businessCases) {
        final result = await reader.read(AssistantBusinessQuery(
          domain: domain,
          question: question,
          now: seedDate,
          yearMonth: month,
          subject: subject,
          operation: switch (domain) {
            AssistantBusinessType.inventory => 'lowStock',
            AssistantBusinessType.gardenRepair => 'monthlyTotal',
            _ => 'summary',
          },
        ));
        expect(result.domain, domain);
        expect(result.facts, isNotEmpty, reason: '$domain 演示查询应找到业务事实');
        expect(result.sourceRule, isNotEmpty);
        expect(result.sourcePage, isNotEmpty);
        expect(
          result.facts.any((fact) =>
              '${fact.label} ${fact.value} ${fact.explanation ?? ''}'
                  .contains(expectedFact)),
          isTrue,
          reason: '$domain 应从真实演示记录回答中文事实及金额/数量',
        );
        if (domain == AssistantBusinessType.payroll) {
          expect(result.relatedReads, hasLength(1));
          expect(
            result.relatedReads.single.summary,
            contains(RegExp(r'出勤\s+20(?:\.0)?\s*天')),
          );
          expect(result.relatedReads.single.sourcePage, contains('2026-10'));
        }
      }

      final seededSnapshot = await _rowSnapshots(database);
      expect(
        await AssistantBusinessDemoDataSeeder.seed(database, now: seedDate),
        isFalse,
      );
      expect(await _rowSnapshots(database), seededSnapshot);
      expect(await _foreignKeyViolationCount(database), 0);
    },
  );
}

Future<Map<String, List<String>>> _rowSnapshots(AppDatabase database) async {
  final tableNames = <String>{
    for (final table in database.allTables) table.actualTableName,
    'item_distribution_batches',
    'item_distribution_entries',
  };
  final result = <String, List<String>>{};
  for (final tableName in tableNames) {
    final safeName = tableName.replaceAll('"', '""');
    final rows = await database.customSelect('SELECT * FROM "$safeName"').get();
    result[tableName] = [
      for (final row in rows)
        jsonEncode(
          row.data.map((key, value) => MapEntry(key, _canonical(value))),
        ),
    ]..sort();
  }
  return result;
}

Object? _canonical(Object? value) => switch (value) {
  Uint8List bytes => base64Encode(bytes),
  DateTime date => date.toIso8601String(),
  _ => value,
};

Future<int> _foreignKeyViolationCount(AppDatabase database) async =>
    (await database.customSelect('PRAGMA foreign_key_check').get()).length;
