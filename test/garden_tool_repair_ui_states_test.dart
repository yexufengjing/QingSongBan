import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/core/widgets/design_canvas.dart';
import 'package:qingsongban/features/garden_tool_repairs/application/garden_tool_repair_providers.dart';
import 'package:qingsongban/features/garden_tool_repairs/data/garden_tool_repair_attachment_service.dart';
import 'package:qingsongban/features/garden_tool_repairs/data/garden_tool_repair_repository.dart';
import 'package:qingsongban/features/garden_tool_repairs/domain/repair_models.dart';
import 'package:qingsongban/features/garden_tool_repairs/presentation/garden_tool_repair_analysis_page.dart';
import 'package:qingsongban/features/garden_tool_repairs/presentation/garden_tool_repair_attachments_page.dart';
import 'package:qingsongban/features/garden_tool_repairs/presentation/garden_tool_repair_page.dart';
import 'package:qingsongban/features/garden_tool_repairs/presentation/garden_tool_repair_price_page.dart';
import 'package:qingsongban/features/garden_tool_repairs/presentation/garden_tool_repair_units_page.dart';

const _captureKey = ValueKey('garden-repair-capture');
const _repairerName = '张师傅（器械维修负责人）';
const _shouldCapture = bool.fromEnvironment('UI_REFACTOR_CAPTURE');
const _captureDirectory =
    'docs/acceptance/ui-refactor-20261009/garden-tool-repairs';
