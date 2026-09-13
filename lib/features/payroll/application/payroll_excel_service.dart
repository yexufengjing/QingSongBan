// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../domain/payroll_calculator.dart';

class PayrollExcelService {
  const PayrollExcelService(this._database);

  final AppDatabase _database;

  Future<File> exportToFile({required int batchId}) async {
    final batch = await _findBatch(batchId);
    final directory = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}exports',
    );
    await exportDirectory.create(recursive: true);
    final file = File(
      '${exportDirectory.path}${Platform.pathSeparator}${_fileName(batch.payrollMonth)}',
    );
    await file.writeAsBytes(await exportBytes(batchId: batchId));
    return file;
  }

  Future<Uint8List> exportBytes({required int batchId}) async {
    final batch = await _findBatch(batchId);
    final items =
        await (_database.select(_database.payrollItems)
              ..where(
                (table) =>
                    table.payrollBatchId.equals(batchId) &
                    table.isManuallyRemoved.equals(false),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.displayOrder),
              ]))
            .get();
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['临时工工资'];
    sheet.appendRow(
      _row([
        '序号',
        '姓名',
        '工号',
        '工种',
        '出勤天数',
        '日薪',
        '基础工资',
        '补助',
        '保险扣除',
        '实发工资',
        '备注',
      ]),
    );
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final calculation = PayrollCalculator.calculate(
        attendanceHalfDays: item.attendanceHalfDaysSnapshot,
        dailyWage: item.dailyWage,
        subsidy: item.subsidy,
        insuranceDeduction: item.insuranceDeduction,
      );
      sheet.appendRow(
        _row([
          index + 1,
          item.employeeNameSnapshot,
          item.employeeNoSnapshot,
          item.jobTypeNameSnapshot ?? '',
          calculation.attendanceDays,
          item.dailyWage,
          calculation.baseWage,
          item.subsidy,
          item.insuranceDeduction,
          calculation.finalWage,
          item.remark ?? '',
        ]),
      );
    }
    sheet.appendRow(
      _row([
        '合计',
        '${batch.employeeCount}人',
        '',
        '',
        batch.attendanceHalfDaysTotal / 2,
        '',
        batch.baseWageTotal,
        batch.subsidyTotal,
        batch.insuranceDeductionTotal,
        batch.finalWageTotal,
        '',
      ]),
    );
    _applyNumberFormats(sheet, items.length);
    final encoded = excel.encode();
    if (encoded == null) throw StateError('工资 Excel 生成失败');
    return Uint8List.fromList(encoded);
  }

  String fileNameForMonth(String month) => _fileName(month);

  Future<PayrollBatche> _findBatch(int id) async {
    final batch =
        await (_database.select(_database.payrollBatches)..where(
              (table) => table.id.equals(id) & table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (batch == null) throw StateError('工资批次不存在或已被删除');
    return batch;
  }

  String _fileName(String month) =>
      '${month.substring(0, 4)}年${month.substring(5)}月临时工工资表.xlsx';

  List<CellValue?> _row(List<Object?> values) => values.map(_cell).toList();

  CellValue? _cell(Object? value) {
    if (value == null) return null;
    if (value is int) return IntCellValue(value);
    if (value is double)
      return DoubleCellValue(PayrollCalculator.roundMoney(value));
    return TextCellValue(value.toString());
  }

  void _applyNumberFormats(Sheet sheet, int itemCount) {
    final attendanceFormat = CustomNumericNumFormat(formatCode: '0.0');
    final moneyFormat = NumFormat.standard_2;
    for (var row = 1; row <= itemCount; row++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .cellStyle = CellStyle(
        numberFormat: attendanceFormat,
      );
      for (var column = 5; column <= 9; column++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
            )
            .cellStyle = CellStyle(
          numberFormat: moneyFormat,
        );
      }
    }
    final totalRow = itemCount + 1;
    for (var column = 4; column <= 9; column++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: column, rowIndex: totalRow),
          )
          .cellStyle = CellStyle(
        numberFormat: column == 4 ? attendanceFormat : moneyFormat,
      );
    }
  }
}
