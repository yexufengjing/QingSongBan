import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/excel/application/excel_service.dart';

void main() {
  late AppDatabase database;
  late ExcelService service;

  setUp(() async {
    database = AppDatabase.forTesting();
    service = ExcelService(database);
    await database
        .into(database.attendanceGroups)
        .insert(AttendanceGroupsCompanion.insert(name: '白班'));
  });

  tearDown(() => database.close());

  test('exports the agreed workbook sheets', () async {
    final bytes = await service.exportBytes(yearMonth: '2026-09');
    final workbook = Excel.decodeBytes(bytes);

    expect(
      workbook.tables.keys,
      containsAll(<String>[
        '人员名单',
        '月考勤表',
        '月度汇总',
        '请假明细',
        '加班明细',
        '离职记录',
        '人员变动',
        '保险变更',
      ]),
    );
  });

  test(
    'previews personnel rows and rejects duplicates or invalid groups',
    () async {
      final workbook = Excel.createExcel();
      workbook.delete('Sheet1');
      final sheet = workbook['人员名单'];
      sheet.appendRow([
        TextCellValue('工号'),
        TextCellValue('姓名'),
        TextCellValue('身份证号'),
        TextCellValue('手机号'),
        TextCellValue('入职日期'),
        TextCellValue('默认考勤组'),
      ]);
      sheet.appendRow([
        TextCellValue('EMP-0001'),
        TextCellValue('张三'),
        TextCellValue('110101199001011234'),
        TextCellValue('13800000000'),
        TextCellValue('2026-09-01'),
        TextCellValue('白班'),
      ]);
      sheet.appendRow([
        TextCellValue('EMP-0002'),
        TextCellValue('李四'),
        TextCellValue('110101199001011234'),
        TextCellValue('13900000000'),
        TextCellValue('2026-09-01'),
        TextCellValue('不存在'),
      ]);
      final preview = await service.previewPersonnelImport(
        Uint8List.fromList(workbook.encode()!),
      );

      expect(preview.rows, hasLength(1));
      expect(preview.issues, hasLength(1));
      expect(preview.issues.single.message, contains('身份证号重复'));
      expect(preview.issues.single.message, contains('默认考勤组不存在'));
      expect(preview.canImport, isFalse);
    },
  );

  test('imports validated rows and preserves the selected group', () async {
    final workbook = Excel.createExcel();
    workbook.delete('Sheet1');
    final sheet = workbook['人员名单'];
    sheet.appendRow([
      TextCellValue('姓名'),
      TextCellValue('入职日期'),
      TextCellValue('默认考勤组'),
    ]);
    sheet.appendRow([
      TextCellValue('王五'),
      TextCellValue('2026-09-01'),
      TextCellValue('白班'),
    ]);
    final preview = await service.previewPersonnelImport(
      Uint8List.fromList(workbook.encode()!),
    );

    expect(preview.canImport, isTrue);
    expect(await service.importPersonnel(preview), 1);
    final employee = await database.listEmployees();
    expect(employee.single.name, '王五');
    expect(employee.single.defaultAttendanceGroupId, 1);
    expect(
      await database.select(database.attendanceGroupMembers).get(),
      hasLength(1),
    );
  });
}
