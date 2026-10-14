import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/utils/gallery_image_writer.dart';
import 'package:qingsongban/features/attendance/domain/monthly_attendance_table_options.dart';
import 'package:qingsongban/features/attendance/application/monthly_attendance_table_providers.dart';
import 'package:qingsongban/features/attendance/presentation/monthly_attendance_image.dart';
import 'package:qingsongban/features/attendance/presentation/monthly_attendance_image_preview_page.dart';
import 'package:qingsongban/features/attendance/presentation/monthly_attendance_table_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('qingsongban/file_exports');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> waitForPreview(WidgetTester tester) async {
    final preview = find.byKey(const Key('monthly-attendance-image-preview'));
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (preview.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
    expect(preview, findsOneWidget);
  }

  MonthlyAttendanceTableView table({
    int people = 20,
    String yearMonth = '2026-10',
  }) {
    final month = DateTime.parse('$yearMonth-01');
    final days = DateTime(month.year, month.month + 1, 0).day;
    return MonthlyAttendanceTableView(
      yearMonth: yearMonth,
      daysInMonth: days,
      rows: [
        for (var person = 1; person <= people; person++)
          MonthlyAttendanceTableRow(
            employee: Employee(
              id: person,
              employeeNo: 'EMP-$person',
              name: person == people ? '最后一位姓名较长的工作人员' : '人员$person',
              hireDate: DateTime(2026, 1, 1),
              status: EmployeeStatus.active,
              createdAt: month,
              updatedAt: month,
              isDeleted: false,
            ),
            records: {
              for (var day = 1; day <= days; day++)
                day: AttendanceRecord(
                  id: person * 100 + day,
                  employeeId: person,
                  attendanceDate: DateTime(month.year, month.month, day),
                  morningStatus: AttendanceHalfStatus.present,
                  afternoonStatus: day == days
                      ? AttendanceHalfStatus.leave
                      : AttendanceHalfStatus.present,
                  createdAt: month,
                  updatedAt: month,
                  isDeleted: false,
                ),
            },
          ),
      ],
    );
  }

  test('freezes all 20 people, 31 dates, symbols and existing totals', () {
    final source = table();
    final snapshot = MonthlyAttendanceImageSnapshot(
      groupName: '十月组',
      table: source,
    );
    expect(snapshot.rows, hasLength(20));
    expect(snapshot.rows.last.cells, hasLength(31));
    expect(snapshot.rows.last.cells.last.symbol, '半');
    expect(snapshot.totalAttendanceDays, 610);
    expect(snapshot.totalLeaveDays, 10);
    source.rows.last.addRecord(
      AttendanceRecord(
        id: 9999,
        employeeId: 20,
        attendanceDate: DateTime(2026, 10, 31),
        morningStatus: AttendanceHalfStatus.absent,
        afternoonStatus: AttendanceHalfStatus.absent,
        createdAt: DateTime(2026, 10, 31),
        updatedAt: DateTime(2026, 10, 31),
        isDeleted: false,
      ),
    );
    expect(
      source.rows.last.cellForDay(month: snapshot.month, day: 31).symbol,
      '🔺',
    );
    expect(snapshot.rows.last.cells.last.symbol, '半');
    expect(snapshot.rows.last.attendanceDays, 30.5);
    expect(snapshot.totalAttendanceDays, 610);
  });

  test('uses real month lengths including leap February', () {
    for (final month in ['2026-02', '2028-02', '2026-04']) {
      final snapshot = MonthlyAttendanceImageSnapshot(
        groupName: '组',
        table: table(people: 1, yearMonth: month),
      );
      expect(snapshot.rows.single.cells.length, snapshot.daysInMonth);
      expect(snapshot.rows.single.cells.last.date.month, snapshot.month.month);
    }
  });

  testWidgets('renders a full PNG including final person, day 31 and totals', (
    tester,
  ) async {
    final snapshot = MonthlyAttendanceImageSnapshot(
      groupName: '完整月表测试组',
      table: table(),
    );
    await tester.runAsync(() async {
      final rendered = await MonthlyAttendanceImageRenderer.render(snapshot);
      final codec = await ui.instantiateImageCodec(rendered.bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      expect(image.width, rendered.width);
      expect(image.height, rendered.height);
      expect(image.width, greaterThan(4300));
      expect(image.height, greaterThan(3300));
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final bytes = rgba.buffer.asUint8List();
      // The last person's final-day badge must be drawn, not clipped by a viewport.
      final nameWidth = image.width / 3 - 48 - 31 * 40 - 108;
      final finalDayX = ((24 + nameWidth + 30 * 40 + 20) * 3).round();
      // Table top is 105.2 logical pixels with these single-line title/metadata.
      final finalRowY = ((105.2 + 46 + 19 * 48 + 24) * 3).round();
      final pixel = (finalRowY * image.width + finalDayX) * 4;
      expect(bytes.sublist(pixel, pixel + 3), isNot([255, 255, 255]));
      final totalPixel =
          (((105.2 + 46 + 20 * 48 + 22) * 3).round() * image.width + 75) * 4;
      expect(bytes[totalPixel + 1], greaterThan(bytes[totalPixel]));
      image.dispose();
      codec.dispose();
    });
  });

  testWidgets(
    'preview keeps image on save failure and allows retry without duplicate writes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      Uint8List? originalBytes;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'saveImageToGallery');
        final args = call.arguments as Map<Object?, Object?>;
        expect(args['fileName'], endsWith('.png'));
        expect(args['bytes'], isNotEmpty);
        expect(args['bytes'], originalBytes);
        calls++;
        if (calls == 1) {
          throw PlatformException(
            code: 'GALLERY_SAVE_FAILED',
            message: '保存失败，请重试',
          );
        }
        return 'content://media/external/images/media/42';
      });
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MonthlyAttendanceImagePreviewPage(
              snapshot: MonthlyAttendanceImageSnapshot(
                groupName: '预览组',
                table: table(people: 1),
              ),
            ),
          ),
        );
        await waitForPreview(tester);
      });
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('monthly-attendance-image-preview')),
        findsOneWidget,
      );
      final viewer = find.byKey(const Key('monthly-attendance-image-preview'));
      final previewImage = tester.widget<Image>(
        find.descendant(of: viewer, matching: find.byType(Image)),
      );
      originalBytes = (previewImage.image as MemoryImage).bytes;
      final transform = find
          .descendant(of: viewer, matching: find.byType(Transform))
          .first;
      final initialScale = tester
          .widget<Transform>(transform)
          .transform
          .getMaxScaleOnAxis();
      final center = tester.getCenter(viewer);
      final firstFinger = await tester.startGesture(
        center - const Offset(30, 0),
        pointer: 1,
      );
      final secondFinger = await tester.startGesture(
        center + const Offset(30, 0),
        pointer: 2,
      );
      await tester.pump();
      await firstFinger.moveTo(center - const Offset(80, 0));
      await secondFinger.moveTo(center + const Offset(80, 0));
      await tester.pump();
      expect(
        tester.widget<Transform>(transform).transform.getMaxScaleOnAxis(),
        greaterThan(initialScale),
      );
      await firstFinger.up();
      await secondFinger.up();
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('monthly-attendance-image-save'));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(
        find.byKey(const Key('monthly-attendance-image-preview')),
        findsOneWidget,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('已保存'), findsOneWidget);
      expect(calls, 2);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exports the selected group and disables image export for stale months',
    (tester) async {
      final month = DateTime(2026, 10);
      AttendanceGroup group(int id, String name) => AttendanceGroup(
        id: id,
        name: name,
        groupType: 'manual',
        isEnabled: true,
        sortOrder: id,
        createdAt: month,
        updatedAt: month,
        isDeleted: false,
      );
      final groups = [group(1, '其他分组'), group(2, '当前所选组')];
      Future<void> pumpTable(MonthlyAttendanceTableView value) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              monthlyAttendanceTableMonthProvider.overrideWith((ref) => month),
              monthlyAttendanceTableGroupIdProvider.overrideWith((ref) => 2),
              monthlyAttendanceTableGroupsProvider.overrideWith(
                (ref) => Stream.value(groups),
              ),
              monthlyAttendanceTableProvider.overrideWith(
                (ref) => Stream.value(value),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const MonthlyAttendanceTablePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('monthly-attendance-export')));
        await tester.pumpAndSettle();
      }

      await pumpTable(table(people: 1, yearMonth: '2026-09'));
      final item = find.widgetWithText(PopupMenuItem<String>, '导出图片');
      expect(tester.widget<PopupMenuItem<String>>(item).enabled, isFalse);
      await tester.tapAt(const Offset(20, 400));
      await tester.pumpAndSettle();
      await pumpTable(table());
      expect(tester.widget<PopupMenuItem<String>>(item).enabled, isTrue);
      await tester.runAsync(() async {
        await tester.tap(find.text('导出图片'));
        await tester.pump();
        await waitForPreview(tester);
      });
      await tester.pumpAndSettle();
      final preview = tester.widget<MonthlyAttendanceImagePreviewPage>(
        find.byType(MonthlyAttendanceImagePreviewPage),
      );
      expect(preview.snapshot.groupName, '当前所选组');
      expect(preview.snapshot.yearMonth, '2026-10');
      expect(preview.snapshot.rows, hasLength(20));
      expect(tester.takeException(), isNull);
    },
  );

  test('does not treat an empty native result as a successful save', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    await expectLater(
      GalleryImageWriter.save(
        bytes: Uint8List.fromList([1]),
        fileName: 'test.png',
      ),
      throwsStateError,
    );
  });
}
