import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/inventory/data/inventory_repository.dart';
import 'package:qingsongban/features/inventory/domain/inventory_models.dart';
import 'package:qingsongban/features/purchase/data/purchase_repository_impl.dart';
import 'package:qingsongban/features/purchase/domain/purchase_models.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_create_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_detail_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_home_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_history_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_item_history_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_item_prefill.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_pending_apply_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_pending_receive_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_stock_in_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_tracking_page.dart';
import 'package:qingsongban/features/purchase/presentation/widgets/purchase_widgets.dart';

const _capturePurchasePages = bool.fromEnvironment('PURCHASE_CAPTURE_UI');
String? _testFontFamily;
const _materialIconsFontFamily = 'MaterialIcons';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File(r'C:\Windows\Fonts\simhei.ttf');
    if (font.existsSync()) {
      final bytes = await font.readAsBytes();
      const family = 'PurchaseAcceptanceChinese';
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      _testFontFamily = family;
    }
    final iconsFont = File(
      r'D:\YoloList\_tooling\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
    );
    if (iconsFont.existsSync()) {
      final bytes = await iconsFont.readAsBytes();
      final loader = FontLoader(_materialIconsFontFamily)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  });

  testWidgets(
    'all nine purchase pages render with in-memory records at phone and tablet sizes',
    (tester) async {
      final database = AppDatabase.forTesting();
      final defaultDebugDisableShadows = debugDisableShadows;
      addTearDown(() {
        debugDisableShadows = defaultDebugDisableShadows;
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpAndSettle();
        await tester.runAsync(database.close);
      });
      final inventory = InventoryRepository(database);
      final purchases = PurchaseRepositoryImpl(database);
      final applyMaterialId = await _createMaterial(inventory, 'MAT-APPLY');
      final appliedMaterialId = await _createMaterial(inventory, 'MAT-APPLIED');
      final buyingMaterialId = await _createMaterial(inventory, 'MAT-BUYING');
      final receiveMaterialId = await _createMaterial(inventory, 'MAT-RECEIVE');
      final completeMaterialId = await _createMaterial(
        inventory,
        'MAT-COMPLETE',
      );
      final freshMaterialId = await _createMaterial(inventory, 'MAT-FRESH');

      final applyId = await _makeRequest(purchases, applyMaterialId, '待申报物资');
      final appliedId = await _makeRequest(
        purchases,
        appliedMaterialId,
        '已申报物资',
      );
      await purchases.confirmApplied(
        appliedId,
        ConfirmAppliedInput(
          appliedDate: DateTime(2026, 9, 12),
          oaRequestNo: 'OA-UI-100',
          oaTitle: '年度物资采购申报',
          oaUrl: 'https://oa.example.test/purchase/100',
        ),
      );
      final buyingId = await _makeRequest(purchases, buyingMaterialId, '采购中物资');
      await purchases.confirmApplied(
        buyingId,
        ConfirmAppliedInput(appliedDate: DateTime(2026, 9, 13)),
      );
      await purchases.assignPurchaser(
        buyingId,
        AssignPurchaserInput(
          purchaseDepartment: '资材部',
          purchaserName: '测试采购员',
          assignedDate: DateTime(2026, 9, 14),
        ),
      );

      final receiveId = await _makeRequest(
        purchases,
        receiveMaterialId,
        '待领取物资',
      );
      await purchases.confirmApplied(
        receiveId,
        ConfirmAppliedInput(
          appliedDate: DateTime(2026, 9, 15),
          oaRequestNo: 'OA-UI-200',
          oaTitle: '待领取演示采购',
          oaUrl: 'https://oa.example.test/purchase/200',
        ),
      );
      await purchases.assignPurchaser(
        receiveId,
        AssignPurchaserInput(
          purchaserName: '测试采购员',
          assignedDate: DateTime(2026, 9, 16),
        ),
      );
      await purchases.markPendingReceive(
        receiveId,
        PendingReceiveInput(
          arrivalNoticeDate: DateTime(2026, 9, 30),
          receiveLocation: '西门仓库',
        ),
      );
      final receiveDetail = await purchases.watchDetail(receiveId).first;
      final receiveItem = receiveDetail!.items.single;
      await purchases.stockIn(
        StockInInput(
          requestId: receiveId,
          stockInDate: DateTime(2026, 10, 1),
          lines: [
            PurchaseStockInLineInput(
              requestItemId: receiveItem.id,
              quantity: 2,
              storageLocation: '西门仓库 A-01',
            ),
          ],
        ),
      );

      final completeId = await _makeRequest(
        purchases,
        completeMaterialId,
        '已入库物资',
      );
      await purchases.confirmApplied(
        completeId,
        ConfirmAppliedInput(appliedDate: DateTime(2026, 8, 5)),
      );
      await purchases.assignPurchaser(
        completeId,
        AssignPurchaserInput(
          purchaserName: '测试采购员',
          assignedDate: DateTime(2026, 8, 6),
        ),
      );
      await purchases.markPendingReceive(
        completeId,
        PendingReceiveInput(arrivalNoticeDate: DateTime(2026, 8, 9)),
      );
      final completeDetail = await purchases.watchDetail(completeId).first;
      await purchases.stockIn(
        StockInInput(
          requestId: completeId,
          stockInDate: DateTime(2026, 8, 10),
          lines: [
            PurchaseStockInLineInput(
              requestItemId: completeDetail!.items.single.id,
              quantity: 8,
            ),
          ],
        ),
      );

      final freshMaterial = (await inventory.getMaterials()).firstWhere(
        (item) => item.id == freshMaterialId,
      );
      final screenshots = <(String, Widget Function(), Finder)>[
        ('01_采购首页', () => const PurchaseHomePage(), find.text('待领取物资 8 把')),
        (
          '02_新建采购',
          () => PurchaseCreatePage(
            initialItem: PurchaseItemPrefill.fromInventoryMaterial(
              freshMaterial,
            ),
          ),
          find.byKey(const Key('purchase-title-field')),
        ),
        (
          '03_待申报',
          () => const PurchasePendingApplyPage(),
          find.byKey(Key('purchase-confirm-applied-$applyId')),
        ),
        (
          '04_采购跟踪',
          () => const PurchaseTrackingPage(),
          find.text('OA申报日期：09月12日'),
        ),
        (
          '05_采购详情',
          () => PurchaseDetailPage(requestId: receiveId),
          find.text('OA-UI-200'),
        ),
        (
          '06_待领取',
          () => const PurchasePendingReceivePage(),
          find.byKey(Key('purchase-stock-in-$receiveId')),
        ),
        (
          '07_采购入库',
          () => PurchaseStockInPage(requestId: receiveId),
          find.byKey(const Key('purchase-confirm-stock-in')),
        ),
        (
          '08_采购历史',
          () => const PurchaseHistoryPage(initialPreset: 'all'),
          find.byKey(Key('purchase-history-request-$receiveId')),
        ),
        (
          '09_物资历史',
          () =>
              PurchaseItemHistoryPage(inventoryMaterialId: completeMaterialId),
          find.byKey(const Key('purchase-repeat-request')),
        ),
      ];
      final sizes = [
        const Size(390, 844),
        const Size(320, 740),
        const Size(600, 960),
      ];
      expect(purchaseQuantityLabel(0.25), '0.25');
      expect(purchaseQuantityLabel(0.001), '0.001');

      for (final size in sizes) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        for (final scale in [1.0, 1.5]) {
          for (final (index, entry) in screenshots.indexed) {
            final capture =
                _capturePurchasePages && size.width == 390 && scale == 1.0;
            final previousShadowSetting = debugDisableShadows;
            if (capture) debugDisableShadows = false;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [appDatabaseProvider.overrideWithValue(database)],
                child: RepaintBoundary(
                  key: const Key('purchase-screenshot-boundary'),
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    theme: _acceptanceTheme(),
                    locale: const Locale('zh', 'CN'),
                    supportedLocales: const [Locale('zh', 'CN')],
                    localizationsDelegates:
                        GlobalMaterialLocalizations.delegates,
                    home: entry.$2(),
                  ),
                ),
              ),
            );
            await tester.pump();
            for (
              var retry = 0;
              retry < 10 && entry.$3.evaluate().isEmpty;
              retry++
            ) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 50)),
              );
              await tester.pump();
            }
            expect(
              find.byKey(const Key('purchase-screenshot-boundary')),
              findsOneWidget,
            );
            expect(
              entry.$3,
              findsOneWidget,
              reason: '${entry.$1}, $size, scale=$scale',
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.$1}, $size, scale=$scale',
            );
            await tester.pumpAndSettle();
            if (size.width == 320 && scale == 1.5 && index == 1) {
              final quantityField = find.byKey(
                const Key('purchase-item-quantity-0'),
              );
              await tester.scrollUntilVisible(
                quantityField,
                220,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.enterText(quantityField, '0.001');
              await tester.pump();
              expect(
                tester.widget<TextField>(quantityField).controller!.text,
                '0.001',
              );
            }
            if (capture) {
              try {
                await tester.pumpAndSettle();
                await tester.runAsync(() => _capture(tester, entry.$1));
              } finally {
                debugDisableShadows = previousShadowSetting;
                await tester.pump();
              }
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await tester.pumpAndSettle();
          }
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}

