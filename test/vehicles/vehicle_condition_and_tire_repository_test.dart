import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/vehicles/data/tire_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_condition_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/condition_options.dart';
import 'package:qingsongban/features/vehicles/domain/tire_options.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';

void main() {
  late AppDatabase database;
  late VehicleRepository vehicleRepository;
  late TireRepository tireRepository;
  late VehicleConditionRepository conditionRepository;
  late int vehicleId;

  setUp(() async {
    database = AppDatabase.forTesting();
    vehicleRepository = VehicleRepository(database);
    tireRepository = TireRepository(database);
    conditionRepository = VehicleConditionRepository(database);
    vehicleId = (await vehicleRepository.save(
      draft: const VehicleDraft(
        name: '1号清扫车',
        vehicleNo: 'SW-001',
        vehicleType: VehicleType.sweeper,
      ),
    )).id;
  });

  tearDown(() => database.close());

  test('keeps condition history while replacing the current item', () async {
    await conditionRepository.save(
      VehicleConditionDraft(
        vehicleId: vehicleId,
        componentType: 'engine',
        componentKey: 'engineMain',
        status: VehicleConditionStatus.needsAttention,
        observedAt: DateTime(2026, 9, 1),
        issueTags: const ['烧机油', '异响'],
      ),
    );
    final current = await conditionRepository.save(
      VehicleConditionDraft(
        vehicleId: vehicleId,
        componentType: 'engine',
        componentKey: 'engineMain',
        status: VehicleConditionStatus.normal,
        observedAt: DateTime(2026, 9, 10),
      ),
    );

    expect(
      (await conditionRepository.watchCurrentItems(vehicleId).first).single.id,
      current.id,
    );
    expect((await conditionRepository.listHistory(vehicleId)), hasLength(2));
    expect(conditionRepository.decodeIssueTags(current), isEmpty);
  });

  test(
    'relocates tires in one transaction and preserves cumulative usage',
    () async {
      final front = await tireRepository.saveAsset(
        draft: const TireDraft(tireNo: 'T-0001'),
      );
      final damaged = await tireRepository.saveAsset(
        draft: const TireDraft(tireNo: 'T-0002'),
      );
      final replacement = await tireRepository.saveAsset(
        draft: const TireDraft(tireNo: 'T-0003'),
      );
      await tireRepository.installTire(
        tireId: front.id,
        vehicleId: vehicleId,
        position: TirePosition.leftFront,
        installDate: DateTime(2026, 1, 1),
      );
      await tireRepository.installTire(
        tireId: damaged.id,
        vehicleId: vehicleId,
        position: TirePosition.leftRearOuter,
        installDate: DateTime(2026, 1, 10),
      );

      await tireRepository.relocateTire(
        vehicleId: vehicleId,
        damagedPosition: TirePosition.leftRearOuter,
        sourcePosition: TirePosition.leftFront,
        replacementTireId: replacement.id,
        date: DateTime(2026, 2, 1),
      );

      final current = await tireRepository.listCurrentInstallations(vehicleId);
      expect(
        current
            .singleWhere((item) => item.position == TirePosition.leftFront)
            .tireId,
        replacement.id,
      );
      expect(
        current
            .singleWhere((item) => item.position == TirePosition.leftRearOuter)
            .tireId,
        front.id,
      );
      final frontHistory = await tireRepository.listHistory(front.id);
      expect(frontHistory, hasLength(2));
      expect(
        TireRepository.cumulativeUsageDays(
          frontHistory,
          onDate: DateTime(2026, 2, 10),
        ),
        40,
      );
      expect(
        (await tireRepository.findById(damaged.id))?.status,
        TireAssetStatus.removed,
      );
    },
  );

  test('records a repair and increments the tire repair count', () async {
    final tire = await tireRepository.saveAsset(
      draft: const TireDraft(tireNo: 'T-0004'),
    );
    await tireRepository.recordRepair(
      tireId: tire.id,
      repairDate: DateTime(2026, 9, 12),
      repairType: TireRepairType.coldPatch,
      severity: TireRepairSeverity.ordinary,
      amountCents: 3500,
    );
    final updated = await tireRepository.findById(tire.id);
    expect(updated?.repairCount, 1);
    expect(
      (await database.select(database.tireRepairs).get()).single.amountCents,
      3500,
    );
  });
}
