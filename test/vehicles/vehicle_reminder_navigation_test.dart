import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/reminders/data/reminder_repository.dart';
import 'package:qingsongban/features/reminders/domain/reminder_options.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';

void main() {
  testWidgets('vehicle reminder rules open without a navigator error', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    try {
      final vehicle = await VehicleRepository(database).save(
        draft: const VehicleDraft(
          name: '提醒测试车',
          vehicleNo: 'REM-RULE-1',
          vehicleType: VehicleType.sweeper,
        ),
      );
      await ReminderRepository(database).save(
        draft: ReminderDraft(
          title: '机油保养提醒',
          reminderType: 'vehicleMaintenance',
          leadDays: 3,
          isEnabled: true,
          dueDate: DateTime.now().add(const Duration(days: 2)),
          links: [
            ReminderLinkDraft(
              entityType: 'vehicle',
              entityId: vehicle.id,
              displayName: vehicle.name,
            ),
          ],
        ),
      );

      appRouter.go('/vehicles/reminders');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const QingSongBanApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('机油保养提醒'), findsOneWidget);

      await tester.tap(find.text('提醒规则'));
      await tester.pumpAndSettle();

      expect(find.text('备忘提醒'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 1));
      appRouter.dispose();
      await database.close();
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}
