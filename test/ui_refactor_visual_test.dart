import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/widgets/design_canvas.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/core/database/demo_data_seeder.dart';
import 'package:qingsongban/core/database/inventory_demo_data_seeder.dart';
import 'package:qingsongban/core/database/purchase_demo_data_seeder.dart';
import 'package:qingsongban/core/database/vehicle_demo_data_seeder.dart';
import 'package:qingsongban/features/reports/data/monthly_summary_repository.dart';
import 'package:qingsongban/features/item_distribution/data/item_distribution_repository.dart';
import 'package:qingsongban/features/item_distribution/domain/item_distribution_models.dart';
import 'package:qingsongban/features/attachments/application/attachment_providers.dart';
import 'package:qingsongban/features/attachments/data/attachment_repository.dart';
import 'package:qingsongban/features/vehicles/application/vehicle_providers.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_attachment_repository.dart';

const _capture = bool.fromEnvironment('UI_REFACTOR_CAPTURE');
const _routeFilter = String.fromEnvironment('UI_ROUTE_FILTER');
const _captureDirectory = String.fromEnvironment(
  'UI_CAPTURE_DIR',
  defaultValue: 'docs/acceptance/ui-refactor-20261008/screenshots',
);
const _boundary = Key('ui-refactor-capture');
String? _font;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final chinese = File(r'C:\Windows\Fonts\msyh.ttc');
    if (chinese.existsSync()) {
      final loader = FontLoader('ReferenceChinese')
        ..addFont(
          Future.value(ByteData.sublistView(await chinese.readAsBytes())),
        );
      await loader.load();
      final fallback = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(await chinese.readAsBytes())),
        );
      await fallback.load();
      _font = 'ReferenceChinese';
    }
    final icons = File(
      r'D:\Flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
      await loader.load();
    }
  });

  // GT7 panel ratio at a simulated 480dpi; actual device density is not yet measured.
  for (final size in [(1280 / 3, 1.0), (1080 / 3, 1.0), (320.0, 1.3)]) {
    testWidgets('reference routes remain usable at ${size.$1}dp, font ${size.$2}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      final gt7 = size.$1 > 400;
      final phoneProfile = size.$1 >= 360;
      tester.view.physicalSize = Size(
        size.$1,
        gt7 ? 2800 / 3 : (phoneProfile ? 2362 / 3 : 844),
      );
      if (phoneProfile) {
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      }
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        tester.view.resetPadding();
      });
      final db = AppDatabase.forTesting();
      Directory? attachmentRoot;
      late AttachmentRepository attachments;
      late VehicleAttachmentRepository vehicleAttachments;
      late int employeeId,
          materialId,
          vehicleId,
          requestId,
          receiptId,
          issueId,
          payrollItemId,
          payrollBatchId,
          payrollDraftId,
          payrollDraftItemId,
          payrollLockedId,
          payrollLockedItemId;
      try {
        // Fixtures are restricted to this disposable in-memory test database.
        await tester.runAsync(() async {
          await DemoDataSeeder.seed(db);
          await InventoryDemoDataSeeder.seed(db);
          await PurchaseDemoDataSeeder.seed(db);
          await VehicleDemoDataSeeder.seed(db);
          employeeId = (await db.select(db.employees).get()).first.id;
          materialId = (await db.select(db.inventoryMaterials).get()).first.id;
          vehicleId = (await db.select(db.vehicles).get()).first.id;
          attachmentRoot = await Directory.systemTemp.createTemp(
            'qsb-ui-attachments-',
          );
          attachments = AttachmentRepository(
            db,
            documentsDirectory: () async => attachmentRoot!,
          );
          vehicleAttachments = VehicleAttachmentRepository(
            db,
            documentsDirectory: () async => attachmentRoot!,
          );
          requestId = (await db.select(db.purchaseRequests).get())
              .firstWhere((row) => row.status == 'pending_receive')
              .id;
          receiptId = (await db.select(db.inventoryReceipts).get()).first.id;
          issueId = (await db.select(db.inventoryIssues).get()).first.id;
          payrollItemId = (await db.select(db.payrollItems).get()).first.id;
          payrollBatchId = (await db.select(db.payrollBatches).get()).first.id;
          payrollDraftId = (await db.select(db.payrollBatches).get())
              .firstWhere((batch) => batch.status == PayrollStatus.draft)
              .id;
          payrollDraftItemId = (await db.select(db.payrollItems).get())
              .firstWhere((item) => item.payrollBatchId == payrollDraftId)
              .id;
          final now = DateTime.now();
          // Prepare the locked UI fixture before any provider streams mount.
          // Repository tests separately cover the actual confirmation/lock transition.
          final confirmed = (await db.select(db.payrollBatches).get())
              .firstWhere((batch) => batch.id == payrollBatchId);
          final lockedMonth = DateTime(now.year, now.month - 2);
          payrollLockedId = await db
              .into(db.payrollBatches)
              .insert(
                confirmed
                    .toCompanion(true)
                    .copyWith(
                      id: const Value.absent(),
                      payrollMonth: Value(
                        '${lockedMonth.year}-${lockedMonth.month.toString().padLeft(2, '0')}',
                      ),
                      name: const Value('已锁定工资测试批次'),
                      status: const Value(PayrollStatus.locked),
                      lockedAt: Value(now),
                    ),
              );
          for (final item in (await db.select(db.payrollItems).get()).where(
            (item) => item.payrollBatchId == payrollBatchId,
          )) {
            final id = await db
                .into(db.payrollItems)
                .insert(
                  item
                      .toCompanion(true)
                      .copyWith(
                        id: const Value.absent(),
                        payrollBatchId: Value(payrollLockedId),
                      ),
                );
            if (item.id == payrollItemId) payrollLockedItemId = id;
          }
          final previousMonth = DateTime(now.year, now.month - 1);
          final distributionMonth =
              '${previousMonth.year}-${previousMonth.month.toString().padLeft(2, '0')}';
          final distribution = ItemDistributionRepository(db);
          for (final category in [
            DistributionCategory.office,
            DistributionCategory.tool,
          ]) {
            await distribution.addManualDistribution(
              ManualDistributionDraft(
                category: category,
                month: distributionMonth,
                recipientName: '测试领用员',
                recipientType: 'custom',
                recipientKey: 'custom:测试领用员',
                itemName: category == DistributionCategory.office
                    ? '签字笔'
                    : '修枝剪',
                quantity: 2,
                unit: '把',
              ),
            );
          }
          // Existing project art exercises decoding and zoom without personal data.
          final source = File('assets/vehicles/water-truck.png');
          await attachments.importFile(
            employeeId: employeeId,
            sourceFile: source,
            originalFileName: '敏感信息测试.png',
            category: 'bankCard',
          );
          final removed = await attachments.importFile(
            employeeId: employeeId,
            sourceFile: source,
            originalFileName: '已删除资料测试.png',
            category: 'other',
          );
          await attachments.softDelete(removed);
          await vehicleAttachments.importFile(
            vehicleId: vehicleId,
            sourceFile: source,
            originalFileName: '车辆照片测试.png',
            category: 'vehiclePhoto',
          );
          final removedVehicle = await vehicleAttachments.importFile(
            vehicleId: vehicleId,
            sourceFile: source,
            originalFileName: '已删除车辆资料测试.png',
            category: 'vehiclePhoto',
          );
          await vehicleAttachments.softDelete(removedVehicle);
          await MonthlySummaryRepository(db).generate(
            yearMonth: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          );
        });
        final base = AppTheme.light;
        final theme = _font == null ? base : _referenceTheme(base, _font!);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              attachmentRepositoryProvider.overrideWithValue(attachments),
              vehicleAttachmentRepositoryProvider.overrideWithValue(
                vehicleAttachments,
              ),
            ],
            child: RepaintBoundary(
              key: _boundary,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: theme,
                locale: const Locale('zh', 'CN'),
                supportedLocales: const [Locale('zh', 'CN')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(size.$2)),
                  child: DesignCanvas(child: child!),
                ),
                routerConfig: appRouter,
              ),
            ),
          ),
        );
        final routes = <(String, String)>[
          ('home', '/home'),
          ('personnel', '/personnel'),
          ('people_list', '/personnel/list'),
          ('person_form', '/personnel/new'),
          ('attendance', '/attendance'),
          ('daily_attendance', '/attendance/daily'),
          ('reports', '/reports'),
          ('settings', '/settings'),
          ('inventory', '/inventory'),
          ('materials', '/inventory/materials'),
          ('stock', '/inventory/stock'),
          ('receipt_form', '/inventory/receipts/new'),
          ('issue_form', '/inventory/issues/new'),
          ('stocktake_form', '/inventory/stocktake/new'),
          ('purchase', '/purchase'),
          ('purchase_form', '/purchase/create'),
          ('vehicles', '/vehicles'),
          ('vehicle_archive', '/vehicles/archive'),
          ('vehicle_form', '/vehicles/new'),
          ('vehicle_repairs', '/vehicles/repairs'),
          ('fuel_summary', '/vehicles/fuel-summary'),
          ('garden_repairs', '/garden-tool-repairs'),
          ('garden_form', '/garden-tool-repairs/new'),
          ('leave', '/attendance/leave'),
          ('overtime', '/attendance/overtime'),
          ('termination', '/attendance/termination'),
          ('insurance', '/settings/insurance'),
          ('payroll', '/reports/payroll'),
          ('reminders', '/settings/reminders'),
          ('reminder_form', '/settings/reminders/new'),
          ('excel', '/settings/excel'),
          ('backup', '/settings/backup'),
          ('logs', '/settings/operation-logs'),
        ];
        routes.addAll([
          ('person_detail', '/personnel/$employeeId'),
          ('attachments', '/personnel/$employeeId/attachments'),
          ('person_edit', '/personnel/$employeeId/edit'),
          ('attendance_groups', '/attendance/groups'),
          ('group_form', '/attendance/groups/new'),
          ('monthly_roster', '/attendance/monthly-roster'),
          ('monthly_table', '/attendance/monthly-table'),
          ('leave_form', '/attendance/leave/new'),
          ('overtime_form', '/attendance/overtime/new'),
          ('termination_form', '/attendance/termination/new'),
          ('material_form', '/inventory/materials/new'),
          ('material_detail', '/inventory/materials/$materialId'),
          ('receipt_list', '/inventory/receipts'),
          ('receipt_detail', '/inventory/receipts/$receiptId'),
          ('issue_list', '/inventory/issues'),
          ('issue_detail', '/inventory/issues/$issueId'),
          ('stocktake_list', '/inventory/stocktake'),
          ('warnings', '/inventory/warnings'),
          ('replenishment', '/inventory/replenishment'),
          ('transactions', '/inventory/transactions'),
          ('purchase_pending', '/purchase/pending-apply'),
          ('purchase_tracking', '/purchase/tracking'),
          ('purchase_receive', '/purchase/pending-receive'),
          ('purchase_history', '/purchase/history'),
          ('purchase_detail', '/purchase/detail/$requestId'),
          ('purchase_stock_in', '/purchase/stock-in/$requestId'),
          ('vehicle_detail', '/vehicles/$vehicleId'),
          ('vehicle_repair_form', '/vehicles/$vehicleId/repair/new'),
          ('vehicle_attachments', '/vehicles/$vehicleId/attachments'),
          ('vehicle_reminders', '/vehicles/reminders'),
          ('garden_analysis', '/garden-tool-repairs/analysis'),
          ('garden_prices', '/garden-tool-repairs/prices'),
          ('garden_units', '/garden-tool-repairs/units'),
          ('payroll_editor', '/reports/payroll/edit/$payrollBatchId'),
          ('payroll_draft', '/reports/payroll/edit/$payrollDraftId'),
          ('payroll_locked', '/reports/payroll/edit/$payrollLockedId'),
          ('payroll_history', '/reports/payroll/history'),
          ('payroll_detail', '/reports/payroll/item/$payrollItemId'),
          ('payroll_export', '/reports/payroll/export/$payrollBatchId'),
          ('item_distribution', '/items'),
        ]);
        final failures = <String>[];
        final originalErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          originalErrorHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalErrorHandler);
        void recordException(String route) {
          final error = tester.takeException();
          if (error != null) failures.add("$route: $error");
        }

        for (final route in routes) {
          if (_routeFilter.isNotEmpty &&
              !_routeFilter.split(',').contains(route.$1)) {
            continue;
          }
          appRouter.go(route.$2);
          await _settle(tester);
          recordException(route.$2);
          if (route.$1 == 'home' && size.$1 == 390) {
            expect(
              tester.getTopLeft(find.byKey(const Key('home-metric-今日请假'))).dy,
              tester.getTopLeft(find.byKey(const Key('home-metric-当前在岗'))).dy,
              reason:
                  'The reference keeps the four personnel metrics on one row.',
            );
          }
          expect(
            find.textContaining('GoException'),
            findsNothing,
            reason: route.$2,
          );
          await _snapshot(tester, '${route.$1}_${size.$1.toInt()}_${size.$2}');
          if (route.$1 == 'inventory') {
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -460),
            );
            await _settle(tester);
            recordException('/inventory/下半区');
            await _snapshot(
              tester,
              'inventory_lower_${size.$1.toInt()}_${size.$2}',
            );
          }
          if (route.$1 == 'payroll_editor') {
            await tester.tap(find.byType(PopupMenuButton<String>).first);
            await _settle(tester);
            recordException('/payroll/菜单');
            await _snapshot(
              tester,
              'payroll_menu_${size.$1.toInt()}_${size.$2}',
            );
            final revoke = find.text('撤销确认 / 解锁');
            if (revoke.evaluate().isNotEmpty) {
              await tester.tap(revoke);
              await _settle(tester);
              expect(find.text('原因'), findsOneWidget);
              await tester.enterText(
                find.byType(TextField).last,
                '核对人员出勤后重新确认',
              );
              tester.view.viewInsets = const FakeViewPadding(bottom: 280);
              await _settle(tester);
              recordException('/payroll/解锁原因/键盘');
              await _snapshot(
                tester,
                'payroll_reason_keyboard_${size.$1.toInt()}_${size.$2}',
              );
              await tester.tap(find.text('取消').last);
              tester.view.resetViewInsets();
              FocusManager.instance.primaryFocus?.unfocus();
              await _settle(tester);
            } else {
              await tester.tapAt(const Offset(12, 400));
              await _settle(tester);
            }
          }
          if (route.$1 == 'payroll_export') {
            await tester.tap(find.byKey(const Key('payroll-preview-button')));
            await _settle(tester);
            expect(find.text('工资表预览'), findsOneWidget);
            recordException('/payroll/表格预览');
            await _snapshot(
              tester,
              'payroll_table_preview_${size.$1.toInt()}_${size.$2}',
            );
          }
          if (route.$1 == 'payroll_draft' || route.$1 == 'payroll_locked') {
            final draft = route.$1 == 'payroll_draft';
            expect(find.text('人工增加人员'), draft ? findsOneWidget : findsNothing);
            await tester.tap(find.byType(PopupMenuButton<String>).first);
            await _settle(tester);
            expect(find.text('删除工资草稿'), draft ? findsOneWidget : findsNothing);
            expect(
              find.text('撤销确认 / 解锁'),
              draft ? findsNothing : findsOneWidget,
            );
            await _snapshot(
              tester,
              '${route.$1}_menu_${size.$1.toInt()}_${size.$2}',
            );
            if (draft) {
              await tester.tap(find.text('删除工资草稿'));
              await _settle(tester);
              expect(find.text('删除工资草稿？'), findsOneWidget);
              await _snapshot(
                tester,
                'payroll_delete_confirm_${size.$1.toInt()}_${size.$2}',
              );
              await tester.tap(find.text('取消').last);
            } else {
              await tester.tapAt(const Offset(4, 400));
            }
            await _settle(tester);
            expect(
              find.byType(ReorderableListView),
              draft ? findsOneWidget : findsNothing,
            );
            final card = find.byKey(
              ValueKey(draft ? payrollDraftItemId : payrollLockedItemId),
            );
            await tester.tap(
              find.descendant(of: card, matching: find.byType(InkWell)).first,
            );
            await _settle(tester);
            if (draft) {
              final money = find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is TextField &&
                        widget.decoration?.suffixText == '元',
                  )
                  .first;
              await tester.enterText(money, '-1');
              await _settle(tester);
              final save = find.widgetWithText(FilledButton, '保存');
              expect(tester.widget<FilledButton>(save).onPressed, isNull);
              tester.view.viewInsets = const FakeViewPadding(bottom: 280);
              await _settle(tester);
              await tester.ensureVisible(money);
              await _snapshot(
                tester,
                'payroll_invalid_amount_${size.$1.toInt()}_${size.$2}',
              );
              await tester.enterText(money, '200');
              await _settle(tester);
              expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
              await tester.tap(find.text('取消').last);
              tester.view.resetViewInsets();
              FocusManager.instance.primaryFocus?.unfocus();
              await _settle(tester);
            } else {
              expect(find.textContaining('工资明细'), findsOneWidget);
              expect(find.byType(TextField), findsNothing);
              await _snapshot(
                tester,
                'payroll_locked_detail_${size.$1.toInt()}_${size.$2}',
              );
            }
            recordException('${route.$2}/${route.$1}');
          }
          if (route.$1 == 'item_distribution') {
            for (final tab in ['办公用品', '工具']) {
              await tester.tap(find.text(tab).first);
              await _settle(tester);
              recordException('/items/$tab');
              await _snapshot(
                tester,
                'distribution_${tab}_${size.$1.toInt()}_${size.$2}',
              );
            }
          }
          if (route.$1 == 'attachments') {
            await tester.tap(find.text('敏感信息测试.png'));
            await _settle(tester);
            expect(find.text('查看敏感附件'), findsOneWidget);
            recordException('/attachments/敏感确认');
            await _snapshot(
              tester,
              'attachment_sensitive_${size.$1.toInt()}_${size.$2}',
            );
            await tester.tap(find.text('取消').last);
            await _settle(tester);
            await tester.tap(find.text('敏感信息测试.png'));
            await _settle(tester);
            await tester.tap(find.text('显示原图'));
            await _settle(tester);
            expect(find.byType(InteractiveViewer), findsOneWidget);
            await _settleImage(tester);
            recordException('/attachments/原图');
            await _snapshot(
              tester,
              'attachment_image_preview_${size.$1.toInt()}_${size.$2}',
            );
            await tester.tapAt(const Offset(4, 4));
            await _settle(tester);
          }
          if (route.$1 == 'vehicle_attachments') {
            await tester.tap(find.text('车辆照片测试.png'));
            await _settleUntil(tester, find.byType(InteractiveViewer));
            expect(find.byType(InteractiveViewer), findsOneWidget);
            await _settleImage(tester);
            recordException('/vehicles/attachment/原图');
            await _snapshot(
              tester,
              'vehicle_image_preview_${size.$1.toInt()}_${size.$2}',
            );
            await tester.tapAt(const Offset(4, 4));
            await _settle(tester);
          }
          if (route.$1 == 'attachments' || route.$1 == 'vehicle_attachments') {
            await tester.tap(
              route.$1 == 'attachments'
                  ? find.byType(Switch).first
                  : find.byType(SwitchListTile).first,
            );
            await _settle(tester);
            final deletedName = route.$1 == 'attachments'
                ? '已删除资料测试.png'
                : '已删除车辆资料测试.png';
            await tester.ensureVisible(find.text(deletedName));
            recordException('${route.$2}/已删除');
            await _snapshot(
              tester,
              '${route.$1}_deleted_${size.$1.toInt()}_${size.$2}',
            );
            expect(find.text(deletedName), findsOneWidget);
            final deletedCard = find.ancestor(
              of: find.text(deletedName),
              matching: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_AttachmentCard',
              ),
            );
            final menu = find.descendant(
              of: deletedCard,
              matching: find.byType(PopupMenuButton<String>),
            );
            await tester.tap(menu);
            await _settle(tester);
            expect(find.text('恢复'), findsOneWidget);
            expect(find.text('删除'), findsNothing);
            await _snapshot(
              tester,
              '${route.$1}_restore_menu_${size.$1.toInt()}_${size.$2}',
            );
            await tester.tap(find.text('恢复'));
            await _settle(tester);
            await tester.runAsync(() async {
              final restored = route.$1 == 'attachments'
                  ? (await attachments.listForEmployee(employeeId))
                        .map((item) => item.originalFileName)
                  : (await vehicleAttachments.listForVehicle(vehicleId))
                        .map((item) => item.originalFileName);
              expect(restored, contains(deletedName));
            });
            await tester.tap(menu);
            await _settle(tester);
            expect(find.text('查看'), findsOneWidget);
            expect(find.text('删除'), findsOneWidget);
            await _snapshot(
              tester,
              '${route.$1}_normal_menu_${size.$1.toInt()}_${size.$2}',
            );
            await tester.tap(find.text('删除'));
            await _settle(tester);
            await tester.runAsync(() async {
              final active = route.$1 == 'attachments'
                  ? (await attachments.listForEmployee(employeeId))
                        .map((item) => item.originalFileName)
                  : (await vehicleAttachments.listForVehicle(vehicleId))
                        .map((item) => item.originalFileName);
              expect(active, isNot(contains(deletedName)));
            });
            recordException('${route.$2}/恢复及删除');
          }
          if (route.$1 == 'reminder_form') {
            await tester.enterText(
              find.byKey(const Key('reminder-title-field')),
              '现场巡检',
            );
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.tap(find.text('更多设置'));
            await _settle(tester);
            final detail = find.byKey(const Key('reminder-detail-field'));
            await tester.ensureVisible(detail);
            await tester.enterText(detail, '检查现场设备，联系班组负责人确认准备材料。');
            // Simulate the keyboard inset to verify scroll and footer visibility.
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            await _settle(tester);
            await tester.ensureVisible(detail);
            recordException('/reminders/展开/键盘');
            await _snapshot(
              tester,
              'reminder_expanded_keyboard_${size.$1.toInt()}_${size.$2}',
            );
            tester.view.resetViewInsets();
            FocusManager.instance.primaryFocus?.unfocus();
            await _settle(tester);
            final people = find.byKey(const Key('reminder-employees'));
            await tester.ensureVisible(people);
            await tester.tap(people);
            await _settle(tester);
            expect(find.byType(CheckboxListTile), findsWidgets);
            await tester.tap(find.byType(CheckboxListTile).first);
            await _settle(tester);
            recordException('/reminders/人员选择');
            await _snapshot(
              tester,
              'reminder_employee_picker_${size.$1.toInt()}_${size.$2}',
            );
            await tester.tap(find.text('完成').last);
            await _settle(tester);
            expect(find.text('已选择 1 人'), findsOneWidget);
            await _snapshot(
              tester,
              'reminder_expanded_${size.$1.toInt()}_${size.$2}',
            );
            Future<void> openReminderSetting(String key) async {
              final setting = find.byKey(Key(key));
              await tester.ensureVisible(setting);
              await tester.tap(setting);
              await _settle(tester);
            }

            Future<void> captureReminderSetting(String state) async {
              recordException('/reminders/$state');
              await _snapshot(
                tester,
                'reminder_${state}_${size.$1.toInt()}_${size.$2}',
              );
            }

            await openReminderSetting('reminder-custom-time');
            await captureReminderSetting('schedule');
            await openReminderSetting('reminder-year-month-wheel');
            expect(find.byType(CupertinoPicker), findsNWidgets(3));
            await captureReminderSetting('date_picker');
            await tester.tap(find.text('取消').last);
            await _settle(tester);
            await openReminderSetting('reminder-schedule-time');
            expect(find.byType(CupertinoPicker), findsNWidgets(2));
            await captureReminderSetting('time_picker');
            await tester.tap(find.text('确定').last);
            await _settle(tester);
            await openReminderSetting('reminder-schedule-repeat');
            await captureReminderSetting('repeat_presets');
            await openReminderSetting('reminder-repeat-custom');
            await captureReminderSetting('repeat_weekly');
            await openReminderSetting('reminder-repeat-frequency');
            await captureReminderSetting('frequency_picker');
            await tester.drag(
              find.byType(CupertinoPicker).last,
              const Offset(0, -48),
            );
            await _settle(tester);
            await tester.tap(find.text('确定').last);
            await _settle(tester);
            expect(find.text('选择提醒日期（可多选）'), findsOneWidget);
            await tester.ensureVisible(find.text('31'));
            await tester.tap(find.text('31'));
            await _settle(tester);
            await captureReminderSetting('repeat_monthly');
            await openReminderSetting('reminder-repeat-end');
            await captureReminderSetting('repeat_end_choices');
            await tester.tap(find.text('按次数'));
            await _settle(tester);
            expect(find.text('重复次数'), findsOneWidget);
            await captureReminderSetting('repeat_count_picker');
            await tester.tap(find.text('确定').last);
            await _settle(tester);
            expect(find.text('重复 10 次'), findsOneWidget);
            await openReminderSetting('reminder-repeat-end');
            await tester.tap(find.text('按日期'));
            await _settle(tester);
            expect(find.byType(DatePickerDialog), findsOneWidget);
            await captureReminderSetting('repeat_end_date');
            await tester.tap(find.text('取消').last);
            await _settle(tester);
            await tester.tap(find.text('完成').last);
            await _settle(tester);
            await openReminderSetting('reminder-schedule-alerts');
            await captureReminderSetting('alerts');
            await openReminderSetting('reminder-alert-custom');
            await captureReminderSetting('custom_alert_picker');
            await tester.tap(find.text('确定').last);
            await _settle(tester);
            expect(find.text('1 分钟前'), findsOneWidget);
            await captureReminderSetting('custom_alert_selected');
            await tester.tap(find.text('完成').last);
            await _settle(tester);
            await tester.tap(find.byKey(const Key('reminder-schedule-done')));
            await _settle(tester);
            expect(find.textContaining('每月'), findsWidgets);
            expect(find.textContaining('1 分钟前'), findsWidgets);
            await captureReminderSetting('configured_form');
          }
          if (route.$1 == 'reports') {
            for (final tab in ['车辆', '库存', '工资']) {
              await tester.tap(find.text(tab).first);
              await _settle(tester);
              recordException('汇总/$tab');
              await _snapshot(
                tester,
                'reports_${tab}_${size.$1.toInt()}_${size.$2}',
              );
            }
          }
          if (route.$1 == 'home') {
            expect(find.byType(NavigationDestination), findsNWidgets(4));
            await tester.tap(find.text('处理'));
            await _settle(tester);
            recordException('/home/处理');
            await _snapshot(
              tester,
              'home_processing_${size.$1.toInt()}_${size.$2}',
            );
          }
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.idle();
        await tester.pump(const Duration(milliseconds: 1));
        await _settle(tester);
        await tester.runAsync(() => db.close());
        await tester.runAsync(() async {
          if (attachmentRoot != null) {
            await attachmentRoot!.delete(recursive: true);
          }
        });
        await tester.idle();
        await tester.pump(const Duration(milliseconds: 1));
      }
    });
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await _settle(tester);
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

