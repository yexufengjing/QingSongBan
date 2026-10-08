import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

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
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/core/database/demo_data_seeder.dart';
import 'package:qingsongban/core/database/inventory_demo_data_seeder.dart';
import 'package:qingsongban/core/database/purchase_demo_data_seeder.dart';
import 'package:qingsongban/core/database/vehicle_demo_data_seeder.dart';
import 'package:qingsongban/features/reports/data/monthly_summary_repository.dart';

const _capture = bool.fromEnvironment('UI_REFACTOR_CAPTURE');
const _captureNames = String.fromEnvironment('UI_CAPTURE_NAMES');
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
    final config = jsonDecode(
      File('.dart_tool/package_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final flutterPackage = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((package) => package['name'] == 'flutter');
    final flutterDirectory = File('.dart_tool/package_config.json').absolute.uri
        .resolve('${flutterPackage['rootUri']}/');
    final icons = File.fromUri(
      flutterDirectory.resolve(
        '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
    if (icons.existsSync()) {
      final loader = FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
      await loader.load();
    }
  });

  for (final size in [(390.0, 1.0), (320.0, 1.3)]) {
    testWidgets(
      'reference routes remain usable at ${size.$1}dp, font ${size.$2}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(size.$1, 844);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final db = AppDatabase.forTesting();
        late int employeeId,
            materialId,
            vehicleId,
            requestId,
            receiptId,
            issueId,
            payrollItemId,
            payrollBatchId;
        try {
          // Fixtures are restricted to this disposable in-memory test database.
          await tester.runAsync(() async {
            await DemoDataSeeder.seed(db);
            await InventoryDemoDataSeeder.seed(db);
            await PurchaseDemoDataSeeder.seed(db);
            await VehicleDemoDataSeeder.seed(db);
            employeeId = (await db.select(db.employees).get()).first.id;
            materialId =
                (await db.select(db.inventoryMaterials).get()).first.id;
            vehicleId = (await db.select(db.vehicles).get()).first.id;
            requestId = (await db.select(db.purchaseRequests).get())
                .firstWhere((row) => row.status == 'pending_receive')
                .id;
            receiptId = (await db.select(db.inventoryReceipts).get()).first.id;
            issueId = (await db.select(db.inventoryIssues).get()).first.id;
            payrollItemId = (await db.select(db.payrollItems).get()).first.id;
            payrollBatchId =
                (await db.select(db.payrollBatches).get()).first.id;
            final now = DateTime.now();
            await MonthlySummaryRepository(db).generate(
              yearMonth: '${now.year}-${now.month.toString().padLeft(2, '0')}',
            );
          });
          final base = AppTheme.light;
          final theme = _font == null ? base : _referenceTheme(base, _font!);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appDatabaseProvider.overrideWithValue(db)],
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
            appRouter.go(route.$2);
            await _settle(tester);
            recordException(route.$2);
            if (route.$1 == 'home' && size.$1 == 390) {
              expect(
                tester.getTopLeft(find.byKey(const Key('home-metric-今日请假'))).dy,
                tester.getTopLeft(find.byKey(const Key('home-metric-当前在岗'))).dy,
                reason: 'The reference keeps the four personnel metrics on one row.',
              );
            }
            expect(
              find.textContaining('GoException'),
              findsNothing,
              reason: route.$2,
            );
            if (route.$1 == 'issue_form') {
              expect(
                find.text('员工领取'),
                findsNWidgets(2),
                reason: 'Both issue and receiver types show their real value.',
              );
            }
            if (route.$1 == 'issue_form' && _capture && size.$1 == 390.0) {
              await _fillIssueFormCapture(tester, db, employeeId);
            }
            await _snapshot(
              tester,
              '${route.$1}_${size.$1.toInt()}_${size.$2}',
            );
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
            if (route.$1 == 'vehicle_detail' && _capture) {
              for (final tab in ['费用', '提醒']) {
                final target = find.widgetWithText(Tab, tab);
                await tester.ensureVisible(target);
                await tester.pumpAndSettle();
                await tester.tap(target);
                await _settle(tester);
                recordException('车辆详情/$tab');
                await _snapshot(
                  tester,
                  'vehicle_${tab}_${size.$1.toInt()}_${size.$2}',
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
          await tester.runAsync(() => db.close());
          await tester.idle();
          await tester.pump(const Duration(milliseconds: 1));
        }
      },
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillIssueFormCapture(
  WidgetTester tester,
  AppDatabase database,
  int employeeId,
) async {
  late String employeeName;
  late List<InventoryMaterial> materials;
  await tester.runAsync(() async {
    employeeName = (await database.findEmployeeById(employeeId))!.name;
    materials = await database.select(database.inventoryMaterials).get();
  });
  if (materials.length < 2) {
    throw StateError(
      'The inventory fixture needs two materials for the form capture.',
    );
  }

  Future<void> choose(
    String key,
    String query,
    String result, {
    int index = 0,
  }) async {
    final field = find.byKey(Key(key)).at(index);
    await tester.ensureVisible(field);
    await tester.tap(field);
    await _settle(tester);
    final sheet = find.byType(BottomSheet).last;
    final search = find
        .descendant(of: sheet, matching: find.byType(TextField))
        .first;
    await tester.enterText(search, query);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: sheet, matching: find.textContaining(result)).last,
    );
    await _settle(tester);
  }

  await choose(
    'inventory-employee-select',
    _searchPrefix(employeeName),
    employeeName,
  );
  await tester.ensureVisible(find.byTooltip('添加明细'));
  await tester.tap(find.byTooltip('添加明细'));
  await _settle(tester);
  await choose(
    'inventory-issue-material-select',
    _searchPrefix(materials.first.materialName),
    materials.first.materialName,
  );
  await choose(
    'inventory-issue-material-select',
    _searchPrefix(materials[1].materialName),
    materials[1].materialName,
    index: 1,
  );
  final quantities = find.byKey(const Key('inventory-issue-quantity'));
  for (var index = 0; index < quantities.evaluate().length; index++) {
    await tester.ensureVisible(quantities.at(index));
    await tester.enterText(quantities.at(index), '${index + 1}');
  }
  await _snapshot(tester, 'issue_form_items_390_1.0');
  final scrollable = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byKey(const Key('inventory-issue-form-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  scrollable.position.jumpTo(scrollable.position.minScrollExtent);
  await tester.pumpAndSettle();
}

String _searchPrefix(String value) =>
    value.substring(0, value.length < 2 ? value.length : 2);

Future<void> _snapshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  if (_captureNames.isNotEmpty &&
      !_captureNames
          .split(',')
          .any((prefix) => name.startsWith('${prefix}_390_'))) {
    return;
  }
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundary),
    );
    final image = await boundary.toImage(pixelRatio: 2);
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
