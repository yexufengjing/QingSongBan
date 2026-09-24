import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/vehicles/application/fuel_anomaly_service.dart';
import 'package:qingsongban/features/vehicles/data/fuel_repository.dart';
import 'package:qingsongban/features/vehicles/data/repair_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_expense_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/expense_options.dart';
import 'package:qingsongban/features/vehicles/domain/fuel_options.dart';
import 'package:qingsongban/features/vehicles/domain/repair_options.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';

void main() {
  late AppDatabase database;
  late int vehicleId;

  setUp(() async {
    database = AppDatabase.forTesting();
    vehicleId = (await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '4号水车',
        vehicleNo: 'WT-004',
        vehicleType: VehicleType.waterTruck,
      ),
    )).id;
  });

  tearDown(() => database.close());

  test('saves one monthly fuel record and calculates annual summary', () async {
    final repository = FuelRepository(database);
    await repository.save(
      FuelMonthlyDraft(
        vehicleId: vehicleId,
        year: 2026,
        month: 8,
        liters: 180.5,
        amountCents: 126350,
      ),
    );
    await repository.save(
      FuelMonthlyDraft(
        vehicleId: vehicleId,
        year: 2026,
        month: 9,
        liters: 220,
        amountCents: 154000,
      ),
    );

    final summary = await repository.annualSummary(vehicleId, 2026);
    expect(summary.recordedMonths, 2);
    expect(summary.totalLiters, 400.5);
    expect(summary.totalAmountCents, 280350);
    expect(summary.highestLitersMonth, 9);
    expect(summary.lowestLitersMonth, 8);
    expect(summary.latestMonthChangePercent, closeTo(21.8836, 0.001));

    expect(
      () => repository.save(
        FuelMonthlyDraft(
          vehicleId: vehicleId,
          year: 2026,
          month: 9,
          liters: 1,
          amountCents: 100,
        ),
      ),
      throwsStateError,
    );
  });

  test(
    'expense aggregation uses completed repair actual amount once',
    () async {
      final repair = await RepairRepository(database).save(
        draft: RepairOrderDraft(
          vehicleId: vehicleId,
          reportDate: DateTime(2026, 9, 10),
          faultFoundAt: DateTime(2026, 9, 10),
          symptom: '水泵更换',
          ticketStatus: RepairTicketStatus.notRequired,
          status: VehicleRepairStatus.completed,
          completedAt: DateTime(2026, 9, 12),
          costs: const [
            RepairCostDraft(
              content: '水泵',
              quantity: 1,
              unit: '个',
              unitPriceCents: 88000,
              costType: RepairCostType.part,
            ),
          ],
        ),
      );
      expect(repair.actualAmountCents, 88000);
      await FuelRepository(database).save(
        FuelMonthlyDraft(
          vehicleId: vehicleId,
          year: 2026,
          month: 9,
          liters: 100,
          amountCents: 70000,
        ),
      );
      await VehicleExpenseRepository(database).saveManual(
        ManualVehicleExpenseDraft(
          vehicleId: vehicleId,
          expenseDate: DateTime(2026, 9, 13),
          expenseType: VehicleManualExpenseType.inspection,
          amountCents: 20000,
          remark: '年度检验',
        ),
      );

      final items = await VehicleExpenseRepository(database)
          .list(vehicleId, year: 2026);
      expect(
        items.map((item) => item.sourceType),
        containsAll(<String>['repair', 'fuel', 'manual']),
      );
      expect(
        items.where((item) => item.sourceType == 'repair').single.amountCents,
        88000,
      );
      expect(items.fold<int>(0, (sum, item) => sum + item.amountCents), 178000);
    },
  );

  test(
    'fuel anomaly checks recent average without changing source records',
    () async {
      final repository = FuelRepository(database);
      for (final entry in [
        (month: 6, liters: 100.0),
        (month: 7, liters: 110.0),
        (month: 8, liters: 125.0),
        (month: 9, liters: 170.0),
      ]) {
        await repository.save(
          FuelMonthlyDraft(
            vehicleId: vehicleId,
            year: 2026,
            month: entry.month,
            liters: entry.liters,
            amountCents: 10000,
          ),
        );
      }
      final anomaly = await FuelAnomalyService(repository)
          .analyze(vehicleId: vehicleId, year: 2026, month: 9);
      expect(anomaly?.highComparedWithRecentAverage, isTrue);
      expect(anomaly?.consecutiveIncrease, isTrue);
      expect((await repository.findByMonth(vehicleId, 2026, 9))?.liters, 170);
    },
  );

  test('child updates cannot cross vehicle ownership boundaries', () async {
    final otherVehicle = (await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '5号水车',
        vehicleNo: 'WT-005',
        vehicleType: VehicleType.waterTruck,
      ),
    )).id;
    final fuel = FuelRepository(database);
    final fuelRow = await fuel.save(
      FuelMonthlyDraft(
        vehicleId: vehicleId,
        year: 2026,
        month: 9,
        liters: 100,
        amountCents: 10000,
      ),
    );
    expect(
      fuel.save(
        FuelMonthlyDraft(
          vehicleId: otherVehicle,
          year: 2026,
          month: 9,
          liters: 200,
          amountCents: 20000,
        ),
        id: fuelRow.id,
      ),
      throwsStateError,
    );
    expect((await fuel.findByMonth(vehicleId, 2026, 9))?.liters, 100);

    final expenseRepository = VehicleExpenseRepository(database);
    final expense = await expenseRepository.saveManual(
      ManualVehicleExpenseDraft(
        vehicleId: vehicleId,
        expenseDate: DateTime(2026, 9, 20),
        expenseType: VehicleManualExpenseType.inspection,
        amountCents: 5000,
      ),
    );
    expect(
      expenseRepository.saveManual(
        ManualVehicleExpenseDraft(
          vehicleId: otherVehicle,
          expenseDate: DateTime(2026, 9, 20),
          expenseType: VehicleManualExpenseType.cleaning,
          amountCents: 1,
        ),
        id: expense.id,
      ),
      throwsStateError,
    );
    expect(
      (await expenseRepository.list(vehicleId))
          .where((item) => item.sourceType == 'manual')
          .single
          .amountCents,
      5000,
    );

    final repairRepository = RepairRepository(database);
    final repair = await repairRepository.save(
      draft: RepairOrderDraft(
        vehicleId: vehicleId,
        reportDate: DateTime(2026, 9, 20),
        faultFoundAt: DateTime(2026, 9, 20),
        symptom: '原车辆维修',
        ticketStatus: RepairTicketStatus.notRequired,
      ),
    );
    expect(
      repairRepository.save(
        id: repair.id,
        draft: RepairOrderDraft(
          vehicleId: otherVehicle,
          reportDate: DateTime(2026, 9, 20),
          faultFoundAt: DateTime(2026, 9, 20),
          symptom: '越权修改',
          ticketStatus: RepairTicketStatus.notRequired,
        ),
      ),
      throwsStateError,
    );
    expect((await repairRepository.findById(repair.id))?.symptom, '原车辆维修');
  });
}
