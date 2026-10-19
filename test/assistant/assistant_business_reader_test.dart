import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/assistant/data/assistant_business_reader.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/daily_attendance_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/payroll/data/payroll_repository.dart';
import 'package:qingsongban/features/payroll/data/wage_settings_repository.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';
import 'package:qingsongban/features/reports/data/monthly_summary_repository.dart';

import '../support/app_route_cases.dart';

void main() {
  late AppDatabase database;
  late AssistantBusinessReader reader;

  setUp(() {
    database = AppDatabase.forTesting();
    reader = AssistantBusinessReader(database);
  });

  tearDown(() async => database.close());

  test('payroll reports a persisted validation warning and attendance basis read-only', () async {
    final groupId = await database.into(database.attendanceGroups).insert(
      AttendanceGroupsCompanion.insert(name: '工资只读依据组'),
    );
    final employeeId = await database.into(database.employees).insert(
      EmployeesCompanion.insert(
        employeeNo: 'TEST-EMP-901',
        name: '周启明',
        hireDate: DateTime(2024, 1, 1),
      ),
    );
    await database.into(database.monthlyAttendanceRosters).insert(
      MonthlyAttendanceRostersCompanion.insert(
        yearMonth: '2026-09',
        attendanceGroupId: groupId,
        employeeId: employeeId,
      ),
    );
    await database.into(database.attendanceRecords).insert(
      AttendanceRecordsCompanion.insert(
        employeeId: employeeId,
        attendanceDate: DateTime(2026, 9, 1),
        morningStatus: const Value(AttendanceHalfStatus.present),
        afternoonStatus: const Value(AttendanceHalfStatus.present),
      ),
    );
    final augustBatch = await database.into(database.payrollBatches).insert(
      PayrollBatchesCompanion.insert(payrollMonth: '2026-08', name: '八月测试批次'),
    );
    final septemberBatch = await database.into(database.payrollBatches).insert(
      PayrollBatchesCompanion.insert(payrollMonth: '2026-09', name: '九月测试批次'),
    );
    final jobTypeId = await database.into(database.wageJobTypes).insert(
      WageJobTypesCompanion.insert(
        name: '测试工种',
        defaultDailyWage: const Value(100.0),
      ),
    );
    await _insertPayrollItem(database, augustBatch, employeeId, '2026-08', 99999);
    final septemberItemId = await _insertPayrollItem(
      database,
      septemberBatch,
      employeeId,
      '2026-09',
      4500,
      jobTypeId: jobTypeId,
      baseWage: 2000,
      subsidy: 2500,
      dailyWage: 100,
    );
    final before = await _snapshotBusinessTables(database);

    final result = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.payroll,
        question: '检查周启明2026年9月工资异常并说明考勤依据',
        yearMonth: '2026-09',
        subject: '周启明',
        operation: 'detail',
        now: DateTime(2026, 10, 19),
      ),
    );

    expect(result.domain, AssistantBusinessType.payroll);
    expect(result.facts.map((fact) => fact.value), contains(contains('4500.00')));
    expect(result.facts.map((fact) => fact.value), isNot(contains(contains('99999'))));
    final subsidyWarning = result.facts.firstWhere(
      (fact) =>
          fact.label == '工资待核对' && fact.value.contains('补助高于基础工资'),
    );
    expect(subsidyWarning.sourcePage, '/reports/payroll/item/$septemberItemId');
    expect(result.relatedReads, hasLength(1));
    expect(result.relatedReads.single.domain, AssistantBusinessType.attendance);
    expect(result.relatedReads.single.title, contains('2026-09'));
    expect(result.relatedReads.single.summary, contains('出勤'));
    expect(result.sourcePage, '/reports/payroll/item/$septemberItemId');
    expect(_matchesProductionRoute(result.sourcePage), isTrue);
    expect(_matchesProductionRoute(result.facts.last.sourcePage!), isTrue);
    expect(result.facts.last.sourcePage, '/reports/payroll/item/$septemberItemId');
    expect(await _snapshotBusinessTables(database), before);
  });

  test('payroll reader warns only after repository attendance snapshot changes', () async {
    final group = await AttendanceGroupRepository(database).save(
      draft: const AttendanceGroupDraft(name: '工资快照回归组'),
    );
    final employee = await PersonnelRepository(database).save(
      draft: EmployeeDraft(
        employeeNo: 'TEST-ATT-SNAPSHOT-001',
        name: '陈晓芸',
        hireDate: DateTime(2026, 10, 1),
        status: EmployeeStatus.active,
        employmentType: '临时工',
      ),
    );
    await MonthlyRosterRepository(database).addEmployee(
      yearMonth: '2026-10',
      groupId: group.id,
      employeeId: employee.id,
    );
    await DailyAttendanceRepository(database).save(
      DailyAttendanceDraft(
        employeeId: employee.id,
        attendanceDate: DateTime(2026, 10, 1),
        morningStatus: AttendanceHalfStatus.present,
        afternoonStatus: AttendanceHalfStatus.present,
      ),
    );
    final wages = WageSettingsRepository(database);
    final job = await wages.saveJobType(
      draft: const WageJobTypeDraft(name: '快照测试工种', defaultDailyWage: 100),
    );
    await wages.saveProfile(
      EmployeeWageProfileDraft(
        employeeId: employee.id,
        participatesInPayroll: true,
        jobTypeId: job.id,
      ),
    );
    final summaries = MonthlySummaryRepository(database);
    await summaries.generate(yearMonth: '2026-10');
    await summaries.setStatus(
      yearMonth: '2026-10',
      status: MonthlySummaryStatus.confirmed,
    );

    final payroll = PayrollRepository(database);
    final batch = await payroll.ensureDraft('2026-10');
    await payroll.generateRoster(batch.id);
    final query = AssistantBusinessQuery(
      domain: AssistantBusinessType.payroll,
      question: '查陈晓芸2026年10月工资异常和金额',
      yearMonth: '2026-10',
      subject: '陈晓芸',
      operation: 'detail',
      now: DateTime(2026, 11, 1),
    );

    final beforeUnchangedRead = await _snapshotBusinessTables(database);
    final unchanged = await reader.read(query);
    expect(
      unchanged.facts.any((fact) => fact.value.contains('考勤汇总在工资生成后发生变化')),
      isFalse,
    );
    expect(await _snapshotBusinessTables(database), beforeUnchangedRead);

    final summary = await (database.select(database.monthlyAttendanceSummaries)
          ..where((row) =>
              row.yearMonth.equals('2026-10') &
              row.employeeId.equals(employee.id)))
        .getSingle();
    await (database.update(database.monthlyAttendanceSummaries)
          ..where((row) => row.id.equals(summary.id)))
        .write(
      MonthlyAttendanceSummariesCompanion(
        attendanceDays: Value(summary.attendanceDays + 1),
        updatedAt: Value(DateTime(2026, 11, 2)),
      ),
    );

    final beforeChangedRead = await _snapshotBusinessTables(database);
    final changed = await reader.read(query);
    expect(
      changed.facts.any((fact) => fact.value.contains('考勤汇总在工资生成后发生变化')),
      isTrue,
    );
    expect(await _snapshotBusinessTables(database), beforeChangedRead);
  });

  test('welfare reads only received, live entries in the requested benefit month', () async {
    final septemberBatch = await _insertDistributionBatch(database, '2026-09');
    final octoberBatch = await _insertDistributionBatch(database, '2026-10');
    await _insertDistributionEntry(database, septemberBatch, name: '周启明', status: 'received');
    await _insertDistributionEntry(database, septemberBatch, name: '周启明', itemCode: 'unreceived', status: 'not_received');
    await _insertDistributionEntry(database, octoberBatch, name: '周启明', itemCode: 'october', status: 'received');
    await _insertDistributionEntry(database, septemberBatch, name: '已删除', itemCode: 'deleted', status: 'received', deleted: true);
    final before = await _snapshotBusinessTables(database);

    final result = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.distribution,
        question: '查周启明2026年9月已领取的福利',
        yearMonth: '2026-09',
        subject: '周启明',
        operation: 'received',
        now: DateTime(2026, 10, 19),
      ),
    );

    final receivedRows = result.facts
        .where((fact) => fact.label.contains('周启明'))
        .toList();
    expect(receivedRows, hasLength(1));
    expect(receivedRows.single.value, contains('已领取'));
    expect(receivedRows.single.value, isNot(contains('2026-10')));
    expect(result.sourcePage, '/items?year=2026&month=09');
    expect(_matchesProductionRoute(result.sourcePage), isTrue);
    expect(await _snapshotBusinessTables(database), before);

    final unreceived = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.distribution,
        question: '查周启明2026年9月还没有领取的福利',
        yearMonth: '2026-09',
        subject: '周启明',
        operation: 'notReceived',
        now: DateTime(2026, 10, 19),
      ),
    );
    final unreceivedRows = unreceived.facts
        .where((fact) => fact.label.contains('周启明'))
        .toList();
    expect(unreceivedRows, hasLength(1));
    expect(unreceivedRows.single.value, contains('未领取'));
    expect(unreceivedRows.single.value, isNot(contains('2026-10')));
    expect(_matchesProductionRoute(unreceivedRows.single.sourcePage!), isTrue);
    expect(await _snapshotBusinessTables(database), before);
  });

  test('low-stock purchase link follows material identity when names are duplicated', () async {
    final neededId = await database.into(database.inventoryMaterials).insert(
      InventoryMaterialsCompanion.insert(
        materialCode: 'FILTER-A',
        materialName: '同名滤芯',
        unitName: '个',
        modelSpec: const Value('A型'),
        currentStock: const Value(1),
        minStock: const Value(4),
      ),
    );
    final otherId = await database.into(database.inventoryMaterials).insert(
      InventoryMaterialsCompanion.insert(
        materialCode: 'FILTER-B',
        materialName: '同名滤芯',
        unitName: '盒',
        modelSpec: const Value('B型'),
        currentStock: const Value(20),
        minStock: const Value(2),
      ),
    );
    final neededRequest = await _insertPurchase(database, 'A型滤芯补货');
    final otherRequest = await _insertPurchase(database, 'B型滤芯补货');
    await _insertPurchaseItem(database, neededRequest, neededId, '同名滤芯', '个', 4, 1);
    await _insertPurchaseItem(database, otherRequest, otherId, '同名滤芯', '盒', 6, 0);

    final result = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.inventory,
        question: '哪些滤芯低库存，关联到对应采购单？',
        subject: '同名滤芯',
        operation: 'lowStock',
        now: DateTime(2026, 10, 19),
      ),
    );

    expect(result.facts.any((fact) => fact.label.contains('FILTER-A')), isTrue);
    expect(result.facts.any((fact) => fact.label.contains('FILTER-B')), isFalse);
    expect(result.relatedReads, hasLength(1));
    expect(result.relatedReads.single.facts.map((fact) => fact.label), ['A型滤芯补货']);
    expect(result.relatedReads.single.facts.map((fact) => fact.label), isNot(contains('B型滤芯补货')));
    expect(
      result.facts.singleWhere((fact) => fact.label.contains('FILTER-A')).sourcePage,
      '/inventory/materials/$neededId',
    );
    expect(result.sourcePage, '/inventory/materials/$neededId');
    expect(result.relatedReads.single.facts.single.sourcePage, '/purchase/detail/$neededRequest');
    expect(_matchesProductionRoute(result.facts.last.sourcePage!), isTrue);
    expect(_matchesProductionRoute(result.relatedReads.single.facts.single.sourcePage!), isTrue);
  });

  test('a named personnel miss stays empty instead of becoming an all-staff summary', () async {
    final employeeId = await database.into(database.employees).insert(
      EmployeesCompanion.insert(
        employeeNo: 'TEST-EMP-902',
        name: '周启明',
        hireDate: DateTime(2024, 1, 1),
      ),
    );

    final result = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.personnel,
        question: '查一位未登记人员的档案',
        subject: '没有这位员工',
        now: DateTime(2026, 10, 19),
      ),
    );

    expect(result.facts, isEmpty);
    expect(result.summary, contains('没有找到'));
    expect(result.summary, isNot(contains('周启明')));
    expect(result.sourcePage, '/personnel');
    expect(_matchesProductionRoute(result.sourcePage), isTrue);

    final found = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.personnel,
        question: '查周启明的人员档案',
        subject: '周启明',
        now: DateTime(2026, 10, 19),
      ),
    );
    expect(found.facts, hasLength(1));
    expect(found.facts.single.label, contains('周启明'));
    expect(found.facts.single.sourcePage, '/personnel/$employeeId');
    expect(found.sourcePage, '/personnel/$employeeId');
    expect(_matchesProductionRoute(found.facts.single.sourcePage!), isTrue);
  });

  test('purchase progress keeps requested and received quantities with their own units', () async {
    final request = await _insertPurchase(database, '多单位演示采购单');
    await _insertPurchaseItem(database, request, null, '刹车片', '片', 4, 2);
    await _insertPurchaseItem(database, request, null, '润滑油', '桶', 3, 1);

    final result = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.purchase,
        question: '多单位演示采购单分批到货进度',
        subject: '多单位演示采购单',
        now: DateTime(2026, 10, 19),
      ),
    );

    expect(result.facts, hasLength(1));
    expect(result.facts.single.explanation, contains('刹车片'));
    expect(result.facts.single.explanation, contains('2/4 片'));
    expect(result.facts.single.explanation, contains('润滑油'));
    expect(result.facts.single.explanation, contains('1/3 桶'));
    expect(result.facts.single.explanation, isNot(contains('3/7')));
    expect(result.sourcePage, '/purchase/detail/$request');
    expect(result.facts.single.sourcePage, '/purchase/detail/$request');
    expect(_matchesProductionRoute(result.facts.single.sourcePage!), isTrue);
  });

  test('garden unit-price comparison keeps month, specification, and unit separate', () async {
    final unitId = await database.into(database.gardenToolRepairUnits).insert(
      GardenToolRepairUnitsCompanion.insert(name: '测试维修单位'),
    );
    final september = await _insertGardenGroup(database, unitId, '2026-09');
    final august = await _insertGardenGroup(database, unitId, '2026-08');
    await _insertGardenItem(database, september, spec: '40厘米', unit: '片', cents: 12000);
    await _insertGardenItem(database, september, spec: '60厘米', unit: '片', cents: 28000);
    await _insertGardenItem(database, september, spec: '40厘米', unit: '套', cents: 45000);
    await _insertGardenItem(database, august, spec: '40厘米', unit: '片', cents: 5000);

    final result = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.gardenRepair,
        question: '2026年9月40厘米刀片按片的维修单价',
        yearMonth: '2026-09',
        subject: '刀片',
        operation: 'comparePrice',
        now: DateTime(2026, 10, 19),
      ),
    );

    expect(result.facts, hasLength(1));
    expect(result.facts.single.value, contains('50.00'));
    expect(result.facts.single.value, contains('120.00'));
    expect(result.facts.single.explanation, contains('2026-09'));
    expect(result.facts.single.explanation, contains('2026-08'));
    expect(result.facts.single.explanation, isNot(contains('60厘米')));
    expect(result.facts.single.explanation, isNot(contains('套')));
    expect(result.sourcePage, '/garden-tool-repairs/analysis?year=2026&month=09');
    expect(Uri.parse(result.facts.single.sourcePage!).queryParameters, {'year': '2026', 'month': '09'});
    expect(_matchesProductionRoute(result.sourcePage), isTrue);
  });

  test('vehicle reminders follow the selected vehicle and exclude closed or disabled rows', () async {
    final firstVehicle = await database.into(database.vehicles).insert(
      VehiclesCompanion.insert(name: '北区巡检车', vehicleNo: 'TEST-REM-01'),
    );
    final secondVehicle = await database.into(database.vehicles).insert(
      VehiclesCompanion.insert(name: '南区巡检车', vehicleNo: 'TEST-REM-02'),
    );
    final targetReminder = await _insertReminder(
      database,
      '定期保养',
      entityId: firstVehicle,
      vehicleName: '北区巡检车',
    );
    await _insertReminder(
      database,
      '定期保养',
      entityId: secondVehicle,
      vehicleName: '南区巡检车',
    );
    await _insertReminder(
      database,
      '已完成保养',
      entityId: firstVehicle,
      vehicleName: '北区巡检车',
      completed: true,
    );
    await _insertReminder(
      database,
      '停用保养',
      entityId: firstVehicle,
      vehicleName: '北区巡检车',
      enabled: false,
    );

    final result = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.vehicleReminders,
        question: '北区巡检车有哪些未处理提醒？',
        subject: '北区巡检车',
        now: DateTime(2026, 10, 19),
      ),
    );

    expect(result.facts, hasLength(1));
    expect(result.facts.single.explanation, contains('北区巡检车'));
    expect(result.facts.single.sourcePage, '/settings/reminders/$targetReminder/edit');
    expect(_matchesProductionRoute(result.facts.single.sourcePage!), isTrue);
    expect(result.facts.single.label, isNot(contains('南区')));

    final pageContextResult = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.vehicleReminders,
        question: '这辆车有哪些未处理提醒？',
        vehicleId: firstVehicle,
        subject: null,
        now: DateTime(2026, 10, 19),
      ),
    );
    expect(pageContextResult.facts, hasLength(1));
    expect(pageContextResult.facts.single.sourcePage, result.facts.single.sourcePage);
    expect(pageContextResult.facts.single.explanation, contains('北区巡检车'));
  });

  test('vehicle maintenance query stays on the selected vehicle and reports order status', () async {
    final targetVehicle = await database.into(database.vehicles).insert(
      VehiclesCompanion.insert(name: '北区维修车', vehicleNo: 'TEST-REPAIR-01'),
    );
    final otherVehicle = await database.into(database.vehicles).insert(
      VehiclesCompanion.insert(name: '南区维修车', vehicleNo: 'TEST-REPAIR-02'),
    );
    final targetRepair = await database.into(database.repairOrders).insert(
      RepairOrdersCompanion.insert(
        repairNo: 'TEST-ORDER-01',
        vehicleId: targetVehicle,
        reportDate: DateTime(2026, 10, 2),
        faultFoundAt: DateTime(2026, 10, 2),
        symptom: '刹车异响',
        ticketStatus: RepairTicketStatus.notRequired,
        actualAmountCents: const Value(12500),
        status: const Value(VehicleRepairStatus.repairing),
      ),
    );
    await database.into(database.repairOrders).insert(
      RepairOrdersCompanion.insert(
        repairNo: 'TEST-ORDER-02',
        vehicleId: otherVehicle,
        reportDate: DateTime(2026, 10, 3),
        faultFoundAt: DateTime(2026, 10, 3),
        symptom: '刹车异响',
        ticketStatus: RepairTicketStatus.notRequired,
        actualAmountCents: const Value(99000),
        status: const Value(VehicleRepairStatus.completed),
        completedAt: Value(DateTime(2026, 10, 4)),
      ),
    );
    final before = await _snapshotBusinessTables(database);

    final result = await reader.read(
      AssistantBusinessQuery(
        domain: AssistantBusinessType.vehicleMaintenance,
        question: '北区维修车刹车异响维修到哪一步了？',
        subject: '北区维修车',
        now: DateTime(2026, 10, 19),
      ),
    );

    expect(result.facts, hasLength(1));
    expect(result.facts.single.label, '北区维修车 · TEST-ORDER-01');
    expect(result.facts.single.value, contains('维修中'));
    expect(result.facts.single.explanation, contains('125.00'));
    expect(result.facts.single.sourcePage, '/vehicles/repairs/$targetRepair');
    expect(result.sourcePage, '/vehicles/repairs/$targetRepair');
    expect(_matchesProductionRoute(result.facts.single.sourcePage!), isTrue);
    expect(await _snapshotBusinessTables(database), before);
  });
}

