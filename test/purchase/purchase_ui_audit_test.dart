import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/app/router/app_router.dart' show appRouter;
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/core/database/purchase_demo_data_seeder.dart';
import 'package:qingsongban/features/inventory/data/inventory_repository.dart';
import 'package:qingsongban/features/inventory/domain/inventory_models.dart';
import 'package:qingsongban/features/purchase/domain/purchase_status.dart';
import 'package:qingsongban/features/purchase/data/purchase_repository_impl.dart';
import 'package:qingsongban/features/purchase/domain/purchase_models.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_create_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_detail_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_history_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_home_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_item_history_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_item_prefill.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_pending_apply_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_pending_receive_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_stock_in_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_tracking_page.dart';
import 'package:qingsongban/features/reminders/presentation/reminder_form_page.dart';

const _capturePurchaseUi = bool.fromEnvironment('PURCHASE_CAPTURE_UI');
const _materialIconsFamily = 'MaterialIcons';
String? _auditFontFamily;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File(r'C:\Windows\Fonts\simhei.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('PurchaseAuditChinese')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
      _auditFontFamily = 'PurchaseAuditChinese';
    }
    final icons = File(
      r'D:\Flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader(
        _materialIconsFamily,
      )..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
      await loader.load();
    }
  });

  testWidgets('库存选择、手动新增和重复采购弹窗保留真实操作', (tester) async {
    final database = AppDatabase.forTesting();
    final closeDatabase = _closeDatabaseOnExit(database, tester);
    await tester.runAsync(() => PurchaseDemoDataSeeder.seed(database));
    final inventory = InventoryRepository(database);
    final active = (await inventory.getMaterials()).firstWhere(
      (material) => material.materialName == '防护手套',
    );
    final router = _router(
      createItem: PurchaseItemPrefill.fromInventoryMaterial(active),
    );
    final cleanup = await _mount(
      tester,
      database,
      router,
      '/purchase/create',
      closeDatabase: closeDatabase,
    );

    expect(find.widgetWithText(AlertDialog, '已有未完成采购'), findsOneWidget);
    await _captureIfEnabled(tester, '00_initial_duplicate_purchase_dialog');
    await tester.tap(find.widgetWithText(FilledButton, '继续创建'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移除物资'));
    await tester.pumpAndSettle();

    final selectInventory = find.byKey(const Key('purchase-select-inventory'));
    await _ensureVisibleAndHitTestable(
      tester,
      selectInventory,
      scrollable: find
          .descendant(
            of: find.byType(PurchaseCreatePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(selectInventory);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '01_inventory_picker_sheet');
    expect(find.text('选择库存物资'), findsWidgets);
    expect(find.text('防护手套'), findsOneWidget);
    final pickerMaterial = find.text('防护手套');
    await _ensureVisibleAndHitTestable(
      tester,
      pickerMaterial,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(pickerMaterial);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '02_duplicate_purchase_dialog');
    expect(find.widgetWithText(AlertDialog, '已有未完成采购'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '继续创建'));
    await tester.pumpAndSettle();
    expect(find.text('防护手套'), findsOneWidget);
    await tester.ensureVisible(find.text('创建日期'));
    await tester.tap(find.text('创建日期'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '03_create_date_picker');
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();

    final manualAdd = find.widgetWithText(OutlinedButton, '手动新增物资');
    await _ensureVisibleAndHitTestable(
      tester,
      manualAdd,
      scrollable: find
          .descendant(
            of: find.byType(PurchaseCreatePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(manualAdd);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '03_manual_item_dialog');
    expect(find.widgetWithText(AlertDialog, '手动新增物资'), findsOneWidget);
    expect(find.widgetWithText(TextField, '物资名称'), findsOneWidget);
    expect(find.widgetWithText(TextField, '规格型号（选填）'), findsOneWidget);
    expect(find.widgetWithText(TextField, '单位'), findsOneWidget);
    expect(find.widgetWithText(TextField, '申报数量'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '物资名称'), '中文演示手套');
    await tester.enterText(find.widgetWithText(TextField, '单位'), '双');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();
    expect(find.text('中文演示手套'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cleanup();
  });

  testWidgets('OA确认、跟踪分配和通知弹窗显示字段并真实更新采购状态', (tester) async {
    final database = AppDatabase.forTesting();
    final closeDatabase = _closeDatabaseOnExit(database, tester);
    await tester.runAsync(() => PurchaseDemoDataSeeder.seed(database));
    final pending = await _requestByTitle(database, '【演示】待申报·保洁班日常耗材补充');
    final applied = await _requestByTitle(database, '【演示】已申报·维修班常用备件');
    final purchasing = await _requestByTitle(database, '【演示】采购中·环卫车辆保养用品');
    final router = _router();
    final cleanup = await _mount(
      tester,
      database,
      router,
      '/purchase',
      closeDatabase: closeDatabase,
    );
    // The reference home shows the first three urgent records. Pending apply
    // remains reachable from the stage summary for requests outside that subset.
    await tester.ensureVisible(find.text('待申报').first);
    await tester.tap(find.text('待申报').first);
    await tester.pumpAndSettle();
    expect(find.byType(PurchasePendingApplyPage), findsOneWidget);
    await tester.tap(find.byKey(Key('purchase-confirm-applied-${pending.id}')));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '04_pending_apply_oa_sheet');
    expect(find.widgetWithText(BottomSheet, '确认已完成 OA 申报'), findsOneWidget);
    expect(find.widgetWithText(BottomSheet, 'OA申报日期'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'OA流程编号（可选）'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'OA流程标题（可选）'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'OA流程链接（可选）'), findsOneWidget);
    await tester.tap(find.text('OA申报日期'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '05_oa_date_picker');
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'OA流程编号（可选）'),
      '演示OA-测试-01',
    );
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();
    expect(
      (await _request(database, pending.id)).status,
      PurchaseStatus.applied.storageValue,
    );
    expect((await _request(database, pending.id)).oaRequestNo, '演示OA-测试-01');

    final detailPendingId = await _createPendingApplyRequest(database);
    router.go('/purchase/detail/$detailPendingId');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认已申报'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '05_detail_oa_sheet');
    expect(find.widgetWithText(BottomSheet, '确认已完成 OA 申报'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();
    expect(
      (await _request(database, detailPendingId)).status,
      PurchaseStatus.applied.storageValue,
    );

    router.go('/purchase/tracking?all=1');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('日期筛选'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '06_tracking_date_menu');
    expect(find.widgetWithText(PopupMenuItem<String>, '全部日期'), findsOneWidget);
    expect(find.widgetWithText(PopupMenuItem<String>, '最近30天'), findsOneWidget);
    expect(find.widgetWithText(PopupMenuItem<String>, '自定义日期'), findsOneWidget);
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '自定义日期'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '07_tracking_custom_date_picker');
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('日期筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '全部日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('采购执行人'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '07_tracking_people_menu');
    expect(find.widgetWithText(PopupMenuItem<String>, '所有执行人'), findsOneWidget);
    expect(find.widgetWithText(PopupMenuItem<String>, '演示采购员甲'), findsOneWidget);
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '所有执行人'));
    await tester.pumpAndSettle();
    final assignButton = find.byKey(Key('purchase-assign-${applied.id}'));
    await _ensureVisibleAndHitTestable(
      tester,
      assignButton,
      scrollable: _mainListScrollable(find.byType(PurchaseTrackingPage)),
    );
    await tester.tap(assignButton);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '08_assign_sheet');
    expect(find.widgetWithText(BottomSheet, '填写采购执行信息'), findsOneWidget);
    expect(find.widgetWithText(TextField, '采购分部（选填）'), findsOneWidget);
    expect(find.widgetWithText(TextField, '采购执行人（选填）'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '采购分部（选填）'), '演示采购部');
    await tester.enterText(
      find.widgetWithText(TextField, '采购执行人（选填）'),
      '演示执行人',
    );
    await tester.tap(find.text('分配日期'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '09_assign_date_picker');
    expect(find.widgetWithText(DatePickerDialog, '选择日期'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    await _tapSheet(tester, '确认');
    expect(
      (await _request(database, applied.id)).status,
      PurchaseStatus.purchasing.storageValue,
    );
    expect((await _request(database, applied.id)).purchaserName, '演示执行人');

    final markReceiveButton = find.byKey(
      Key('purchase-mark-receive-${purchasing.id}'),
    );
    final trackingList = _mainListScrollable(
      find.byType(PurchaseTrackingPage),
    );
    final trackingListState = tester.state<ScrollableState>(trackingList);
    trackingListState.position.jumpTo(
      trackingListState.position.minScrollExtent,
    );
    await tester.pumpAndSettle();
    await _ensureVisibleAndHitTestable(
      tester,
      markReceiveButton,
      scrollable: trackingList,
    );
    await tester.tap(markReceiveButton);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '10_arrival_notice_sheet');
    expect(find.widgetWithText(BottomSheet, '收到物资入厂通知'), findsOneWidget);
    expect(find.widgetWithText(BottomSheet, '通知日期'), findsOneWidget);
    expect(find.widgetWithText(TextField, '领取地点（选填）'), findsOneWidget);
    await tester.tap(find.text('通知日期'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '11_arrival_date_picker');
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '领取地点（选填）'), '测试收货区');
    await _tapSheet(tester, '设为待领取');
    expect(
      (await _request(database, purchasing.id)).status,
      PurchaseStatus.pendingReceive.storageValue,
    );
    expect((await _request(database, purchasing.id)).receiveLocation, '测试收货区');
    expect(tester.takeException(), isNull);
    await cleanup();
  });

  testWidgets('详情编辑、状态菜单、跳步与删除确认保留业务语义', (tester) async {
    final database = AppDatabase.forTesting();
    final closeDatabase = _closeDatabaseOnExit(database, tester);
    await tester.runAsync(() => PurchaseDemoDataSeeder.seed(database));
    final pending = await _requestByTitle(database, '【演示】待申报·保洁班日常耗材补充');
    final router = _router();
    final cleanup = await _mount(
      tester,
      database,
      router,
      '/purchase/detail/${pending.id}',
      closeDatabase: closeDatabase,
    );

    final editExecution = find.byKey(
      const Key('purchase-detail-edit-execution'),
    );
    await _ensureVisibleAndHitTestable(
      tester,
      editExecution,
      scrollable: find
          .descendant(
            of: find.byType(PurchaseDetailPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(editExecution);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '11_detail_metadata_sheet');
    expect(find.widgetWithText(BottomSheet, '编辑采购信息'), findsOneWidget);
    final metadataSheet = find.byType(BottomSheet).last;
    Finder metadataField(String label) {
      final textFieldLabels = const {
        '采购事项名称',
        '需求原因',
        'OA流程编号',
        'OA流程标题',
        'OA流程链接',
        '采购分部',
        '采购执行人',
        '领取地点',
        '备注',
      };
      return find.descendant(
        of: metadataSheet,
        matching: textFieldLabels.contains(label)
            ? find.widgetWithText(TextField, label)
            : find.text(label),
      );
    }
    final requestDateField = metadataField('创建日期');
    await _scrollSheetUntilVisible(tester, requestDateField);
    await tester.tap(requestDateField);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '12_metadata_date_picker');
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    final metadataLabels = [
      '采购事项名称',
      '需求原因',
      '创建日期',
      'OA申报日期',
      'OA流程编号',
      'OA流程标题',
      'OA流程链接',
      '分配日期',
      '采购分部',
      '采购执行人',
      '入厂通知日期',
      '领取地点',
      '备注',
    ];
    for (final label in metadataLabels) {
      final field = metadataField(label);
      await _scrollSheetUntilVisible(tester, field);
      expect(field, findsWidgets, reason: '详情编辑字段：$label');
    }
    await tester.tap(find.widgetWithText(FilledButton, '保存信息'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('调整状态'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '12_detail_status_menu');
    expect(find.widgetWithText(PopupMenuItem<String>, '设为采购中'), findsOneWidget);
    expect(find.widgetWithText(PopupMenuItem<String>, '设为已申报'), findsOneWidget);
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '设为已入库'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '13_status_skip_dialog');
    expect(
      find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.textContaining('不会增加库存或创建库存流水'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pumpAndSettle();
    expect(
      (await _request(database, pending.id)).status,
      PurchaseStatus.stocked.storageValue,
    );
    final entries = await database.select(database.purchaseStockEntries).get();
    expect(entries.where((entry) => entry.requestId == pending.id), isEmpty);

    await tester.tap(find.byTooltip('调整状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '删除采购记录'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '14_delete_confirmation');
    expect(
      find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.text('确认将这条未入库采购记录移入回收状态？'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await _request(database, pending.id)).isDeleted, isFalse);
    expect(tester.takeException(), isNull);
    await cleanup();
  });

  testWidgets('入库正常、超量、历史补录和停用物资三种处理均写入数据库', (tester) async {
    final database = AppDatabase.forTesting();
    final closeDatabase = _closeDatabaseOnExit(database, tester);
    await tester.runAsync(() => PurchaseDemoDataSeeder.seed(database));
    final partial = await _requestByTitle(database, '【演示】待领取·防护用品分批到货');
    final stopped = await _requestByTitle(database, '【演示】待领取·原关联物资已停用');
    await PurchaseRepositoryImpl(database).changeStatusManually(
      ManualPurchaseStatusInput(
        requestId: stopped.id,
        targetStatus: PurchaseStatus.purchasing,
        confirmed: true,
        remark: '测试历史补录入库确认分支',
      ),
    );
    final router = _router();

    final partialItem = (await _items(database, partial.id)).first;
    final cleanup = await _mount(
      tester,
      database,
      router,
      '/purchase',
      closeDatabase: closeDatabase,
    );
    router.push('/purchase/stock-in/${partial.id}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('入库日期'));
    await tester.tap(find.text('入库日期'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '19_stockin_date_picker');
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(Key('purchase-stock-quantity-${partialItem.id}')),
      '7',
    );
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('purchase-confirm-stock-in')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '确认超量入库'), findsOneWidget);
    await _captureIfEnabled(tester, '15_excess_stockin_dialog');
    expect(
      find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.textContaining('超出'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect((await _items(database, partial.id)).first.receivedQuantity, 4);
    await tester.tap(find.byKey(const Key('purchase-confirm-stock-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仍然入库'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '16_normal_stockin_confirmation');
    expect(_dialogAction(tester, '确认入库'), findsOneWidget);
    await _tapDialogAction(tester, '确认入库');
    await tester.pumpAndSettle();
    expect((await _items(database, partial.id)).first.receivedQuantity, 11);
    expect(find.byType(PurchaseHomePage), findsOneWidget);
    expect(find.textContaining('入库失败'), findsNothing);

    final stoppedItem = (await _items(database, stopped.id)).single;
    router.push('/purchase/stock-in/${stopped.id}');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, '恢复原物资'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '选择其他物资'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '新建库存物资'), findsOneWidget);
    final restoreOption = find.widgetWithText(ChoiceChip, '恢复原物资');
    await _ensureVisibleAndHitTestable(
      tester,
      restoreOption,
      scrollable: find
          .descendant(
            of: find.byType(PurchaseStockInPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(restoreOption);
    await tester.enterText(
      find.byKey(Key('purchase-stock-quantity-${stoppedItem.id}')),
      '1',
    );
    await tester.tap(find.byKey(const Key('purchase-confirm-stock-in')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '确认历史补录入库'), findsOneWidget);
    await _captureIfEnabled(tester, '17_historical_stockin_confirmation');
    await tester.tap(find.text('确认补录'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '18_historical_stockin_final_confirmation');
    expect(_dialogAction(tester, '确认入库'), findsOneWidget);
    await _tapDialogAction(tester, '确认入库');
    await tester.pumpAndSettle();
    final restored = (await InventoryRepository(database).getMaterials())
        .firstWhere((m) => m.materialCode == 'DEMO-PUR-STOPPED-01');
    expect(restored.status, 'active');
    expect(restored.currentStock, 1);
    expect(
      await database.select(database.purchaseStockEntries).get(),
      isNotEmpty,
    );
    expect(find.byType(PurchaseHomePage), findsOneWidget);
    expect(find.textContaining('入库失败'), findsNothing);
    expect(tester.takeException(), isNull);
    await cleanup();
  });

  testWidgets('历史筛选菜单、物资历史周期和再次申报入口可操作', (tester) async {
    final database = AppDatabase.forTesting();
    final closeDatabase = _closeDatabaseOnExit(database, tester);
    await tester.runAsync(() => PurchaseDemoDataSeeder.seed(database));
    final history = await _requestByTitle(database, '【演示】已入库·应急物资补充');
    final historyItem = (await _items(database, history.id)).first;
    final router = _router();
    final cleanup = await _mount(
      tester,
      database,
      router,
      '/purchase/history?preset=all',
      closeDatabase: closeDatabase,
    );

    for (final label in ['本月', '近3个月', '本年度', '自定义']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    final historyDateMenu = find.byTooltip('更多日期范围');
    await _ensureVisibleAndHitTestable(
      tester,
      historyDateMenu,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(historyDateMenu);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '19_history_date_menu');
    expect(find.widgetWithText(PopupMenuItem<String>, '全部日期'), findsOneWidget);
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '全部日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuButton<String>, '执行人'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '20_history_people_menu');
    expect(find.widgetWithText(PopupMenuItem<String>, '所有执行人'), findsOneWidget);
    expect(find.widgetWithText(PopupMenuItem<String>, '演示采购员丙'), findsOneWidget);
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '所有执行人'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('状态筛选'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '21_history_status_menu');
    expect(find.text('已入库'), findsWidgets);
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '已入库'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('purchase-history-request-${history.id}')),
      findsOneWidget,
    );
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '22_history_custom_date_picker');
    expect(find.widgetWithText(DatePickerDialog, '选择日期'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();

    router.go('/purchase/item-history/${historyItem.inventoryMaterialId}');
    await tester.pumpAndSettle();
    for (final label in ['全部', '近半年', '本年度']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('近半年'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('purchase-repeat-request')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '采购事项名称'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cleanup();
  });

  testWidgets('入库改选现有库存与新建库存分支均更新关联和库存', (tester) async {
    final database = AppDatabase.forTesting();
    final closeDatabase = _closeDatabaseOnExit(database, tester);
    await tester.runAsync(() => PurchaseDemoDataSeeder.seed(database));
    final inventory = InventoryRepository(database);
    final active = (await inventory.getMaterials()).firstWhere(
      (m) => m.materialCode == 'DEMO-PUR-HISTORY-01',
    );
    final selectRequestId = await _createDisabledLinkedRequest(
      database,
      'TEST-SELECT-STOPPED',
    );
    final newRequestId = await _createDisabledLinkedRequest(
      database,
      'TEST-NEW-STOPPED',
    );
    final selectItem = (await _items(database, selectRequestId)).single;
    final newItem = (await _items(database, newRequestId)).single;
    final router = _router();
    final cleanup = await _mount(
      tester,
      database,
      router,
      '/purchase',
      closeDatabase: closeDatabase,
    );
    router.push('/purchase/stock-in/$selectRequestId');
    await tester.pumpAndSettle();

    await tester.tap(find.text('选择其他物资'));
    await tester.pumpAndSettle();
    final inventoryDropdown = find.byType(DropdownButtonFormField<int?>);
    await _ensureVisibleAndHitTestable(
      tester,
      inventoryDropdown,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(inventoryDropdown);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '23_stockin_material_menu');
    await tester.tap(find.textContaining('应急手电筒').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(Key('purchase-stock-quantity-${selectItem.id}')),
      '1',
    );
    await _captureIfEnabled(tester, '26_stockin_select_branch');
    await tester.tap(find.byKey(const Key('purchase-confirm-stock-in')));
    await tester.pumpAndSettle();
    await _tapDialogAction(tester, '确认入库');
    await tester.pumpAndSettle();
    final selectedRequestItem = (await _items(
      database,
      selectRequestId,
    )).single;
    expect(selectedRequestItem.inventoryMaterialId, active.id);
    expect((await _material(database, active.id)).currentStock, greaterThan(0));
    expect(find.byType(PurchaseHomePage), findsOneWidget);
    expect(find.textContaining('入库失败'), findsNothing);

    router.push('/purchase/stock-in/$newRequestId');
    await tester.pumpAndSettle();
    final newMaterialOption = find.widgetWithText(
      ChoiceChip,
      '新建库存物资',
    );
    await _ensureVisibleAndHitTestable(
      tester,
      newMaterialOption,
      scrollable: _mainListScrollable(find.byType(PurchaseStockInPage)),
    );
    await tester.tap(newMaterialOption);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(Key('purchase-stock-quantity-${newItem.id}')),
      '1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '新库存物资编号（选填，自动生成）'),
      'TEST-NEW-PURCHASE-ITEM',
    );
    await _captureIfEnabled(tester, '26_stockin_new_branch');
    await tester.tap(find.byKey(const Key('purchase-confirm-stock-in')));
    await tester.pumpAndSettle();
    await _tapDialogAction(tester, '确认入库');
    await tester.pumpAndSettle();
    final created = (await inventory.getMaterials()).firstWhere(
      (m) => m.materialCode == 'TEST-NEW-PURCHASE-ITEM',
    );
    expect(created.status, 'active');
    expect(created.currentStock, 1);
    expect(
      (await _items(database, newRequestId)).single.inventoryMaterialId,
      created.id,
    );
    expect(find.byType(PurchaseHomePage), findsOneWidget);
    expect(find.textContaining('入库失败'), findsNothing);
    expect(tester.takeException(), isNull);
    await cleanup();
  });

  testWidgets('320窄屏、大字号、键盘遮挡和长文本手动物资仍可录入', (tester) async {
    final database = AppDatabase.forTesting();
    final closeDatabase = _closeDatabaseOnExit(database, tester);
    await tester.runAsync(() => PurchaseDemoDataSeeder.seed(database));
    final pending = await _requestByTitle(database, '【演示】待申报·保洁班日常耗材补充');
    final router = _router();
    final cleanup = await _mount(
      tester,
      database,
      router,
      '/purchase/create',
      width: 320,
      height: 740,
      textScale: 1.5,
      closeDatabase: closeDatabase,
    );
    final manualAdd = find.widgetWithText(OutlinedButton, '手动新增物资');
    await _ensureVisibleAndHitTestable(
      tester,
      manualAdd,
      scrollable: find
          .descendant(
            of: find.byType(PurchaseCreatePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(manualAdd);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '物资名称'),
      '中文长文本演示物资名称用于验证窄屏输入弹窗的自动换行与键盘遮挡行为',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '规格型号（选填）'),
      '中文长规格型号：加厚耐磨复合材料、适用于多种作业环境的标准可替换组件',
    );
    await tester.enterText(find.widgetWithText(TextField, '单位'), '件');
    await tester.enterText(find.widgetWithText(TextField, '申报数量'), '12');
    await _captureIfEnabled(
      tester,
      '27_narrow_large_text_keyboard_long_content',
    );
    final addButton = find.widgetWithText(FilledButton, '添加');
    await tester.ensureVisible(addButton);
    expect(addButton.hitTestable(), findsOneWidget);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    expect(find.text('中文长文本演示物资名称用于验证窄屏输入弹窗的自动换行与键盘遮挡行为'), findsOneWidget);
    router.go('/purchase/detail/${pending.id}');
    await tester.pumpAndSettle();
    final editExecution = find.byKey(
      const Key('purchase-detail-edit-execution'),
    );
    await _ensureVisibleAndHitTestable(
      tester,
      editExecution,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(editExecution);
    await tester.pumpAndSettle();
    final metadataSheet = find.byType(BottomSheet).last;
    final remarkField = find.descendant(
      of: metadataSheet,
      matching: find.widgetWithText(TextField, '备注'),
    );
    await _scrollSheetUntilVisible(
      tester,
      remarkField,
      scrollable: find
          .descendant(
            of: metadataSheet,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(
      remarkField,
      '中文长备注用于核对窄屏、大字号、键盘遮挡时采购信息编辑Sheet的滚动和保存：此内容来自测试数据，不代表真实采购事实。' * 3,
    );
    await _captureIfEnabled(
      tester,
      '28_narrow_large_text_keyboard_long_remark_sheet',
    );
    final saveMetadata = find.widgetWithText(FilledButton, '保存信息');
    await tester.ensureVisible(saveMetadata);
    expect(saveMetadata.hitTestable(), findsOneWidget);
    await tester.tap(saveMetadata);
    await tester.pumpAndSettle();
    expect((await _request(database, pending.id)).remark, contains('中文长备注'));
    expect(tester.takeException(), isNull);
    await cleanup();
  });

  testWidgets('采购提醒新建和修改使用真实路由并能正常返回', (tester) async {
    final database = AppDatabase.forTesting();
    final closeDatabase = _closeDatabaseOnExit(database, tester);
    await tester.runAsync(() => PurchaseDemoDataSeeder.seed(database));
    final receive = await _requestByTitle(database, '【演示】待领取·防护用品分批到货');
    final newReminderRequest = await _requestByTitle(
      database,
      '【演示】待领取·原关联物资已停用',
    );
    final router = appRouter;
    final cleanup = await _mount(
      tester,
      database,
      router,
      '/purchase',
      closeDatabase: closeDatabase,
    );

    final createReminderButton = find.byKey(
      Key('purchase-home-reminder-${newReminderRequest.id}'),
    );
    await _ensureVisibleAndHitTestable(
      tester,
      createReminderButton,
      scrollable: find
          .descendant(
            of: find.byType(PurchaseHomePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(createReminderButton);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '24_reminder_create_form');
    expect(find.byType(ReminderFormPage), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('reminder-title-field')))
          .controller!
          .text,
      '领取采购物资',
    );
    expect(tester.takeException(), isNull);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(PurchaseHomePage), findsOneWidget);

    final editReminderButton = find.byKey(
      Key('purchase-home-reminder-${receive.id}'),
    );
    await _ensureVisibleAndHitTestable(
      tester,
      editReminderButton,
      scrollable: find
          .descendant(
            of: find.byType(PurchaseHomePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(editReminderButton);
    await tester.pumpAndSettle();
    await _captureIfEnabled(tester, '25_reminder_edit_form');
    expect(find.byType(ReminderFormPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, '编辑提醒'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(PurchaseHomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await cleanup();
  });
}

GoRouter _router({PurchaseItemPrefill? createItem}) => GoRouter(
  initialLocation: '/purchase',
  routes: [
    GoRoute(path: '/purchase', builder: (_, _) => const PurchaseHomePage()),
    GoRoute(
      path: '/purchase/create',
      builder: (_, _) => PurchaseCreatePage(initialItem: createItem),
    ),
    GoRoute(
      path: '/purchase/pending-apply',
      builder: (_, _) => const PurchasePendingApplyPage(),
    ),
    GoRoute(
      path: '/purchase/tracking',
      builder: (_, state) => PurchaseTrackingPage(
        showAll: state.uri.queryParameters['all'] == '1',
      ),
    ),
    GoRoute(
      path: '/purchase/pending-receive',
      builder: (_, _) => const PurchasePendingReceivePage(),
    ),
    GoRoute(
      path: '/purchase/history',
      builder: (_, state) => PurchaseHistoryPage(
        initialPreset: state.uri.queryParameters['preset'],
      ),
    ),
    GoRoute(
      path: '/purchase/item-history/:id',
      builder: (_, state) => PurchaseItemHistoryPage(
        inventoryMaterialId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/purchase/detail/:id',
      builder: (_, state) =>
          PurchaseDetailPage(requestId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/purchase/stock-in/:id',
      builder: (_, state) => PurchaseStockInPage(
        requestId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/settings/reminders/new',
      builder: (_, state) => ReminderFormPage(
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
      builder: (_, state) =>
          ReminderFormPage(reminderId: int.parse(state.pathParameters['id']!)),
    ),
  ],
);

Future<Future<void> Function()> _mount(
  WidgetTester tester,
  AppDatabase database,
  GoRouter router,
  String location, {
  double width = 390,
  double height = 844,
  double textScale = 1,
  required Future<void> Function() closeDatabase,
}) async {
  var cleaned = false;
  Future<void> cleanup() async {
    if (cleaned) return;
    cleaned = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await closeDatabase();
    tester.view.resetViewInsets();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
  addTearDown(cleanup);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: RepaintBoundary(
        key: const Key('purchase-audit-capture-boundary'),
        child: MaterialApp.router(
          routerConfig: router,
          theme: _acceptanceTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.go(location);
  await tester.pumpAndSettle();
  return cleanup;
}

ThemeData _acceptanceTheme() {
  final base = AppTheme.light;
  final family = _auditFontFamily;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: family),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: family,
      ),
      toolbarTextStyle: base.appBarTheme.toolbarTextStyle?.copyWith(
        fontFamily: family,
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: base.inputDecorationTheme.labelStyle?.copyWith(
        fontFamily: family,
      ),
      floatingLabelStyle: base.inputDecorationTheme.floatingLabelStyle
          ?.copyWith(fontFamily: family),
    ),
  );
}

Future<void> _captureIfEnabled(WidgetTester tester, String name) async {
  if (!_capturePurchaseUi) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('purchase-audit-capture-boundary')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return;
    final directory = Directory(
      '${Directory.current.path}${Platform.pathSeparator}docs${Platform.pathSeparator}acceptance${Platform.pathSeparator}ui-reference-audit${Platform.pathSeparator}purchase-20261002',
    )..createSync(recursive: true);
    final bytes = Uint8List.view(
      data.buffer,
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File('${directory.path}${Platform.pathSeparator}audit-$name.png')
        .writeAsBytes(bytes);
  });
}

Future<void> Function() _closeDatabaseOnExit(
  AppDatabase database,
  WidgetTester tester,
) {
  var closed = false;
  Future<void> closeDatabase() async {
    if (closed) return;
    closed = true;
    await tester.runAsync(database.close);
  }
  addTearDown(closeDatabase);
  return closeDatabase;
}

Future<void> _tapSheet(WidgetTester tester, String label) async {
  final button = find.descendant(
    of: find.byType(BottomSheet).last,
    matching: find.widgetWithText(FilledButton, label),
  );
  expect(button, findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Finder _mainListScrollable(Finder page) {
  final list = find.descendant(of: page, matching: find.byType(ListView)).first;
  return find.descendant(of: list, matching: find.byType(Scrollable)).first;
}

Future<void> _ensureVisibleAndHitTestable(
  WidgetTester tester,
  Finder finder, {
  required Finder scrollable,
  double delta = 220,
  double alignment = 0.5,
}) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, delta, scrollable: scrollable);
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: alignment);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
}

Future<void> _tapDialogAction(WidgetTester tester, String label) async {
  expect(find.byType(AlertDialog), findsWidgets);
  final action = _dialogAction(tester, label);
  expect(action, findsOneWidget, reason: '确认对话框按钮：$label');
  await tester.tap(action);
}

Finder _dialogAction(WidgetTester tester, String label) {
  expect(find.byType(AlertDialog), findsWidgets);
  final dialog = find.byType(AlertDialog).last;
  return find.descendant(
    of: dialog,
    matching: find.widgetWithText(FilledButton, label),
  );
}

Future<void> _scrollSheetUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
}) async {
  final targetScrollable = scrollable ?? find.byType(Scrollable).last;
  final state = tester.state<ScrollableState>(targetScrollable);
  state.position.jumpTo(state.position.minScrollExtent);
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: targetScrollable,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsWidgets);
}

Future<dynamic> _requestByTitle(AppDatabase database, String title) =>
    (database.select(
      database.purchaseRequests,
    )..where((row) => row.title.equals(title))).getSingle();

Future<dynamic> _request(AppDatabase database, int id) => (database.select(
  database.purchaseRequests,
)..where((row) => row.id.equals(id))).getSingle();

Future<List<dynamic>> _items(AppDatabase database, int id) => (database.select(
  database.purchaseRequestItems,
)..where((row) => row.requestId.equals(id))).get();

Future<dynamic> _material(AppDatabase database, int id) => (database.select(
  database.inventoryMaterials,
)..where((row) => row.id.equals(id))).getSingle();

Future<int> _createDisabledLinkedRequest(
  AppDatabase database,
  String code,
) async {
  final inventory = InventoryRepository(database);
  final materialId = await inventory.createMaterial(
    InventoryMaterialDraft(
      materialCode: code,
      materialName: '测试停用物资 $code',
      modelSpec: '中文规格型号',
      unitName: '个',
      status: 'stopped',
    ),
  );
  final purchases = PurchaseRepositoryImpl(database);
  final requestId = await purchases.createPurchaseRequest(
    CreatePurchaseRequestInput(
      title: '测试入库处理 $code',
      requestDate: DateTime(2026, 10, 1),
      demandReason: '库存不足',
      items: [
        PurchaseItemDraft(
          inventoryMaterialId: materialId,
          itemName: '测试停用物资 $code',
          specification: '中文规格型号',
          unit: '个',
          currentStockSnapshot: 0,
          requestQuantity: 2,
        ),
      ],
    ),
  );
  await purchases.confirmApplied(
    requestId,
    ConfirmAppliedInput(appliedDate: DateTime(2026, 10, 1)),
  );
  await purchases.assignPurchaser(
    requestId,
    AssignPurchaserInput(
      purchaserName: '测试执行人',
      assignedDate: DateTime(2026, 10, 1),
    ),
  );
  await purchases.markPendingReceive(
    requestId,
    PendingReceiveInput(arrivalNoticeDate: DateTime(2026, 10, 1)),
  );
  return requestId;
}

Future<int> _createPendingApplyRequest(AppDatabase database) async {
  final id = await PurchaseRepositoryImpl(database).createPurchaseRequest(
    CreatePurchaseRequestInput(
      title: '【测试】详情入口 OA 确认',
      requestDate: DateTime(2026, 10, 1),
      demandReason: '库存不足',
      items: [
        PurchaseItemDraft(
          itemName: '中文演示物资',
          specification: '标准规格',
          unit: '个',
          currentStockSnapshot: 0,
          requestQuantity: 2,
        ),
      ],
    ),
  );
  return id;
}
