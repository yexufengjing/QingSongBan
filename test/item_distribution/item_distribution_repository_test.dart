import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/inventory/data/inventory_repository.dart';
import 'package:qingsongban/features/inventory/domain/inventory_models.dart';
import 'package:qingsongban/features/item_distribution/data/item_distribution_repository.dart';
import 'package:qingsongban/features/item_distribution/domain/item_distribution_models.dart';

void main() {
  late AppDatabase database;
  late ItemDistributionRepository repository;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = ItemDistributionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'saves manual office records and updates their receipt status',
    () async {
      const draft = ManualDistributionDraft(
        category: DistributionCategory.office,
        month: '2026-08',
        recipientName: '张三',
        recipientType: 'custom',
        recipientKey: 'custom:张三',
        itemName: '签字笔',
        quantity: 2,
        unit: '盒',
      );

      await repository.addManualDistribution(draft);

      expect(await repository.duplicateCount(draft), 1);
      final groups = await repository.listGroupsForMonth(
        '2026-08',
        category: DistributionCategory.office,
      );
      expect(groups, hasLength(1));
      expect(groups.single.entries.single.quantity, 2);
      expect(groups.single.entries.single.createdAt, isNotNull);
      expect(
        groups.single.entries.single.status,
        DistributionStatus.notReceived,
      );

      await repository.setSourceStatus(
        '2026-08',
        'custom:张三',
        DistributionStatus.received,
        category: DistributionCategory.office,
      );

      final updated = await repository.listGroupsForMonth(
        '2026-08',
        category: DistributionCategory.office,
      );
      expect(updated.single.entries.single.status, DistributionStatus.received);
      expect(
        (await database.select(database.operationLogs).get()).map(
          (log) => log.operationType,
        ),
        containsAll(['distribution_manual_add', 'distribution_received']),
      );

      await repository.deleteManualEntry(groups.single.entries.single.id);
      expect(
        await repository.listGroupsForMonth(
          '2026-08',
          category: DistributionCategory.office,
        ),
        isEmpty,
      );
      expect(
        (await database.select(database.operationLogs).get()).map(
          (log) => log.operationType,
        ),
        contains('distribution_manual_delete'),
      );
    },
  );

  test('welfare batch receives and reverses every matching item exactly once', () async {
    final inventory = InventoryRepository(database);
    final gloves = await inventory.createMaterial(
      const InventoryMaterialDraft(
        materialCode: 'GLOVES',
        materialName: '防护手套',
        unitName: '双',
      ),
    );
    final mask = await inventory.createMaterial(
      const InventoryMaterialDraft(
        materialCode: 'MASK',
        materialName: '口罩',
        unitName: '盒',
      ),
    );
    await inventory.adjustStock(gloves, 10);
    await inventory.adjustStock(mask, 10);

    for (final item in [
      ('防护手套', 2.0, '双'),
      ('口罩', 3.0, '盒'),
    ]) {
      await repository.addManualDistribution(
        ManualDistributionDraft(
          category: DistributionCategory.welfare,
          month: '2026-09',
          recipientName: '张三',
          recipientType: 'custom',
          recipientKey: 'custom:张三',
          itemName: item.$1,
          quantity: item.$2,
          unit: item.$3,
        ),
      );
    }

    await repository.setSourceStatus(
      '2026-09',
      'custom:张三',
      DistributionStatus.received,
    );
    expect((await inventory.getMaterial(gloves))!.currentStock, 8);
    expect((await inventory.getMaterial(mask))!.currentStock, 7);
    expect(await inventory.getIssues(), hasLength(2));

    await repository.setSourceStatus(
      '2026-09',
      'custom:张三',
      DistributionStatus.received,
    );
    expect((await inventory.getMaterial(gloves))!.currentStock, 8);
    expect((await inventory.getMaterial(mask))!.currentStock, 7);
    expect(await inventory.getIssues(), hasLength(2));

    await repository.setSourceStatus(
      '2026-09',
      'custom:张三',
      DistributionStatus.notReceived,
    );
    expect((await inventory.getMaterial(gloves))!.currentStock, 10);
    expect((await inventory.getMaterial(mask))!.currentStock, 10);
    expect(await inventory.getIssues(), isEmpty);

    await repository.setSourceStatus(
      '2026-09',
      'custom:张三',
      DistributionStatus.notReceived,
    );
    expect((await inventory.getMaterial(gloves))!.currentStock, 10);
    expect((await inventory.getMaterial(mask))!.currentStock, 10);
  });

  test('welfare batch stock failure rolls back every status and stock change', () async {
    final inventory = InventoryRepository(database);
    final sufficient = await inventory.createMaterial(
      const InventoryMaterialDraft(
        materialCode: 'ENOUGH',
        materialName: '防护手套',
        unitName: '双',
      ),
    );
    final insufficient = await inventory.createMaterial(
      const InventoryMaterialDraft(
        materialCode: 'SHORT',
        materialName: '口罩',
        unitName: '盒',
      ),
    );
    await inventory.adjustStock(sufficient, 10);
    await inventory.adjustStock(insufficient, 2);
    for (final item in [
      ('防护手套', 2.0, '双'),
      ('口罩', 3.0, '盒'),
    ]) {
      await repository.addManualDistribution(
        ManualDistributionDraft(
          category: DistributionCategory.welfare,
          month: '2026-09',
          recipientName: '李四',
          recipientType: 'custom',
          recipientKey: 'custom:李四',
          itemName: item.$1,
          quantity: item.$2,
          unit: item.$3,
        ),
      );
    }

    await expectLater(
      repository.setSourceStatus(
        '2026-09',
        'custom:李四',
        DistributionStatus.received,
      ),
      throwsA(isA<StateError>()),
    );
    final groups = await repository.listGroupsForMonth('2026-09');
    expect(
      groups.expand((group) => group.entries).map((entry) => entry.status),
      everyElement(DistributionStatus.notReceived),
    );
    expect((await inventory.getMaterial(sufficient))!.currentStock, 10);
    expect((await inventory.getMaterial(insufficient))!.currentStock, 2);
    expect(await inventory.getIssues(), isEmpty);
  });
}