bool _matchesProductionRoute(String location) {
  final uri = Uri.parse(location);
  return appRouteCases.any((route) {
    final routePath = route.location.split('?').first;
    final routePattern = routePath
        .split('/')
        .map((segment) => segment.startsWith(':') ? r'[^/]+' : RegExp.escape(segment))
        .join('/');
    final pattern = RegExp('^$routePattern\$');
    return pattern.hasMatch(uri.path);
  });
}

Future<int> _insertPayrollItem(
  AppDatabase database,
  int batchId,
  int employeeId,
  String month,
  double wage, {
  int? jobTypeId,
  double dailyWage = 0,
  double baseWage = 0,
  double subsidy = 0,
}) async {
  return database.into(database.payrollItems).insert(
    PayrollItemsCompanion.insert(
      payrollBatchId: batchId,
      employeeId: employeeId,
      displayOrder: month.endsWith('08') ? 0 : 1,
      employeeNameSnapshot: '周启明',
      employeeNoSnapshot: 'TEST-EMP-901',
      attendanceHalfDaysSnapshot: 40,
      jobTypeId: Value(jobTypeId),
      jobTypeNameSnapshot: const Value('测试工种'),
      dailyWage: Value(dailyWage),
      baseWage: Value(baseWage),
      subsidy: Value(subsidy),
      finalWage: Value(wage),
    ),
  );
}

