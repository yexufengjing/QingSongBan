import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/utils/date_utils.dart';
import 'package:qingsongban/features/reminders/data/reminder_repository.dart';
import 'package:qingsongban/features/vehicles/data/lifecycle_repository.dart';
import 'package:qingsongban/features/vehicles/data/maintenance_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/maintenance_options.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';

void main() {
  late AppDatabase database;
  late MaintenanceRepository repository;
  late int vehicleId;

  setUp(() async {
    database = AppDatabase.forTesting();
    repository = MaintenanceRepository(database);
    vehicleId = (await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '3号清扫车',
        vehicleNo: 'SW-003',
        vehicleType: VehicleType.sweeper,
      ),
    )).id;
  });

  tearDown(() => database.close());

  test('calculates calendar due dates without overflowing short months', () {
    expect(
      MaintenanceRepository.calculateNextDueDate(
        DateTime(2026, 8, 31),
        1,
        MaintenanceIntervalUnit.months,
      ),
      DateTime(2026, 9, 30),
    );
    expect(
      MaintenanceRepository.calculateNextDueDate(
        DateTime(2024, 2, 29),
        1,
        MaintenanceIntervalUnit.years,
      ),
      DateTime(2025, 2, 28),
    );
  });

  test(
    'seeds maintenance items, updates due status, and syncs reminder',
    () async {
      await repository.seedDefaultItems(vehicleId);
      final items = await (database.select(
        database.vehicleMaintenanceItems,
      )..where((table) => table.vehicleId.equals(vehicleId))).get();

      expect(items, hasLength(4));
      final item = items.first;
      expect(
        MaintenanceRepository.dueStatus(item),
        MaintenanceDueStatus.noRecord,
      );

      final serviced = await repository.saveItem(
        VehicleMaintenanceItemDraft(
          vehicleId: vehicleId,
          name: item.name,
          componentType: item.componentType,
          intervalValue: 6,
          intervalUnit: MaintenanceIntervalUnit.months,
          lastServiceDate: DateTime(2026, 1, 31),
        ),
        id: item.id,
      );
      expect(serviced.nextDueDate, DateTime(2026, 7, 31));
      expect(
        MaintenanceRepository.dueStatus(serviced, now: DateTime(2026, 7, 2)),
        MaintenanceDueStatus.dueSoon,
      );
      expect(
        MaintenanceRepository.dueStatus(serviced, now: DateTime(2026, 8, 1)),
        MaintenanceDueStatus.due,
      );
      expect(
        MaintenanceRepository.dueStatus(serviced, now: DateTime(2026, 9, 1)),
        MaintenanceDueStatus.overdue,
      );

      final reminder = await ReminderRepository(database)
          .findBySource('vehicleMaintenance', item.id);
      expect(reminder?.dueDate, DateTime(2026, 7, 31));
      expect(reminder?.leadDays, 30);
    },
  );

  test(
    'records service costs and preserves component lifecycle usage days',
    () async {
      await repository.seedDefaultItems(vehicleId);
      final item = (await (database.select(
        database.vehicleMaintenanceItems,
      )..where((table) => table.vehicleId.equals(vehicleId))).get()).first;
      final record = await repository.record(
        MaintenanceRecordDraft(
          maintenanceItemId: item.id,
          vehicleId: vehicleId,
          serviceDate: DateTime(2026, 9, 18, 12),
          materialCostCents: 12500,
          laborCostCents: 8000,
        ),
      );
      expect(record.totalCostCents, 20500);
      expect(
        (await repository.findItemById(item.id))?.lastServiceDate,
        DateTime(2026, 9, 18),
      );

      final lifecycle = await LifecycleRepository(database).save(
        LifecycleRecordDraft(
          vehicleId: vehicleId,
          componentType: 'sweeper',
          componentKey: 'mainBrush',
          name: '主刷',
          installedDate: DateTime(2026, 9, 1),
        ),
      );
      expect(
        LifecycleRepository.usageDays(lifecycle, onDate: DateTime(2026, 9, 18)),
        17,
      );
      expect(AppDateUtils.formatDate(lifecycle.installedDate), '2026-09-01');
    },
  );
}
