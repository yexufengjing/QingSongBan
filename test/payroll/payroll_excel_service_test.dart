import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/payroll/application/payroll_excel_service.dart';

void main() {
  late AppDatabase database;
  late PayrollExcelService service;

  setUp(() {
    database = AppDatabase.forTesting();
    service = PayrollExcelService(database);
  });

  tearDown(() => database.close());

  test(
    'exports ordered Chinese payroll rows, half-days, decimals and totals',
    () async {
      final employeeOne = await database
          .into(database.employees)
          .insert(
            EmployeesCompanion.insert(
              employeeNo: 'EMP-001',
              name: '张三',
              hireDate: DateTime(2026, 9, 1),
            ),
          );
      final employeeTwo = await database
          .into(database.employees)
          .insert(
            EmployeesCompanion.insert(
              employeeNo: 'EMP-002',
              name: '李四',
              hireDate: DateTime(2026, 9, 1),
              status: const Value(EmployeeStatus.terminated),
            ),
          );
      final batchId = await database
          .into(database.payrollBatches)
          .insert(
            PayrollBatchesCompanion.insert(
              payrollMonth: '2026-09',
              name: '2026年09月临时工工资',
              employeeCount: const Value(2),
              attendanceHalfDaysTotal: const Value(3),
              baseWageTotal: const Value(180.0),
              finalWageTotal: const Value(180.0),
            ),
          );
      await database
          .into(database.payrollItems)
          .insert(
            PayrollItemsCompanion.insert(
              payrollBatchId: batchId,
              employeeId: employeeOne,
              displayOrder: 1,
              employeeNameSnapshot: '张三',
              employeeNoSnapshot: 'EMP-001',
              attendanceHalfDaysSnapshot: 2,
              dailyWage: const Value(120),
              baseWage: const Value(120),
              finalWage: const Value(120),
            ),
          );
      await database
          .into(database.payrollItems)
          .insert(
            PayrollItemsCompanion.insert(
              payrollBatchId: batchId,
              employeeId: employeeTwo,
              displayOrder: 0,
              employeeNameSnapshot: '李四',
              employeeNoSnapshot: 'EMP-002',
              attendanceHalfDaysSnapshot: 1,
              dailyWage: const Value(120),
              baseWage: const Value(60),
              finalWage: const Value(60),
            ),
          );

      final workbook = Excel.decodeBytes(
        await service.exportBytes(batchId: batchId),
      );
      final sheet = workbook['临时工工资'];

      expect(
        (sheet.cell(CellIndex.indexByString('B2')).value as TextCellValue)
            .value
            .text,
        '李四',
      );
      expect(_number(sheet.cell(CellIndex.indexByString('E2')).value), 0.5);
      expect(_number(sheet.cell(CellIndex.indexByString('J2')).value), 60.0);
      expect(
        (sheet.cell(CellIndex.indexByString('B3')).value as TextCellValue)
            .value
            .text,
        '张三',
      );
      expect(
        (sheet.cell(CellIndex.indexByString('A4')).value as TextCellValue)
            .value
            .text,
        '合计',
      );
      expect(_number(sheet.cell(CellIndex.indexByString('J4')).value), 180.0);
      expect(
        sheet
            .cell(CellIndex.indexByString('J2'))
            .cellStyle
            ?.numberFormat
            .formatCode,
        '0.00',
      );
      expect(service.fileNameForMonth('2026-09'), '2026年09月临时工工资表.xlsx');
    },
  );
}

double _number(CellValue? value) {
  if (value is IntCellValue) return value.value.toDouble();
  if (value is DoubleCellValue) return value.value;
  throw StateError('expected numeric cell, got $value');
}