Future<int> _insertDistributionBatch(AppDatabase database, String month) async {
  final now = DateTime(2026, 10, 19).toIso8601String();
  return database.customInsert(
    'INSERT INTO item_distribution_batches '
    '(benefit_month, category, title, status, created_at, updated_at, is_deleted) '
    "VALUES (?, 'welfare', ?, 'active', ?, ?, 0)",
    variables: [
      Variable.withString(month),
      Variable.withString('$month 模拟福利批次'),
      Variable.withString(now),
      Variable.withString(now),
    ],
  );
}

Future<void> _insertDistributionEntry(
  AppDatabase database,
  int batchId, {
  required String name,
  String itemCode = 'welfare-item',
  String status = 'received',
  bool deleted = false,
}) async {
  final now = DateTime(2026, 10, 19).toIso8601String();
  await database.customStatement(
    'INSERT INTO item_distribution_entries '
    '(batch_id, recipient_type, recipient_key, recipient_name, item_code, item_name, '
    'quantity, unit, status, created_at, updated_at, is_deleted) '
    'VALUES (?, \'employee\', ?, ?, ?, \'模拟福利物资\', 1, \'份\', ?, ?, ?, ?)',
    [batchId, name, name, itemCode, status, now, now, deleted ? 1 : 0],
  );
}

