import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/assistant/data/assistant_vehicle_expense_reader.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';

void main() {
  late AppDatabase database;
  late AssistantVehicleExpenseReader reader;
  var nextRepairNo = 0;

  setUp(() {
    database = AppDatabase.forTesting();
    reader = AssistantVehicleExpenseReader(
      database,
      clock: () => DateTime(2026, 10, 18, 12),
    );
    nextRepairNo = 0;
  });

  tearDown(() async => database.close());

  Future<int> createVehicle(
    String name, {
    VehicleType type = VehicleType.sweeper,
    String? brand = '甲牌',
    String? model = 'X1',
    bool isDeleted = false,
  }) => database
      .into(database.vehicles)
      .insert(
        VehiclesCompanion.insert(
          name: name,
          vehicleNo: 'TEST-${name.hashCode}',
          vehicleType: Value(type),
          brand: Value(brand),
          model: Value(model),
          isDeleted: Value(isDeleted),
        ),
      );

  Future<void> addRepair(
    int vehicleId, {
    required DateTime reportDate,
    required int amountCents,
    VehicleRepairStatus status = VehicleRepairStatus.completed,
    bool isDeleted = false,
  }) async {
    nextRepairNo++;
    await database
        .into(database.repairOrders)
        .insert(
          RepairOrdersCompanion.insert(
            repairNo: 'TEST-REPAIR-$nextRepairNo',
            vehicleId: vehicleId,
            reportDate: reportDate,
            faultFoundAt: reportDate,
            symptom: '仅用于隔离测试',
            ticketStatus: RepairTicketStatus.notRequired,
            actualAmountCents: Value(amountCents),
            status: Value(status),
            isDeleted: Value(isDeleted),
          ),
        );
  }

  Future<void> addMaintenance(
    int vehicleId, {
    required DateTime serviceDate,
    required int amountCents,
    bool isDeleted = false,
  }) async {
    final itemId = await database
        .into(database.vehicleMaintenanceItems)
        .insert(
          VehicleMaintenanceItemsCompanion.insert(
            vehicleId: vehicleId,
            name: '隔离测试保养项',
            intervalValue: 1,
            intervalUnit: MaintenanceIntervalUnit.months,
          ),
        );
    await database
        .into(database.maintenanceRecords)
        .insert(
          MaintenanceRecordsCompanion.insert(
            maintenanceItemId: itemId,
            vehicleId: vehicleId,
            serviceDate: serviceDate,
            totalCostCents: Value(amountCents),
            isDeleted: Value(isDeleted),
          ),
        );
  }

  Future<void> addManual(
    int vehicleId, {
    required DateTime expenseDate,
    required int amountCents,
    bool isDeleted = false,
  }) async {
    await database
        .into(database.manualVehicleExpenses)
        .insert(
          ManualVehicleExpensesCompanion.insert(
            vehicleId: vehicleId,
            expenseDate: expenseDate,
            expenseType: '隔离测试费用',
            amountCents: amountCents,
            isDeleted: Value(isDeleted),
          ),
        );
  }

  Future<void> addFuel(
    int vehicleId, {
    required int year,
    required int month,
    required int amountCents,
    required double liters,
    double? mileage,
    int? workDays,
    double? workHours,
    bool isDeleted = false,
  }) async {
    await database
        .into(database.fuelMonthlyRecords)
        .insert(
          FuelMonthlyRecordsCompanion.insert(
            vehicleId: vehicleId,
            year: year,
            month: month,
            amountCents: amountCents,
            liters: liters,
            workMileage: Value(mileage),
            workDays: Value(workDays),
            workHours: Value(workHours),
            isDeleted: Value(isDeleted),
          ),
        );
  }

  VehicleExpenseCategoryResult category(
    VehicleExpensePeriodResult result,
    VehicleExpenseCategoryScope scope,
  ) => result.categories.singleWhere((item) => item.category == scope);

  test('recent 30 day totals use report/service/expense dates and keep monthly fuel separate', () async {
    final vehicleId = await createVehicle('滚动期间车辆');
    await addRepair(
      vehicleId,
      reportDate: DateTime(2026, 9, 19),
      amountCents: 10000,
    );
    await addRepair(
      vehicleId,
      reportDate: DateTime(2026, 9, 20),
      amountCents: 120000,
    );
    await addRepair(
      vehicleId,
      reportDate: DateTime(2026, 10, 10),
      amountCents: 80000,
    );
    await addRepair(
      vehicleId,
      reportDate: DateTime(2026, 10, 19),
      amountCents: 900000,
    );
    await addRepair(
      vehicleId,
      reportDate: DateTime(2026, 8, 25),
      amountCents: 50000,
    );
    await addRepair(
      vehicleId,
      reportDate: DateTime(2026, 10, 11),
      amountCents: 70000,
      status: VehicleRepairStatus.repairing,
    );
    await addRepair(
      vehicleId,
      reportDate: DateTime(2026, 10, 12),
      amountCents: 80000,
      isDeleted: true,
    );
    await addMaintenance(
      vehicleId,
      serviceDate: DateTime(2026, 10, 5),
      amountCents: 30000,
    );
    await addMaintenance(
      vehicleId,
      serviceDate: DateTime(2026, 9, 18),
      amountCents: 50000,
    );
    await addMaintenance(
      vehicleId,
      serviceDate: DateTime(2026, 10, 8),
      amountCents: 50000,
      isDeleted: true,
    );
    await addManual(
      vehicleId,
      expenseDate: DateTime(2026, 10, 12),
      amountCents: 20000,
    );
    await addManual(
      vehicleId,
      expenseDate: DateTime(2026, 9, 18),
      amountCents: 30000,
    );
    await addFuel(
      vehicleId,
      year: 2026,
      month: 8,
      amountCents: 60000,
      liters: 80,
    );
    await addFuel(
      vehicleId,
      year: 2026,
      month: 9,
      amountCents: 90000,
      liters: 120,
    );
    await addFuel(
      vehicleId,
      year: 2026,
      month: 10,
      amountCents: 20000,
      liters: 25,
    );

    final result = await reader.readVehicleExpenses(
      VehicleExpenseToolRequest(
        vehicleId: vehicleId,
        period: AssistantAgentPeriod.recent30Days,
      ),
    );

    expect(result.startInclusive, DateTime(2026, 9, 19));
    expect(result.endExclusive, DateTime(2026, 10, 19));
    expect(
      category(result, VehicleExpenseCategoryScope.repair).amountCents,
      210000,
    );
    expect(category(result, VehicleExpenseCategoryScope.repair).recordCount, 3);
    expect(
      category(result, VehicleExpenseCategoryScope.maintenance).amountCents,
      30000,
    );
    expect(
      category(result, VehicleExpenseCategoryScope.manual).amountCents,
      20000,
    );
    expect(
      result.categories.any(
        (item) => item.category == VehicleExpenseCategoryScope.fuel,
      ),
      isFalse,
    );
    expect(
      category(result, VehicleExpenseCategoryScope.all).amountCents,
      260000,
    );
    expect(category(result, VehicleExpenseCategoryScope.all).recordCount, 5);
    expect(
      result.fuelMonths.map(
        (item) => (item.year, item.month, item.amountCents),
      ),
      [(2026, 9, 90000), (2026, 10, 20000)],
    );
    expect(result.coverage, VehicleExpenseCoverage.partial);
    expect(result.coverageNotes.join(' '), contains('不纳入日级合计'));
    expect(result.coverageNotes.join(' '), contains('不代表零支出'));
  });

  test('all categories aggregate a specified natural month and retain independent workload fields', () async {
    final vehicleId = await createVehicle('自然月车辆');
    await addRepair(
      vehicleId,
      reportDate: DateTime(2026, 9, 20),
      amountCents: 200000,
    );
    await addMaintenance(
      vehicleId,
      serviceDate: DateTime(2026, 9, 5),
      amountCents: 30000,
    );
    await addManual(
      vehicleId,
      expenseDate: DateTime(2026, 9, 12),
      amountCents: 20000,
    );
    await addFuel(
      vehicleId,
      year: 2026,
      month: 9,
      amountCents: 90000,
      liters: 120,
      mileage: 4000,
    );
    await addFuel(
      vehicleId,
      year: 2026,
      month: 8,
      amountCents: 60000,
      liters: 80,
      isDeleted: true,
    );

    final result = await reader.readVehicleExpenses(
      VehicleExpenseToolRequest(
        vehicleId: vehicleId,
        period: AssistantAgentPeriod.previousMonth,
        scope: VehicleExpenseCategoryScope.all,
        yearMonth: '2026-09',
      ),
    );

    expect(result.startInclusive, DateTime(2026, 9));
    expect(result.endExclusive, DateTime(2026, 10));
    expect(
      category(result, VehicleExpenseCategoryScope.repair).amountCents,
      200000,
    );
    expect(
      category(result, VehicleExpenseCategoryScope.maintenance).amountCents,
      30000,
    );
    expect(
      category(result, VehicleExpenseCategoryScope.manual).amountCents,
      20000,
    );
    expect(
      category(result, VehicleExpenseCategoryScope.fuel).amountCents,
      90000,
    );
    expect(
      category(result, VehicleExpenseCategoryScope.all).amountCents,
      340000,
    );
    expect(result.fuelMonths, hasLength(1));
    expect(result.fuelMonths.single.month, 9);
    expect(result.workload?.mileage, 4000);
    expect(result.workload?.workDays, isNull);
    expect(result.workload?.workHours, isNull);
    expect(result.workload?.coverage, VehicleExpenseCoverage.partial);

    final deletedFuelMonth = await reader.readVehicleExpenses(
      VehicleExpenseToolRequest(
        vehicleId: vehicleId,
        period: AssistantAgentPeriod.previousMonth,
        scope: VehicleExpenseCategoryScope.fuel,
        yearMonth: '2026-08',
      ),
    );
    expect(deletedFuelMonth.fuelMonths, isEmpty);
  });

  test(
    'missing a contained month keeps monthly workload coverage partial',
    () async {
      final vehicleId = await createVehicle('缺月工作量车辆');
      await addFuel(
        vehicleId,
        year: 2026,
        month: 8,
        amountCents: 60000,
        liters: 80,
        mileage: 1200,
        workDays: 20,
        workHours: 100,
      );

      final result = await reader.readVehicleExpenses(
        VehicleExpenseToolRequest(
          vehicleId: vehicleId,
          period: AssistantAgentPeriod.recent90Days,
          scope: VehicleExpenseCategoryScope.fuel,
        ),
      );

      expect(result.fuelMonths, hasLength(1));
      expect(result.categories.single.recordCount, 1);
      expect(result.categories.single.coverage, VehicleExpenseCoverage.partial);
      expect(result.workload?.mileage, isNull);
      expect(result.workload?.coverage, VehicleExpenseCoverage.partial);
      expect(result.coverageNotes.join(' '), contains('没有油费登记'));
    },
  );

  test(
    'all scope keeps monthly fuel separate from a mixed rolling 90-day total',
    () async {
      final vehicleId = await createVehicle('九十天车辆');
      await addRepair(
        vehicleId,
        reportDate: DateTime(2026, 8, 5),
        amountCents: 120000,
      );
      await addFuel(
        vehicleId,
        year: 2026,
        month: 8,
        amountCents: 60000,
        liters: 80,
        mileage: 1500,
      );
      await addFuel(
        vehicleId,
        year: 2026,
        month: 9,
        amountCents: 90000,
        liters: 120,
        mileage: 1900,
      );
      await addFuel(
        vehicleId,
        year: 2026,
        month: 10,
        amountCents: 20000,
        liters: 25,
        mileage: 400,
      );

      final result = await reader.readVehicleExpenses(
        VehicleExpenseToolRequest(
          vehicleId: vehicleId,
          period: AssistantAgentPeriod.recent90Days,
          scope: VehicleExpenseCategoryScope.all,
        ),
      );

      expect(result.startInclusive, DateTime(2026, 7, 21));
      expect(result.endExclusive, DateTime(2026, 10, 19));
      expect(
        category(result, VehicleExpenseCategoryScope.all).amountCents,
        120000,
      );
      expect(category(result, VehicleExpenseCategoryScope.all).recordCount, 1);
      expect(
        result.categories.any(
          (item) => item.category == VehicleExpenseCategoryScope.fuel,
        ),
        isFalse,
      );
      expect(result.fuelMonths.map((item) => item.month), [8, 9, 10]);
      expect(result.workload, isNull);
    },
  );

  test('peer average and unit mileage cost use same month and exclude unregistered peers', () async {
    final targetId = await createVehicle('目标车辆');
    final peerId = await createVehicle('已登记同类车');
    final unregisteredPeerId = await createVehicle('无登记同类车');
    await createVehicle('不同型号车辆', model: 'X2');
    await createVehicle('不同类型车辆', type: VehicleType.waterTruck);
    await addFuel(
      targetId,
      year: 2026,
      month: 9,
      amountCents: 200000,
      liters: 200,
      mileage: 4000,
    );
    await addFuel(
      peerId,
      year: 2026,
      month: 9,
      amountCents: 100000,
      liters: 100,
      mileage: 1000,
    );
    // Same-class candidate without a record is excluded from the average.
    expect(unregisteredPeerId, greaterThan(0));

    final result = await reader.comparePeerVehicleExpenses(
      VehicleExpenseToolRequest(
        vehicleId: targetId,
        period: AssistantAgentPeriod.previousMonth,
        yearMonth: '2026-09',
        scope: VehicleExpenseCategoryScope.fuel,
      ),
    );

    expect(result.comparableVehicleCount, 1);
    expect(result.targetAmountCents, 200000);
    expect(result.peerAmountCents, 100000);
    expect(result.targetWorkload?.mileage, 4000);
    expect(result.targetWorkload?.workDays, isNull);
    expect(result.peerWorkload?.mileage, 1000);
    expect(result.peerWorkload?.workDays, isNull);
    expect(result.peerWorkload?.workHours, isNull);
    expect(result.targetCentsPerKilometer, 50);
    expect(result.peerMeanCentsPerKilometer, 100);
    expect(result.comparability, VehicleExpenseCoverage.partial);
    expect(result.note, contains('1 辆有同期费用记录'));
    expect(result.note, contains('其余 1 辆没有可比登记'));
    expect(result.note, contains('不按零费用计入均值'));
  });

  test(
    'peer unit cost stays unavailable when its same-month mileage is missing',
    () async {
      final targetId = await createVehicle('目标无里程');
      final peerId = await createVehicle('同类无里程');
      await addFuel(
        targetId,
        year: 2026,
        month: 9,
        amountCents: 200000,
        liters: 200,
        mileage: 4000,
      );
      await addFuel(
        peerId,
        year: 2026,
        month: 9,
        amountCents: 100000,
        liters: 100,
      );

      final result = await reader.comparePeerVehicleExpenses(
        VehicleExpenseToolRequest(
          vehicleId: targetId,
          period: AssistantAgentPeriod.previousMonth,
          yearMonth: '2026-09',
          scope: VehicleExpenseCategoryScope.fuel,
        ),
      );

      expect(result.peerAmountCents, 100000);
      expect(result.peerWorkload?.mileage, isNull);
      expect(result.targetCentsPerKilometer, 50);
      expect(result.peerMeanCentsPerKilometer, isNull);
      expect(result.note, contains('没有可共同使用的同期工作量指标'));
      expect(result.comparability, VehicleExpenseCoverage.partial);
    },
  );

  test(
    'explicit zero record differs from no record in peer comparison',
    () async {
      final targetId = await createVehicle('有登记目标');
      final zeroPeerId = await createVehicle('零金额同类车');
      final emptyPeerId = await createVehicle('缺记录同类车');
      await addFuel(
        targetId,
        year: 2026,
        month: 9,
        amountCents: 80000,
        liters: 80,
      );
      await addFuel(
        zeroPeerId,
        year: 2026,
        month: 9,
        amountCents: 0,
        liters: 0,
      );
      expect(emptyPeerId, greaterThan(0));

      final result = await reader.comparePeerVehicleExpenses(
        VehicleExpenseToolRequest(
          vehicleId: targetId,
          period: AssistantAgentPeriod.previousMonth,
          yearMonth: '2026-09',
          scope: VehicleExpenseCategoryScope.fuel,
        ),
      );

      expect(result.targetAmountCents, 80000);
      expect(result.peerAmountCents, 0);
      expect(result.comparableVehicleCount, 1);
      expect(result.note, contains('其余 1 辆没有可比登记'));
      expect(result.note, contains('不按零费用计入均值'));
    },
  );

  test(
    'natural-month repair comparison can fall back to shared work hours',
    () async {
      final targetId = await createVehicle('维修目标工时');
      final peerId = await createVehicle('维修同类工时');
      await addRepair(
        targetId,
        reportDate: DateTime(2026, 9, 10),
        amountCents: 200000,
      );
      await addRepair(
        peerId,
        reportDate: DateTime(2026, 9, 10),
        amountCents: 100000,
      );
      await addFuel(
        targetId,
        year: 2026,
        month: 9,
        amountCents: 90000,
        liters: 100,
        workHours: 20,
      );
      await addFuel(
        peerId,
        year: 2026,
        month: 9,
        amountCents: 40000,
        liters: 50,
        workHours: 10,
      );

      final result = await reader.comparePeerVehicleExpenses(
        VehicleExpenseToolRequest(
          vehicleId: targetId,
          period: AssistantAgentPeriod.previousMonth,
          yearMonth: '2026-09',
          scope: VehicleExpenseCategoryScope.repair,
        ),
      );

      expect(result.period.workload?.workHours, 20);
      expect(result.period.fuelMonths, isEmpty);
      expect(result.period.categories.map((item) => item.category), [
        VehicleExpenseCategoryScope.repair,
      ]);
      expect(result.metricUnit, VehicleExpenseWorkloadMetric.workHours);
      expect(result.targetUnitCost, 10000);
      expect(result.peerUnitCost, 10000);
    },
  );

  test('invalid explicit month is rejected', () async {
    final vehicleId = await createVehicle('非法月份车辆');
    expect(
      () => reader.readVehicleExpenses(
        VehicleExpenseToolRequest(
          vehicleId: vehicleId,
          period: AssistantAgentPeriod.previousMonth,
          yearMonth: '2026-13',
        ),
      ),
      throwsA(
        isA<AssistantProviderException>().having(
          (error) => error.code,
          'code',
          AssistantErrorCode.invalidArgument,
        ),
      ),
    );
  });
}