ThemeData _acceptanceTheme() {
  final base = AppTheme.light;
  final fontFamily = _testFontFamily;
  final textTheme = base.textTheme.apply(fontFamily: fontFamily);
  final primaryTextTheme = base.primaryTextTheme.apply(fontFamily: fontFamily);
  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: primaryTextTheme,
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: fontFamily,
      ),
      toolbarTextStyle: base.appBarTheme.toolbarTextStyle?.copyWith(
        fontFamily: fontFamily,
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: base.inputDecorationTheme.labelStyle?.copyWith(
        fontFamily: fontFamily,
      ),
      floatingLabelStyle: base.inputDecorationTheme.floatingLabelStyle
          ?.copyWith(fontFamily: fontFamily),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => base.navigationBarTheme.labelTextStyle
            ?.resolve(states)
            ?.copyWith(fontFamily: fontFamily),
      ),
    ),
  );
}

Future<int> _createMaterial(InventoryRepository repository, String code) =>
    repository.createMaterial(
      InventoryMaterialDraft(
        materialCode: code,
        materialName: '$code 扫路车边刷',
        modelSpec: '标准型 240mm',
        unitName: '把',
        storageLocation: '西门仓库 A-01',
        minStock: 2,
      ),
    );

Future<int> _makeRequest(
  PurchaseRepositoryImpl repository,
  int materialId,
  String title,
) => repository.createPurchaseRequest(
  CreatePurchaseRequestInput(
    title: title,
    requestDate: DateTime(2026, 8, 1),
    demandReason: '库存不足',
    items: [
      PurchaseItemDraft(
        inventoryMaterialId: materialId,
        itemName: title,
        specification: '标准型 240mm',
        unit: '把',
        currentStockSnapshot: 1,
        requestQuantity: 8,
      ),
    ],
  ),
);

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('purchase-screenshot-boundary')),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (png == null) return;
  final directory = Directory(
    '${Directory.current.path}${Platform.pathSeparator}docs${Platform.pathSeparator}development${Platform.pathSeparator}采购管理模块_验收截图',
  )..createSync(recursive: true);
  final filename = '${name.replaceAll('/', '_')}.png';
  await File('${directory.path}${Platform.pathSeparator}$filename')
      .writeAsBytes(
        Uint8List.view(png.buffer, png.offsetInBytes, png.lengthInBytes),
      );
}
