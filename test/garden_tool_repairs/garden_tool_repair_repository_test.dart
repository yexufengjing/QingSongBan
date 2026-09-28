import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
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
    'stores unit and repairer masters and snapshots names on a group',
    () async {
      final unit = await repository.saveUnit(
        name: '特钢',
        sortOrder: 1,
        isActive: true,
      );
      final person = await repository.addPerson(unitId: unit.id, name: '张三');
      final group = await repository.saveGroup(
        _draft(
          unitId: unit.id,
          repairerName: person.name,
          repairerId: person.id,
          items: const [
            GardenToolRepairItemDraft(
              projectName: '刀片',
              countUnit: '片',
              quantity: 1.5,
              unitPriceCents: 1234,
            ),
          ],
        ),
      );
      await repository.saveUnit(
        id: unit.id,
        name: '特钢分厂',
        sortOrder: 1,
        isActive: true,
      );
      expect(group.unitNameSnapshot, '特钢');
      expect(group.repairerNameSnapshot, '张三');
      expect(group.repairerId, person.id);
      expect(group.subtotalCents, 1851);

      final temporary = await repository.saveGroup(
        _draft(unitId: unit.id, repairerName: '临时维修人'),
      );
      expect(temporary.repairerId, isNull);
      expect(temporary.repairerNameSnapshot, '临时维修人');
    },
  );

  test('keeps same-day repairers in separate ordered groups', () async {
    final unit = await repository.saveUnit(
      name: '特钢',
      sortOrder: 0,
      isActive: true,
    );
    await repository.saveGroup(_draft(unitId: unit.id, repairerName: '张三'));
    await repository.saveGroup(_draft(unitId: unit.id, repairerName: '李四'));

    final groups = await repository.loadMonth(DateTime(2026, 9));
    expect(groups, hasLength(2));
    expect(groups.map((entry) => entry.group.repairerNameSnapshot), [
      '张三',
      '李四',
    ]);
  });

  test(
    'does not assign an inactive unit to new records but allows edits',
    () async {
      final unit = await repository.saveUnit(
        name: '重科',
        sortOrder: 0,
        isActive: true,
      );
      final group = await repository.saveGroup(
        _draft(unitId: unit.id, repairerName: '王五'),
      );
      await repository.saveUnit(
        id: unit.id,
        name: unit.name,
        sortOrder: unit.sortOrder,
        isActive: false,
      );

      await expectLater(
        repository.saveGroup(_draft(unitId: unit.id, repairerName: '李四')),
        throwsStateError,
      );
      final edited = await repository.saveGroup(
        GardenToolRepairGroupDraft(
          id: group.id,
          repairMonth: '2026-09',
          repairDate: DateTime(2026, 9, 3),
          unitId: unit.id,
          repairerName: '王五',
          items: const [
            GardenToolRepairItemDraft(
              projectName: '刀片',
              countUnit: '片',
              quantity: 2,
              unitPriceCents: 800,
            ),
          ],
        ),
      );
      expect(edited.unitNameSnapshot, '重科');
      expect(edited.subtotalCents, 1600);
    },
  );

  test(
    'editing recalculates item amounts and subtotal; deleting is soft',
    () async {
      final unit = await repository.saveUnit(
        name: '管业',
        sortOrder: 0,
        isActive: true,
      );
      final saved = await repository.saveGroup(
        _draft(
          unitId: unit.id,
          repairerName: '李四',
          items: const [
            GardenToolRepairItemDraft(
              projectName: '润滑油',
              countUnit: '桶',
              quantity: 2,
              unitPriceCents: 4500,
            ),
          ],
        ),
      );
      final edit = await repository.saveGroup(
        GardenToolRepairGroupDraft(
          id: saved.id,
          repairMonth: '2026-09',
          repairDate: DateTime(2026, 9, 3),
          unitId: unit.id,
          repairerName: '李四',
          items: const [
            GardenToolRepairItemDraft(
              projectName: '润滑油',
              countUnit: '桶',
              quantity: 3,
              unitPriceCents: 4000,
            ),
          ],
        ),
      );
      expect(edit.subtotalCents, 12000);
      expect(
        (await repository.loadMonth(DateTime(2026, 9)))
            .single
            .items
            .single
            .amountCents,
        12000,
      );

      await repository.softDeleteGroup(saved.id);
      expect(await repository.loadMonth(DateTime(2026, 9)), isEmpty);
      expect(
        (await database.select(database.gardenToolRepairGroups).get())
            .single
            .deletedAt,
        isNotNull,
      );
      expect(
        (await database.select(database.gardenToolRepairItems).get())
            .first
            .deletedAt,
        isNotNull,
      );
    },
  );

  test(
    'price history matches project, specification, unit, date and unit filter',
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
        _draft(
          unitId: steel.id,
          repairerName: '张三',
          items: const [
            GardenToolRepairItemDraft(
              projectName: '化油器',
              specModel: 'GX35',
              countUnit: '个',
              quantity: 1,
              unitPriceCents: 12000,
            ),
          ],
        ),
      );
      await repository.saveGroup(
        _draft(
          unitId: pipe.id,
          repairerName: '李四',
          repairDate: DateTime(2026, 8, 3),
          items: const [
            GardenToolRepairItemDraft(
              projectName: '化油器',
              specModel: 'GX35',
              countUnit: '个',
              quantity: 1,
              unitPriceCents: 13500,
            ),
            GardenToolRepairItemDraft(
              projectName: '化油器',
              specModel: 'GX25',
              countUnit: '个',
              quantity: 1,
              unitPriceCents: 9000,
            ),
          ],
        ),
      );
      final points = await repository.loadPricePoints(
        projectName: '化油器',
        specModel: 'GX35',
        countUnit: '个',
        start: DateTime(2026, 1),
        endExclusive: DateTime(2027, 1),
        unitId: steel.id,
      );
      expect(points, hasLength(1));
      expect(points.single.unitPriceCents, 12000);
      expect(points.single.unitName, '特钢');
    },
  );

  test(
    'rejects a date outside the selected month and invalid details',
    () async {
      final unit = await repository.saveUnit(
        name: '重科',
        sortOrder: 0,
        isActive: true,
      );
      await expectLater(
        repository.saveGroup(
          GardenToolRepairGroupDraft(
            repairMonth: '2026-08',
            repairDate: DateTime(2026, 9, 3),
            unitId: unit.id,
            repairerName: '王五',
            items: const [
              GardenToolRepairItemDraft(
                projectName: '刀片',
                countUnit: '片',
                quantity: 1,
                unitPriceCents: 800,
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.saveGroup(
          _draft(
            unitId: unit.id,
            repairerName: '王五',
            items: const [
              GardenToolRepairItemDraft(
                projectName: '',
                countUnit: '片',
                quantity: 1,
                unitPriceCents: 800,
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'enforces nine active attachments and soft deletes attachment rows',
    () async {
      final unit = await repository.saveUnit(
        name: '特钢',
        sortOrder: 0,
        isActive: true,
      );
      final group = await repository.saveGroup(
        _draft(unitId: unit.id, repairerName: '张三'),
      );
      for (var index = 0; index < 9; index++) {
        await repository.addAttachment(
          groupId: group.id,
          attachmentType: 'receipt',
          filePath: 'garden_tool_repairs/${group.id}/$index.jpg',
        );
      }
      expect(
        (await repository.loadMonth(DateTime(2026, 9))).single.attachmentCount,
        9,
      );
      await expectLater(
        repository.addAttachment(
          groupId: group.id,
          attachmentType: 'other',
          filePath: 'garden_tool_repairs/${group.id}/extra.jpg',
        ),
        throwsStateError,
      );

      await repository.softDeleteGroup(group.id);
      expect(
        (await database.select(database.gardenToolRepairAttachments).get())
            .every((attachment) => attachment.deletedAt != null),
        isTrue,
      );
    },
  );
}

GardenToolRepairGroupDraft _draft({
  required int unitId,
  required String repairerName,
  int? repairerId,
  DateTime? repairDate,
  List<GardenToolRepairItemDraft> items = const [
    GardenToolRepairItemDraft(
      projectName: '刀片',
      countUnit: '片',
      quantity: 1,
      unitPriceCents: 800,
    ),
  ],
}) {
  final date = repairDate ?? DateTime(2026, 9, 3);
  return GardenToolRepairGroupDraft(
    repairMonth: repairMonthKey(date),
    repairDate: date,
    unitId: unitId,
    repairerId: repairerId,
    repairerName: repairerName,
    items: items,
  );
}
