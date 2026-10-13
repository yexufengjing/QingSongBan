// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:excel/excel.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/export_file_writer.dart';
import '../domain/payroll_calculator.dart';
import '../domain/payroll_export_snapshot.dart';

class PayrollExcelService {
  const PayrollExcelService(this._database);

  final AppDatabase _database;

  Future<File> exportToFile({required int batchId}) async {
    final snapshot = await loadSnapshot(batchId: batchId);
    return ExportFileWriter.write(
      fileName: _fileName(snapshot.payrollMonth),
      bytes: encodeSnapshot(snapshot),
    );
  }

  Future<Uint8List> exportBytes({required int batchId}) async {
    return encodeSnapshot(await loadSnapshot(batchId: batchId));
  }

  Future<PayrollExportSnapshot> loadSnapshot({required int batchId}) =>
      _database.transaction(() async {
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
        return PayrollExportSnapshot.fromBatch(batch, items);
      });

  Uint8List encodeSnapshot(PayrollExportSnapshot snapshot) {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['临时工工资'];
    sheet.appendRow(_row(PayrollExportSnapshot.headers));
    for (final row in snapshot.rows) {
      sheet.appendRow(_row(row));
    }
    sheet.appendRow(_row(snapshot.totalRow));
    _applyNumberFormats(sheet, snapshot.rows.length);
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
