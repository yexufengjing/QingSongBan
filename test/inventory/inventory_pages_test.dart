import 'dart:async';

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
import 'package:qingsongban/features/inventory/presentation/inventory_issues_page.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_receipt_form_page.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_receipts_page.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_stock_page.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_stocktakes_page.dart';
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
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: HomePage()),
        ),
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
              lowStockCount: 0,
              outOfStockCount: 1,
              pendingReplenishmentCount: 0,
              monthlyReceiptCount: 1,
              monthlyIssueCount: 0,
            ),
          ),
          inventoryWarningsProvider.overrideWith(
            (ref) async => [
              InventoryStockRow(material: material.copyWith(currentStock: 0)),
            ],
          ),
          inventoryTransactionsProvider.overrideWith((ref) async => []),
          inventoryReceiptsProvider.overrideWith((ref) async => []),
          inventoryIssuesProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('处理'));
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('home-action-库存管理'));
    expect(entry, findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final warnings = find.byKey(const Key('inventory-home-warning-count'));
    await tester.scrollUntilVisible(
      warnings,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: warnings, matching: find.text('1')),
      findsOneWidget,
    );
    for (final label in [
      '物资信息',
      '入库管理',
      '领用出库',
      '当前库存',
      '库存盘点',
      '库存预警',
      '待采购',
      '库存流水',
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(Key('inventory-shortcut-$label')),
        150,
        scrollable: find.byType(Scrollable).last,
      );
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

  testWidgets(
    'receipt list shows mixed units and detail count on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final receipt = InventoryReceipt(
        id: 31,
        receiptNo: 'RK-31',
        receiptDate: now,
        receiptType: 'purchase',
        sourceName: '测试采购来源',
        operatorNameSnapshot: '测试登记人',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryReceiptsProvider.overrideWith((ref) async => [receipt]),
            inventoryReceiptItemsProvider(31).overrideWith(
              (ref) async => [
                InventoryReceiptItem(
                  id: 1,
                  receiptId: 31,
                  materialId: 7,
                  materialNameSnapshot: '防护手套',
                  modelSnapshot: '均码',
                  unitSnapshot: '副',
                  quantity: 2,
                  createdAt: now,
                ),
                InventoryReceiptItem(
                  id: 2,
                  receiptId: 31,
                  materialId: 8,
                  materialNameSnapshot: '消毒液',
                  modelSnapshot: '500ml',
                  unitSnapshot: '瓶',
                  quantity: 3,
                  createdAt: now,
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: InventoryReceiptsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('副'), findsOneWidget);
      expect(find.text('瓶'), findsOneWidget);
      expect(find.text('共 2 条明细'), findsOneWidget);
      expect(find.text('本月入库'), findsOneWidget);
      expect(find.text('记录组数'), findsWidgets);
      expect(find.text('条目条数'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const Key('inventory-receipt-quantity')),
          matching: find.text('2副\n3瓶'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('inventory-receipt-group-count')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('inventory-receipt-detail-count')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'issue list shows mixed units and detail count on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final issue = InventoryIssue(
        id: 41,
        issueNo: 'CK-41',
        issueDate: now,
        issueType: 'employee_claim',
        receiverType: 'employee',
        employeeNameSnapshot: '测试领用人',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      final manualIssue = InventoryIssue(
        id: 42,
        issueNo: 'CK-42',
        issueDate: now,
        issueType: 'other',
        receiverType: 'manual',
        manualReceiverName: '手填领取对象',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      final departmentIssue = InventoryIssue(
        id: 43,
        issueNo: 'CK-43',
        issueDate: now,
        issueType: 'department_use',
        receiverType: 'department',
        departmentNameSnapshot: '后勤组',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      final publicIssue = InventoryIssue(
        id: 44,
        issueNo: 'CK-44',
        issueDate: now,
        issueType: 'other',
        receiverType: 'public',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryIssuesProvider.overrideWith(
              (ref) async => [issue, manualIssue, departmentIssue, publicIssue],
            ),
            inventoryIssueItemsProvider(41).overrideWith(
              (ref) async => [
                InventoryIssueItem(
                  id: 1,
                  issueId: 41,
                  materialId: 7,
                  materialNameSnapshot: '防护手套',
                  modelSnapshot: '均码',
                  unitSnapshot: '副',
                  quantity: 2,
                  createdAt: now,
                ),
                InventoryIssueItem(
                  id: 2,
                  issueId: 41,
                  materialId: 8,
                  materialNameSnapshot: '消毒液',
                  modelSnapshot: '500ml',
                  unitSnapshot: '瓶',
                  quantity: 3,
                  createdAt: now,
                ),
              ],
            ),
            inventoryIssueItemsProvider(42)
                .overrideWith((ref) async => <InventoryIssueItem>[]),
            inventoryIssueItemsProvider(43)
                .overrideWith((ref) async => <InventoryIssueItem>[]),
            inventoryIssueItemsProvider(44)
                .overrideWith((ref) async => <InventoryIssueItem>[]),
          ],
          child: const MaterialApp(home: InventoryIssuesPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('领用记录'), findsOneWidget);
      expect(
        find.byKey(const Key('inventory-issue-add-fixed')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('inventory-issue-search')), findsOneWidget);
      expect(find.textContaining('防护手套 · 均码 · 2副'), findsOneWidget);
      expect(find.text('共2项'), findsOneWidget);
      expect(find.text('领取人次'), findsWidgets);
      expect(find.text('记录条目'), findsWidgets);
      expect(find.textContaining('2副\n3瓶'), findsOneWidget);
      expect(
        find.byKey(
          Key('inventory-issue-day-${now.year}-${now.month}-${now.day}'),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('inventory-issue-search')),
        '消毒液',
      );
      await tester.pumpAndSettle();
      expect(find.text('测试领用人'), findsOneWidget);
      expect(find.text('手填领取对象'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('issue material search waits for detail results and can retry', (
    tester,
  ) async {
    final now = DateTime.now();
    final issue = InventoryIssue(
      id: 61,
      issueNo: 'CK-61',
      issueDate: now,
      issueType: 'employee_claim',
      receiverType: 'employee',
      employeeNameSnapshot: '待查询人员',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    );
    final firstLoad = Completer<List<InventoryIssueItem>>();
    var loadCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryIssuesProvider.overrideWith((ref) async => [issue]),
          inventoryIssueItemsProvider(61).overrideWith((ref) {
            loadCount++;
            return loadCount == 1
                ? firstLoad.future
                : Future.value(<InventoryIssueItem>[]);
          }),
        ],
        child: const MaterialApp(home: InventoryIssuesPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(
      find.byKey(const Key('inventory-issue-search')),
      '不存在的物资',
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    firstLoad.completeError(StateError('material details unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('没有匹配记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft stocktake shows real differences on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final stocktake = InventoryStocktake(
      id: 51,
      stocktakeNo: 'PD-51',
      stocktakeDate: now,
      operatorNameSnapshot: '测试盘点人',
      status: 'draft',
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryStocktakesProvider.overrideWith((ref) async => [stocktake]),
          inventoryStocktakeItemsProvider(51).overrideWith(
            (ref) async => [
              const InventoryStocktakeItem(
                id: 1,
                stocktakeId: 51,
                materialId: 7,
                materialNameSnapshot: '防护手套',
                modelSnapshot: '均码',
                unitSnapshot: '副',
                bookQuantity: 3,
                actualQuantity: 2,
                differenceQuantity: -1,
              ),
              const InventoryStocktakeItem(
                id: 2,
                stocktakeId: 51,
                materialId: 8,
                materialNameSnapshot: '消毒液',
                modelSnapshot: '500ml',
                unitSnapshot: '瓶',
                bookQuantity: 4,
                actualQuantity: 4,
                differenceQuantity: 0,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: InventoryStocktakesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('待盘点'), findsWidgets);
    expect(find.text('防护手套'), findsOneWidget);
    expect(find.text('消毒液'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('-1'), findsOneWidget);
    expect(find.text('差异条数'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

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
      expect(find.text('搜索并选择领取人'), findsOneWidget);
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
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
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
