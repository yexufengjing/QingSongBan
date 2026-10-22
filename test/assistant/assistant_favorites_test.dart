import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/assistant/application/assistant_favorites.dart';
import 'package:qingsongban/features/assistant/domain/assistant_quick_query.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'favorites reload with their query conditions and remove persists',
    () async {
      final firstContainer = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(firstContainer.dispose);
      final firstNotifier = firstContainer.read(
        assistantQueryFavoritesProvider.notifier,
      );
      final query = AssistantQuickQuery(
        kind: AssistantQuickQueryKind.attendance,
        yearMonth: '2026-09',
        employeeId: 42,
      );

      final saved = await firstNotifier.add('九月考勤', query);
      expect(
        await firstContainer.read(assistantQueryFavoritesProvider.future),
        [saved],
      );

      final reloadedContainer = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(reloadedContainer.dispose);
      final reloaded = await reloadedContainer.read(
        assistantQueryFavoritesProvider.future,
      );
      expect(reloaded, hasLength(1));
      expect(reloaded.single.id, saved.id);
      expect(reloaded.single.name, '九月考勤');
      expect(reloaded.single.query.kind, AssistantQuickQueryKind.attendance);
      expect(reloaded.single.query.yearMonth, '2026-09');
      expect(reloaded.single.query.employeeId, 42);

      await reloadedContainer
          .read(assistantQueryFavoritesProvider.notifier)
          .remove(saved.id);
      expect(
        await reloadedContainer.read(assistantQueryFavoritesProvider.future),
        isEmpty,
      );

      final afterRemovalContainer = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(afterRemovalContainer.dispose);
      expect(
        await afterRemovalContainer.read(
          assistantQueryFavoritesProvider.future,
        ),
        isEmpty,
      );
    },
  );

  test(
    'duplicate query conditions are rejected, month remains part of identity',
    () async {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(assistantQueryFavoritesProvider.notifier);

      await notifier.add(
        '九月考勤',
        AssistantQuickQuery(
          kind: AssistantQuickQueryKind.attendance,
          yearMonth: '2026-09',
        ),
      );
      await expectLater(
        notifier.add(
          '同一条件',
          AssistantQuickQuery(
            kind: AssistantQuickQueryKind.attendance,
            yearMonth: '2026-09',
          ),
        ),
        throwsStateError,
      );

      await notifier.add(
        '十月考勤',
        AssistantQuickQuery(
          kind: AssistantQuickQueryKind.attendance,
          yearMonth: '2026-10',
        ),
      );
      expect(
        await container.read(assistantQueryFavoritesProvider.future),
        hasLength(2),
      );
    },
  );
}