Future<int> _insertPurchase(AppDatabase database, String title) => database
    .into(database.purchaseRequests)
    .insert(PurchaseRequestsCompanion.insert(title: title));

Future<void> _insertPurchaseItem(
  AppDatabase database,
  int requestId,
  int? materialId,
  String name,
  String unit,
  double requested,
  double received,
) async {
  await database.into(database.purchaseRequestItems).insert(
    PurchaseRequestItemsCompanion.insert(
      requestId: requestId,
      inventoryMaterialId: Value(materialId),
      itemName: name,
      unit: unit,
      requestQuantity: requested,
      receivedQuantity: Value(received),
      remainingQuantity: requested - received,
    ),
  );
}

Future<int> _insertGardenGroup(AppDatabase database, int unitId, String month) =>
    database.into(database.gardenToolRepairGroups).insert(
      GardenToolRepairGroupsCompanion.insert(
        repairMonth: month,
        repairDate: DateTime.parse('$month-15'),
        unitId: unitId,
        unitNameSnapshot: '测试维修单位',
        repairerNameSnapshot: '测试维修员',
      ),
    );

Future<void> _insertGardenItem(
  AppDatabase database,
  int groupId, {
  required String spec,
  required String unit,
  required int cents,
}) async {
  await database.into(database.gardenToolRepairItems).insert(
    GardenToolRepairItemsCompanion.insert(
      groupId: groupId,
      projectName: '刀片',
      specModel: Value(spec),
      countUnit: unit,
      quantity: 1,
      unitPriceCents: cents,
      amountCents: cents,
    ),
  );
}

