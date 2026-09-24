import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/vehicles/application/fuel_year_summary_service.dart';
import 'package:qingsongban/features/vehicles/data/fuel_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/fuel_options.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';

void main() {
  late AppDatabase database;
  late FuelRepository fuel;

  setUp(() {
    database = AppDatabase.forTesting();
    fuel = FuelRepository(database);
  });

  tearDown(() => database.close());

  test(
    'builds a twelve-month pivot and excludes never-used scrapped vehicles',
    () async {
      final vehicles = VehicleRepository(database);
      final active = await vehicles.save(
        draft: const VehicleDraft(
          name: '在用清扫车',
          vehicleNo: 'SW-001',
          vehicleType: VehicleType.sweeper,
        ),
      );
      final stopped = await vehicles.save(
        draft: const VehicleDraft(
          name: '历史水车',
          vehicleNo: 'WT-002',
          vehicleType: VehicleType.waterTruck,
          status: VehicleStatus.stopped,
        ),
      );
      await vehicles.save(
        draft: const VehicleDraft(
          name: '报废清扫车',
          vehicleNo: 'SW-003',
          vehicleType: VehicleType.sweeper,
          status: VehicleStatus.scrapped,
        ),
      );
      await fuel.save(
        FuelMonthlyDraft(
          vehicleId: active.id,
          year: 2025,
          month: 1,
          liters: 500,
          amountCents: 350000,
        ),
      );
      await fuel.save(
        FuelMonthlyDraft(
          vehicleId: active.id,
          year: 2025,
          month: 2,
          liters: 600,
          amountCents: 420000,
        ),
      );
      await fuel.save(
        FuelMonthlyDraft(
          vehicleId: stopped.id,
          year: 2025,
          month: 1,
          liters: 100,
          amountCents: 70000,
        ),
      );

      final summary = await FuelYearSummaryService(database).build(2025);
      expect(summary.months, hasLength(12));
      expect(summary.vehicles.map((item) => item.vehicle.id), [
        active.id,
        stopped.id,
      ]);
      expect(summary.months.first.totalLiters, 600);
      expect(summary.months.first.validVehicleCount, 2);
      expect(summary.months.first.averageLiters, 300);
      expect(summary.vehicles.first.totalLiters, 1100);
      expect(summary.vehicles.first.validMonthCount, 2);
      expect(summary.vehicles.first.averageLiters, 550);
      expect(summary.expectedRecordCount, 24);
      expect(summary.actualRecordCount, 3);
      expect(summary.completenessPercent, closeTo(12.5, 0.001));
      expect(summary.missingRecords, hasLength(21));
      expect(summary.missingRecords.first.vehicleId, active.id);
    },
  );

  test(
    'soft-deleted month is restored instead of duplicated on re-entry',
    () async {
      final vehicle = await VehicleRepository(database).save(
        draft: const VehicleDraft(
          name: '恢复测试车',
          vehicleNo: 'SW-RESTORE',
          vehicleType: VehicleType.sweeper,
        ),
      );
      final first = await fuel.save(
        FuelMonthlyDraft(
          vehicleId: vehicle.id,
          year: 2025,
          month: 3,
          liters: 100,
          amountCents: 10000,
        ),
      );
      await fuel.softDelete(vehicle.id, first.id);
      final restored = await fuel.save(
        FuelMonthlyDraft(
          vehicleId: vehicle.id,
          year: 2025,
          month: 3,
          liters: 180,
          amountCents: 20000,
        ),
      );
      expect(restored.id, first.id);
      expect(restored.isDeleted, isFalse);
      expect((await fuel.listByVehicle(vehicle.id, 2025)), hasLength(1));
      expect((await fuel.listByVehicle(vehicle.id, 2025)).single.liters, 180);
    },
  );
}
