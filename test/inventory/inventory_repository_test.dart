import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/inventory/application/inventory_excel_service.dart';
import 'package:qingsongban/features/inventory/application/inventory_providers.dart';
import 'package:qingsongban/features/inventory/data/inventory_repository.dart';
import 'package:qingsongban/features/inventory/domain/inventory_models.dart';

void main() {
  late AppDatabase db;
  late InventoryRepository inventory;

  setUp(() {
    db = AppDatabase.forTesting();
    inventory = InventoryRepository(db);
  });

  tearDown(() async => db.close());

  test('validates material basics, rejects duplicate codes, and supports fractional stock', () async {
    expect(
      () => inventory.createMaterial(
        const InventoryMaterialDraft(
          materialCode: 'EMPTY-NAME',
          materialName: '  ',
          unitName: '件',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => inventory.createMaterial(
        const InventoryMaterialDraft(
          materialCode: 'EMPTY-UNIT',
          materialName: '物资',
          unitName: ' ',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => inventory.createMaterial(
        const InventoryMaterialDraft(
          materialCode: 'NEGATIVE-MIN',
          materialName: '物资',
          unitName: '米',
          minStock: -0.1,
        ),
      ),
      throwsArgumentError,
    );
    final id = await _material(inventory, code: 'METER', name: '电缆', unit: '米');
    await expectLater(
      _material(inventory, code: 'METER', name: '重复编码', unit: '件'),
      throwsA(isA<Exception>()),
    );
    await inventory.adjustStock(id, 2.75);
    expect((await inventory.getMaterial(id))!.currentStock, 2.75);
  });

  test('multi-line receipt and issue failures roll back headers, stock, and ledger', () async {
    final first = await _material(inventory, code: 'A', name: '物资甲');
    final second = await _material(inventory, code: 'B', name: '物资乙');

    await expectLater(
      inventory.createReceipt(
        InventoryReceiptDraft(
          receiptDate: DateTime(2026, 9, 1),
          receiptType: 'central_store',
          items: [
            InventoryReceiptLineDraft(materialId: first, quantity: 3),
            const InventoryReceiptLineDraft(materialId: -100, quantity: 1),
          ],
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await inventory.getReceipts(), isEmpty);
    expect((await inventory.getMaterial(first))!.currentStock, 0);
    expect(await inventory.getTransactions(), isEmpty);

    await inventory.createReceipt(
      InventoryReceiptDraft(
        receiptDate: DateTime(2026, 9, 1),
        receiptType: 'central_store',
        items: [
          InventoryReceiptLineDraft(materialId: first, quantity: 3),
          InventoryReceiptLineDraft(materialId: second, quantity: 1.5),
        ],
      ),
    );
    final baselineTransactions = await inventory.getTransactions();
    await expectLater(
      inventory.createIssue(
        InventoryIssueDraft(
          issueDate: DateTime(2026, 9, 2),
          issueType: 'manual',
          receiverType: 'manual',
          manualReceiverName: '临时人员',
          items: [
            InventoryIssueLineDraft(materialId: first, quantity: 1),
            InventoryIssueLineDraft(materialId: second, quantity: 2),
          ],
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await inventory.getIssues(), isEmpty);
    expect((await inventory.getMaterial(first))!.currentStock, 3);
    expect((await inventory.getMaterial(second))!.currentStock, 1.5);
    expect(
      await inventory.getTransactions(),
      hasLength(baselineTransactions.length),
    );
  });

  test(
    'receives multiple lines atomically and writes snapshot ledger rows',
    () async {
      final glove = await _material(
        inventory,
        code: 'G1',
        name: '手套',
        unit: '副',
      );
      final soap = await _material(
        inventory,
        code: 'S1',
        name: '洗手液',
        unit: '瓶',
      );
      final receiptId = await inventory.createReceipt(
        InventoryReceiptDraft(
          receiptDate: DateTime(2026, 9, 1),
          receiptType: 'central_store',
          sourceName: '总库',
          items: [
            InventoryReceiptLineDraft(materialId: glove, quantity: 4),
            InventoryReceiptLineDraft(materialId: soap, quantity: 2.5),
          ],
        ),
      );

      expect((await inventory.getMaterial(glove))!.currentStock, 4);
      expect((await inventory.getMaterial(soap))!.currentStock, 2.5);
      final receipt = await inventory.getReceipt(receiptId);
      expect(receipt, isNotNull);
      expect(
        (await inventory.getReceiptItems(receiptId))
            .map((e) => e.materialNameSnapshot),
        ['手套', '洗手液'],
      );
      final tx = await inventory.getTransactions();
      expect(tx, hasLength(2));
      expect(tx.map((e) => e.stockBefore).toSet(), {0});
      expect(tx.map((e) => e.quantityChange).toSet(), {4, 2.5});
      expect(tx.map((e) => e.stockAfter).toSet(), {4, 2.5});
    },
  );

  test(
    'rejects invalid and overstock issues and permits issue to exactly zero',
    () async {
      final id = await _material(inventory, code: 'G1', name: '手套');
      await inventory.createReceipt(_receipt(id, 3));
      final employeeId = await db
          .into(db.employees)
          .insert(
            EmployeesCompanion.insert(
              employeeNo: 'E1',
              name: '李明',
              hireDate: DateTime(2020),
              team: const Value('绿化组'),
            ),
          );
      Future<int> createEmployeeIssue(double quantity) => inventory.createIssue(
        InventoryIssueDraft(
          issueDate: DateTime(2026, 9, 2),
          issueType: 'employee',
          receiverType: 'employee',
          employeeId: employeeId,
          items: [InventoryIssueLineDraft(materialId: id, quantity: quantity)],
        ),
      );
      await expectLater(createEmployeeIssue(4), throwsA(isA<StateError>()));
      expect((await inventory.getMaterial(id))!.currentStock, 3);
      final issueId = await createEmployeeIssue(3);
      final createdIssue = await inventory.getIssue(issueId);
      expect(createdIssue!.employeeNameSnapshot, '李明');
      expect(createdIssue.departmentNameSnapshot, '绿化组');
      expect((await inventory.getMaterial(id))!.currentStock, 0);
      expect((await inventory.getTransactions()).first.quantityChange, -3);
    },
  );

  test(
    'preserves material and employee snapshots and exposes employee history',
    () async {
      final id = await _material(inventory, code: 'G1', name: '旧手套', unit: '副');
      await inventory.createReceipt(_receipt(id, 2));
      final employeeId = await db
          .into(db.employees)
          .insert(
            EmployeesCompanion.insert(
              employeeNo: 'E1',
              name: '王芳',
              hireDate: DateTime(2020),
              team: const Value('一组'),
            ),
          );
      await inventory.createIssue(
        InventoryIssueDraft(
          issueDate: DateTime(2026, 9, 3),
          issueType: 'employee',
          receiverType: 'employee',
          employeeId: employeeId,
          items: [InventoryIssueLineDraft(materialId: id, quantity: 1)],
        ),
      );
      await inventory.updateMaterial(
        id,
        const InventoryMaterialDraft(
          materialCode: 'G1',
          materialName: '新手套',
          unitName: '盒',
        ),
      );

      final history = await inventory.getEmployeeMaterialHistory(employeeId);
      expect(history.single.item.materialNameSnapshot, '旧手套');
      expect(history.single.issue.employeeNameSnapshot, '王芳');
      expect(history.single.issue.departmentNameSnapshot, '一组');
      expect(
        (await inventory.getTransactions()).first.materialNameSnapshot,
        '旧手套',
      );
    },
  );

  test('manual adjustment creates a signed ledger entry and rejects negative stock', () async {
    final id = await _material(inventory, code: 'G1', name: '手套');
    await inventory.adjustStock(id, 8, remark: '初始盘点');
    await inventory.adjustStock(id, 6.5, remark: '实物修正');
    expect((await inventory.getMaterial(id))!.currentStock, 6.5);
    final rows = await inventory.getTransactions();
    expect(rows.map((e) => e.quantityChange).toSet(), {8, -1.5});
    expect(rows.first.remark, '实物修正');
    await expectLater(inventory.adjustStock(id, -1), throwsArgumentError);
  });

  test(
    'stocktake draft confirmation applies gains and losses through the ledger',
    () async {
      final gainId = await _material(inventory, code: 'A', name: '盘盈物资');
      final lossId = await _material(inventory, code: 'B', name: '盘亏物资');
      await inventory.adjustStock(lossId, 5);
      final stocktakeId = await inventory.createStocktakeDraft(
        InventoryStocktakeDraft(
          stocktakeDate: DateTime(2026, 9, 5),
          items: [
            InventoryStocktakeLineDraft(materialId: gainId, actualQuantity: 3),
            InventoryStocktakeLineDraft(materialId: lossId, actualQuantity: 2),
          ],
        ),
      );
      await inventory.confirmStocktake(stocktakeId);
      expect((await inventory.getStocktake(stocktakeId))!.status, 'confirmed');
      expect((await inventory.getMaterial(gainId))!.currentStock, 3);
      expect((await inventory.getMaterial(lossId))!.currentStock, 2);
      final stocktakeTx = (await inventory.getTransactions())
          .where((e) => e.sourceType == 'stocktake')
          .toList();
      expect(stocktakeTx.map((e) => e.transactionType).toSet(), {
        'stocktake_gain',
        'stocktake_loss',
      });
      expect(
        (await inventory.getStocktakeItems(stocktakeId))
            .map((e) => e.differenceQuantity),
        [3, -3],
      );
    },
  );

  test(
    'warning boundaries, disabled warning, and zero-stock status are distinct',
    () async {
      final low = await _material(
        inventory,
        code: 'L',
        name: '低库存',
        minStock: 2,
      );
      final disabled = await _material(
        inventory,
        code: 'D',
        name: '关闭预警',
        minStock: 2,
        warningEnabled: false,
      );
      final normal = await _material(
        inventory,
        code: 'N',
        name: '正常库存',
        minStock: 2,
      );
      await inventory.adjustStock(low, 2);
      await inventory.adjustStock(disabled, 1);
      await inventory.adjustStock(normal, 2.01);
      final warningsWithoutStatusFilter = await inventory.getCurrentStock(
        warningsOnly: true,
      );
      expect(warningsWithoutStatusFilter.map((e) => e.material.id), [low]);
      final warningRows = await inventory.getCurrentStock(
        warningsOnly: true,
        status: InventoryStockStatus.low,
      );
      expect(warningRows.map((e) => e.material.id), [low]);
      final disabledRow = (await inventory.getCurrentStock()).singleWhere(
        (e) => e.material.id == disabled,
      );
      expect(disabledRow.status, InventoryStockStatus.low);
      await inventory.adjustStock(low, 0);
      final zeroRow = (await inventory.getCurrentStock()).singleWhere(
        (e) => e.material.id == low,
      );
      expect(zeroRow.status, InventoryStockStatus.outOfStock);
      expect(
        (await inventory.getCurrentStock(warningsOnly: true))
            .map((e) => e.material.id),
        [low],
      );
    },
  );

  test('warning replenishment deduplicates, linked receipt completes, and delete reverses stock', () async {
    final id = await _material(inventory, code: 'G1', name: '手套', minStock: 5);
    final replenishmentId = await inventory.addWarningToReplenishment(
      id,
      plannedQuantity: 6,
    );
    expect(await inventory.addWarningToReplenishment(id), replenishmentId);
    expect((await inventory.getOverview()).pendingReplenishmentCount, 1);
    await inventory.createReceipt(
      InventoryReceiptDraft(
        receiptDate: DateTime(2026, 9, 6),
        receiptType: 'central_store',
        items: [
          InventoryReceiptLineDraft(
            materialId: id,
            quantity: 4,
            replenishmentId: replenishmentId,
          ),
        ],
      ),
    );
    final replenishment = (await inventory.getReplenishments()).single;
    expect(replenishment.status, 'received');
    expect(replenishment.linkedReceiptId, isNotNull);
    final receipt = (await inventory.getReceipts()).single;
    await inventory.deleteReceipt(receipt.id);
    expect((await inventory.getMaterial(id))!.currentStock, 0);
    expect((await inventory.getReplenishments()).single.status, 'pending');
    expect(
      (await inventory.getTransactions()).first.sourceType,
      'receipt_reversal',
    );
  });

  test(
    'deleting issue restores stock and soft-deletes its business record',
    () async {
      final id = await _material(inventory, code: 'G1', name: '手套');
      await inventory.createReceipt(_receipt(id, 3));
      final issueId = await inventory.createIssue(
        InventoryIssueDraft(
          issueDate: DateTime(2026, 9, 7),
          issueType: 'manual',
          receiverType: 'manual',
          manualReceiverName: '临时人员',
          items: [InventoryIssueLineDraft(materialId: id, quantity: 2)],
        ),
      );
      await inventory.deleteIssue(issueId);
      expect((await inventory.getMaterial(id))!.currentStock, 3);
      expect(await inventory.getIssue(issueId), isNull);
      expect(
        (await inventory.getTransactions()).first.sourceType,
        'issue_reversal',
      );
    },
  );

  test(
    'warning provider includes enabled low and out-of-stock materials only',
    () async {
      final low = await _material(
        inventory,
        code: 'LOW',
        name: '低库存',
        minStock: 2,
      );
      final out = await _material(
        inventory,
        code: 'OUT',
        name: '缺货',
        minStock: 0,
      );
      final normal = await _material(
        inventory,
        code: 'NORMAL',
        name: '正常库存',
        minStock: 2,
      );
      final disabled = await _material(
        inventory,
        code: 'DISABLED',
        name: '关闭预警',
        minStock: 2,
        warningEnabled: false,
      );
      await inventory.adjustStock(low, 2);
      await inventory.adjustStock(normal, 2.1);
      await inventory.adjustStock(disabled, 1);

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final warnings = await container.read(inventoryWarningsProvider.future);
      expect(warnings.map((row) => row.material.id).toSet(), {low, out});
    },
  );

  test(
    'refuses receipt deletion when later issues consumed its stock',
    () async {
      final id = await _material(inventory, code: 'G1', name: '手套');
      final receiptId = await inventory.createReceipt(_receipt(id, 3));
      await inventory.createIssue(
        InventoryIssueDraft(
          issueDate: DateTime(2026, 9, 2),
          issueType: 'manual',
          receiverType: 'manual',
          manualReceiverName: '临时人员',
          items: [InventoryIssueLineDraft(materialId: id, quantity: 2)],
        ),
      );
      final beforeTransactions = await inventory.getTransactions();

      await expectLater(
        inventory.deleteReceipt(receiptId),
        throwsA(isA<StateError>()),
      );

      expect((await inventory.getMaterial(id))!.currentStock, 1);
      expect(await inventory.getReceipt(receiptId), isNotNull);
      expect(
        await inventory.getTransactions(),
        hasLength(beforeTransactions.length),
      );
    },
  );

  test('refuses to remove in-use stock and prevents transactions on inactive materials', () async {
    final id = await _material(inventory, code: 'G1', name: '手套');
    await inventory.adjustStock(id, 1);
    await expectLater(
      inventory.softDeleteMaterial(id),
      throwsA(isA<StateError>()),
    );
    await inventory.adjustStock(id, 0);
    await inventory.softDeleteMaterial(id);
    expect(await inventory.getMaterial(id), isNull);
    final inactive = await _material(
      inventory,
      code: 'X',
      name: '停用物资',
      status: 'stopped',
    );
    await expectLater(
      inventory.createReceipt(_receipt(inactive, 1)),
      throwsA(isA<StateError>()),
    );
    expect((await inventory.getMaterial(inactive))!.currentStock, 0);
  });

  test(
    'exports one six-sheet workbook and identifies a completely empty export',
    () async {
      final exporter = InventoryExcelService(db);
      await expectLater(
        exporter.exportBytes(),
        throwsA(isA<InventoryExportEmptyException>()),
      );
      final id = await _material(inventory, code: 'G1', name: '手套');
      await inventory.createReceipt(_receipt(id, 3));
      final bytes = await exporter.exportBytes();
      expect(bytes, isA<Uint8List>());
      final workbook = Excel.decodeBytes(bytes);
      expect(
        workbook.tables.keys,
        containsAll(['当前库存', '入库记录', '员工领取', '库存流水', '盘点记录', '待补充']),
      );
      expect(workbook.tables['当前库存']!.maxRows, 2);
    },
  );
}

Future<int> _material(
  InventoryRepository inventory, {
  required String code,
  required String name,
  String unit = '件',
  double minStock = 0,
  bool warningEnabled = true,
  String status = 'active',
}) => inventory.createMaterial(
  InventoryMaterialDraft(
    materialCode: code,
    materialName: name,
    unitName: unit,
    minStock: minStock,
    warningEnabled: warningEnabled,
    status: status,
  ),
);

InventoryReceiptDraft _receipt(int materialId, double quantity) =>
    InventoryReceiptDraft(
      receiptDate: DateTime(2026, 9, 1),
      receiptType: 'central_store',
      items: [
        InventoryReceiptLineDraft(materialId: materialId, quantity: quantity),
      ],
    );