Future<void> _settleImage(WidgetTester tester) async {
  final image = find.descendant(
    of: find.byType(InteractiveViewer),
    matching: find.byType(RawImage),
  );
  await _settleUntil(tester, image);
  for (var attempt = 0; attempt < 20; attempt++) {
    await _settle(tester);
    if (tester.widget<RawImage>(image).image != null) return;
  }
  expect(tester.widget<RawImage>(image).image, isNotNull);
}

Future<void> _snapshot(WidgetTester tester, String name) async {
  // Narrow large-font checks are diagnostic, not phone effect previews.
  if (!_capture || tester.view.physicalSize.width < 360) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundary),
    );
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('Unable to render $name');
    final directory = Directory(_captureDirectory)..createSync(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  });
}

ThemeData _referenceTheme(ThemeData base, String font) {
  ButtonStyle? buttonFont(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) => (style.textStyle?.resolve(states) ?? const TextStyle())
          .copyWith(fontFamily: font),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: font),
    dialogTheme: base.dialogTheme.copyWith(
      titleTextStyle: base.dialogTheme.titleTextStyle?.copyWith(
        fontFamily: font,
      ),
      contentTextStyle: base.dialogTheme.contentTextStyle?.copyWith(
        fontFamily: font,
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: base.inputDecorationTheme.labelStyle?.copyWith(
        fontFamily: font,
      ),
      floatingLabelStyle: base.inputDecorationTheme.floatingLabelStyle
          ?.copyWith(fontFamily: font),
      hintStyle: base.inputDecorationTheme.hintStyle?.copyWith(
        fontFamily: font,
      ),
      errorStyle: base.inputDecorationTheme.errorStyle?.copyWith(
        fontFamily: font,
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: font,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: buttonFont(base.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buttonFont(base.outlinedButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buttonFont(base.elevatedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style:
          buttonFont(base.textButtonTheme.style) ??
          TextButton.styleFrom(textStyle: TextStyle(fontFamily: font)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: buttonFont(base.segmentedButtonTheme.style),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: base.chipTheme.labelStyle?.copyWith(fontFamily: font),
      secondaryLabelStyle: base.chipTheme.secondaryLabelStyle?.copyWith(
        fontFamily: font,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      textStyle: base.popupMenuTheme.textStyle?.copyWith(fontFamily: font),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => base.navigationBarTheme.labelTextStyle
            ?.resolve(states)
            ?.copyWith(fontFamily: font),
      ),
    ),
  );
}
