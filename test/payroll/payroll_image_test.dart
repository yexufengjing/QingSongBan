import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/payroll/application/payroll_excel_service.dart';
import 'package:qingsongban/features/payroll/domain/payroll_export_snapshot.dart';
import 'package:qingsongban/features/payroll/presentation/payroll_export_page.dart';
import 'package:qingsongban/features/payroll/presentation/payroll_image.dart';
import 'package:qingsongban/features/payroll/presentation/payroll_image_preview_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late PayrollExcelService service;
  const channel = MethodChannel('qingsongban/file_exports');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    database = AppDatabase.forTesting();
    service = PayrollExcelService(database);
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await database.close();
  });

  Future<int> seed({int count = 20}) async {
    final id = await database
        .into(database.payrollBatches)
        .insert(
          PayrollBatchesCompanion.insert(
            payrollMonth: '2026-10',
            name: '十月工资批次',
            employeeCount: Value(count),
            attendanceHalfDaysTotal: Value(count * 3),
            baseWageTotal: Value(count * 185.18),
            subsidyTotal: Value(count * 10.0),
            insuranceDeductionTotal: Value(count * 5.0),
            finalWageTotal: Value(count * 190.18),
          ),
        );
    for (var index = 1; index <= count + 1; index++) {
      final employee = await database
          .into(database.employees)
          .insert(
            EmployeesCompanion.insert(
              employeeNo: 'P-$index',
              name: '当前人员$index',
              hireDate: DateTime(2026, 1),
            ),
          );
      await database
          .into(database.payrollItems)
          .insert(
            PayrollItemsCompanion.insert(
              payrollBatchId: id,
              employeeId: employee,
              displayOrder: index,
              employeeNameSnapshot: index == count
                  ? '最后一名完整姓名超过通常列宽的工作人员'
                  : '快照姓名$index',
              employeeNoSnapshot: 'P-$index',
              jobTypeNameSnapshot: const Value('保洁员'),
              attendanceHalfDaysSnapshot: 3,
              dailyWage: const Value(123.45),
              baseWage: const Value(185.18),
              subsidy: const Value(10),
              insuranceDeduction: const Value(5),
              finalWage: const Value(190.18),
              isManuallyRemoved: Value(index > count),
              remark: Value(
                index == count ? List.filled(15, '完整备注不能被截断。').join() : '普通备注',
              ),
            ),
          );
    }
    return id;
  }

  test('Excel and image use the same ordered 20-person immutable snapshot and formats', () async {
    final id = await seed();
    final snapshot = await service.loadSnapshot(batchId: id);
    expect(snapshot.rows, hasLength(20));
    expect(snapshot.rows.first[1], '快照姓名1');
    expect(snapshot.rows.last[2], 'P-20');
    expect(PayrollExportSnapshot.headers, hasLength(11));
    expect(PayrollExportSnapshot.formatCell(snapshot.rows.first[4], 4), '1.5');
    expect(
      PayrollExportSnapshot.formatCell(snapshot.rows.first[9], 9),
      '190.18',
    );
    expect(PayrollExportSnapshot.formatCell(10, 7), '10.00');
    await database
        .update(database.payrollItems)
        .write(const PayrollItemsCompanion(remark: Value('后来修改')));
    final sheet = Excel.decodeBytes(service.encodeSnapshot(snapshot))['临时工工资'];
    final allRows = [
      PayrollExportSnapshot.headers,
      ...snapshot.rows,
      snapshot.totalRow,
    ];
    expect(sheet.rows.length, 22);
    for (var row = 0; row < allRows.length; row++) {
      for (var col = 0; col < 11; col++) {
        final value = sheet.rows[row][col]?.value;
        final Object actual = switch (value) {
          TextCellValue value => value.value.text ?? '',
          IntCellValue value => value.value,
          DoubleCellValue value => value.value,
          _ => '',
        };
        expect(
          PayrollExportSnapshot.formatCell(actual, col),
          PayrollExportSnapshot.formatCell(allRows[row][col], col),
          reason: 'row $row column $col',
        );
      }
    }
    expect(snapshot.rows.last[10], isNot('后来修改'));
    expect(() => snapshot.rows.first[1] = '修改', throwsUnsupportedError);
    final anotherId = await database
        .into(database.payrollBatches)
        .insert(
          PayrollBatchesCompanion.insert(
            payrollMonth: '2026-09',
            name: '另一个批次',
          ),
        );
    expect((await service.loadSnapshot(batchId: anotherId)).rows, isEmpty);
  });

  testWidgets(
    'renders all 20 people, wrapped names and remarks, all columns and total row',
    (tester) async {
      final id = await seed();
      final snapshot = await service.loadSnapshot(batchId: id);
      await tester.runAsync(() async {
        final image = await PayrollImageRenderer.render(snapshot);
        final codec = await ui.instantiateImageCodec(image.bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, image.width);
        expect(frame.image.height, image.height);
        expect(image.width, greaterThan(4200));
        expect(image.height, greaterThan(3600));
        final data = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        // Bottom total row is tinted blue, followed only by units and page margin.
        final offset = ((image.height - 200) * image.width + 80) * 4;
        expect(data[offset + 2], greaterThan(data[offset]));
        frame.image.dispose();
        codec.dispose();
        await database
            .update(database.payrollItems)
            .write(
              const PayrollItemsCompanion(
                remark: Value('短备注'),
                employeeNameSnapshot: Value('短姓名'),
              ),
            );
        final short = await PayrollImageRenderer.render(
          await service.loadSnapshot(batchId: id),
        );
        expect(image.height, greaterThan(short.height));
      });
    },
  );

  testWidgets(
    'existing preview button opens complete wage image and saves original PNG',
    (tester) async {
      final id = await seed(count: 2);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Uint8List? original;
      var saves = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'saveImageToGallery');
        final args = call.arguments as Map<Object?, Object?>;
        expect(args['bytes'], original);
        expect(args['fileName'], startsWith('工资表_2026-10_十月工资批次_'));
        saves++;
        return 'content://media/external/images/media/1';
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: PayrollExportPage(batchId: id),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.pump();
        await tester.tap(find.byKey(const Key('payroll-preview-button')));
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (find
                .byKey(const Key('payroll-image-preview'))
                .evaluate()
                .isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('工资图片预览'), findsOneWidget);
      final preview = tester.widget<PayrollImagePreviewPage>(
        find.byType(PayrollImagePreviewPage),
      );
      expect(preview.snapshot.rows, hasLength(2));
      final viewer = find.byKey(const Key('payroll-image-preview'));
      original =
          (tester
                      .widget<Image>(
                        find.descendant(
                          of: viewer,
                          matching: find.byType(Image),
                        ),
                      )
                      .image
                  as MemoryImage)
              .bytes;
      await tester.tap(find.byKey(const Key('payroll-image-save')));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.text('已保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty batches keep the export page and show a useful message', (
    tester,
  ) async {
    final id = await seed(count: 0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PayrollExportPage(batchId: id),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.pump();
      await tester.tap(find.byKey(const Key('payroll-preview-button')));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.text('当前工资批次暂无可导出人员').evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pump();
    expect(find.text('当前工资批次暂无可导出人员'), findsOneWidget);
    expect(find.byType(PayrollImagePreviewPage), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('payroll-preview-button')),
          )
          .onPressed,
      isNotNull,
    );
  });
}
