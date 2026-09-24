import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';

void main() {
  late AppDatabase database;
  late VehicleRepository repository;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = VehicleRepository(database);
  });

  tearDown(() => database.close());

  test('saves and filters a vehicle archive', () async {
    final vehicle = await repository.save(
      draft: const VehicleDraft(
        name: '1号清扫车',
        vehicleNo: 'SW-001',
        licensePlate: '粤A00001',
        vehicleType: VehicleType.sweeper,
        workArea: '重科',
      ),
    );

    expect(vehicle.status, VehicleStatus.normal);
    expect(
      await repository.watchVehicles(type: VehicleType.waterTruck).first,
      isEmpty,
    );
    expect(
      (await repository.watchVehicles(search: '粤A00001').first).single.id,
      vehicle.id,
    );
  });

  test(
    'updates and soft deletes a vehicle without losing its archive',
    () async {
      final vehicle = await repository.save(
        draft: const VehicleDraft(
          name: '2号洒水车',
          vehicleNo: 'WT-002',
          vehicleType: VehicleType.waterTruck,
        ),
      );

      final updated = await repository.save(
        id: vehicle.id,
        draft: const VehicleDraft(
          name: '2号洒水车',
          vehicleNo: 'WT-002',
          vehicleType: VehicleType.waterTruck,
          status: VehicleStatus.stopped,
        ),
      );
      expect(updated.status, VehicleStatus.stopped);

      await repository.softDelete(vehicle.id);
      expect(await repository.watchVehicles().first, isEmpty);
      expect(
        (await repository.watchVehicles(includeDeleted: true).first)
            .single
            .isDeleted,
        isTrue,
      );
      expect((await repository.restore(vehicle.id)), 1);
      expect((await repository.watchVehicles().first).single.id, vehicle.id);
    },
  );

  test('enforces unique vehicle number', () async {
    await repository.save(
      draft: const VehicleDraft(
        name: '1号车',
        vehicleNo: 'V-001',
        vehicleType: VehicleType.sweeper,
      ),
    );
    await expectLater(
      repository.save(
        draft: const VehicleDraft(
          name: '2号车',
          vehicleNo: 'V-001',
          vehicleType: VehicleType.waterTruck,
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });
}
