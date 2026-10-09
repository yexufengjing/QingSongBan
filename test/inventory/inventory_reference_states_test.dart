import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/widgets/design_canvas.dart';
import 'package:qingsongban/features/inventory/application/inventory_providers.dart';
import 'package:qingsongban/features/inventory/application/inventory_service.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_issue_detail_page.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_material_detail_page.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_receipt_detail_page.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_stocktake_detail_page.dart';
import 'package:qingsongban/features/inventory/presentation/widgets/inventory_widgets.dart';

const _captureBoundary = Key('inventory-reference-states-capture');
const _captureEnabled =
    String.fromEnvironment('QSB_CAPTURE_INVENTORY_STATES') == 'true';
String? _chineseFont;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadPreviewFonts);

  for (final size in _phoneSizes) {
    testWidgets(
      'material picker searches and scrolls with keyboard at ${size.name}',
      (tester) async {
        _setPhoneSize(tester, size);
        final materials = List.generate(
          16,
          (index) => _material(id: index + 1, name: '清洁物资 ${index + 1}'),
        );
        var selectedId = 0;
        await tester.pumpWidget(
          RepaintBoundary(
            key: _captureBoundary,
            child: _productApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: InventoryMaterialPickerField(
                      materials: materials,
                      selectedId: selectedId == 0 ? null : selectedId,
                      onChanged: (id) => setState(() => selectedId = id),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('inventory-material-picker')));
        await tester.pumpAndSettle();
        final search = find.byKey(const Key('inventory-material-search'));
        expect(search, findsOneWidget);
        expect(tester.view.viewInsets.bottom, 0);
        await _capture(tester, '${size.name}-material-picker-default');
        tester.view.viewInsets = const FakeViewPadding(bottom: 810);
        await tester.tap(search);
        await tester.showKeyboard(search);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(search, '清洁物资');
        await tester.pumpAndSettle();
        expect(find.text('清洁物资 1'), findsOneWidget);
        await _capture(tester, '${size.name}-material-picker-keyboard');

        final finalOption = find.byKey(
          const Key('inventory-material-option-16'),
        );
        await tester.scrollUntilVisible(
          finalOption,
          180,
          scrollable: _materialResultsScrollable(),
        );
        await tester.ensureVisible(finalOption);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(finalOption).bottom,
          lessThanOrEqualTo(_safeViewportBottom(tester)),
        );
        expect(finalOption, findsOneWidget);
        expect(find.text('清洁物资 16'), findsOneWidget);
        await tester.tap(finalOption);
        await tester.pumpAndSettle();
        expect(_selectedMaterialText('清洁物资 16'), findsOneWidget);
        expect(
          find.byKey(const Key('inventory-material-search')),
          findsNothing,
        );

        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('inventory-material-picker')));
        await tester.pumpAndSettle();
        final safeAreaSearch = find.byKey(
          const Key('inventory-material-search'),
        );
        await tester.enterText(safeAreaSearch, '清洁物资');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          finalOption,
          180,
          scrollable: _materialResultsScrollable(),
        );
        await tester.ensureVisible(finalOption);
        await tester.pumpAndSettle();
        await _capture(tester, '${size.name}-material-picker-safe-bottom');
        await tester.pumpAndSettle();
        expect(
          tester.getRect(finalOption).bottom,
          lessThanOrEqualTo(_safeViewportBottom(tester)),
        );
        await tester.tap(finalOption);
        await tester.pumpAndSettle();
        expect(_selectedMaterialText('清洁物资 16'), findsOneWidget);
        expect(
          find.byKey(const Key('inventory-material-search')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('inventory-material-picker')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(_selectedMaterialText('清洁物资 16'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('receipt and issue revoke confirmations at ${size.name}', (
      tester,
    ) async {
      _setPhoneSize(tester, size);
      final service = _RevokeInventoryService();
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureBoundary,
          child: ProviderScope(
            overrides: [inventoryServiceProvider.overrideWithValue(service)],
            child: _productApp(
              home: const InventoryReceiptDetailPage(receiptId: 12),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('撤销入库'));
      await tester.pumpAndSettle();
      expect(find.text('撤销这笔入库？'), findsOneWidget);
      expect(find.text('库存将按入库明细反向调整，并生成对应流水。'), findsOneWidget);
      await _capture(tester, '${size.name}-receipt-revoke-confirm');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(service.receiptDeleted, isFalse);
      await tester.tap(find.byTooltip('撤销入库'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤销入库').last);
      await tester.pumpAndSettle();
      expect(service.receiptDeleted, isTrue);

      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureBoundary,
          child: ProviderScope(
            overrides: [inventoryServiceProvider.overrideWithValue(service)],
            child: _productApp(
              key: const ValueKey('inventory-issue-detail'),
              home: const InventoryIssueDetailPage(issueId: 13),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('撤销出库'));
      await tester.pumpAndSettle();
      expect(find.text('撤销这笔出库？'), findsOneWidget);
      expect(find.text('库存会按出库明细返还，并生成对应流水。'), findsOneWidget);
      await _capture(tester, '${size.name}-issue-revoke-confirm');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(service.issueDeleted, isFalse);
      await tester.tap(find.byTooltip('撤销出库'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤销出库').last);
      await tester.pumpAndSettle();
      expect(service.issueDeleted, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'stocktake draft, confirmation, and read-only at ${size.name}',
      (tester) async {
        _setPhoneSize(tester, size);
        final service = _StocktakeInventoryService();
        await tester.pumpWidget(
          RepaintBoundary(
            key: _captureBoundary,
            child: ProviderScope(
              overrides: [inventoryServiceProvider.overrideWithValue(service)],
              child: _productApp(
                home: const InventoryStocktakeDetailPage(stocktakeId: 51),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('待盘点'), findsOneWidget);
        expect(find.text('盘亏'), findsOneWidget);
        final actual = find.byKey(const Key('inventory-stocktake-actual-1'));
        expect(tester.widget<TextField>(actual).enabled, isTrue);
        await _capture(tester, '${size.name}-stocktake-draft');

        final confirm = find.byKey(const Key('inventory-stocktake-confirm'));
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(find.text('确认盘点？'), findsOneWidget);
        expect(find.text('继续核对'), findsOneWidget);
        await _capture(tester, '${size.name}-stocktake-confirm-dialog');
        await tester.tap(find.text('继续核对'));
        await tester.pumpAndSettle();
        expect(find.text('待盘点'), findsOneWidget);
        expect(service.confirmCount, 0);

        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        await tester.tap(find.text('确认盘点').last);
        await tester.pump();
        expect(find.text('正在确认…'), findsOneWidget);
        expect(tester.widget<TextField>(actual).enabled, isTrue);
        await _capture(tester, '${size.name}-stocktake-confirming');
        service.releaseConfirmation.complete();
        await tester.pumpAndSettle();

        expect(find.text('已完成'), findsOneWidget);
        expect(find.text('盘亏'), findsOneWidget);
        expect(
          find.byKey(const Key('inventory-stocktake-confirm')),
          findsNothing,
        );
        expect(tester.widget<TextField>(actual).enabled, isFalse);
        await _capture(tester, '${size.name}-stocktake-confirm-success');
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await _capture(tester, '${size.name}-stocktake-readonly');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('material picker remains usable at 320dp with 1.3 text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(top: 72, bottom: 72);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    final materials = List.generate(
      16,
      (index) => _material(id: index + 1, name: '清洁物资 ${index + 1}'),
    );
    var selectedId = 0;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureBoundary,
        child: _productApp(
          textScale: 1.3,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: const EdgeInsets.all(12),
                child: InventoryMaterialPickerField(
                  materials: materials,
                  selectedId: selectedId == 0 ? null : selectedId,
                  onChanged: (id) => setState(() => selectedId = id),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inventory-material-picker')));
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('inventory-material-search'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 810);
    addTearDown(tester.view.resetViewInsets);
    await tester.showKeyboard(search);
    await tester.enterText(search, '清洁物资');
    await tester.pumpAndSettle();
    final finalOption = find.byKey(const Key('inventory-material-option-16'));
    await tester.scrollUntilVisible(
      finalOption,
      160,
      scrollable: _materialResultsScrollable(),
    );
    await tester.ensureVisible(finalOption);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(finalOption).bottom,
      lessThanOrEqualTo(_safeViewportBottom(tester)),
    );
    expect(finalOption, findsOneWidget);
    await tester.tap(finalOption);
    await tester.pumpAndSettle();
    expect(_selectedMaterialText('清洁物资 16'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding();
    final stocktakeService = _StocktakeInventoryService();
    stocktakeService.item = const InventoryStocktakeItem(
      id: 1,
      stocktakeId: 51,
      materialId: 7,
      materialNameSnapshot: '超长名称清洁物资适用于厨房餐厅公共走廊与储物间',
      modelSnapshot: '加厚型五千毫升补充装',
      unitSnapshot: '瓶',
      bookQuantity: 20,
      actualQuantity: 18,
      differenceQuantity: -2,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryServiceProvider.overrideWithValue(stocktakeService),
        ],
        child: _productApp(
          textScale: 1.3,
          home: const InventoryStocktakeDetailPage(stocktakeId: 51),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('超长名称清洁物资适用于厨房餐厅公共走廊与储物间'), findsOneWidget);
    expect(find.text('加厚型五千毫升补充装 · 瓶'), findsOneWidget);
    final actual = find.byKey(const Key('inventory-stocktake-actual-1'));
    await tester.ensureVisible(actual);
    expect(tester.getRect(actual).right, lessThanOrEqualTo(320));
    final confirm = find.byKey(const Key('inventory-stocktake-confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('确认盘点？'), findsOneWidget);
    expect(find.text('继续核对'), findsOneWidget);
    expect(find.text('确认盘点'), findsOneWidget);
    await tester.tap(find.text('继续核对'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected long material name wraps without truncation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longName = '超长名称测试用清洁消毒物资完整名称蓝色包装五千毫升适用于厨房餐厅和公共区域';
    await tester.pumpWidget(
      _productApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: InventoryMaterialPickerField(
              materials: [_material(id: 1, name: longName)],
              selectedId: 1,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final nameFinder = find.text(longName);
    expect(nameFinder, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(nameFinder);
    expect(paragraph.size.height, greaterThan(30));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing inventory detail records leave loading and show empty state',
    (tester) async {
      final service = _NullInventoryDetailService();
      await _expectMissingDetail(
        tester,
        service,
        const InventoryReceiptDetailPage(receiptId: -1),
        '入库单不存在',
        'missing-receipt',
      );
      await _expectMissingDetail(
        tester,
        service,
        const InventoryIssueDetailPage(issueId: -1),
        '出库单不存在',
        'missing-issue',
      );
      await _expectMissingDetail(
        tester,
        service,
        const InventoryMaterialDetailPage(materialId: -1),
        '物资不存在',
        'missing-material',
      );
      await _expectMissingDetail(
        tester,
        service,
        const InventoryStocktakeDetailPage(stocktakeId: -1),
        '盘点记录不存在',
        'missing-stocktake',
      );
    },
  );
}

const _phoneSizes = <_PhoneSize>[
  _PhoneSize('1280x2800', 1280, 2800),
  _PhoneSize('1080x2362', 1080, 2362),
];

class _PhoneSize {
  const _PhoneSize(this.name, this.width, this.height);
  final String name;
  final int width;
  final int height;
}

Finder _materialResultsScrollable() => find.descendant(
  of: find.byKey(const Key('inventory-material-results')),
  matching: find.byType(Scrollable),
);

Finder _selectedMaterialText(String name) => find.descendant(
  of: find.byKey(const Key('inventory-material-picker')),
  matching: find.text(name),
);

double _safeViewportBottom(WidgetTester tester) {
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final inset = tester.view.viewInsets.bottom > 0
      ? tester.view.viewInsets.bottom
      : tester.view.viewPadding.bottom;
  return height - inset / tester.view.devicePixelRatio;
}

Future<void> _loadPreviewFonts() async {
  final chinese = File(r'C:\Windows\Fonts\msyh.ttc');
  final materialIconsDirectory = _findMaterialFontsDirectory();
  final materialIcons = materialIconsDirectory == null
      ? null
      : File(
          '${materialIconsDirectory.path}${Platform.pathSeparator}'
          'MaterialIcons-Regular.otf',
        );
  if (!chinese.existsSync() ||
      materialIcons == null ||
      !materialIcons.existsSync()) {
    if (_captureEnabled) {
      throw StateError(
        'Inventory UI capture requires Windows msyh.ttc and the Flutter '
        'MaterialIcons-Regular.otf font.',
      );
    }
    return;
  }
  final chineseBytes = ByteData.sublistView(await chinese.readAsBytes());
  await (FontLoader(
    'InventoryPreviewChinese',
  )..addFont(Future.value(chineseBytes))).load();
  await (FontLoader('Roboto')..addFont(Future.value(chineseBytes))).load();
  final iconBytes = ByteData.sublistView(await materialIcons.readAsBytes());
  await (FontLoader('MaterialIcons')..addFont(Future.value(iconBytes))).load();
  _chineseFont = 'InventoryPreviewChinese';
}

Directory? _findMaterialFontsDirectory() {
  var ancestor = File(Platform.resolvedExecutable).parent;
  while (true) {
    final candidate = Directory(
      '${ancestor.path}${Platform.pathSeparator}bin'
      '${Platform.pathSeparator}cache${Platform.pathSeparator}artifacts'
      '${Platform.pathSeparator}material_fonts',
    );
    if (File(
      '${candidate.path}${Platform.pathSeparator}MaterialIcons-Regular.otf',
    ).existsSync()) {
      return candidate;
    }
    final parent = ancestor.parent;
    if (parent.path == ancestor.path) return null;
    ancestor = parent;
  }
}

Future<void> _expectMissingDetail(
  WidgetTester tester,
  InventoryService service,
  Widget page,
  String message,
  String key,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [inventoryServiceProvider.overrideWithValue(service)],
      child: _productApp(key: ValueKey(key), home: page),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text(message), findsOneWidget);
  expect(find.byType(InventoryLoadingState), findsNothing);
  expect(tester.takeException(), isNull);
}

Widget _productApp({required Widget home, Key? key, double textScale = 1}) =>
    MaterialApp(
      key: key,
      debugShowCheckedModeBanner: false,
      theme: _referenceTheme(AppTheme.light, _chineseFont),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: DesignCanvas(child: child!),
      ),
    );

ThemeData _referenceTheme(ThemeData base, String? font) => font == null
    ? base
    : base.copyWith(
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
        ),
        appBarTheme: base.appBarTheme.copyWith(
          titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
            fontFamily: font,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: base.filledButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: font)),
          ),
        ),
      );

void _setPhoneSize(WidgetTester tester, _PhoneSize size) {
  tester.view.physicalSize = Size(
    size.width.toDouble(),
    size.height.toDouble(),
  );
  tester.view.devicePixelRatio = 3;
  tester.view.viewPadding = const FakeViewPadding(top: 72, bottom: 72);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewPadding);
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureEnabled) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureBoundary),
    );
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Could not capture $name');
    final directory = Directory(
      'docs/acceptance/ui-refactor-20261009/inventory-states',
    )..createSync(recursive: true);
    final bytes = Uint8List.view(
      data.buffer,
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
  });
}

InventoryMaterial _material({required int id, required String name}) =>
    InventoryMaterial(
      id: id,
      materialCode: 'MAT-$id',
      materialName: name,
      modelSpec: '通用型',
      unitName: '件',
      currentStock: 20,
      minStock: 5,
      warningEnabled: true,
      isCommon: true,
      status: 'active',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
      isDeleted: false,
    );

class _NullInventoryDetailService implements InventoryService {
  @override
  Future<InventoryReceipt?> getReceipt(int id) async => null;

  @override
  Future<InventoryIssue?> getIssue(int id) async => null;

  @override
  Future<InventoryMaterial?> getMaterial(int id) async => null;

  @override
  Future<InventoryStocktake?> getStocktake(int id) async => null;

  @override
  Future<List<InventoryReceiptItem>> getReceiptItems(int receiptId) async => [];

  @override
  Future<List<InventoryIssueItem>> getIssueItems(int issueId) async => [];

  @override
  Future<List<InventoryStocktakeItem>> getStocktakeItems(
    int stocktakeId,
  ) async => [];

  @override
  Future<List<InventoryCategory>> getCategories() async => [];

  @override
  Future<List<InventoryTransaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType,
    int? materialId,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is outside the missing-detail fixture',
  );
}

class _RevokeInventoryService implements InventoryService {
  final now = DateTime(2026, 10, 8);
  bool receiptDeleted = false;
  bool issueDeleted = false;

  @override
  Future<InventoryReceipt?> getReceipt(int id) async => InventoryReceipt(
    id: id,
    receiptNo: 'RK-20261008-001',
    receiptDate: now,
    receiptType: 'purchase',
    sourceName: '测试隔离来源',
    operatorNameSnapshot: '测试登记人',
    remark: '只读测试夹具',
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
  );

  @override
  Future<List<InventoryReceiptItem>> getReceiptItems(int receiptId) async => [
    InventoryReceiptItem(
      id: 1,
      receiptId: receiptId,
      materialId: 7,
      materialNameSnapshot: '测试手套',
      modelSnapshot: '通用型',
      unitSnapshot: '副',
      quantity: 2,
      createdAt: now,
    ),
  ];

  @override
  Future<void> deleteReceipt(int id) async {
    receiptDeleted = true;
  }

  @override
  Future<InventoryIssue?> getIssue(int id) async => InventoryIssue(
    id: id,
    issueNo: 'CK-20261008-001',
    issueDate: now,
    issueType: 'employee_claim',
    receiverType: 'manual',
    manualReceiverName: '测试领取人',
    purpose: '隔离测试',
    operatorNameSnapshot: '测试登记人',
    remark: '只读测试夹具',
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
  );

  @override
  Future<List<InventoryIssueItem>> getIssueItems(int issueId) async => [
    InventoryIssueItem(
      id: 2,
      issueId: issueId,
      materialId: 7,
      materialNameSnapshot: '测试手套',
      modelSnapshot: '通用型',
      unitSnapshot: '副',
      quantity: 1,
      createdAt: now,
    ),
  ];

  @override
  Future<void> deleteIssue(int id) async {
    issueDeleted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is outside this UI fixture',
  );
}

class _StocktakeInventoryService implements InventoryService {
  final releaseConfirmation = Completer<void>();
  InventoryStocktake stocktake = InventoryStocktake(
    id: 51,
    stocktakeNo: 'PD-20261008-001',
    stocktakeDate: DateTime(2026, 10, 8),
    operatorNameSnapshot: '测试盘点人',
    status: 'draft',
    remark: '月度核对',
    createdAt: DateTime(2026, 10, 8),
    updatedAt: DateTime(2026, 10, 8),
  );
  InventoryStocktakeItem item = const InventoryStocktakeItem(
    id: 1,
    stocktakeId: 51,
    materialId: 7,
    materialNameSnapshot: '测试手套',
    modelSnapshot: '通用型',
    unitSnapshot: '副',
    bookQuantity: 20,
    actualQuantity: 18,
    differenceQuantity: -2,
  );
  int confirmCount = 0;

  @override
  Future<InventoryStocktake?> getStocktake(int id) async => stocktake;

  @override
  Future<List<InventoryStocktakeItem>> getStocktakeItems(
    int stocktakeId,
  ) async => [item];

  @override
  Future<void> updateStocktakeItem(
    int id,
    double quantity, {
    String? remark,
  }) async {
    item = InventoryStocktakeItem(
      id: item.id,
      stocktakeId: item.stocktakeId,
      materialId: item.materialId,
      materialNameSnapshot: item.materialNameSnapshot,
      modelSnapshot: item.modelSnapshot,
      unitSnapshot: item.unitSnapshot,
      bookQuantity: item.bookQuantity,
      actualQuantity: quantity,
      differenceQuantity: quantity - item.bookQuantity,
    );
  }

  @override
  Future<void> confirmStocktake(int id) async {
    confirmCount++;
    await releaseConfirmation.future;
    stocktake = stocktake.copyWith(status: 'confirmed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is outside this UI fixture',
  );
}