Future<int> _insertReminder(
  AppDatabase database,
  String title, {
  required int entityId,
  required String vehicleName,
  bool enabled = true,
  bool completed = false,
}) async {
  final reminderId = await database.into(database.reminders).insert(
    RemindersCompanion.insert(
      title: title,
      reminderType: 'maintenance',
      category: const Value('vehicle'),
      dueDate: Value(DateTime(2026, 10, 20)),
      isEnabled: Value(enabled),
      isCompleted: Value(completed),
      sourceEntityType: const Value('vehicle'),
      sourceEntityId: Value(entityId),
    ),
  );
  await database.into(database.reminderLinks).insert(
    ReminderLinksCompanion.insert(
      reminderId: reminderId,
      entityType: 'vehicle',
      entityId: entityId,
      displayNameSnapshot: vehicleName,
    ),
  );
  return reminderId;
}

Future<Map<String, Object?>> _snapshotBusinessTables(
  AppDatabase database,
) async {
  final result = <String, Object?>{};
  final tables = await database.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  ).get();
  for (final table in tables) {
    final name = table.read<String>('name');
    final escaped = name.replaceAll('"', '""');
    final rows = await database.customSelect('SELECT * FROM "$escaped" ORDER BY rowid').get();
    final canonicalRows = rows.map((row) {
      final keys = row.data.keys.toList()..sort();
      return {for (final key in keys) key: row.data[key]};
    }).toList();
    result[name] = jsonEncode(canonicalRows);
  }
  return result;
}
