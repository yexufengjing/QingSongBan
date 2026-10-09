import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/widgets/design_canvas.dart';
import 'package:qingsongban/features/backup/application/backup_providers.dart';
import 'package:qingsongban/features/backup/application/backup_service.dart';
import 'package:qingsongban/features/backup/presentation/backup_page.dart';
import 'package:qingsongban/features/excel/application/excel_providers.dart';
import 'package:qingsongban/features/excel/application/excel_service.dart';
import 'package:qingsongban/features/excel/presentation/excel_page.dart';

const _captureKey = ValueKey('system-tools-reference-capture');
const _captureEnabled = bool.fromEnvironment(
  'UI_SYSTEM_TOOLS_CAPTURE',
  defaultValue: false,
);
const _captureDirectory = 'docs/acceptance/ui-refactor-20261009/system-tools';
const _phoneSizes = <_PhoneSize>[
  _PhoneSize('1280x2800', 1280, 2800),
  _PhoneSize('1080x2362', 1080, 2362),
];
String? _font;
double _textScale = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final chinese = File(r'C:\Windows\Fonts\msyh.ttc');
    if (chinese.existsSync()) {
      final fontBytes = ByteData.sublistView(await chinese.readAsBytes());
      await (FontLoader(
        'SystemToolsChinese',
      )..addFont(Future.value(fontBytes))).load();
      await (FontLoader('Roboto')..addFont(Future.value(fontBytes))).load();
      _font = 'SystemToolsChinese';
    }
    final flutterRoot = File(Platform.resolvedExecutable)
        .parent
        .parent
        .parent
        .parent
        .parent
        .parent;
    final materialFonts = Directory(
      '${flutterRoot.path}${Platform.pathSeparator}bin${Platform.pathSeparator}'
      'cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}'
      'material_fonts',
    );
    if (!await materialFonts.exists()) {
      throw StateError('Flutter MaterialIcons 字体目录不存在：${materialFonts.path}');
    }
    final iconFonts = await materialFonts
        .list()
        .where(
          (entity) =>
              entity is File &&
              entity.path.split(Platform.pathSeparator).last.toLowerCase() ==
                  'materialicons-regular.otf',
        )
        .toList();
    if (iconFonts.isEmpty) {
      throw StateError('Flutter SDK 中没有 MaterialIcons-Regular.otf');
    }
    final fontBytes = ByteData.sublistView(
      await (iconFonts.first as File).readAsBytes(),
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(fontBytes))).load();
  });

  testWidgets('backup password, busy, and restore cancellation states', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    final root = await _runAsync(
      tester,
      () => Directory.systemTemp.createTemp('qsb-system-tools-'),
    );
    addTearDown(() async {
      await database.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    for (final profile in _phoneSizes) {
      final service = _UiBackupService(database, root);
      _setPhoneSize(tester, profile);
      final originalPicker = FilePickerPlatform.instance;
      final picker = _TestFilePickerPlatform();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);
      final backupFile = File(
        '${root.path}${Platform.pathSeparator}sample.qsbak',
      );
      await _runAsync(tester, () => backupFile.writeAsBytes([1, 2, 3]));
      picker.result = [_TestPlatformFile(backupFile, Uint8List(0))];

      final router = await _pumpPage(tester, const BackupPage(), [
        backupServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(() => _unmount(tester, router));
      await _capture(tester, '${profile.name}-backup-main');

      expect(find.byKey(const Key('backup-create-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('backup-create-button')));
      await tester.pump(const Duration(milliseconds: 400));
      final passwordField = find.byKey(const Key('backup-password-field'));
      final confirmationField = find.byKey(
        const Key('backup-password-confirmation-field'),
      );
      expect(
        tester.widget<Text>(find.text('设置备份密码')).textAlign,
        TextAlign.center,
      );
      expect(passwordField, findsOneWidget);
      expect(confirmationField, findsOneWidget);
      final firstField = tester.widget<TextField>(passwordField);
      expect(firstField.decoration?.labelText, isNull);
      expect(firstField.obscureText, isTrue);
      expect(tester.getSize(passwordField).height, greaterThanOrEqualTo(56));
      expect(
        tester.getSize(find.byKey(const Key('backup-password-cancel'))).width,
        tester.getSize(find.byKey(const Key('backup-password-submit'))).width,
      );
      await tester.tap(find.byTooltip('显示密码').first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
      await tester.tap(find.byTooltip('隐藏密码').first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
      expect(tester.widget<TextField>(confirmationField).obscureText, isTrue);
      await tester.tap(find.byTooltip('显示密码').last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<TextField>(confirmationField).obscureText, isFalse);
      await tester.tap(find.byTooltip('隐藏密码').last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<TextField>(confirmationField).obscureText, isTrue);
      await _capture(tester, '${profile.name}-backup-password');

      await tester.enterText(passwordField, 'short');
      await tester.tap(find.text('继续'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('密码至少需要 8 个字符'), findsOneWidget);
      await tester.enterText(passwordField, 'backup-123');
      await tester.enterText(confirmationField, 'backup-456');
      await tester.tap(find.text('继续'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('两次输入的密码不一致'), findsOneWidget);
      await tester.enterText(confirmationField, 'backup-123');
      await tester.tap(find.text('继续'));
      await tester.pump();
      expect(service.createCount, 1);
      expect(find.byKey(const Key('backup-progress')), findsOneWidget);
      expect(find.text('正在创建备份…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('backup-create-button')))
            .onPressed,
        isNull,
      );
      await _capture(tester, '${profile.name}-backup-busy');
      service.releaseCreate.complete(File('${root.path}/created.qsbak'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('backup-progress')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('backup-create-button')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await _dismissSnackBar(tester);

      await tester.tap(find.byKey(const Key('backup-create-button')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(service.createCount, 1);

      picker.result = [];
      await tester.tap(find.byKey(const Key('backup-restore-button')));
      await tester.pumpAndSettle();
      expect(find.text('确认恢复？'), findsNothing);
      expect(service.restoreCount, 0);

      picker.result = [_TestPlatformFile(backupFile, Uint8List(0))];
      await tester.tap(find.byKey(const Key('backup-restore-button')));
      await tester.pumpAndSettle();
      expect(find.text('当前本地数据将被备份包覆盖，恢复后需要重启应用。是否继续？'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('确认恢复？')).textAlign,
        TextAlign.center,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      final cancelRestore = tester.getSize(
        find.widgetWithText(OutlinedButton, '取消'),
      );
      final confirmRestore = tester.getSize(
        find.widgetWithText(FilledButton, '确认恢复'),
      );
      expect(cancelRestore.width, confirmRestore.width);
      expect(cancelRestore.height, greaterThanOrEqualTo(48));
      expect(confirmRestore.height, greaterThanOrEqualTo(48));
      final destructiveAction = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '确认恢复'),
      );
      expect(
        destructiveAction.style?.backgroundColor?.resolve({}),
        AppTheme.light.colorScheme.error,
      );
      await _capture(tester, '${profile.name}-backup-restore-confirm');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(service.restoreCount, 0);
      expect(find.text('选择备份并恢复'), findsOneWidget);
      await _capture(tester, '${profile.name}-backup-restore-cancelled');

      service.restoreGate = Completer<BackupRestoreResult>();
      picker.result = [_TestPlatformFile(backupFile, Uint8List(0))];
      await tester.tap(find.byKey(const Key('backup-restore-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '确认恢复'));
      await tester.pumpAndSettle();
      final restorePassword = find.byKey(const Key('backup-password-field'));
      expect(restorePassword, findsOneWidget);
      expect(tester.widget<TextField>(restorePassword).obscureText, isTrue);
      await tester.enterText(restorePassword, 'restore-123');
      await tester.tap(find.byKey(const Key('backup-password-submit')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.restoreCount, 1);
      expect(find.text('正在恢复备份…'), findsOneWidget);
      expect(find.byKey(const Key('backup-progress')), findsOneWidget);
      await _capture(tester, '${profile.name}-backup-restore-busy');
      service.restoreGate!.complete(
        BackupRestoreResult(
          safetyBackup: File(
            '${root.path}${Platform.pathSeparator}safety.qsbak',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('恢复完成'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('恢复完成')).textAlign,
        TextAlign.center,
      );
      expect(find.byKey(const Key('backup-progress')), findsNothing);
      expect(find.textContaining('safety.qsbak'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '重启应用'), findsOneWidget);
      await _capture(tester, '${profile.name}-backup-restore-complete');
      expect(tester.takeException(), isNull);

      await tester.tapAt(const Offset(2, 2));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('恢复完成'), findsNothing);
      service.restoreGate = Completer<BackupRestoreResult>();
      picker.result = [_TestPlatformFile(backupFile, Uint8List(0))];
      await tester.tap(find.byKey(const Key('backup-restore-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '确认恢复'));
      await tester.pumpAndSettle();
      await tester.enterText(restorePassword, 'restore-123');
      await tester.tap(find.byKey(const Key('backup-password-submit')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('正在恢复备份…'), findsOneWidget);
      await _capture(tester, '${profile.name}-backup-restore-error-busy');
      service.restoreGate!.completeError(StateError('模拟解密失败'));
      await tester.pumpAndSettle();
      expect(find.textContaining('恢复失败：'), findsOneWidget);
      expect(find.byKey(const Key('backup-progress')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('backup-restore-button')),
            )
            .onPressed,
        isNotNull,
      );
      await _capture(tester, '${profile.name}-backup-restore-error');
      expect(tester.takeException(), isNull);
      await _dismissSnackBar(tester);
    }
  });

  testWidgets('Excel import preview pass, errors, cancel, and busy state', (
    tester,
  ) async {
    for (final profile in _phoneSizes) {
      final database = AppDatabase.forTesting();
      await _runAsync(
        tester,
        () => database.select(database.attendanceGroups).get(),
      );
      final root = await _runAsync(
        tester,
        () => Directory.systemTemp.createTemp('qsb-system-tools-'),
      );
      GoRouter? router;
      var routerUnmounted = false;
      var databaseClosed = false;
      addTearDown(() async {
        final activeRouter = router;
        if (activeRouter != null && !routerUnmounted) {
          await _unmount(tester, activeRouter);
        }
        if (!databaseClosed) await database.close();
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      _setPhoneSize(tester, profile);
      final employeeName = '测试人员-${profile.name}';
      final validFile = await _runAsync(
        tester,
        () => _workbookFile(
          root,
          'valid.xlsx',
          headers: ['姓名', '入职日期'],
          row: [employeeName, '2026-10-01'],
        ),
      );
      final invalidFile = await _runAsync(
        tester,
        () => _workbookFile(
          root,
          'invalid.xlsx',
          headers: ['姓名', '入职日期'],
          row: ['', '2026-10-01'],
        ),
      );
      final service = _UiExcelService(database, tester)
        ..importGate = Completer<void>();
      final originalPicker = FilePickerPlatform.instance;
      final picker = _TestFilePickerPlatform();
      var pickerRestored = false;
      FilePickerPlatform.instance = picker;
      addTearDown(() {
        if (!pickerRestored) FilePickerPlatform.instance = originalPicker;
      });

      final activeRouter = await _pumpPage(
        tester,
        ExcelPage(initialMonth: DateTime(2026, 10)),
        [excelServiceProvider.overrideWithValue(service)],
      );
      router = activeRouter;
      await _capture(tester, '${profile.name}-excel-main');

      final pickerGate = Completer<List<PlatformFile>>();
      picker.nextResult = pickerGate;
      await tester.tap(find.byKey(const Key('excel-import-button')));
      await tester.pump();
      expect(find.byKey(const Key('excel-progress')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('excel-progress')),
          matching: find.text('正在选择人员名单文件…'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('excel-export-button')))
            .onPressed,
        isNull,
      );
      await _capture(tester, '${profile.name}-excel-picker-busy');
      pickerGate.complete([await _pickedFile(tester, validFile)]);
      await tester.pump();
      final validPreviewSettled = service.previewSettled;
      expect(validPreviewSettled, isNotNull);
      await validPreviewSettled!.future;
      await tester.pump();
      expect(find.text('校验通过，可导入 1 人'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('excel-confirm-import-button')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        find.byKey(const Key('excel-confirm-import-button')),
        findsOneWidget,
      );
      expect(find.text('正在核验人员名单…'), findsNothing);
      final validButton = find.byKey(const Key('excel-confirm-import-button'));
      await tester.ensureVisible(validButton);
      await tester.pumpAndSettle();
      final validButtonRect = tester.getRect(validButton);
      expect(validButtonRect.top, greaterThanOrEqualTo(0));
      expect(
        validButtonRect.bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      await _capture(tester, '${profile.name}-excel-preview-pass');

      await tester.tap(validButton);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('excel-confirm-import-button')),
            )
            .onPressed,
        isNull,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('excel-progress')), findsOneWidget);
      expect(find.text('正在导入人员…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('excel-confirm-import-button')),
            )
            .onPressed,
        isNull,
      );
      await _capture(tester, '${profile.name}-excel-import-busy');
      service.importGate!.complete();
      await tester.pump();
      final importSettled = service.importSettled;
      expect(importSettled, isNotNull);
      await importSettled!.future;
      await tester.pump();
      expect(find.text('已导入 1 人'), findsOneWidget);
      final employeesAfterImport = await _runAsync(
        tester,
        database.listEmployees,
      );
      expect(
        employeesAfterImport.map((employee) => employee.name),
        contains(employeeName),
      );
      final employeeCountAfterImport = employeesAfterImport.length;
      await _dismissSnackBar(tester);

      picker.result = [await _pickedFile(tester, invalidFile)];
      await tester.tap(find.byKey(const Key('excel-import-button')));
      await tester.pump();
      final invalidPreviewSettled = service.previewSettled;
      expect(invalidPreviewSettled, isNotNull);
      await invalidPreviewSettled!.future;
      await tester.pump();
      expect(find.textContaining('发现 1 个问题'), findsOneWidget);
      expect(find.textContaining('第2行：姓名不能为空'), findsOneWidget);
      final invalidImportButton = tester.widget<FilledButton>(
        find.byKey(const Key('excel-confirm-import-button')),
      );
      expect(invalidImportButton.onPressed, isNull);
      final employeesAfterInvalidPreview = await _runAsync(
        tester,
        database.listEmployees,
      );
      expect(employeesAfterInvalidPreview, hasLength(employeeCountAfterImport));
      expect(
        employeesAfterInvalidPreview.map((employee) => employee.name),
        contains(employeeName),
      );
      final invalidButton = find.byKey(
        const Key('excel-confirm-import-button'),
      );
      await tester.ensureVisible(invalidButton);
      await tester.pumpAndSettle();
      final invalidButtonRect = tester.getRect(invalidButton);
      expect(invalidButtonRect.top, greaterThanOrEqualTo(0));
      expect(
        invalidButtonRect.bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      await _capture(tester, '${profile.name}-excel-preview-error');

      picker.result = [];
      await tester.tap(find.byKey(const Key('excel-import-button')));
      await tester.pump();
      expect(find.textContaining('发现 1 个问题'), findsOneWidget);
      expect(find.byKey(const Key('excel-progress')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('excel-confirm-import-button')),
            )
            .onPressed,
        isNull,
      );
      final employeesAfterPickerCancel = await _runAsync(
        tester,
        database.listEmployees,
      );
      expect(employeesAfterPickerCancel, hasLength(employeeCountAfterImport));
      expect(tester.takeException(), isNull);

      await _unmount(tester, activeRouter);
      routerUnmounted = true;
      await database.close();
      databaseClosed = true;
      FilePickerPlatform.instance = originalPicker;
      pickerRestored = true;
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });

  testWidgets('password dialog scrolls above a large simulated keyboard', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    final root = await _runAsync(
      tester,
      () => Directory.systemTemp.createTemp('qsb-system-tools-'),
    );
    final service = _UiBackupService(database, root);
    addTearDown(() async {
      await database.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    _setPhoneSize(tester, const _PhoneSize('1080x2362', 1080, 2362));
    final router = await _pumpPage(tester, const BackupPage(), [
      backupServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(() => _unmount(tester, router));
    await tester.tap(find.byKey(const Key('backup-create-button')));
    await tester.pump(const Duration(milliseconds: 400));
    final passwordField = find.byKey(const Key('backup-password-field'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 270);
    addTearDown(tester.view.resetViewInsets);
    await tester.showKeyboard(passwordField);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('再次输入密码'), findsOneWidget);
    expect(
      tester.getRect(find.text('继续')).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height - 270),
    );
    await _capture(tester, '1080x2362-backup-password-keyboard');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(service.createCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system tools remain usable at 320dp with 1.3 text scale', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    final root = await _runAsync(
      tester,
      () => Directory.systemTemp.createTemp('qsb-system-tools-'),
    );
    final service = _UiBackupService(database, root);
    addTearDown(() async {
      await database.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    _textScale = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
      _textScale = 1;
    });
    final router = await _pumpPage(tester, const BackupPage(), [
      backupServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(() => _unmount(tester, router));
    await tester.tap(find.byKey(const Key('backup-create-button')));
    await tester.pump(const Duration(milliseconds: 400));
    final password = find.byKey(const Key('backup-password-field'));
    final confirmation = find.byKey(
      const Key('backup-password-confirmation-field'),
    );
    expect(password, findsOneWidget);
    expect(confirmation, findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('backup-password-cancel'))).width,
      tester.getSize(find.byKey(const Key('backup-password-submit'))).width,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 310);
    addTearDown(tester.view.resetViewInsets);
    await tester.showKeyboard(password);
    await tester.ensureVisible(confirmation);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getRect(confirmation).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height - 310),
    );
    expect(
      tester.getRect(find.text('继续')).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height - 310),
    );
    expect(tester.takeException(), isNull);
  });
}

class _PhoneSize {
  const _PhoneSize(this.name, this.width, this.height);

  final String name;
  final int width;
  final int height;
}

void _setPhoneSize(WidgetTester tester, _PhoneSize size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(size.width / 3, size.height / 3);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  _textScale = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
    _textScale = 1;
  });
}

Future<GoRouter> _pumpPage(
  WidgetTester tester,
  Widget page,
  List<Override> overrides,
) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (context, state) => page)],
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          theme: _referenceTheme(AppTheme.light, _font),
          debugShowCheckedModeBanner: false,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(_textScale)),
            child: DesignCanvas(child: child!),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<File> _workbookFile(
  Directory directory,
  String name, {
  required List<String> headers,
  required List<String> row,
}) async {
  final workbook = Excel.createExcel();
  workbook.delete('Sheet1');
  final sheet = workbook['人员名单'];
  sheet.appendRow(headers.map(TextCellValue.new).toList());
  sheet.appendRow(row.map(TextCellValue.new).toList());
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(workbook.encode()!);
  return file;
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureEnabled) return;
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('无法编码截图：$name');
      final directory = Directory(_captureDirectory);
      await directory.create(recursive: true);
      await File('${directory.path}${Platform.pathSeparator}$name.png')
          .writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
    } finally {
      image.dispose();
    }
  });
}

Future<void> _dismissSnackBar(WidgetTester tester) async {
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .hideCurrentSnackBar();
  await tester.pumpAndSettle();
}

class _UiBackupService extends BackupService {
  _UiBackupService(super.database, this.root)
    : super(documentsDirectory: () async => root);

  final Directory root;
  final Completer<File> releaseCreate = Completer<File>();
  int createCount = 0;
  int restoreCount = 0;
  Completer<BackupRestoreResult>? restoreGate;

  @override
  Future<File> createBackup({required String password}) {
    createCount++;
    return releaseCreate.future;
  }

  @override
  Future<BackupRestoreResult> restoreFromFile(
    File backupFile, {
    String? password,
  }) async {
    restoreCount++;
    final gate = restoreGate;
    if (gate != null) return gate.future;
    return BackupRestoreResult(
      safetyBackup: File('${root.path}${Platform.pathSeparator}safety.qsbak'),
    );
  }
}

class _UiExcelService extends ExcelService {
  _UiExcelService(super.database, this.tester);

  final WidgetTester tester;
  Completer<void>? importGate;
  Completer<void>? previewSettled;
  Completer<void>? importSettled;

  @override
  Future<PersonnelImportPreview> previewPersonnelImport(Uint8List bytes) async {
    final settled = previewSettled = Completer<void>();
    try {
      final preview = await tester.runAsync(
        () => super.previewPersonnelImport(bytes),
      );
      if (preview == null) throw StateError('Excel 预览没有返回结果');
      return preview;
    } finally {
      settled.complete();
    }
  }

  @override
  Future<int> importPersonnel(PersonnelImportPreview preview) async {
    await importGate?.future;
    final settled = importSettled = Completer<void>();
    try {
      final imported = await tester.runAsync(
        () => super.importPersonnel(preview),
      );
      if (imported == null) throw StateError('Excel 导入没有返回结果');
      return imported;
    } finally {
      settled.complete();
    }
  }
}

class _TestFilePickerPlatform extends FilePickerPlatform {
  List<PlatformFile> result = [];
  Completer<List<PlatformFile>>? nextResult;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus status)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    final gate = nextResult;
    nextResult = null;
    return gate?.future ?? Future.value(result);
  }
}

final class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile(this.file, this.bytes);

  final File file;
  final Uint8List bytes;

  @override
  String get name => file.uri.pathSegments.last;

  @override
  Uri get uri => file.uri;

  @override
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  int? lengthSync() => file.lengthSync();

  @override
  Future<int> length() => file.length();

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream<Uint8List>.value(bytes);
}

Future<T> _runAsync<T>(
  WidgetTester tester,
  Future<T> Function() operation,
) async {
  final value = await tester.runAsync(operation);
  if (value == null) throw StateError('异步测试操作未返回结果');
  return value;
}

Future<_TestPlatformFile> _pickedFile(WidgetTester tester, File file) async =>
    _TestPlatformFile(file, await _runAsync(tester, file.readAsBytes));

Future<void> _unmount(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  router.dispose();
  await tester.idle();
  await tester.pumpAndSettle();
}

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
    textButtonTheme: TextButtonThemeData(
      style: buttonFont(base.textButtonTheme.style),
    ),
  );
}
