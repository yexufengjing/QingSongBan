import 'dart:io';

import 'package:drift/drift.dart';
import 'package:excel/excel.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/export_file_writer.dart';

class InventoryExportEmptyException implements Exception {
  const InventoryExportEmptyException();

  @override
  String toString() => '暂无可导出的库存业务数据';
}

class InventoryExcelService {
  const InventoryExcelService(this._db);

  final AppDatabase _db;

  Future<File> exportToFile() async {
    final date = DateTime.now();
    final stamp =
        '${date.year}${_two(date.month)}${_two(date.day)}_${_two(date.hour)}${_two(date.minute)}';
    return ExportFileWriter.write(
      fileName: '库存管理_$stamp.xlsx',
      bytes: await exportBytes(),
    );
  }

  /// Creates one workbook containing current stock, receipt, issue, ledger,
  /// stocktake and replenishment sheets.
  Future<Uint8List> exportBytes() async {
    final hasData =
        (await _db.select(_db.inventoryMaterials).get()).isNotEmpty ||
        (await _db.select(_db.inventoryReceipts).get()).isNotEmpty ||
        (await _db.select(_db.inventoryIssues).get()).isNotEmpty ||
        (await _db.select(_db.inventoryTransactions).get()).isNotEmpty ||
        (await _db.select(_db.inventoryStocktakes).get()).isNotEmpty ||
        (await _db.select(_db.inventoryReplenishmentItems).get()).isNotEmpty;
    if (!hasData) throw const InventoryExportEmptyException();
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    await _writeStock(excel['当前库存']);
    await _writeReceipts(excel['入库记录']);
    await _writeIssues(excel['员工领取']);
    await _writeTransactions(excel['库存流水']);
    await _writeStocktakes(excel['盘点记录']);
    await _writeReplenishments(excel['待补充']);
    final bytes = excel.encode();
    if (bytes == null) throw StateError('库存 Excel 文件生成失败');
    return Uint8List.fromList(bytes);
  }

  Future<void> _writeStock(Sheet sheet) async {
    sheet.appendRow(
      _row([
        '物资编码',
        '物资名称',
        '型号',
        '分类',
        '单位',
        '当前库存',
        '最低库存',
        '最高库存',
        '预警',
        '存放位置',
      ]),
    );
    final materials =
        await (_db.select(_db.inventoryMaterials)
              ..where((t) => t.isDeleted.equals(false))
              ..orderBy([(t) => OrderingTerm(expression: t.materialName)]))
            .get();
    final categories = await _db.select(_db.inventoryCategories).get();
    final names = {for (final c in categories) c.id: c.name};
    for (final m in materials) {
      sheet.appendRow(
        _row([
          m.materialCode,
          m.materialName,
          m.modelSpec,
          names[m.categoryId],
          m.unitName,
          m.currentStock,
          m.minStock,
          m.maxStock,
          m.warningEnabled,
          m.storageLocation,
        ]),
      );
    }
  }

  Future<void> _writeReceipts(Sheet sheet) async {
    sheet.appendRow(
      _row(['入库单号', '日期', '类型', '来源', '物资', '型号', '数量', '单位', '单价/分', '备注']),
    );
    final receipts =
        await (_db.select(_db.inventoryReceipts)
              ..where((t) => t.isDeleted.equals(false))
              ..orderBy([(t) => OrderingTerm(expression: t.receiptDate)]))
            .get();
    for (final receipt in receipts) {
      final items = await (_db.select(
        _db.inventoryReceiptItems,
      )..where((t) => t.receiptId.equals(receipt.id))).get();
      for (final item in items) {
        sheet.appendRow(
          _row([
            receipt.receiptNo,
            receipt.receiptDate,
            receipt.receiptType,
            receipt.sourceName,
            item.materialNameSnapshot,
            item.modelSnapshot,
            item.quantity,
            item.unitSnapshot,
            item.referencePriceCent,
            item.remark ?? receipt.remark,
          ]),
        );
      }
    }
  }

