import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/garden_tool_repairs/application/garden_tool_repair_analysis_service.dart';
import 'package:qingsongban/features/garden_tool_repairs/data/garden_tool_repair_repository.dart';
import 'package:qingsongban/features/garden_tool_repairs/domain/repair_models.dart';

void main() {
  late AppDatabase database;
  late GardenToolRepairRepository repository;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = GardenToolRepairRepository(database);
  });

  tearDown(() async => database.close());

  test(
    'aggregates monthly totals, unit shares and separate project rankings',
    () async {
      final steel = await repository.saveUnit(
        name: '特钢',
        sortOrder: 0,
        isActive: true,
      );
      final pipe = await repository.saveUnit(
        name: '管业',
        sortOrder: 1,
        isActive: true,
      );
      await repository.saveGroup(
        _draft(DateTime(2026, 9, 3), steel.id, '张三', const [
          GardenToolRepairItemDraft(
            projectName: '刀片',
            countUnit: '片',
            quantity: 1,
            unitPriceCents: 800,
          ),
          GardenToolRepairItemDraft(
            projectName: '润滑油',
            countUnit: '桶',
            quantity: 1,
            unitPriceCents: 9000,
          ),
        ]),
      );
      await repository.saveGroup(
        _draft(DateTime(2026, 8, 3), pipe.id, '李四', const [
          GardenToolRepairItemDraft(
            projectName: '刀片',
            countUnit: '片',
            quantity: 1,
            unitPriceCents: 700,
          ),
          GardenToolRepairItemDraft(
            projectName: '螺栓',
            countUnit: '个',
            quantity: 1,
            unitPriceCents: 500,
          ),
        ]),
      );

      final service = const GardenToolRepairAnalysisService();
      final annual = service.summarize([
        ...await repository.loadMonth(DateTime(2026, 8)),
        ...await repository.loadMonth(DateTime(2026, 9)),
      ], year: 2026);
      expect(annual.totalCents, 11000);
      expect(annual.itemCount, 4);
      expect(annual.averageMonthCents, 917);
      expect(annual.repairerCount, 2);
      expect(annual.monthlyTotalsCents[7], 1200);
      expect(annual.monthlyTotalsCents[8], 9800);
      expect(annual.unitAmounts.first.unitName, '特钢');
      expect(annual.unitAmounts.first.share, closeTo(9800 / 11000, 0.0001));
      expect(annual.projectAmounts.first.projectName, '润滑油');
      expect(annual.projectCounts.first.projectName, '刀片');
      expect(annual.projectCounts.first.count, 2);

      final month = service.summarize(
        await repository.loadMonth(DateTime(2026, 9)),
        year: 2026,
        month: 9,
      );
      expect(month.totalCents, 9800);
      expect(month.averageMonthCents, 9800);
    },
  );
}

GardenToolRepairGroupDraft _draft(
  DateTime date,
  int unitId,
  String person,
  List<GardenToolRepairItemDraft> items,
) => GardenToolRepairGroupDraft(
  repairMonth: repairMonthKey(date),
  repairDate: date,
  unitId: unitId,
  repairerName: person,
  items: items,
);
