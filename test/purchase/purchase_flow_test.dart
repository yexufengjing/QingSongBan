import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/purchase/presentation/widgets/purchase_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/inventory/data/inventory_repository.dart';
import 'package:qingsongban/features/inventory/domain/inventory_models.dart';
import 'package:qingsongban/features/purchase/data/purchase_repository_impl.dart';
import 'package:qingsongban/features/purchase/domain/purchase_models.dart';
import 'package:qingsongban/features/purchase/domain/purchase_status.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_create_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_detail_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_home_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_item_prefill.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_pending_apply_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_pending_receive_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_stock_in_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_tracking_page.dart';
import 'package:qingsongban/features/reminders/application/notification_service.dart';
import 'package:qingsongban/features/reminders/application/reminder_providers.dart';
import 'package:qingsongban/features/reminders/presentation/reminder_form_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'creates, applies with no purchaser, assigns, receives in two batches and protects stock history',
    (tester) async {
      final database = AppDatabase.forTesting();
      final inventory = InventoryRepository(database);
      final purchases = PurchaseRepositoryImpl(database);
      final materialId = await _createMaterial(inventory, 'FLOW-001');
      final material = (await inventory.getMaterials()).single;
      final router = _purchaseRouter(
        initialLocation: '/purchase',
        createItem: PurchaseItemPrefill.fromInventoryMaterial(material),
      );
      final cleanup = _addCleanup(tester, database, router);
      await _pump(tester, database, router);

      router.go('/purchase/create');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('purchase-title-field')),
        '扫路车边刷采购',
      );
      await _enterTextVisible(
        tester,
        find.byKey(const Key('purchase-item-quantity-0')),
        '5',
      );
      await tester.tap(find.byKey(const Key('purchase-save-button')));
      await tester.pumpAndSettle();

      var request = await database
          .select(database.purchaseRequests)
          .getSingle();
      expect(request.status, PurchaseStatus.pendingApply.storageValue);
      final requestId = request.id;

      router.go('/purchase/pending-apply');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('purchase-confirm-applied-$requestId')));
      await tester.pumpAndSettle();
      await tester.enterText(
        _purchaseTextField('OA流程链接（可选）'),
        'not a valid OA URL',
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();

      request = await database.select(database.purchaseRequests).getSingle();
      expect(request.status, PurchaseStatus.applied.storageValue);
      expect(request.purchaserName, isNull);
      expect(request.oaUrl, 'not a valid OA URL');

      router.go('/purchase/detail/$requestId');
      await tester.pumpAndSettle();
      final oaButton = find.widgetWithText(TextButton, '查看 OA 流程');
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .clearSnackBars();
      await tester.pumpAndSettle();
      await _scrollTo(tester, oaButton);
      expect(oaButton, findsOneWidget);
      expect(oaButton.hitTestable(), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(tester.widget<TextButton>(oaButton).onPressed, isNotNull);
      await tester.tap(oaButton);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('当前 OA 链接无法打开，请检查链接是否有效。'), findsOneWidget);
      expect(
        (await database.select(database.purchaseRequests).getSingle()).status,
        PurchaseStatus.applied.storageValue,
      );

      router.go('/purchase/tracking?all=1');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('purchase-assign-$requestId')));
      await tester.pumpAndSettle();
      await tester.enterText(_purchaseTextField('采购执行人（选填）'), '林采购');
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();
      request = await database.select(database.purchaseRequests).getSingle();
      expect(request.status, PurchaseStatus.purchasing.storageValue);
      expect(request.purchaserName, '林采购');

      await tester.tap(find.byKey(Key('purchase-mark-receive-$requestId')));
      await tester.pumpAndSettle();
      await tester.enterText(_purchaseTextField('领取地点（选填）'), '西门仓库');
      await _tapSheetButton(tester, '设为待领取');
      await tester.pumpAndSettle();
      expect(
        (await database.select(database.purchaseRequests).getSingle()).status,
        PurchaseStatus.pendingReceive.storageValue,
      );

      final item = await (database.select(
        database.purchaseRequestItems,
      )..where((row) => row.requestId.equals(requestId))).getSingle();
      router.go('/purchase/stock-in/$requestId');
      await tester.pumpAndSettle();
      await _enterTextVisible(
        tester,
        find.byKey(Key('purchase-stock-quantity-${item.id}')),
        '2',
      );
      await _confirmStockIn(tester);
      expect(
        (await database.select(database.purchaseRequests).getSingle()).status,
        PurchaseStatus.pendingReceive.storageValue,
      );
      expect((await _getMaterial(database, materialId)).currentStock, 2);

      router.go('/purchase/stock-in/$requestId');
      await tester.pumpAndSettle();
      await _enterTextVisible(
        tester,
        find.byKey(Key('purchase-stock-quantity-${item.id}')),
        '3',
      );
      await _confirmStockIn(tester);
      request = await database.select(database.purchaseRequests).getSingle();
      expect(request.status, PurchaseStatus.stocked.storageValue);
      expect(request.completedAt, isNotNull);
      expect((await _getMaterial(database, materialId)).currentStock, 5);
      expect(
        await database.select(database.purchaseStockEntries).get(),
        hasLength(2),
      );
      expect(
        await database.select(database.inventoryReceipts).get(),
        hasLength(2),
      );
      await expectLater(
        purchases.softDelete(requestId),
        throwsA(isA<PurchaseException>()),
      );
      router.go('/purchase/detail/$requestId');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('调整状态'));
      await tester.pumpAndSettle();
      expect(find.text('删除采购记录'), findsNothing);
      await cleanup();
    },
  );

  testWidgets(
    'manual item fields persist and reload when reopening the request editor',
    (tester) async {
      final database = AppDatabase.forTesting();
      final router = _purchaseRouter(initialLocation: '/purchase');
      final cleanup = _addCleanup(tester, database, router);
      await _pump(tester, database, router);

      router.go('/purchase/create');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('purchase-title-field')),
        '手工物资采购',
      );
      final manualAdd = find.widgetWithText(OutlinedButton, '手动新增物资');
      await tester.scrollUntilVisible(
        manualAdd,
        280,
        scrollable: _mainListScrollable(),
      );
      await tester.tap(manualAdd);
      await tester.pumpAndSettle();
      await tester.enterText(_purchaseTextField('物资名称'), '定制拉手');
      await tester.enterText(_purchaseTextField('规格型号（选填）'), 'M12×30');
      await tester.enterText(_purchaseTextField('单位'), '个');
      await tester.enterText(_purchaseTextField('申报数量'), '7.5');
      await tester.tap(find.widgetWithText(FilledButton, '添加'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _scrollTo(tester, find.text('定制拉手'));
      expect(find.text('定制拉手'), findsOneWidget);

      await tester.tap(find.byKey(const Key('purchase-save-button')));
      await tester.pumpAndSettle();
      final request = await database
          .select(database.purchaseRequests)
          .getSingle();
      final item = await (database.select(
        database.purchaseRequestItems,
      )..where((row) => row.requestId.equals(request.id))).getSingle();
      expect(request.status, PurchaseStatus.pendingApply.storageValue);
      expect(item.itemName, '定制拉手');
      expect(item.specification, 'M12×30');
      expect(item.unit, '个');
      expect(item.requestQuantity, 7.5);

      router.go('/purchase/pending-apply');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('purchase-edit-${request.id}')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('定制拉手'));
      expect(find.text('定制拉手'), findsOneWidget);
      expect(find.text('规格：M12×30'), findsOneWidget);
      expect(find.text('单位：个'), findsWidgets);
      final quantityField = find.byKey(const Key('purchase-item-quantity-0'));
      await tester.scrollUntilVisible(
        quantityField,
        280,
        scrollable: _mainListScrollable(),
      );
      expect(tester.widget<TextField>(quantityField).controller!.text, '7.5');
      expect(tester.takeException(), isNull);
      await cleanup();
    },
  );

  testWidgets(
    'manual status correction and unreceived soft delete leave inventory untouched',
    (tester) async {
      final database = AppDatabase.forTesting();
      final inventory = InventoryRepository(database);
      final purchases = PurchaseRepositoryImpl(database);
      final materialId = await _createMaterial(inventory, 'FLOW-002');
      final requestId = await _createRequest(purchases, materialId);
      final router = _purchaseRouter(
        initialLocation: '/purchase/detail/$requestId',
      );
      final cleanup = _addCleanup(tester, database, router);
      await _pump(tester, database, router);

      await tester.tap(find.byTooltip('调整状态'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('设为已入库'));
      await tester.pumpAndSettle();
      expect(find.text('这只会将采购状态改为已入库，不会增加库存或创建库存流水。确定继续吗？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '继续'));
      await tester.pumpAndSettle();
      final request = await database
          .select(database.purchaseRequests)
          .getSingle();
      expect(request.status, PurchaseStatus.stocked.storageValue);
      expect(request.completedAt, isNull);
      expect((await _getMaterial(database, materialId)).currentStock, 0);
      expect(
        await database.select(database.purchaseStockEntries).get(),
        isEmpty,
      );
      expect(await database.select(database.inventoryReceipts).get(), isEmpty);

      await tester.tap(find.byTooltip('调整状态'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除采购记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '确认删除'));
      await tester.pumpAndSettle();
      expect(
        (await database.select(database.purchaseRequests).getSingle())
            .isDeleted,
        isTrue,
      );
      await cleanup();
    },
  );

  testWidgets(
    'reminder persistence failure leaves pending-receive request unchanged',
    (tester) async {
      final database = AppDatabase.forTesting();
      final purchases = PurchaseRepositoryImpl(database);
      final materialId = await _createMaterial(
        InventoryRepository(database),
        'FLOW-003',
      );
      final requestId = await _createPendingReceive(purchases, materialId);
      final router = _purchaseRouter(
        initialLocation: '/purchase/pending-receive',
      );
      final cleanup = _addCleanup(tester, database, router);
      await database.customStatement('''
        CREATE TRIGGER fail_purchase_reminder_insert
        BEFORE INSERT ON reminders
        BEGIN
          SELECT RAISE(ABORT, 'simulated reminder persistence failure');
        END;
      ''');
      await _pump(
        tester,
        database,
        router,
        notificationService: _FakeNotificationService(),
      );

      await tester.tap(find.byKey(Key('purchase-reminder-$requestId')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reminder-save-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reminder-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('采购状态已更新，但领取提醒创建失败，可稍后重新设置。'), findsOneWidget);
      expect(await database.select(database.reminders).get(), isEmpty);
      expect(
        (await database.select(database.purchaseRequests).getSingle()).status,
        PurchaseStatus.pendingReceive.storageValue,
      );
      await cleanup();
    },
  );

  testWidgets(
    'notification sync failure preserves saved reminder source through later edit',
    (tester) async {
      final database = AppDatabase.forTesting();
      final purchases = PurchaseRepositoryImpl(database);
      final materialId = await _createMaterial(
        InventoryRepository(database),
        'FLOW-004',
      );
      final requestId = await _createPendingReceive(purchases, materialId);
      final router = _purchaseRouter(
        initialLocation: '/purchase/pending-receive',
      );
      final cleanup = _addCleanup(tester, database, router);
      await _pump(
        tester,
        database,
        router,
        notificationService: _FakeNotificationService(throwOnSync: true),
      );

      await tester.tap(find.byKey(Key('purchase-reminder-$requestId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('提醒已保存，但系统通知同步失败，请稍后检查提醒设置。'), findsOneWidget);
      var reminder = await database.select(database.reminders).getSingle();
      expect(reminder.sourceEntityType, 'purchase_request');
      expect(reminder.sourceEntityId, requestId);
      final reminderId = reminder.id;

      router.go('/settings/reminders/$reminderId/edit');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reminder-title-field')),
        '更新后的采购领取提醒',
      );
      await tester.tap(find.byKey(const Key('reminder-save-button')));
      await tester.pumpAndSettle();
      reminder = await database.select(database.reminders).getSingle();
      expect(reminder.title, '更新后的采购领取提醒');
      expect(reminder.sourceEntityType, 'purchase_request');
      expect(reminder.sourceEntityId, requestId);
      expect(
        (await database.select(database.purchaseRequests).getSingle()).status,
        PurchaseStatus.pendingReceive.storageValue,
      );
      await cleanup();
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database,
  GoRouter router, {
  NotificationService? notificationService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        if (notificationService != null)
          notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> Function() _addCleanup(
  WidgetTester tester,
  AppDatabase database,
  GoRouter router,
) {
  var cleaned = false;
  Future<void> cleanup() async {
    if (cleaned) return;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    router.dispose();
    await database.close();
    cleaned = true;
  }

  addTearDown(cleanup);
  return cleanup;
}

Future<void> _enterTextVisible(
  WidgetTester tester,
  Finder finder,
  String value,
) async {
  await _scrollTo(tester, finder);
  await tester.enterText(finder, value);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    280,
    scrollable: _mainListScrollable(),
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder _mainListScrollable() => find
    .descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    )
    .first;

GoRouter _purchaseRouter({
  required String initialLocation,
  PurchaseItemPrefill? createItem,
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/purchase',
      builder: (context, state) => const PurchaseHomePage(),
      routes: [
        GoRoute(
          path: 'create',
          builder: (context, state) => PurchaseCreatePage(
            initialItem: state.extra as PurchaseItemPrefill? ?? createItem,
            requestId: int.tryParse(state.uri.queryParameters['editId'] ?? ''),
          ),
        ),
        GoRoute(
          path: 'pending-apply',
          builder: (context, state) => const PurchasePendingApplyPage(),
        ),
        GoRoute(
          path: 'tracking',
          builder: (context, state) => PurchaseTrackingPage(
            showAll: state.uri.queryParameters['all'] == '1',
          ),
        ),
        GoRoute(
          path: 'pending-receive',
          builder: (context, state) => const PurchasePendingReceivePage(),
        ),
        GoRoute(
          path: 'detail/:requestId',
          builder: (context, state) => PurchaseDetailPage(
            requestId: int.parse(state.pathParameters['requestId']!),
          ),
        ),
        GoRoute(
          path: 'stock-in/:requestId',
          builder: (context, state) => PurchaseStockInPage(
            requestId: int.parse(state.pathParameters['requestId']!),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/settings/reminders/new',
      builder: (context, state) => ReminderFormPage(
        initialTitle: state.uri.queryParameters['title'],
        initialRemark: state.uri.queryParameters['remark'],
        sourceEntityType: state.uri.queryParameters['sourceType'],
        sourceEntityId: int.tryParse(
          state.uri.queryParameters['sourceId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/settings/reminders/:id/edit',
      builder: (context, state) =>
          ReminderFormPage(reminderId: int.parse(state.pathParameters['id']!)),
    ),
  ],
);

Future<void> _confirmStockIn(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('purchase-confirm-stock-in')));
  await tester.pumpAndSettle();
  final dialogButton = find.descendant(
    of: find.byType(AlertDialog).last,
    matching: find.widgetWithText(FilledButton, '确认入库'),
  );
  expect(dialogButton, findsOneWidget);
  await tester.tap(dialogButton);
  await tester.pumpAndSettle();
}

Future<void> _tapSheetButton(WidgetTester tester, String label) async {
  final sheetButton = find.descendant(
    of: find.byType(BottomSheet).last,
    matching: find.widgetWithText(FilledButton, label),
  );
  expect(sheetButton, findsOneWidget);
  await tester.tap(sheetButton);
  await tester.pumpAndSettle();
}

Future<int> _createMaterial(InventoryRepository inventory, String code) =>
    inventory.createMaterial(
      InventoryMaterialDraft(
        materialCode: code,
        materialName: '扫路车边刷',
        modelSpec: '标准型',
        unitName: '把',
        storageLocation: '西门仓库',
      ),
    );

Future<InventoryMaterial> _getMaterial(AppDatabase database, int materialId) =>
    (database.select(
      database.inventoryMaterials,
    )..where((row) => row.id.equals(materialId))).getSingle();

Future<int> _createRequest(PurchaseRepositoryImpl purchases, int materialId) =>
    purchases.createPurchaseRequest(
      CreatePurchaseRequestInput(
        title: '测试采购',
        requestDate: DateTime(2026, 10, 1),
        demandReason: '库存不足',
        items: [
          PurchaseItemDraft(
            inventoryMaterialId: materialId,
            itemName: '扫路车边刷',
            specification: '标准型',
            unit: '把',
            currentStockSnapshot: 0,
            requestQuantity: 5,
          ),
        ],
      ),
    );

Future<int> _createPendingReceive(
  PurchaseRepositoryImpl purchases,
  int materialId,
) async {
  final requestId = await _createRequest(purchases, materialId);
  await purchases.confirmApplied(
    requestId,
    ConfirmAppliedInput(appliedDate: DateTime(2026, 10, 1)),
  );
  await purchases.assignPurchaser(
    requestId,
    AssignPurchaserInput(
      purchaserName: '测试采购员',
      assignedDate: DateTime(2026, 10, 1),
    ),
  );
  await purchases.markPendingReceive(
    requestId,
    PendingReceiveInput(arrivalNoticeDate: DateTime(2026, 10, 2)),
  );
  return requestId;
}

class _FakeNotificationService implements NotificationService {
  _FakeNotificationService({this.throwOnSync = false});

  final bool throwOnSync;

  @override
  Future<void> initialize() async {}

  @override
  Future<String> currentTimezoneId() async => 'Etc/UTC';

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> sync(
    Reminder reminder, {
    Iterable<DateTime>? pendingOccurrences,
  }) async {
    if (throwOnSync) throw StateError('simulated notification failure');
  }

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> showTestNotification() async {}
}

// Labels are now outside their inputs; keep driving the same business fields.
Finder _purchaseTextField(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is PurchaseLabeledField && widget.label == label,
  ),
  matching: find.byType(TextField),
);