  Future<void> _writeIssues(Sheet sheet) async {
    sheet.appendRow(_row(['日期', '物品名称', '型号', '领取数量', '领取人', '备注']));
    final issues =
        await (_db.select(_db.inventoryIssues)
              ..where((t) => t.isDeleted.equals(false))
              ..orderBy([(t) => OrderingTerm(expression: t.issueDate)]))
            .get();
    for (final issue in issues) {
      final items = await (_db.select(
        _db.inventoryIssueItems,
      )..where((t) => t.issueId.equals(issue.id))).get();
      final receiver =
          issue.employeeNameSnapshot ??
          issue.manualReceiverName ??
          issue.departmentNameSnapshot ??
          '公用';
      for (final item in items) {
        sheet.appendRow(
          _row([
            issue.issueDate,
            item.materialNameSnapshot,
            item.modelSnapshot,
            item.quantity,
            receiver,
            item.remark ?? issue.remark,
          ]),
        );
      }
    }
  }

  Future<void> _writeTransactions(Sheet sheet) async {
    sheet.appendRow(
      _row([
        '日期',
        '物资',
        '型号',
        '单位',
        '变化类型',
        '业务来源',
        '变更前',
        '变化数量',
        '变更后',
        '经办人',
        '备注',
      ]),
    );
    final rows = await (_db.select(
      _db.inventoryTransactions,
    )..orderBy([(t) => OrderingTerm(expression: t.occurredAt)])).get();
    for (final row in rows) {
      sheet.appendRow(
        _row([
          row.occurredAt,
          row.materialNameSnapshot,
          row.modelSnapshot,
          row.unitSnapshot,
          row.transactionType,
          row.sourceType,
          row.stockBefore,
          row.quantityChange,
          row.stockAfter,
          row.operatorNameSnapshot,
          row.remark,
        ]),
      );
    }
  }

  Future<void> _writeStocktakes(Sheet sheet) async {
    sheet.appendRow(
      _row(['盘点单号', '日期', '状态', '物资', '型号', '单位', '账面数量', '实盘数量', '差异', '备注']),
    );
    final stocktakes = await _db.select(_db.inventoryStocktakes).get();
    for (final take in stocktakes) {
      final items = await (_db.select(
        _db.inventoryStocktakeItems,
      )..where((t) => t.stocktakeId.equals(take.id))).get();
      for (final item in items) {
        sheet.appendRow(
          _row([
            take.stocktakeNo,
            take.stocktakeDate,
            take.status,
            item.materialNameSnapshot,
            item.modelSnapshot,
            item.unitSnapshot,
            item.bookQuantity,
            item.actualQuantity,
            item.differenceQuantity,
            item.remark ?? take.remark,
          ]),
        );
      }
    }
  }

  Future<void> _writeReplenishments(Sheet sheet) async {
    sheet.appendRow(
      _row([
        '物资',
        '型号',
        '单位',
        '当前库存',
        '最低库存',
        '建议数量',
        '计划数量',
        '补充方式',
        '原因',
        '状态',
        '关联入库单',
        '备注',
      ]),
    );
    final items = await (_db.select(
      _db.inventoryReplenishmentItems,
    )..where((t) => t.isDeleted.equals(false))).get();
    for (final item in items) {
      final receipt = item.linkedReceiptId == null
          ? null
          : await (_db.select(_db.inventoryReceipts)
                  ..where((t) => t.id.equals(item.linkedReceiptId!)))
                .getSingleOrNull();
      sheet.appendRow(
        _row([
          item.materialNameSnapshot,
          item.modelSnapshot,
          item.unitSnapshot,
          item.currentStockSnapshot,
          item.minStockSnapshot,
          item.suggestedQuantity,
          item.plannedQuantity,
          item.replenishMethod,
          item.reason,
          item.status,
          receipt?.receiptNo,
          item.remark,
        ]),
      );
    }
  }

  List<CellValue?> _row(List<Object?> values) => values.map((value) {
    if (value == null) return null;
    if (value is DateTime) return DateTimeCellValue.fromDateTime(value);
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value.toString());
  }).toList();

  String _two(int value) => value.toString().padLeft(2, '0');
}
