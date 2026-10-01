import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/inventory_models.dart';

class InventoryRepository {
  InventoryRepository(this.db);

  final AppDatabase db;

  Future<int> createCategory(String name, {String? remark}) => db
      .into(db.inventoryCategories)
      .insert(
        InventoryCategoriesCompanion.insert(
          name: name.trim(),
          remark: Value(remark),
        ),
      );

  Future<List<InventoryCategory>> getCategories() =>
      (db.select(db.inventoryCategories)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();

  Future<int> createMaterial(InventoryMaterialDraft draft) {
    _requireText(draft.materialCode, '物资编码');
    _requireText(draft.materialName, '物资名称');
    _requireText(draft.unitName, '单位');
    if (draft.minStock < 0 || (draft.maxStock != null && draft.maxStock! < 0)) {
      throw ArgumentError('库存上下限不能小于 0');
    }
    return db
        .into(db.inventoryMaterials)
        .insert(
          InventoryMaterialsCompanion.insert(
            materialCode: draft.materialCode.trim(),
            materialName: draft.materialName.trim(),
            unitName: draft.unitName.trim(),
            categoryId: Value(draft.categoryId),
            modelSpec: Value(draft.modelSpec),
            storageLocation: Value(draft.storageLocation),
            minStock: Value(draft.minStock),
            maxStock: Value(draft.maxStock),
            defaultSource: Value(draft.defaultSource),
            referencePriceCent: Value(draft.referencePriceCent),
            warningEnabled: Value(draft.warningEnabled),
            isCommon: Value(draft.isCommon),
            status: Value(draft.status),
            remark: Value(draft.remark),
          ),
        );
  }

  Future<void> updateMaterial(int id, InventoryMaterialDraft draft) async {
    _requireText(draft.materialCode, '物资编码');
    _requireText(draft.materialName, '物资名称');
    _requireText(draft.unitName, '单位');
    if (draft.minStock < 0 || (draft.maxStock != null && draft.maxStock! < 0)) {
      throw ArgumentError('库存上下限不能小于 0');
    }
    await (db.update(
      db.inventoryMaterials,
    )..where((t) => t.id.equals(id))).write(
      InventoryMaterialsCompanion(
        materialCode: Value(draft.materialCode.trim()),
        materialName: Value(draft.materialName.trim()),
        categoryId: Value(draft.categoryId),
        modelSpec: Value(draft.modelSpec),
        unitName: Value(draft.unitName.trim()),
        storageLocation: Value(draft.storageLocation),
        minStock: Value(draft.minStock),
        maxStock: Value(draft.maxStock),
        defaultSource: Value(draft.defaultSource),
        referencePriceCent: Value(draft.referencePriceCent),
        warningEnabled: Value(draft.warningEnabled),
        isCommon: Value(draft.isCommon),
        status: Value(draft.status),
        remark: Value(draft.remark),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDeleteMaterial(int id) async {
    final material = await getMaterial(id);
    if (material == null) throw StateError('物资不存在或已删除');
    if (material.currentStock != 0) throw StateError('物资仍有库存，不能删除；请先出库或调整至 0');
    await (db.update(
      db.inventoryMaterials,
    )..where((t) => t.id.equals(id))).write(
      InventoryMaterialsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<InventoryMaterial>> getMaterials({String? keyword}) {
    final query = db.select(db.inventoryMaterials)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm(expression: t.materialName)]);
    if (keyword != null && keyword.trim().isNotEmpty) {
      final term = '%${keyword.trim()}%';
      query.where(
        (t) =>
            t.materialName.like(term) |
            t.materialCode.like(term) |
            t.modelSpec.like(term),
      );
    }
    return query.get();
  }

  Future<InventoryMaterial?> getMaterial(int id) =>
      (db.select(db.inventoryMaterials)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .getSingleOrNull();

  Future<List<InventoryStockRow>> getCurrentStock({
    String? keyword,
    int? categoryId,
    InventoryStockStatus? status,
    bool commonOnly = false,
    bool warningsOnly = false,
  }) async {
    final materials = await getMaterials(keyword: keyword);
    final categories = await getCategories();
    final names = {for (final c in categories) c.id: c.name};
    return materials
        .where((m) {
          if (categoryId != null && m.categoryId != categoryId) return false;
          if (commonOnly && !m.isCommon) return false;
          final row = InventoryStockRow(
            material: m,
            categoryName: names[m.categoryId],
          );
          if (warningsOnly &&
              (!m.warningEnabled || m.currentStock > m.minStock)) {
            return false;
          }
          return status == null || row.status == status;
        })
        .map(
          (m) =>
              InventoryStockRow(material: m, categoryName: names[m.categoryId]),
        )
        .toList();
  }

  Future<InventoryOverview> getOverview() async {
    final materials = await getMaterials();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    final receipts =
        await (db.select(db.inventoryReceipts)..where(
              (t) =>
                  t.isDeleted.equals(false) &
                  t.receiptDate.isBiggerOrEqualValue(monthStart) &
                  t.receiptDate.isSmallerThanValue(monthEnd),
            ))
            .get();
    final issues =
        await (db.select(db.inventoryIssues)..where(
              (t) =>
                  t.isDeleted.equals(false) &
                  t.issueDate.isBiggerOrEqualValue(monthStart) &
                  t.issueDate.isSmallerThanValue(monthEnd),
            ))
            .get();
    final pending =
        await (db.select(db.inventoryReplenishmentItems)..where(
              (t) =>
                  t.isDeleted.equals(false) &
                  t.status.isNotIn(['received', 'cancelled']),
            ))
            .get();
    return InventoryOverview(
      totalMaterialCount: materials.length,
      lowStockCount: materials
          .where(
            (m) =>
                m.warningEnabled &&
                m.currentStock > 0 &&
                m.currentStock <= m.minStock,
          )
          .length,
      outOfStockCount: materials.where((m) => m.currentStock == 0).length,
      pendingReplenishmentCount: pending.length,
      monthlyReceiptCount: receipts.length,
      monthlyIssueCount: issues.length,
    );
  }

  Future<int> createReceipt(InventoryReceiptDraft draft) async {
    _requireLines(draft.items.map((item) => item.quantity));
    return db.transaction(() async {
      final now = DateTime.now();
      final receiptId = await db
          .into(db.inventoryReceipts)
          .insert(
            InventoryReceiptsCompanion.insert(
              receiptNo: draft.receiptNo ?? _number('RK'),
              receiptDate: draft.receiptDate,
              receiptType: draft.receiptType,
              sourceName: Value(draft.sourceName),
              operatorId: Value(draft.operatorId),
              operatorNameSnapshot: Value(draft.operatorName),
              remark: Value(draft.remark),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      for (final line in draft.items) {
        final material = await _requireMaterial(line.materialId);
        await db
            .into(db.inventoryReceiptItems)
            .insert(
              InventoryReceiptItemsCompanion.insert(
                receiptId: receiptId,
                materialId: material.id,
                materialNameSnapshot: material.materialName,
                modelSnapshot: Value(material.modelSpec),
                unitSnapshot: material.unitName,
                quantity: line.quantity,
                referencePriceCent: Value(line.referencePriceCent),
                replenishmentId: Value(line.replenishmentId),
                remark: Value(line.remark),
                createdAt: Value(now),
              ),
            );
        await _applyStockChange(
          material,
          line.quantity,
          transactionType: 'receipt',
          sourceType: 'receipt',
          sourceId: receiptId,
          occurredAt: draft.receiptDate,
          operatorId: draft.operatorId,
          operatorName: draft.operatorName,
          remark: line.remark ?? draft.remark,
        );
        if (line.replenishmentId != null) {
          final replenishment =
              await (db.select(db.inventoryReplenishmentItems)..where(
                    (t) =>
                        t.id.equals(line.replenishmentId!) &
                        t.isDeleted.equals(false),
                  ))
                  .getSingleOrNull();
          if (replenishment == null ||
              replenishment.materialId != material.id ||
              replenishment.status == 'cancelled') {
            throw StateError('待补充记录不存在、已取消或物资不匹配');
          }
          await (db.update(
            db.inventoryReplenishmentItems,
          )..where((t) => t.id.equals(replenishment.id))).write(
            InventoryReplenishmentItemsCompanion(
              status: const Value('received'),
              linkedReceiptId: Value(receiptId),
              completedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      }
      return receiptId;
    });
  }

  Future<int> createIssue(InventoryIssueDraft draft) async {
    _requireLines(draft.items.map((item) => item.quantity));
    if (draft.receiverType == 'employee' && draft.employeeId == null) {
      throw ArgumentError('请选择领取员工');
    }
    if (draft.receiverType != 'employee' &&
        (draft.manualReceiverName?.trim().isEmpty ?? true) &&
        draft.receiverType != 'public') {
      throw ArgumentError('请填写领取人或领取对象');
    }
    return db.transaction(() async {
      if (draft.sourceType != null && draft.sourceId != null) {
        final priorIssue =
            await (db.select(db.inventoryIssues)..where(
                  (t) =>
                      t.issueNo.equals(draft.issueNo ?? '福利-${draft.sourceId}'),
                ))
                .getSingleOrNull();
        if (priorIssue != null) return priorIssue.id;
      }
      final now = DateTime.now();
      String? employeeName = draft.employeeName;
      String? departmentName = draft.departmentName;
      if (draft.employeeId != null) {
        final employee = await (db.select(
          db.employees,
        )..where((t) => t.id.equals(draft.employeeId!))).getSingleOrNull();
        if (employee == null || employee.isDeleted) throw StateError('领取员工不存在');
        employeeName ??= employee.name;
        departmentName ??= employee.team ?? employee.workArea;
      }
      final issueId = await db
          .into(db.inventoryIssues)
          .insert(
            InventoryIssuesCompanion.insert(
              issueNo: draft.issueNo ?? _number('CK'),
              issueDate: draft.issueDate,
              issueType: draft.issueType,
              receiverType: draft.receiverType,
              employeeId: Value(draft.employeeId),
              employeeNameSnapshot: Value(employeeName),
              departmentNameSnapshot: Value(departmentName),
              manualReceiverName: Value(draft.manualReceiverName),
              purpose: Value(draft.purpose),
              operatorId: Value(draft.operatorId),
              operatorNameSnapshot: Value(draft.operatorName),
              remark: Value(draft.remark),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      for (final line in draft.items) {
        final material = await _requireMaterial(line.materialId);
        if (material.currentStock < line.quantity) {
          throw StateError(
            '物资“${material.materialName}”库存仅剩 ${material.currentStock}，本次需要 ${line.quantity}',
          );
        }
        await db
            .into(db.inventoryIssueItems)
            .insert(
              InventoryIssueItemsCompanion.insert(
                issueId: issueId,
                materialId: material.id,
                materialNameSnapshot: material.materialName,
                modelSnapshot: Value(material.modelSpec),
                unitSnapshot: material.unitName,
                quantity: line.quantity,
                remark: Value(line.remark),
                createdAt: Value(now),
              ),
            );
        await _applyStockChange(
          material,
          -line.quantity,
          transactionType: 'issue',
          sourceType: draft.sourceType ?? 'issue',
          sourceId: draft.sourceType == null ? issueId : draft.sourceId,
          occurredAt: draft.issueDate,
          operatorId: draft.operatorId,
          operatorName: draft.operatorName,
          remark: line.remark ?? draft.remark,
        );
      }
      return issueId;
    });
  }

  Future<void> adjustStock(
    int materialId,
    double newQuantity, {
    String? remark,
    int? operatorId,
    String? operatorName,
  }) async {
    if (newQuantity < 0) throw ArgumentError('库存不能小于 0');
    await db.transaction(() async {
      final material = await _requireMaterial(materialId);
      await _applyStockChange(
        material,
        newQuantity - material.currentStock,
        transactionType: 'adjustment',
        sourceType: 'adjustment',
        sourceId: null,
        occurredAt: DateTime.now(),
        operatorId: operatorId,
        operatorName: operatorName,
        remark: remark,
      );
    });
  }

  Future<int> createStocktakeDraft(InventoryStocktakeDraft draft) =>
      db.transaction(() async {
        if (draft.items.isEmpty) throw ArgumentError('盘点单至少添加一项物资');
        final now = DateTime.now();
        final id = await db
            .into(db.inventoryStocktakes)
            .insert(
              InventoryStocktakesCompanion.insert(
                stocktakeNo: draft.stocktakeNo ?? _number('PD'),
                stocktakeDate: draft.stocktakeDate,
                operatorId: Value(draft.operatorId),
                operatorNameSnapshot: Value(draft.operatorName),
                remark: Value(draft.remark),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        for (final line in draft.items) {
          final m = await _requireMaterial(line.materialId);
          if (line.actualQuantity < 0) throw ArgumentError('实盘数量不能小于 0');
          await db
              .into(db.inventoryStocktakeItems)
              .insert(
                InventoryStocktakeItemsCompanion.insert(
                  stocktakeId: id,
                  materialId: m.id,
                  materialNameSnapshot: m.materialName,
                  modelSnapshot: Value(m.modelSpec),
                  unitSnapshot: m.unitName,
                  bookQuantity: m.currentStock,
                  actualQuantity: line.actualQuantity,
                  differenceQuantity: line.actualQuantity - m.currentStock,
                  remark: Value(line.remark),
                ),
              );
        }
        return id;
      });

  Future<void> updateStocktakeItem(
    int itemId,
    double actualQuantity, {
    String? remark,
  }) async {
    if (actualQuantity < 0) throw ArgumentError('实盘数量不能小于 0');
    final changed = await db.customUpdate(
      'UPDATE inventory_stocktake_items SET actual_quantity = ?, difference_quantity = ? - book_quantity, remark = ? WHERE id = ? AND stocktake_id IN (SELECT id FROM inventory_stocktakes WHERE status = \'draft\')',
      variables: [
        Variable.withReal(actualQuantity),
        Variable.withReal(actualQuantity),
        Variable.withString(remark ?? ''),
        Variable.withInt(itemId),
      ],
      updates: {db.inventoryStocktakeItems},
    );
    if (changed == 0) throw StateError('盘点明细不存在或盘点已确认');
  }

  Future<void> confirmStocktake(int id) async {
    await db.transaction(() async {
      final stocktake = await (db.select(
        db.inventoryStocktakes,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (stocktake == null || stocktake.status != 'draft') {
        throw StateError('盘点不存在或已处理');
      }
      final items = await (db.select(
        db.inventoryStocktakeItems,
      )..where((t) => t.stocktakeId.equals(id))).get();
      for (final item in items) {
        final material = await _requireMaterial(item.materialId);
        final delta = item.actualQuantity - material.currentStock;
        await (db.update(
          db.inventoryStocktakeItems,
        )..where((t) => t.id.equals(item.id))).write(
          InventoryStocktakeItemsCompanion(
            bookQuantity: Value(material.currentStock),
            differenceQuantity: Value(delta),
          ),
        );
        if (delta != 0) {
          await _applyStockChange(
            material,
            delta,
            transactionType: delta > 0 ? 'stocktake_gain' : 'stocktake_loss',
            sourceType: 'stocktake',
            sourceId: id,
            occurredAt: stocktake.stocktakeDate,
            operatorId: stocktake.operatorId,
            operatorName: stocktake.operatorNameSnapshot,
            remark: item.remark ?? stocktake.remark,
          );
        }
      }
      await (db.update(
        db.inventoryStocktakes,
      )..where((t) => t.id.equals(id))).write(
        InventoryStocktakesCompanion(
          status: const Value('confirmed'),
          confirmedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<int> createReplenishment(InventoryReplenishmentDraft draft) => db
      .into(db.inventoryReplenishmentItems)
      .insert(
        InventoryReplenishmentItemsCompanion.insert(
          materialId: Value(draft.materialId),
          materialNameSnapshot: draft.materialName,
          modelSnapshot: Value(draft.modelSpec),
          unitSnapshot: draft.unitName,
          currentStockSnapshot: draft.currentStock,
          minStockSnapshot: draft.minStock,
          suggestedQuantity: draft.suggestedQuantity,
          plannedQuantity: Value(draft.plannedQuantity),
          replenishMethod: draft.replenishMethod,
          reason: Value(draft.reason),
          remark: Value(draft.remark),
        ),
      );

  Future<void> updateReplenishmentStatus(
    int id,
    String status, {
    double? plannedQuantity,
    String? remark,
  }) async {
    const allowed = {
      'pending',
      'submitted',
      'ordered',
      'received',
      'cancelled',
    };
    if (!allowed.contains(status)) {
      throw ArgumentError.value(status, 'status', '不支持的待补充状态');
    }
    if (plannedQuantity != null && plannedQuantity < 0) {
      throw ArgumentError('计划数量不能小于 0');
    }
    final changed =
        await (db.update(
          db.inventoryReplenishmentItems,
        )..where((t) => t.id.equals(id) & t.isDeleted.equals(false))).write(
          InventoryReplenishmentItemsCompanion(
            status: Value(status),
            plannedQuantity: Value(plannedQuantity),
            remark: Value(remark),
            completedAt: Value(status == 'received' ? DateTime.now() : null),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed == 0) throw StateError('待补充记录不存在');
  }

  Future<int> addWarningToReplenishment(
    int materialId, {
    double? plannedQuantity,
    String replenishMethod = 'central_store',
  }) async {
    final m = await _requireMaterial(materialId);
    final existing =
        await (db.select(db.inventoryReplenishmentItems)..where(
              (t) =>
                  t.materialId.equals(materialId) &
                  t.isDeleted.equals(false) &
                  t.status.isNotIn(['received', 'cancelled']),
            ))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    return createReplenishment(
      InventoryReplenishmentDraft(
        materialId: m.id,
        materialName: m.materialName,
        modelSpec: m.modelSpec,
        unitName: m.unitName,
        currentStock: m.currentStock,
        minStock: m.minStock,
        suggestedQuantity: (m.minStock - m.currentStock).clamp(
          0,
          double.infinity,
        ),
        plannedQuantity: plannedQuantity,
        replenishMethod: replenishMethod,
        reason: '库存预警',
      ),
    );
  }

  Future<List<InventoryReplenishmentItem>> getReplenishments() =>
      (db.select(db.inventoryReplenishmentItems)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .get();

  Future<List<InventoryReceipt>> getReceipts() =>
      (db.select(db.inventoryReceipts)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.receiptDate,
                mode: OrderingMode.desc,
              ),
            ]))
          .get();
  Future<InventoryReceipt?> getReceipt(int id) =>
      (db.select(db.inventoryReceipts)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .getSingleOrNull();
  Future<List<InventoryReceiptItem>> getReceiptItems(int receiptId) =>
      (db.select(
        db.inventoryReceiptItems,
      )..where((t) => t.receiptId.equals(receiptId))).get();
  Future<List<InventoryIssue>> getIssues({int? employeeId}) {
    final query = db.select(db.inventoryIssues)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([
        (t) => OrderingTerm(expression: t.issueDate, mode: OrderingMode.desc),
      ]);
    if (employeeId != null) query.where((t) => t.employeeId.equals(employeeId));
    return query.get();
  }

  Future<InventoryIssue?> getIssue(int id) =>
      (db.select(db.inventoryIssues)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .getSingleOrNull();
  Future<List<InventoryIssueItem>> getIssueItems(int issueId) => (db.select(
    db.inventoryIssueItems,
  )..where((t) => t.issueId.equals(issueId))).get();
  Future<List<InventoryTransaction>> getTransactions({
    int? materialId,
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType,
  }) {
    final query = db.select(db.inventoryTransactions)
      ..orderBy([
        (t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ]);
    if (materialId != null) {
      query.where((t) => t.materialId.equals(materialId));
    }
    if (startDate != null) {
      query.where((t) => t.occurredAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.occurredAt.isSmallerOrEqualValue(endDate));
    }
    if (transactionType != null) {
      query.where((t) => t.transactionType.equals(transactionType));
    }
    return query.get();
  }

  Future<List<InventoryStocktake>> getStocktakes() =>
      (db.select(db.inventoryStocktakes)..orderBy([
            (t) => OrderingTerm(
              expression: t.stocktakeDate,
              mode: OrderingMode.desc,
            ),
          ]))
          .get();
  Future<InventoryStocktake?> getStocktake(int id) => (db.select(
    db.inventoryStocktakes,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<List<InventoryStocktakeItem>> getStocktakeItems(int stocktakeId) =>
      (db.select(
        db.inventoryStocktakeItems,
      )..where((t) => t.stocktakeId.equals(stocktakeId))).get();

  Future<void> deleteReceipt(int receiptId) async {
    await db.transaction(() async {
      final receipt =
          await (db.select(db.inventoryReceipts)..where(
                (t) => t.id.equals(receiptId) & t.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      if (receipt == null) throw StateError('入库单不存在或已删除');
      final items = await (db.select(
        db.inventoryReceiptItems,
      )..where((t) => t.receiptId.equals(receiptId))).get();
      final purchaseEntries =
          await (db.select(db.purchaseStockEntries)..where(
                (t) =>
                    t.inventoryReceiptId.equals(receiptId) &
                    t.isReversed.equals(false),
              ))
              .get();
      for (final item in items) {
        final material = await (db.select(
          db.inventoryMaterials,
        )..where((t) => t.id.equals(item.materialId))).getSingleOrNull();
        if (material == null || material.currentStock < item.quantity) {
          throw StateError('物资“${item.materialNameSnapshot}”当前库存不足以撤销该入库');
        }
      }
      for (final item in items) {
        final material = await (db.select(
          db.inventoryMaterials,
        )..where((t) => t.id.equals(item.materialId))).getSingle();
        await _applyStockChange(
          material,
          -item.quantity,
          transactionType: 'adjustment',
          sourceType: 'receipt_reversal',
          sourceId: receiptId,
          occurredAt: DateTime.now(),
          operatorId: receipt.operatorId,
          operatorName: receipt.operatorNameSnapshot,
          remark: '撤销入库 ${receipt.receiptNo}',
        );
        if (item.replenishmentId != null) {
          await (db.update(
            db.inventoryReplenishmentItems,
          )..where((t) => t.id.equals(item.replenishmentId!))).write(
            InventoryReplenishmentItemsCompanion(
              status: const Value('pending'),
              linkedReceiptId: const Value(null),
              completedAt: const Value(null),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
      for (final entry in purchaseEntries) {
        final purchaseItem = await (db.select(
          db.purchaseRequestItems,
        )..where((t) => t.id.equals(entry.requestItemId))).getSingleOrNull();
        if (purchaseItem == null) {
          throw StateError('采购入库关联明细不存在，无法撤销库存入库');
        }
        final received = purchaseItem.receivedQuantity - entry.quantity;
        if (received < -0.000001) {
          throw StateError('采购累计入库数量小于本次撤销数量');
        }
        final normalizedReceived = received < 0 ? 0.0 : received;
        await (db.update(
          db.purchaseRequestItems,
        )..where((t) => t.id.equals(purchaseItem.id))).write(
          PurchaseRequestItemsCompanion(
            receivedQuantity: Value(normalizedReceived),
            remainingQuantity: Value(
              purchaseItem.requestQuantity - normalizedReceived,
            ),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await (db.update(
          db.purchaseStockEntries,
        )..where((t) => t.id.equals(entry.id))).write(
          PurchaseStockEntriesCompanion(
            isReversed: const Value(true),
            reversedAt: Value(DateTime.now()),
          ),
        );
      }
      for (final requestId
          in purchaseEntries.map((entry) => entry.requestId).toSet()) {
        final request = await (db.select(
          db.purchaseRequests,
        )..where((t) => t.id.equals(requestId))).getSingleOrNull();
        if (request == null) continue;
        final purchaseItems = await (db.select(
          db.purchaseRequestItems,
        )..where((t) => t.requestId.equals(requestId))).get();
        final allReceived = purchaseItems.every(
          (item) => item.remainingQuantity <= 0.000001,
        );
        final nextStatus = request.status == 'cancelled'
            ? 'cancelled'
            : allReceived
            ? 'stocked'
            : 'pending_receive';
        final validEntries =
            await (db.select(db.purchaseStockEntries)..where(
                  (t) =>
                      t.requestId.equals(requestId) &
                      t.isReversed.equals(false),
                ))
                .get();
        final actualCompletedAt = allReceived && validEntries.isNotEmpty
            ? validEntries
                  .map((entry) => entry.stockInDate)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
            : null;
        final now = DateTime.now();
        if (request.status != nextStatus ||
            request.completedAt != actualCompletedAt) {
          await (db.update(
            db.purchaseRequests,
          )..where((t) => t.id.equals(request.id))).write(
            PurchaseRequestsCompanion(
              status: Value(nextStatus),
              completedAt: Value(actualCompletedAt),
              updatedAt: Value(now),
            ),
          );
          if (request.status != nextStatus) {
            await db
                .into(db.purchaseStatusLogs)
                .insert(
                  PurchaseStatusLogsCompanion.insert(
                    requestId: request.id,
                    oldStatus: Value(request.status),
                    newStatus: nextStatus,
                    changedAt: now,
                    remark: const Value('库存入库撤销，采购数量与状态已回写'),
                    createdAt: Value(now),
                  ),
                );
          }
        }
      }
      await (db.update(
        db.inventoryReceipts,
      )..where((t) => t.id.equals(receiptId))).write(
        InventoryReceiptsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> deleteIssue(int issueId) async {
    await db.transaction(() async {
      final issue =
          await (db.select(
                db.inventoryIssues,
              )..where((t) => t.id.equals(issueId) & t.isDeleted.equals(false)))
              .getSingleOrNull();
      if (issue == null) throw StateError('出库单不存在或已删除');
      final items = await (db.select(
        db.inventoryIssueItems,
      )..where((t) => t.issueId.equals(issueId))).get();
      for (final item in items) {
        final material = await (db.select(
          db.inventoryMaterials,
        )..where((t) => t.id.equals(item.materialId))).getSingleOrNull();
        if (material == null) {
          throw StateError('物资“${item.materialNameSnapshot}”不存在');
        }
        await _applyStockChange(
          material,
          item.quantity,
          transactionType: 'adjustment',
          sourceType: 'issue_reversal',
          sourceId: issueId,
          occurredAt: DateTime.now(),
          operatorId: issue.operatorId,
          operatorName: issue.operatorNameSnapshot,
          remark: '撤销出库 ${issue.issueNo}',
        );
      }
      await (db.update(
        db.inventoryIssues,
      )..where((t) => t.id.equals(issueId))).write(
        InventoryIssuesCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<List<InventoryEmployeeHistoryItem>> getEmployeeMaterialHistory(
    int employeeId,
  ) async {
    final issues = await getIssues(employeeId: employeeId);
    final result = <InventoryEmployeeHistoryItem>[];
    for (final issue in issues) {
      final items = await (db.select(
        db.inventoryIssueItems,
      )..where((t) => t.issueId.equals(issue.id))).get();
      result.addAll(
        items.map(
          (item) => InventoryEmployeeHistoryItem(issue: issue, item: item),
        ),
      );
    }
    return result;
  }

  Future<int> issueWelfareDistribution(int distributionEntryId) async {
    final entry = await db
        .customSelect(
          '''SELECT e.*, b.benefit_month FROM item_distribution_entries e
      JOIN item_distribution_batches b ON b.id = e.batch_id
      WHERE e.id = ? AND e.is_deleted = 0 AND e.status = 'received' AND b.is_deleted = 0''',
          variables: [Variable.withInt(distributionEntryId)],
        )
        .getSingleOrNull();
    if (entry == null) throw StateError('未找到已实际发放的福利记录');
    final data = entry.data;
    final existingIssues =
        await (db.select(db.inventoryIssues)..where(
              (t) =>
                  t.isDeleted.equals(false) &
                  t.issueNo.like('福利-$distributionEntryId-%'),
            ))
            .get();
    if (existingIssues.isNotEmpty) return existingIssues.first.id;
    final itemCode = (data['item_code'] as String? ?? '').trim();
    var materialRows = itemCode.isEmpty
        ? <InventoryMaterial>[]
        : await (db.select(db.inventoryMaterials)..where(
                (t) =>
                    t.isDeleted.equals(false) & t.materialCode.equals(itemCode),
              ))
              .get();
    if (materialRows.isEmpty) {
      materialRows =
          await (db.select(db.inventoryMaterials)..where(
                (t) =>
                    t.isDeleted.equals(false) &
                    t.materialName.equals(data['item_name'] as String),
              ))
              .get();
    }
    if (materialRows.length != 1) {
      throw StateError(materialRows.isEmpty ? '福利物品未关联库存物资' : '福利物品匹配到多个库存物资');
    }
    final material = materialRows.single;
    return createIssue(
      InventoryIssueDraft(
        issueDate:
            DateTime.tryParse(data['signed_at'] as String? ?? '') ??
            DateTime.now(),
        issueType: 'employee_distribution',
        receiverType: data['employee_id'] == null ? 'manual' : 'employee',
        items: [
          InventoryIssueLineDraft(
            materialId: material.id,
            quantity: (data['quantity'] as num).toDouble(),
          ),
        ],
        issueNo:
            '福利-$distributionEntryId-${DateTime.now().microsecondsSinceEpoch}',
        employeeId: data['employee_id'] as int?,
        employeeName: data['recipient_name'] as String?,
        manualReceiverName: data['recipient_name'] as String?,
        purpose: '劳保福利实际发放',
        remark: data['note'] as String?,
        sourceType: 'item_distribution',
        sourceId: distributionEntryId,
      ),
    );
  }

  Future<void> cancelWelfareDistribution(int distributionEntryId) async {
    await db.transaction(() async {
      final issue =
          await (db.select(db.inventoryIssues)..where(
                (t) =>
                    t.issueNo.like('福利-$distributionEntryId-%') &
                    t.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      if (issue != null) await deleteIssue(issue.id);
    });
  }

  Future<InventoryMaterial> _requireMaterial(int id) async {
    final material = await getMaterial(id);
    if (material == null) throw StateError('物资不存在或已停用');
    if (material.status != 'active') throw StateError('物资已停用或淘汰，不能办理新的库存业务');
    return material;
  }

  Future<void> _applyStockChange(
    InventoryMaterial material,
    double change, {
    required String transactionType,
    required String sourceType,
    required int? sourceId,
    required DateTime occurredAt,
    int? operatorId,
    String? operatorName,
    String? remark,
  }) async {
    final after = material.currentStock + change;
    if (after < 0) throw StateError('库存不足，无法出库');
    await (db.update(
      db.inventoryMaterials,
    )..where((t) => t.id.equals(material.id))).write(
      InventoryMaterialsCompanion(
        currentStock: Value(after),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await db
        .into(db.inventoryTransactions)
        .insert(
          InventoryTransactionsCompanion.insert(
            materialId: material.id,
            materialNameSnapshot: material.materialName,
            modelSnapshot: Value(material.modelSpec),
            unitSnapshot: material.unitName,
            occurredAt: occurredAt,
            transactionType: transactionType,
            sourceType: sourceType,
            sourceId: Value(sourceId),
            stockBefore: material.currentStock,
            quantityChange: change,
            stockAfter: after,
            operatorId: Value(operatorId),
            operatorNameSnapshot: Value(operatorName),
            remark: Value(remark),
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  void _requireLines(Iterable<double> quantities) {
    if (quantities.isEmpty) throw ArgumentError('至少添加一条物资明细');
    if (quantities.any((q) => !q.isFinite || q <= 0)) {
      throw ArgumentError('数量必须大于 0');
    }
  }

  void _requireText(String value, String field) {
    if (value.trim().isEmpty) throw ArgumentError('$field不能为空');
  }

  String _number(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
