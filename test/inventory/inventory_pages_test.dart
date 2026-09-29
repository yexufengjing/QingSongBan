import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/home/application/home_providers.dart';
import 'package:qingsongban/features/home/presentation/home_page.dart';
import 'package:qingsongban/features/inventory/application/inventory_providers.dart';
import 'package:qingsongban/features/inventory/domain/inventory_models.dart';
import 'package:qingsongban/features/inventory/inventory_routes.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_issue_form_page.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_receipt_form_page.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_stock_page.dart';
import 'package:qingsongban/features/inventory/presentation/widgets/inventory_employee_history_section.dart';
import 'package:qingsongban/features/personnel/application/personnel_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final material = InventoryMaterial(
    id: 7,
    materialCode: 'GLV-07',
    materialName: '防护手套',
    modelSpec: '均码',
    unitName: '副',
    currentStock: 3,
    minStock: 5,
    warningEnabled: true,
    isCommon: true,
    status: 'active',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
    isDeleted: false,
  );

  testWidgets('home inventory shortcut opens the eight-operation home', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        ...inventoryRoutes(),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDashboardProvider.overrideWith(
            (ref) async => const HomeDashboardStats(
              activeEmployees: 1,
              newEmployees: 0,
              terminatedEmployees: 0,
              todayAttendance: 0,
              anomalies: 0,
              pendingReminders: 0,
            ),
          ),
          inventoryOverviewProvider.overrideWith(
            (ref) async => const InventoryOverview(
              totalMaterialCount: 1,
              lowStockCount: 1,
              outOfStockCount: 0,
              pendingReplenishmentCount: 0,
              monthlyReceiptCount: 1,
              monthlyIssueCount: 0,
            ),
          ),
          inventoryWarningsProvider.overrideWith(
            (ref) async => [InventoryStockRow(material: material)],
          ),
          inventoryTransactionsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('home-action-库存管理'));
    expect(entry, findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    for (final label in [
      '物资信息',
      '入库管理',
      '领用出库',
      '当前库存',
      '库存盘点',
      '预警与待补充',
      '待补充清单',
      '库存流水',
    ]) {
      expect(find.byKey(Key('inventory-shortcut-$label')), findsOneWidget);
    }
  });

  testWidgets(
    'stock list shows status and adjustment action on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryStockProvider.overrideWith(
              (ref) async => [InventoryStockRow(material: material)],
            ),
          ],
          child: const MaterialApp(home: InventoryStockPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('库存不足'), findsWidgets);
      expect(find.byKey(const Key('inventory-adjust-7')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('receipt form validates quantities before submission', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryMaterialsProvider.overrideWith((ref) async => [material]),
        ],
        child: const MaterialApp(home: InventoryReceiptFormPage()),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    final submit = find.byKey(const Key('inventory-receipt-submit'));
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('请输入大于 0 的数量'), findsOneWidget);
  });

  testWidgets(
    'issue form supports empty personnel state and requires a receiver',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryMaterialsProvider.overrideWith((ref) async => [material]),
            allPersonnelProvider.overrideWith(
              (ref) => Stream.value(<Employee>[]),
            ),
          ],
          child: const MaterialApp(home: InventoryIssueFormPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('领取人（可搜索人员档案）'), findsOneWidget);
      await tester.tap(find.byKey(const Key('inventory-issue-type')));
      await tester.pumpAndSettle();
      expect(find.text('调拨出库'), findsOneWidget);
      await tester.tap(find.text('调拨出库').last);
      await tester.pumpAndSettle();
      expect(find.text('调拨出库'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      final submit = find.byKey(const Key('inventory-issue-submit'));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('请选择领取人'), findsOneWidget);
    },
  );

  testWidgets(
    'employee history exposes six columns in a horizontal mobile table',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final issue = InventoryIssue(
        id: 1,
        issueNo: 'CK-1',
        issueDate: DateTime(2026, 9, 5),
        issueType: 'employee_claim',
        receiverType: 'employee',
        employeeId: 17,
        employeeNameSnapshot: '张三',
        departmentNameSnapshot: '维修组',
        createdAt: DateTime(2026, 9, 5),
        updatedAt: DateTime(2026, 9, 5),
        isDeleted: false,
      );
      final issueItem = InventoryIssueItem(
        id: 2,
        issueId: 1,
        materialId: 7,
        materialNameSnapshot: '防护手套',
        modelSnapshot: '均码',
        unitSnapshot: '副',
        quantity: 2,
        createdAt: DateTime(2026, 9, 5),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeMaterialHistoryProvider(17).overrideWith(
              (ref) async => [
                InventoryEmployeeHistoryItem(issue: issue, item: issueItem),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InventoryEmployeeHistorySection(employeeId: 17),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['日期', '物品名称', '型号', '领取数量', '领取人', '备注']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.byKey(const Key('inventory-employee-history-horizontal-scroll')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
