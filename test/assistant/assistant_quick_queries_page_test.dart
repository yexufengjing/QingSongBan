import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/assistant/application/assistant_providers.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/assistant/domain/assistant_quick_query.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_quick_queries.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'attendance shortcut selects a specific employee and month, saves, reloads, reuses, and removes favorite',
    (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final firstEmployeeId = await database
          .into(database.employees)
          .insert(
            EmployeesCompanion.insert(
              employeeNo: 'E-001',
              name: '同名员工',
              hireDate: DateTime(2020),
            ),
          );
      final secondEmployeeId = await database
          .into(database.employees)
          .insert(
            EmployeesCompanion.insert(
              employeeNo: 'E-002',
              name: '同名员工',
              hireDate: DateTime(2021),
            ),
          );
      final firstRun = <AssistantQuickQuery>[];
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpQueries(tester, database, onRun: firstRun.add, textScale: 1.3);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('考勤查询'));
      await tester.pumpAndSettle();
      expect(find.text('选择人员'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('选择人员'));
      await tester.pumpAndSettle();
      expect(find.text('同名员工 · E-001'), findsOneWidget);
      expect(find.text('同名员工 · E-002'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'E-002');
      await tester.pump();
      expect(find.text('同名员工 · E-001'), findsNothing);
      await tester.ensureVisible(find.text('同名员工 · E-002'));
      await tester.tap(find.text('同名员工 · E-002'));
      await tester.pumpAndSettle();
      expect(find.text('同名员工 · E-002'), findsOneWidget);

      final now = DateTime.now();
      final previousMonth = DateTime(now.year, now.month - 1);
      final expectedMonth =
          '${previousMonth.year.toString().padLeft(4, '0')}-${previousMonth.month.toString().padLeft(2, '0')}';
      await tester.tap(find.text('上月'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('收藏查询'));
      await tester.tap(find.text('收藏查询'));
      await tester.pumpAndSettle();
      expect(find.text('已收藏此查询'), findsOneWidget);

      await tester.ensureVisible(find.text('查询本地数据'));
      await tester.tap(find.text('查询本地数据'));
      await tester.pumpAndSettle();
      expect(firstRun, hasLength(1));
      expect(firstRun.single.kind, AssistantQuickQueryKind.attendance);
      expect(firstRun.single.employeeId, secondEmployeeId);
      expect(firstRun.single.employeeId, isNot(firstEmployeeId));
      expect(firstRun.single.yearMonth, expectedMonth);
      expect(tester.takeException(), isNull);

      final reloadRun = <AssistantQuickQuery>[];
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await _pumpQueries(
        tester,
        database,
        onRun: reloadRun.add,
        textScale: 1.3,
      );
      final favoriteName = find.textContaining('同名员工（E-002）');
      expect(favoriteName, findsOneWidget);
      expect(find.text('查询考勤 · $expectedMonth'), findsOneWidget);

      await tester.ensureVisible(favoriteName);
      await tester.tap(favoriteName);
      await tester.pumpAndSettle();
      expect(reloadRun, hasLength(1));
      expect(reloadRun.single.kind, AssistantQuickQueryKind.attendance);
      expect(reloadRun.single.employeeId, secondEmployeeId);
      expect(reloadRun.single.yearMonth, expectedMonth);

      final removeFavorite = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip?.startsWith('移除收藏 ') == true,
      );
      await tester.ensureVisible(removeFavorite);
      await tester.tap(removeFavorite);
      await tester.pumpAndSettle();
      expect(find.text('在查询条件中点击“收藏查询”，下次可一键重查。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpQueries(
  WidgetTester tester,
  AppDatabase database, {
  required ValueChanged<AssistantQuickQuery> onRun,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        assistantControllerProvider.overrideWith(
          _IdleAssistantSessionNotifier.new,
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AssistantQuickQueries(onRun: onRun),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _IdleAssistantSessionNotifier extends AssistantSessionNotifier {
  @override
  AssistantState build() => const AssistantState();
}
