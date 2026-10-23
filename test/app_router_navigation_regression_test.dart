import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/home/presentation/home_page.dart';
import 'package:qingsongban/features/personnel/presentation/personnel_page.dart';

Future<void> _pumpNavigationFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real app routes survive repeated push and back interactions', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const QingSongBanApp(),
        ),
      );
      await _pumpNavigationFrames(tester);

      for (var cycle = 0; cycle < 3; cycle++) {
        await tester.tap(find.text('我的').last);
        await _pumpNavigationFrames(tester);
        await tester.tap(find.text('备忘提醒').first);
        await _pumpNavigationFrames(tester);
        await tester.tap(find.byKey(const Key('reminder-add-button')));
        await _pumpNavigationFrames(tester);

        expect(find.text('新建提醒'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, '取消').first);
        await _pumpNavigationFrames(tester);
        expect(find.text('备忘提醒'), findsWidgets);

        await tester.tap(find.byTooltip('返回').first);
        await _pumpNavigationFrames(tester);
        expect(find.text('我的'), findsWidgets);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('首页').last);
        await _pumpNavigationFrames(tester);
      }

      await tester.tap(find.text('我的').last);
      await _pumpNavigationFrames(tester);
      await tester.tap(find.text('备忘提醒').first);
      await _pumpNavigationFrames(tester);
      await tester.tap(find.byKey(const Key('reminder-open-calendar')));
      await _pumpNavigationFrames(tester);
      expect(find.text('日历与记录'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.binding.handlePopRoute();
      await _pumpNavigationFrames(tester);
      expect(find.text('备忘提醒'), findsWidgets);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byTooltip('返回').first);
      await _pumpNavigationFrames(tester);
      expect(find.text('我的'), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);

      appRouter.go('/personnel');
      await _pumpNavigationFrames(tester);
      expect(find.byType(PersonnelPage), findsOneWidget);

      await tester.tap(find.byTooltip('返回').first);
      await _pumpNavigationFrames(tester);

      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.idle();
      appRouter.dispose();
      await database.close();
    }
  });
}