String? _font;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final chinese = File(r'C:\Windows\Fonts\msyh.ttc');
    if (chinese.existsSync()) {
      final fontBytes = ByteData.sublistView(await chinese.readAsBytes());
      await (FontLoader(
        'GardenRepairChinese',
      )..addFont(Future.value(fontBytes))).load();
      await (FontLoader('Roboto')..addFont(Future.value(fontBytes))).load();
      _font = 'GardenRepairChinese';
    }
    final materialFonts = _findMaterialFontsDirectory();
    final icons = materialFonts == null
        ? null
        : File(
            '${materialFonts.path}${Platform.pathSeparator}MaterialIcons-Regular.otf',
          );
    if (icons == null || !icons.existsSync()) {
      if (_shouldCapture) {
        throw StateError('Flutter SDK MaterialIcons-Regular.otf not found');
      }
    } else {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(await icons.readAsBytes())),
          ))
          .load();
    }
    if (_shouldCapture && _font == null) {
      throw StateError(
        'Windows Chinese font C:\\Windows\\Fonts\\msyh.ttc not found',
      );
    }
  });

  testWidgets('data states render at target portrait sizes', (tester) async {
    final fixture = await tester.runAsync(_seedFixture);
    if (fixture == null) throw StateError('无法初始化隔离的器械维修测试数据');
    final database = fixture.database;
    final focusGroupId = fixture.focusGroupId;
    final attachmentService = fixture.attachmentService;
    addTearDown(() async {
      await tester.runAsync(database.close);
      await tester.runAsync(
        () => fixture.attachmentDirectory.delete(recursive: true),
      );
    });
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);

    final profiles = [
      (name: 'gt7_1280x2800', size: const Size(1280, 2800), scale: 1.0),
      (name: '1080x2362', size: const Size(1080, 2362), scale: 1.0),
      (name: 'large_text_stress', size: const Size(960, 2532), scale: 1.3),
    ];
    for (final profile in profiles) {
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.scale;
      tester.view.physicalSize = Size(
        profile.size.width / 3,
        profile.size.height / 3,
      );
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final pages = <(String, Widget)>[
        (
          'ledger',
          GardenToolRepairPage(
            initialYear: month.year,
            initialMonth: month.month,
          ),
        ),
        (
          'analysis',
          GardenToolRepairAnalysisPage(
            initialYear: month.year,
            initialMonth: month.month,
          ),
        ),
        ('price_comparison', const GardenToolRepairPricePage()),
      ];
      for (final (pageName, page) in pages) {
        await _mount(tester, database, page);
        expect(find.text('青松器械维修中心'), findsWidgets);
        expect(find.text('割草机刀片'), findsWidgets);
        expect(
          tester.takeException(),
          isNull,
          reason: '${profile.name}/$pageName',
        );
        await _capture(tester, '${profile.name}_$pageName');
        if (pageName == 'ledger') {
          final tableScroll = find.byType(SingleChildScrollView).first;
          await tester.drag(tableScroll, const Offset(-520, 0));
          await tester.pumpAndSettle();
          _expectVisibleIn(
            tester,
            find.text('金额'),
            find.byType(SingleChildScrollView).first,
          );
          _expectVisibleIn(
            tester,
            find.text('备注'),
            find.byType(SingleChildScrollView).first,
          );
          await _capture(tester, '${profile.name}_ledger_table_right');
        } else if (pageName == 'analysis') {
          await tester.scrollUntilVisible(
            find.text(_repairerName),
            280,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          _expectVisibleIn(
            tester,
            find.text(_repairerName),
            find.byType(ListView).first,
          );
          final repairerScroll = find.byKey(
            const ValueKey('repairer-table-scroll'),
          );
          await tester.drag(repairerScroll, const Offset(600, 0));
          await tester.pumpAndSettle();
          _expectVisibleIn(tester, find.text('排名'), repairerScroll);
          await _capture(tester, '${profile.name}_analysis_repairers');
          await tester.drag(repairerScroll, const Offset(-600, 0));
          await tester.pumpAndSettle();
          _expectVisibleIn(tester, find.text('维修金额'), repairerScroll);
          _expectVisibleIn(tester, find.text('占比'), repairerScroll);
          await _capture(tester, '${profile.name}_analysis_repairers_right');
        } else if (pageName == 'price_comparison') {
          await tester.scrollUntilVisible(
            find.text('历史记录'),
            240,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          _expectVisibleIn(
            tester,
            find.text('历史记录'),
            find.byType(ListView).first,
          );
          _expectVisibleIn(
            tester,
            find.text('日期'),
            find.byType(ListView).first,
          );
          await _capture(tester, '${profile.name}_price_history');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }

      await _mount(tester, database, const GardenToolRepairUnitsPage());
      expect(find.text('青松器械维修中心'), findsOneWidget);
      expect(find.text('旧维修单位'), findsOneWidget);
      await _capture(tester, '${profile.name}_units');
      await tester.tap(
        find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('编辑名称'), findsOneWidget);
      await _capture(tester, '${profile.name}_unit_menu');
      await tester.tap(find.text('编辑名称'));
      await tester.pumpAndSettle();
      expect(find.text('编辑维修单位'), findsOneWidget);
      await _capture(tester, '${profile.name}_unit_rename');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await _mount(
        tester,
        database,
        GardenToolRepairAttachmentsPage(groupId: focusGroupId),
        attachmentService: attachmentService,
      );
      await _waitForDecodedImage(tester);
      expect(find.text('维修票据'), findsOneWidget);
      expect(find.text('维修前照片'), findsOneWidget);
      expect(_decodedImages(), findsWidgets);
      await _capture(tester, '${profile.name}_attachments');
      await tester.tap(find.byType(Card).first);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      await _waitForDecodedPreviewImage(tester);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await _capture(tester, '${profile.name}_attachment_fullscreen');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.idle();
      await tester.pumpAndSettle();
    }
  });
}

Directory? _findMaterialFontsDirectory() {
  var directory = Directory(Platform.resolvedExecutable).parent;
  for (var level = 0; level < 10; level++) {
    final candidate = Directory(
      '${directory.path}${Platform.pathSeparator}bin'
      '${Platform.pathSeparator}cache'
      '${Platform.pathSeparator}artifacts'
      '${Platform.pathSeparator}material_fonts',
    );
    if (File(
      '${candidate.path}${Platform.pathSeparator}MaterialIcons-Regular.otf',
    ).existsSync()) {
      return candidate;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) return null;
    directory = parent;
  }
  return null;
}

Future<
  ({
    AppDatabase database,
    int focusGroupId,
    Directory attachmentDirectory,
    GardenToolRepairAttachmentService attachmentService,
  })
>
_seedFixture() async {
  final database = AppDatabase.forTesting();
  final repository = GardenToolRepairRepository(database);
  final unit = await repository.saveUnit(
    name: '青松器械维修中心',
    sortOrder: 0,
    isActive: true,
  );
  await repository.saveUnit(name: '旧维修单位', sortOrder: 1, isActive: false);
  final now = DateTime.now();
  var focusGroupId = 0;
  for (final offset in [0, -1, -4, -8]) {
    final date = DateTime(
      now.year,
      now.month + offset,
      5 + (offset.abs() % 20),
    );
    final group = await repository.saveGroup(
      GardenToolRepairGroupDraft(
        repairMonth: repairMonthKey(date),
        repairDate: date,
        unitId: unit.id,
        repairerName: [_repairerName, '李师傅', '王师傅', '赵师傅'][offset.abs() % 4],
        remark: '器械定期保养与易损件更换',
        items: [
          GardenToolRepairItemDraft(
            projectName: '割草机刀片',
            specModel: '专业型 300mm',
            countUnit: '片',
            quantity: 2 + offset.abs() % 3,
            unitPriceCents: 7600 + offset.abs() * 170,
            remark: '原厂规格',
          ),
        ],
      ),
    );
    if (offset == 0) focusGroupId = group.id;
  }

  final attachmentDirectory = await Directory.systemTemp.createTemp(
    'garden_repair_ui_attachments_',
  );
  final asset = File('assets/vehicles/water-truck.png');
  if (!await asset.exists()) throw StateError('测试图片不存在：${asset.path}');
  final imageDirectory = Directory(
    '${attachmentDirectory.path}${Platform.pathSeparator}attachments'
    '${Platform.pathSeparator}garden_tool_repairs'
    '${Platform.pathSeparator}$focusGroupId',
  )..createSync(recursive: true);
  await asset.copy('${imageDirectory.path}${Platform.pathSeparator}repair.png');
  final firstAttachment = await repository.addAttachment(
    groupId: focusGroupId,
    attachmentType: 'receipt',
    filePath: 'garden_tool_repairs/$focusGroupId/repair.png',
  );
  await repository.addAttachment(
    groupId: focusGroupId,
    attachmentType: 'before',
    filePath: firstAttachment.filePath,
  );
  return (
    database: database,
    focusGroupId: focusGroupId,
    attachmentDirectory: attachmentDirectory,
    attachmentService: GardenToolRepairAttachmentService(
      repository,
      documentsDirectory: () async => attachmentDirectory,
    ),
  );
}

Future<void> _mount(
  WidgetTester tester,
  AppDatabase database,
  Widget page, {
  GardenToolRepairAttachmentService? attachmentService,
}) async {
  // Each isolated page needs a fresh Navigator and ProviderScope.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  final service =
      attachmentService ??
      GardenToolRepairAttachmentService(GardenToolRepairRepository(database));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        gardenToolRepairAttachmentServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN')],
        theme: _referenceTheme(AppTheme.light, _font),
        initialRoute: '/page',
        routes: {'/page': (_) => page},
        onGenerateInitialRoutes: (initialRoute) => [
          MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
          MaterialPageRoute<void>(builder: (_) => page),
        ],
        builder: (context, child) => RepaintBoundary(
          key: _captureKey,
          child: DesignCanvas(child: child!),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pumpAndSettle();
}

Finder _decodedImages() => find.byWidgetPredicate(
  (widget) => widget is RawImage && widget.image != null,
);

ThemeData _referenceTheme(ThemeData base, String? font) {
  if (font == null) return base;
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
    chipTheme: base.chipTheme.copyWith(
      labelStyle: base.chipTheme.labelStyle?.copyWith(fontFamily: font),
      secondaryLabelStyle: base.chipTheme.secondaryLabelStyle?.copyWith(
        fontFamily: font,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      textStyle: base.popupMenuTheme.textStyle?.copyWith(fontFamily: font),
    ),
  );
}

Future<void> _waitForDecodedImage(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    if (_decodedImages().evaluate().isNotEmpty) return;
  }
  expect(_decodedImages(), findsWidgets);
}

Future<void> _waitForDecodedPreviewImage(WidgetTester tester) async {
  final previewImage = find.descendant(
    of: find.byType(InteractiveViewer),
    matching: _decodedImages(),
  );
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    if (previewImage.evaluate().isNotEmpty) return;
  }
  expect(previewImage, findsWidgets);
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_shouldCapture || tester.view.physicalSize.width < 360) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Unable to render $name');
    final directory = Directory(_captureDirectory)..createSync(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  });
}

void _expectVisibleIn(WidgetTester tester, Finder target, Finder viewport) {
  expect(target, findsOneWidget);
  final targetRect = tester.getRect(target);
  final viewportRect = tester.getRect(viewport);
  expect(targetRect.overlaps(viewportRect), isTrue);
}
