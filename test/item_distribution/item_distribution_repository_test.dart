import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
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
}
