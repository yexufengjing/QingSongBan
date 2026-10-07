import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/garden_tool_repairs/data/garden_tool_repair_repository.dart';
import 'package:qingsongban/features/garden_tool_repairs/domain/repair_models.dart';
import 'package:qingsongban/features/garden_tool_repairs/presentation/garden_tool_repair_form_page.dart';
import 'package:qingsongban/features/garden_tool_repairs/presentation/garden_tool_repair_page.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting());

  tearDown(() async => database.close());

  testWidgets(
    'month ledger shows one header for each date, unit and person group',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = GardenToolRepairRepository(database);
      final unit = await repository.saveUnit(
        name: '特钢',
        sortOrder: 0,
        isActive: true,
      );
      final group = await repository.saveGroup(
        GardenToolRepairGroupDraft(
          repairMonth: '2026-09',
          repairDate: DateTime(2026, 9, 3),
          unitId: unit.id,
          repairerName: '张三',
          items: const [
            GardenToolRepairItemDraft(
              projectName: '割草机刀片',
              specModel: '300mm',
              countUnit: '片',
              quantity: 10,
              unitPriceCents: 800,
            ),
            GardenToolRepairItemDraft(
              projectName: '润滑油',
              specModel: '4L',
              countUnit: '桶',
              quantity: 2,
              unitPriceCents: 4500,
            ),
          ],
        ),
      );
      await repository.saveGroup(
        GardenToolRepairGroupDraft(
          repairMonth: '2026-09',
          repairDate: DateTime(2026, 9, 3),
          unitId: unit.id,
          repairerName: '李四',
          items: const [
            GardenToolRepairItemDraft(
              projectName: '螺栓',
              countUnit: '个',
              quantity: 5,
              unitPriceCents: 50,
            ),
          ],
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const GardenToolRepairPage(initialYear: 2026, initialMonth: 9),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('9月器械维修信息'), findsOneWidget);
      expect(
        tester.getRect(find.text('9月器械维修信息')).right,
        lessThan(tester.getRect(find.text('新增')).left),
      );
      expect(find.text('本月合计'), findsOneWidget);
      expect(find.text('记录组数'), findsOneWidget);
      expect(find.text('项目条数'), findsOneWidget);
      expect(find.text('割草机刀片'), findsOneWidget);
      expect(find.text('润滑油'), findsOneWidget);
      expect(find.text('螺栓'), findsOneWidget);
      expect(find.text('张三'), findsOneWidget);
      expect(find.text('李四'), findsOneWidget);
      expect(find.text('小计：¥170.00'), findsOneWidget);
      expect(find.text('小计：¥2.50'), findsOneWidget);
      expect(find.text('合计金额'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(group.subtotalCents, 17000);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'form calculates multiple item amounts and saves a temporary repairer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(411, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = GardenToolRepairRepository(database);
      await repository.saveUnit(name: '特钢', sortOrder: 0, isActive: true);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                GardenToolRepairFormPage(initialMonth: DateTime.now()),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('特钢').last);
      await tester.pumpAndSettle();
      await tester.enterText(_field('选择人员或临时输入姓名'), '临时维修人');
      await tester.enterText(_field('项目名称'), '刀片');
      await tester.enterText(_field('单位'), '片');
      await tester.enterText(_field('数量'), '2.5');
      await tester.enterText(_field('单价'), '8.40');
      await tester.pumpAndSettle();
      expect(find.text('¥21.00'), findsNWidgets(2));

      await tester.tap(find.text('添加明细'));
      await tester.pumpAndSettle();
      final projects = _field('项目名称');
      await tester.enterText(projects.last, '润滑油');
      await tester.enterText(_field('单位').last, '桶');
      await tester.enterText(_field('数量').last, '2');
      await tester.enterText(_field('单价').last, '4.50');
      await tester.pumpAndSettle();
      expect(find.text('小计：¥30.00'), findsOneWidget);
      expect(find.text('¥30.00'), findsOneWidget);

      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并继续'));
      await tester.pumpAndSettle();

      final savedGroups = await repository.loadMonth(DateTime.now());
      expect(savedGroups, hasLength(1));
      expect(savedGroups.single.group.repairerNameSnapshot, '临时维修人');
      expect(savedGroups.single.group.repairerId, isNull);
      expect(savedGroups.single.items, hasLength(2));
      expect(savedGroups.single.subtotalCents, 3000);
      expect(find.text('已保存，可继续录入下一组'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );
}

Finder _field(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
  description: 'TextField with hint $hint',
);
