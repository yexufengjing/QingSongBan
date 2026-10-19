import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/garden_tool_repairs/data/garden_tool_repair_repository.dart';
import '../../features/garden_tool_repairs/domain/repair_models.dart';
import '../../features/inventory/data/inventory_repository.dart';
import '../../features/inventory/domain/inventory_models.dart';
import '../../features/payroll/domain/payroll_calculator.dart';
import '../../features/purchase/data/purchase_repository_impl.dart';
import '../../features/purchase/domain/purchase_models.dart';
import '../utils/date_utils.dart';
import 'app_database.dart';
import 'database_enums.dart';

/// Opt-in, additive demo fixtures for exercising read-only assistant tools.
/// Each month is seeded once. Existing rows are never updated or removed.
abstract final class AssistantBusinessDemoDataSeeder {
  static const markerPrefix = 'assistant_business_demo_seed_v1_';
  static const employeeNo = 'DEMO-ASSISTANT-EMP-001';
  static const materialCode = 'DEMO-ASSISTANT-MAT-001';
  static const vehicleNo = 'DEMO-ASSISTANT-VEH-001';
  static const repairNo = 'DEMO-ASSISTANT-REPAIR-001';
  static const purchaseId = 'DEMO-ASSISTANT-PUR-001';
  static const benefitBatchPrefix = '【演示】DEMO-ASSISTANT-WELFARE-';
  static const gardenProject = '演示北区绿篱养护';

  static Future<bool> seed(AppDatabase database, {DateTime? now}) async {
    final today = AppDateUtils.dateOnly(now ?? DateTime.now());
    final currentMonth = AppDateUtils.yearMonth(today);
    final previousMonth = AppDateUtils.yearMonth(
      DateTime(today.year, today.month).subtract(const Duration(days: 1)),
    );
    final marker = '$markerPrefix$currentMonth';
    final seeded = await (database.select(database.appSettings)
          ..where((row) => row.settingKey.equals(marker)))
        .getSingleOrNull();
    if (seeded != null) {
      await repairOwnedDemoSnapshots(database);
      return false;
    }

    final existingEmployee = await (database.select(database.employees)
          ..where((row) => row.employeeNo.equals(employeeNo)))
        .getSingleOrNull();
    if (existingEmployee != null &&
        !(existingEmployee.remark ?? '').contains('DEMO-ASSISTANT-EMP-001')) {
      return false;
    }

    return database.transaction(() async {
      final createdAt = today;
      final employeeId = existingEmployee?.id ?? await database
          .into(database.employees)
          .insert(EmployeesCompanion.insert(
            employeeNo: employeeNo,
            name: '演示员工林晓禾',
            hireDate: DateTime(today.year - 2, 3, 1),
            position: const Value('绿化养护员'),
            team: const Value('北区园林演示组'),
            workArea: const Value('北区'),
            employmentType: const Value('临时工'),
            remark: const Value('【演示】DEMO-ASSISTANT-EMP-001；助手只读问答演示记录。'),
            createdAt: Value(createdAt),
            updatedAt: Value(createdAt),
          ));
      final group = await (database.select(database.attendanceGroups)
            ..where((row) => row.name.equals('【演示】助手演示考勤组')))
          .getSingleOrNull();
      final groupId = group?.id ?? await database
          .into(database.attendanceGroups)
          .insert(AttendanceGroupsCompanion.insert(
            name: '【演示】助手演示考勤组',
            remark: const Value('DEMO-ASSISTANT-EMP-001'),
            createdAt: Value(createdAt),
            updatedAt: Value(createdAt),
          ));
      final job = await (database.select(database.wageJobTypes)
            ..where((row) => row.name.equals('【演示】园林养护员')))
          .getSingleOrNull();
      final jobId = job?.id ?? await database
          .into(database.wageJobTypes)
          .insert(WageJobTypesCompanion.insert(
            name: '【演示】园林养护员',
            defaultDailyWage: const Value(100),
            remark: const Value('DEMO-ASSISTANT-EMP-001'),
            createdAt: Value(createdAt),
            updatedAt: Value(createdAt),
          ));

      for (final month in [previousMonth, currentMonth]) {
        final summary = await (database.select(database.monthlyAttendanceSummaries)
              ..where((row) => row.yearMonth.equals(month) &
                  row.employeeId.equals(employeeId) &
                  row.attendanceGroupId.equals(groupId)))
            .getSingleOrNull();
        if (summary == null) {
          final isCurrent = month == currentMonth;
          await database.into(database.monthlyAttendanceSummaries).insert(
            MonthlyAttendanceSummariesCompanion.insert(
              yearMonth: month,
              employeeId: employeeId,
              attendanceGroupId: Value(groupId),
              participates: const Value(true),
              attendanceDays: Value(isCurrent ? 20 : 19),
              monthStartStatus: const Value('正常'),
              monthEndStatus: const Value('正常'),
              isComplete: const Value(true),
              status: const Value(MonthlySummaryStatus.confirmed),
              generatedAt: Value(createdAt),
              updatedAt: Value(createdAt),
            ),
          );
        }
        final roster = await (database.select(database.monthlyAttendanceRosters)
              ..where((row) => row.yearMonth.equals(month) &
                  row.employeeId.equals(employeeId) &
                  row.attendanceGroupId.equals(groupId)))
            .getSingleOrNull();
        if (roster == null) {
          await database.into(database.monthlyAttendanceRosters).insert(
            MonthlyAttendanceRostersCompanion.insert(
              yearMonth: month,
              attendanceGroupId: groupId,
              employeeId: employeeId,
              remark: Value('【演示】DEMO-ASSISTANT-EMP-001 $month'),
              createdAt: Value(createdAt),
              updatedAt: Value(createdAt),
            ),
          );
        }
        final year = int.parse(month.substring(0, 4));
        final monthNumber = int.parse(month.substring(5, 7));
        final isCurrent = month == currentMonth;
        final expectedWorkDays = isCurrent ? 20 : 19;
        var seededWorkDays = 0;
        final monthLength = DateTime(year, monthNumber + 1, 0).day;
        for (var day = 1; day <= monthLength && seededWorkDays < expectedWorkDays; day++) {
          final date = DateTime(year, monthNumber, day);
          if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
            continue;
          }
          final record = await (database.select(database.attendanceRecords)
                ..where((row) => row.employeeId.equals(employeeId) &
                    row.attendanceDate.equals(date) & row.isDeleted.equals(false)))
              .getSingleOrNull();
          if (record == null) {
            await database.into(database.attendanceRecords).insert(
              AttendanceRecordsCompanion.insert(
                employeeId: employeeId,
                attendanceDate: date,
                morningStatus: const Value(AttendanceHalfStatus.present),
                afternoonStatus: const Value(AttendanceHalfStatus.present),
                remark: Value('【演示】DEMO-ASSISTANT-EMP-001 $month'),
                createdAt: Value(createdAt),
                updatedAt: Value(createdAt),
              ),
            );
          }
          seededWorkDays++;
        }
        await _seedPayroll(database, employeeId, jobId, month, createdAt,
            current: month == currentMonth);
      }

      final material = await (database.select(database.inventoryMaterials)
            ..where((row) => row.materialCode.equals(materialCode)))
          .getSingleOrNull();
      final materialId = material?.id ?? await InventoryRepository(database)
          .createMaterial(const InventoryMaterialDraft(
            materialCode: materialCode,
            materialName: '演示绿篱刀片',
            modelSpec: '40厘米',
            unitName: '片',
            minStock: 8,
            referencePriceCent: 1200,
            remark: '【演示】DEMO-ASSISTANT-MAT-001',
          ));
      if (material == null) {
        await (database.update(database.inventoryMaterials)
              ..where((row) => row.id.equals(materialId)))
            .write(InventoryMaterialsCompanion(
              currentStock: const Value(2),
              updatedAt: Value(createdAt),
            ));
      }
      await _seedPartialPurchase(database, materialId, currentMonth, createdAt);
      await _seedWelfare(database, employeeId, currentMonth, createdAt);

      final vehicle = await (database.select(database.vehicles)
            ..where((row) => row.vehicleNo.equals(vehicleNo)))
          .getSingleOrNull();
      final vehicleId = vehicle?.id ?? await database.into(database.vehicles).insert(
        VehiclesCompanion.insert(
          name: '【演示】北区巡检车',
          vehicleNo: vehicleNo,
          vehicleType: const Value(VehicleType.sweeper),
          department: const Value('北区保障组'),
          workArea: const Value('北区'),
          responsiblePerson: const Value('演示驾驶员'),
          remark: const Value('DEMO-ASSISTANT-VEH-001'),
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
        ),
      );
      await _seedVehicleRecords(database, vehicleId, today, previousMonth, currentMonth);
      await _seedGarden(database, previousMonth, currentMonth, today);

      await database.into(database.appSettings).insert(
        AppSettingsCompanion.insert(
          settingKey: marker,
          settingValue: Value('完成 $currentMonth；DEMO-ASSISTANT；只新增不覆盖。'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return true;
    });
  }

  /// Repairs only this seeder's early demo batches that stored the former
  /// joined snapshot encoding. Production payroll rows are never selected.
  static Future<int> repairOwnedDemoSnapshots(AppDatabase database) async {
    final employee = await (database.select(database.employees)
          ..where((row) => row.employeeNo.equals(employeeNo) & row.isDeleted.equals(false)))
        .getSingleOrNull();
    if (employee == null) return 0;
    final batches = (await database.select(database.payrollBatches).get())
        .where((row) => row.name.startsWith('【演示】$employeeNo '))
        .toList();
    var repaired = 0;
    for (final batch in batches) {
      final month = batch.payrollMonth;
      if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) continue;
      final items = await (database.select(database.payrollItems)
            ..where((row) => row.payrollBatchId.equals(batch.id) &
                row.employeeId.equals(employee.id) &
                row.employeeNoSnapshot.equals(employeeNo) &
                row.isManuallyRemoved.equals(false)))
          .get();
      if (items.isEmpty) continue;
      final previousEncoding = await _legacySnapshotVersion(database, month);
      if (previousEncoding == null ||
          batch.attendanceSnapshotVersion != previousEncoding) {
        continue;
      }
      final currentEncoding = await _snapshotVersion(database, month);
      if (currentEncoding == null) continue;
      final count = await (database.update(database.payrollBatches)
            ..where((row) => row.id.equals(batch.id) &
                row.attendanceSnapshotVersion.equals(previousEncoding)))
          .write(PayrollBatchesCompanion(
        attendanceSnapshotVersion: Value(currentEncoding),
      ));
      repaired += count;
    }
    return repaired;
  }

  static Future<void> _seedPayroll(AppDatabase db, int employeeId, int jobId,
      String month, DateTime now, {required bool current}) async {
    final existing = await (db.select(db.payrollBatches)
          ..where((row) => row.payrollMonth.equals(month)))
        .getSingleOrNull();
    if (existing != null) return;
    final halfDays = current ? 40 : 38;
    final subsidy = current ? 2500.0 : 200.0;
    final wage = PayrollCalculator.calculate(
      attendanceHalfDays: halfDays,
      dailyWage: 100,
      subsidy: subsidy,
      insuranceDeduction: 0,
    );
    final batchId = await db.into(db.payrollBatches).insert(
      PayrollBatchesCompanion.insert(
        payrollMonth: month,
        name: '【演示】DEMO-ASSISTANT-EMP-001 $month 工资',
        status: Value(current ? PayrollStatus.draft : PayrollStatus.confirmed),
        employeeCount: const Value(1),
        attendanceHalfDaysTotal: Value(halfDays),
        baseWageTotal: Value(wage.baseWage),
        subsidyTotal: Value(subsidy),
        finalWageTotal: Value(wage.finalWage),
        attendanceSnapshotVersion: Value(await _snapshotVersion(db, month)),
        remark: const Value('【演示】DEMO-ASSISTANT-EMP-001'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    final employee = await db.findEmployeeById(employeeId);
    if (employee == null) throw StateError('演示人员不存在');
    await db.into(db.payrollItems).insert(PayrollItemsCompanion.insert(
      payrollBatchId: batchId,
      employeeId: employeeId,
      displayOrder: 0,
      employeeNameSnapshot: employee.name,
      employeeNoSnapshot: employee.employeeNo,
      jobTypeId: Value(jobId),
      jobTypeNameSnapshot: const Value('【演示】园林养护员'),
      attendanceHalfDaysSnapshot: halfDays,
      dailyWage: const Value(100),
      dailyWageSource: const Value('job_history'),
      baseWage: Value(wage.baseWage),
      subsidy: Value(subsidy),
      insuranceDeduction: const Value(0),
      finalWage: Value(wage.finalWage),
      remark: Value('【演示】DEMO-ASSISTANT-EMP-001 $month'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  static Future<String?> _snapshotVersion(AppDatabase db, String month) async {
    final rows = await (db.select(db.monthlyAttendanceSummaries)
          ..where((row) => row.yearMonth.equals(month) & row.isDeleted.equals(false)))
        .get();
    if (rows.isEmpty) return null;
    final snapshots = [
      for (final row in rows)
        jsonEncode([row.employeeId, row.attendanceGroupId, row.participates,
          row.attendanceDays, row.leaveDays, row.absentDays, row.restDays,
          row.stoppedDays, row.overtimeCount, row.overtimeMinutes,
          row.monthStartStatus, row.monthEndStatus, row.joinedDuringMonth,
          row.terminatedDuringMonth, row.isComplete, row.anomalyCount]),
    ]..sort();
    return jsonEncode(snapshots);
  }

  static Future<String?> _legacySnapshotVersion(AppDatabase db, String month) async {
    final rows = await (db.select(db.monthlyAttendanceSummaries)
          ..where((row) => row.yearMonth.equals(month) & row.isDeleted.equals(false)))
        .get();
    if (rows.isEmpty) return null;
    final snapshots = [
      for (final row in rows)
        jsonEncode([
          row.employeeId,
          row.attendanceGroupId,
          row.participates,
          row.attendanceDays,
          row.leaveDays,
          row.absentDays,
          row.restDays,
          row.stoppedDays,
          row.overtimeCount,
          row.overtimeMinutes,
          row.monthStartStatus,
          row.monthEndStatus,
          row.joinedDuringMonth,
          row.terminatedDuringMonth,
          row.isComplete,
          row.anomalyCount,
        ]),
    ]..sort();
    return snapshots.join('||');
  }

  static Future<void> _seedPartialPurchase(AppDatabase db, int materialId,
      String month, DateTime now) async {
    final title = '【演示】DEMO-ASSISTANT-PUR-001 演示绿篱刀片分批采购';
    final existing = await (db.select(db.purchaseRequests)
          ..where((row) => row.title.equals(title)))
        .getSingleOrNull();
    if (existing != null) return;
    final repo = PurchaseRepositoryImpl(db);
    final requestId = await repo.createPurchaseRequest(CreatePurchaseRequestInput(
      title: title,
      requestDate: now,
      demandReason: '库存低于补货下限',
      remark: '【演示】DEMO-ASSISTANT-PUR-001；关联库存物资ID。',
      items: [PurchaseItemDraft(
        inventoryMaterialId: materialId,
        itemName: '演示绿篱刀片',
        specification: '40厘米',
        unit: '片',
        currentStockSnapshot: 2,
        requestQuantity: 10,
        remark: '【演示】DEMO-ASSISTANT-PUR-001',
      )],
    ));
    await repo.confirmApplied(requestId, ConfirmAppliedInput(
      appliedDate: now,
      oaRequestNo: 'DEMO-ASSISTANT-PUR-001',
      oaTitle: '演示绿篱刀片补货',
    ));
    await repo.assignPurchaser(requestId, AssignPurchaserInput(
      purchaseDepartment: '演示保障组',
      purchaserName: '演示采购员',
      assignedDate: now,
    ));
    await repo.markPendingReceive(requestId, PendingReceiveInput(
      arrivalNoticeDate: now,
      receiveLocation: '北区演示库房',
    ));
    final detail = await repo.watchDetail(requestId).first;
    final item = detail!.items.single;
    await repo.stockIn(StockInInput(
      requestId: requestId,
      stockInDate: now,
      remark: '【演示】部分入库4片，余量待到货。',
      lines: [PurchaseStockInLineInput(
        requestItemId: item.id,
        quantity: 4,
        storageLocation: '北区演示库房',
      )],
    ));
  }

  static Future<void> _seedWelfare(AppDatabase db, int employeeId,
      String month, DateTime now) async {
    final title = '$benefitBatchPrefix$month';
    final existing = await db.customSelect(
      'SELECT id FROM item_distribution_batches WHERE title=? AND is_deleted=0 LIMIT 1',
      variables: [Variable.withString(title)],
    ).getSingleOrNull();
    if (existing != null) return;
    final batchId = await db.customInsert(
      'INSERT INTO item_distribution_batches (benefit_month, category, title, status, created_at, updated_at, is_deleted) VALUES (?, ?, ?, ?, ?, ?, 0)',
      variables: [Variable.withString(month), Variable.withString('welfare'),
        Variable.withString(title), Variable.withString('active'),
        Variable.withString(now.toIso8601String()), Variable.withString(now.toIso8601String())],
    );
    for (final entry in [
      (code: 'DEMO-ASSISTANT-WELFARE-RECEIVED', status: 'received'),
      (code: 'DEMO-ASSISTANT-WELFARE-PENDING', status: 'not_received'),
    ]) {
      await db.customStatement(
        'INSERT INTO item_distribution_entries (batch_id, recipient_type, recipient_key, employee_id, recipient_name, employment_type, item_code, item_name, quantity, unit, status, actual_distribution_month, note, created_at, updated_at, is_deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)',
        [batchId, 'employee', employeeId.toString(), employeeId,
          '演示员工林晓禾', '临时工', entry.code, '【演示】季度劳保福利包', 1.0, '份',
          entry.status, entry.status == 'received' ? month : null,
          '【演示】${entry.code}', now.toIso8601String(), now.toIso8601String()],
      );
    }
  }

  static Future<void> _seedVehicleRecords(AppDatabase db, int vehicleId,
      DateTime today, String previousMonth, String currentMonth) async {
    final order = await (db.select(db.repairOrders)
          ..where((row) => row.repairNo.equals(repairNo)))
        .getSingleOrNull();
    if (order == null) {
      await db.into(db.repairOrders).insert(RepairOrdersCompanion.insert(
        repairNo: repairNo,
        vehicleId: vehicleId,
        reportDate: today,
        faultFoundAt: today,
        symptom: '刹车异响',
        cause: const Value('【演示】刹车片磨损待复查'),
        project: const Value('北区巡检车制动系统检查'),
        reportedAmountCents: const Value(15000),
        actualAmountCents: const Value(12500),
        ticketStatus: RepairTicketStatus.notRequired,
        status: const Value(VehicleRepairStatus.repairing),
        remark: const Value('【演示】DEMO-ASSISTANT-REPAIR-001'),
        createdAt: Value(today),
        updatedAt: Value(today),
      ));
    }
    const completedRepairNo = 'DEMO-ASSISTANT-REPAIR-002';
    final completedOrder = await (db.select(db.repairOrders)
          ..where((row) => row.repairNo.equals(completedRepairNo)))
        .getSingleOrNull();
    if (completedOrder == null) {
      await db.into(db.repairOrders).insert(RepairOrdersCompanion.insert(
        repairNo: completedRepairNo,
        vehicleId: vehicleId,
        reportDate: DateTime(today.year, today.month, 5),
        faultFoundAt: DateTime(today.year, today.month, 5),
        symptom: '空调滤芯更换',
        cause: const Value('【演示】定期保养'),
        project: const Value('北区巡检车空调维护'),
        reportedAmountCents: const Value(9800),
        actualAmountCents: const Value(8250),
        ticketStatus: RepairTicketStatus.notRequired,
        status: const Value(VehicleRepairStatus.completed),
        completedAt: Value(DateTime(today.year, today.month, 6)),
        remark: const Value('【演示】DEMO-ASSISTANT-REPAIR-002'),
        createdAt: Value(today),
        updatedAt: Value(today),
      ));
    }
    for (final month in [previousMonth, currentMonth]) {
      final parts = month.split('-');
      final year = int.parse(parts.first);
      final monthNumber = int.parse(parts.last);
      final fuel = await (db.select(db.fuelMonthlyRecords)
            ..where((row) => row.vehicleId.equals(vehicleId) &
                row.year.equals(year) & row.month.equals(monthNumber)))
          .getSingleOrNull();
      if (fuel == null) {
        await db.into(db.fuelMonthlyRecords).insert(FuelMonthlyRecordsCompanion.insert(
          vehicleId: vehicleId,
          year: year,
          month: monthNumber,
          liters: 120,
          amountCents: month == currentMonth ? 93600 : 88200,
          workDays: const Value(20),
          workMileage: const Value(860),
          remark: Value('【演示】DEMO-ASSISTANT-VEH-001 $month'),
          createdAt: Value(today),
          updatedAt: Value(today),
        ));
      }
    }
    final reminderTitle = '【演示】北区巡检车保养提醒';
    final reminder = await (db.select(db.reminders)
          ..where((row) => row.title.equals(reminderTitle) & row.isDeleted.equals(false)))
        .getSingleOrNull();
    if (reminder == null) {
      final reminderId = await db.into(db.reminders).insert(RemindersCompanion.insert(
        title: reminderTitle,
        reminderType: 'vehicle_maintenance',
        category: const Value('vehicle'),
        dueDate: Value(today.add(const Duration(days: 3))),
        sourceEntityType: const Value('vehicle'),
        sourceEntityId: Value(vehicleId),
        remark: const Value('DEMO-ASSISTANT-VEH-001'),
        createdAt: Value(today),
        updatedAt: Value(today),
      ));
      await db.into(db.reminderLinks).insert(ReminderLinksCompanion.insert(
        reminderId: reminderId,
        entityType: 'vehicle',
        entityId: vehicleId,
        displayNameSnapshot: '【演示】北区巡检车',
        createdAt: Value(today),
      ));
    }
  }

  static Future<void> _seedGarden(AppDatabase db, String previousMonth,
      String currentMonth, DateTime today) async {
    final repo = GardenToolRepairRepository(db);
    final existingUnit = await (db.select(db.gardenToolRepairUnits)
          ..where((row) => row.name.equals('【演示】北区园林维修单位')))
        .getSingleOrNull();
    final unit = existingUnit ?? await repo.saveUnit(
      name: '【演示】北区园林维修单位',
      sortOrder: 900,
      isActive: true,
    );
    for (final month in [previousMonth, currentMonth]) {
      final existing = await (db.select(db.gardenToolRepairGroups)
            ..where((row) => row.repairMonth.equals(month) &
                row.remark.equals('DEMO-ASSISTANT-GARDEN-$month') &
                row.deletedAt.isNull()))
          .getSingleOrNull();
      if (existing != null) continue;
      final date = DateTime(int.parse(month.substring(0, 4)),
          int.parse(month.substring(5, 7)), 15);
      await repo.saveGroup(GardenToolRepairGroupDraft(
        repairMonth: month,
        repairDate: date,
        unitId: unit.id,
        repairerName: '演示维修员',
        remark: 'DEMO-ASSISTANT-GARDEN-$month',
        items: [GardenToolRepairItemDraft(
          projectName: gardenProject,
          specModel: '40厘米',
          countUnit: '片',
          quantity: 2,
          unitPriceCents: month == currentMonth ? 1200 : 1000,
          remark: '【演示】同一项目跨月价格对照。',
        )],
      ));
    }
  }
}
