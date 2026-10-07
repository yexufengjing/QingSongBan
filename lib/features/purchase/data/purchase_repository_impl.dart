import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../reminders/data/reminder_repository.dart';
import '../domain/purchase_models.dart';
import '../domain/purchase_status.dart';
import 'purchase_repository.dart';

class PurchaseRepositoryImpl implements PurchaseRepository {
  PurchaseRepositoryImpl(this._db)
    : _inventory = InventoryRepository(_db),
      _reminders = ReminderRepository(_db);

  final AppDatabase _db;
  final InventoryRepository _inventory;
  final ReminderRepository _reminders;

  Set<TableInfo> get _watchedTables => {
    _db.purchaseRequests,
    _db.purchaseRequestItems,
    _db.purchaseStatusLogs,
    _db.purchaseStockEntries,
    _db.inventoryMaterials,
    _db.inventoryTransactions,
    _db.inventoryReceipts,
    _db.reminders,
  };

  @override
  Future<int> createPurchaseRequest(CreatePurchaseRequestInput input) async {
    _validateRequest(input.title, input.items);
    return _db.transaction(() async {
      final now = DateTime.now();
      final requestId = await _db
          .into(_db.purchaseRequests)
          .insert(
            PurchaseRequestsCompanion.insert(
              title: input.title.trim(),
              status: const Value('pending_apply'),
              requestDate: Value(input.requestDate ?? now),
              demandReason: Value(_clean(input.demandReason)),
              remark: Value(_clean(input.remark)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      for (final item in input.items) {
        await _db
            .into(_db.purchaseRequestItems)
            .insert(
              PurchaseRequestItemsCompanion.insert(
                requestId: requestId,
                inventoryMaterialId: Value(item.inventoryMaterialId),
                itemName: item.itemName.trim(),
                specification: Value(_clean(item.specification)),
                unit: item.unit.trim(),
                currentStockSnapshot: Value(item.currentStockSnapshot),
                requestQuantity: item.requestQuantity,
                remainingQuantity: item.requestQuantity,
                remark: Value(_clean(item.remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
      await _writeStatusLog(
        requestId,
        oldStatus: null,
        newStatus: PurchaseStatus.pendingApply,
        at: now,
        remark: '创建采购记录',
      );
      return requestId;
    });
  }

  @override
  Future<void> updatePurchaseRequest(
    int requestId,
    UpdatePurchaseRequestInput input,
  ) async {
    _validateRequest(input.title, input.items);
    await _db.transaction(() async {
      await _requireRequest(requestId);
      final oldItems = await _itemsForRequest(requestId);
      final oldEntries = await (_db.select(
        _db.purchaseStockEntries,
      )..where((t) => t.requestId.equals(requestId))).get();
      if (oldEntries.isNotEmpty) {
        throw const PurchaseException(
          PurchaseFailureCode.invalidState,
          '采购已产生库存入库记录，不能直接重写采购明细',
        );
      }
      final now = DateTime.now();
      await _writeMetadata(
        requestId,
        UpdatePurchaseMetadataInput(
          title: input.title,
          requestDate: input.requestDate,
          appliedDate: input.appliedDate,
          oaRequestNo: input.oaRequestNo,
          oaTitle: input.oaTitle,
          oaUrl: input.oaUrl,
          purchaseDepartment: input.purchaseDepartment,
          purchaserName: input.purchaserName,
          assignedDate: input.assignedDate,
          arrivalNoticeDate: input.arrivalNoticeDate,
          receiveLocation: input.receiveLocation,
          demandReason: input.demandReason,
          remark: input.remark,
        ),
        now,
      );
      for (final item in oldItems) {
        await (_db.delete(
          _db.purchaseRequestItems,
        )..where((t) => t.id.equals(item.id))).go();
      }
      for (final item in input.items) {
        await _db
            .into(_db.purchaseRequestItems)
            .insert(
              PurchaseRequestItemsCompanion.insert(
                requestId: requestId,
                inventoryMaterialId: Value(item.inventoryMaterialId),
                itemName: item.itemName.trim(),
                specification: Value(_clean(item.specification)),
                unit: item.unit.trim(),
                currentStockSnapshot: Value(item.currentStockSnapshot),
                requestQuantity: item.requestQuantity,
                remainingQuantity: item.requestQuantity,
                remark: Value(_clean(item.remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
      // The metadata edit intentionally preserves the state and timeline.
    });
  }

  @override
  Future<void> updatePurchaseMetadata(
    int requestId,
    UpdatePurchaseMetadataInput input,
  ) async {
    if (input.title.trim().isEmpty) {
      throw const PurchaseException(
        PurchaseFailureCode.invalidInput,
        '采购事项名称不能为空',
      );
    }
    await _db.transaction(() async {
      await _requireRequest(requestId);
      await _writeMetadata(requestId, input, DateTime.now());
    });
  }

  @override
  Future<void> confirmApplied(int requestId, ConfirmAppliedInput input) async {
    await _db.transaction(() async {
      final request = await _requireRequest(requestId);
      if (request.status != PurchaseStatus.pendingApply.storageValue) {
        throw _invalidStatus('只有待申报采购可以确认已申报');
      }
      final now = DateTime.now();
      await (_db.update(
        _db.purchaseRequests,
      )..where((t) => t.id.equals(requestId))).write(
        PurchaseRequestsCompanion(
          status: const Value('applied'),
          appliedDate: Value(input.appliedDate),
          oaRequestNo: Value(_clean(input.oaRequestNo)),
          oaTitle: Value(_clean(input.oaTitle)),
          oaUrl: Value(_clean(input.oaUrl)),
          updatedAt: Value(now),
        ),
      );
      await _writeStatusLog(
        requestId,
        oldStatus: PurchaseStatus.pendingApply,
        newStatus: PurchaseStatus.applied,
        at: now,
        remark: '完成 OA 申报',
      );
    });
  }

  @override
  Future<void> assignPurchaser(
    int requestId,
    AssignPurchaserInput input,
  ) async {
    await _db.transaction(() async {
      final request = await _requireRequest(requestId);
      if (request.status != PurchaseStatus.applied.storageValue) {
        throw _invalidStatus('只有已申报采购可以填写采购执行信息');
      }
      final now = DateTime.now();
      await (_db.update(
        _db.purchaseRequests,
      )..where((t) => t.id.equals(requestId))).write(
        PurchaseRequestsCompanion(
          status: const Value('purchasing'),
          purchaseDepartment: Value(_clean(input.purchaseDepartment)),
          purchaserName: Value(_clean(input.purchaserName)),
          assignedDate: Value(input.assignedDate),
          updatedAt: Value(now),
        ),
      );
      await _writeStatusLog(
        requestId,
        oldStatus: PurchaseStatus.applied,
        newStatus: PurchaseStatus.purchasing,
        at: now,
        remark: '填写采购执行信息',
      );
    });
  }

  @override
  Future<void> markPendingReceive(
    int requestId,
    PendingReceiveInput input,
  ) async {
    await _db.transaction(() async {
      final request = await _requireRequest(requestId);
      if (request.status != PurchaseStatus.purchasing.storageValue) {
        throw _invalidStatus('只有采购中记录可以设为待领取');
      }
      final now = DateTime.now();
      await (_db.update(
        _db.purchaseRequests,
      )..where((t) => t.id.equals(requestId))).write(
        PurchaseRequestsCompanion(
          status: const Value('pending_receive'),
          arrivalNoticeDate: Value(input.arrivalNoticeDate),
          receiveLocation: Value(_clean(input.receiveLocation)),
          updatedAt: Value(now),
        ),
      );
      await _writeStatusLog(
        requestId,
        oldStatus: PurchaseStatus.purchasing,
        newStatus: PurchaseStatus.pendingReceive,
        at: now,
        remark: '收到物资入厂通知，设为待领取',
      );
    });
  }

  @override
  Future<void> changeStatusManually(ManualPurchaseStatusInput input) async {
    if (!input.confirmed) {
      throw const PurchaseException(
        PurchaseFailureCode.invalidInput,
        '手动调整状态需要用户确认',
      );
    }
    await _db.transaction(() async {
      final request = await _requireRequest(input.requestId);
      final oldStatus = PurchaseStatus.parse(request.status);
      if (oldStatus == input.targetStatus) return;
      final now = DateTime.now();
      await (_db.update(
        _db.purchaseRequests,
      )..where((t) => t.id.equals(input.requestId))).write(
        PurchaseRequestsCompanion(
          status: Value(input.targetStatus.storageValue),
          updatedAt: Value(now),
        ),
      );
      await _writeStatusLog(
        input.requestId,
        oldStatus: oldStatus,
        newStatus: input.targetStatus,
        at: now,
        remark: _clean(input.remark) == null
            ? '手动调整状态'
            : '${_clean(input.remark)}（手动调整状态）',
      );
    });
  }

  @override
  Future<void> stockIn(StockInInput input) async {
    if (input.lines.isEmpty) {
      throw const PurchaseException(
        PurchaseFailureCode.invalidInput,
        '请至少添加一条入库明细',
      );
    }
    if (input.lines.any(
      (line) => !line.quantity.isFinite || line.quantity <= 0,
    )) {
      throw const PurchaseException(
        PurchaseFailureCode.invalidInput,
        '本次入库数量必须大于 0',
      );
    }
    await _db.transaction(() async {
      final request = await _requireRequest(input.requestId);
      if (request.status != PurchaseStatus.pendingReceive.storageValue &&
          !input.confirmedNonPending) {
        throw const PurchaseException(
          PurchaseFailureCode.invalidState,
          '当前采购状态不是待领取，请确认后继续历史补录',
        );
      }
      final now = DateTime.now();
      for (final line in input.lines) {
        final purchaseItem =
            await (_db.select(_db.purchaseRequestItems)..where(
                  (t) =>
                      t.id.equals(line.requestItemId) &
                      t.requestId.equals(input.requestId),
                ))
                .getSingleOrNull();
        if (purchaseItem == null) {
          throw const PurchaseException(
            PurchaseFailureCode.notFound,
            '采购明细不存在',
          );
        }
        if (line.quantity > purchaseItem.remainingQuantity &&
            !line.confirmExcess) {
          throw PurchaseException(
            PurchaseFailureCode.invalidInput,
            '本次入库数量超过剩余待入库数量 ${purchaseItem.remainingQuantity}，请确认超量入库',
          );
        }
        final materialId = await _resolveMaterial(purchaseItem, line, now);
        final material =
            await (_db.select(_db.inventoryMaterials)..where(
                  (t) => t.id.equals(materialId) & t.isDeleted.equals(false),
                ))
                .getSingleOrNull();
        if (material == null) {
          throw const PurchaseException(
            PurchaseFailureCode.inventoryItemMissing,
            '所选库存物资不存在',
          );
        }
        if (material.status != 'active') {
          throw const PurchaseException(
            PurchaseFailureCode.inventoryItemInactive,
            '关联库存物资已停用，请恢复原物资或选择其他物资',
          );
        }
        final receiptId = await _inventory.createReceipt(
          InventoryReceiptDraft(
            receiptDate: input.stockInDate,
            receiptType: 'purchase',
            sourceName: '采购：${request.title}',
            items: [
              InventoryReceiptLineDraft(
                materialId: materialId,
                quantity: line.quantity,
                remark: _clean(line.remark) ?? _clean(input.remark),
              ),
            ],
            remark: _clean(input.remark) ?? '采购入库记录 #${input.requestId}',
          ),
        );
        final transaction =
            await (_db.select(_db.inventoryTransactions)
                  ..where(
                    (t) =>
                        t.sourceType.equals('receipt') &
                        t.sourceId.equals(receiptId) &
                        t.materialId.equals(materialId),
                  )
                  ..orderBy([(t) => OrderingTerm.desc(t.id)])
                  ..limit(1))
                .getSingle();
        await _db
            .into(_db.purchaseStockEntries)
            .insert(
              PurchaseStockEntriesCompanion.insert(
                requestId: input.requestId,
                requestItemId: purchaseItem.id,
                inventoryTransactionId: Value(transaction.id),
                inventoryReceiptId: receiptId,
                inventoryMaterialId: materialId,
                quantity: line.quantity,
                stockInDate: input.stockInDate,
                storageLocation: Value(
                  _clean(line.storageLocation) ?? material.storageLocation,
                ),
                remark: Value(_clean(line.remark) ?? _clean(input.remark)),
                createdAt: Value(now),
              ),
            );
        await (_db.update(
          _db.purchaseRequestItems,
        )..where((t) => t.id.equals(purchaseItem.id))).write(
          PurchaseRequestItemsCompanion(
            inventoryMaterialId: Value(materialId),
            receivedQuantity: Value(
              purchaseItem.receivedQuantity + line.quantity,
            ),
            remainingQuantity: Value(
              purchaseItem.requestQuantity -
                  purchaseItem.receivedQuantity -
                  line.quantity,
            ),
            updatedAt: Value(now),
          ),
        );
      }
      final items = await _itemsForRequest(input.requestId);
      final allReceived = items.every(
        (item) => item.remainingQuantity <= 0.000001,
      );
      final target = allReceived
          ? PurchaseStatus.stocked
          : PurchaseStatus.pendingReceive;
      final oldStatus = PurchaseStatus.parse(request.status);
      await (_db.update(
        _db.purchaseRequests,
      )..where((t) => t.id.equals(input.requestId))).write(
        PurchaseRequestsCompanion(
          status: Value(target.storageValue),
          completedAt: Value(
            allReceived ? await _actualCompletionDate(input.requestId) : null,
          ),
          updatedAt: Value(now),
        ),
      );
      await _writeStatusLog(
        input.requestId,
        oldStatus: oldStatus,
        newStatus: target,
        at: now,
        remark: allReceived ? '采购物资全部入库完成' : '采购物资分批入库',
      );
    });
  }

  Future<int> _resolveMaterial(
    PurchaseRequestItem item,
    PurchaseStockInLineInput line,
    DateTime now,
  ) async {
    if (line.createInventoryMaterial) {
      final materialId = await _inventory.createMaterial(
        InventoryMaterialDraft(
          materialCode:
              _clean(line.newMaterialCode) ??
              'PUR-${now.microsecondsSinceEpoch}-${item.id}',
          materialName: item.itemName,
          modelSpec: item.specification,
          unitName: item.unit,
          storageLocation: _clean(line.storageLocation),
          warningEnabled: true,
          isCommon: false,
          status: 'active',
          remark: '由采购记录 #${item.requestId} 入库建档',
        ),
      );
      await (_db.update(
        _db.purchaseRequestItems,
      )..where((t) => t.id.equals(item.id))).write(
        PurchaseRequestItemsCompanion(
          inventoryMaterialId: Value(materialId),
          updatedAt: Value(now),
        ),
      );
      return materialId;
    }
    final chosenId = line.inventoryMaterialId ?? item.inventoryMaterialId;
    if (chosenId == null) {
      throw const PurchaseException(
        PurchaseFailureCode.inventoryItemMissing,
        '请选择库存物资、恢复原物资或新建库存物资',
      );
    }
    final material =
        await (_db.select(_db.inventoryMaterials)
              ..where((t) => t.id.equals(chosenId) & t.isDeleted.equals(false)))
            .getSingleOrNull();
    if (material == null) {
      throw const PurchaseException(
        PurchaseFailureCode.inventoryItemMissing,
        '所选库存物资不存在或已删除，请选择其他物资',
      );
    }
    if (material.status != 'active') {
      if (!line.restoreLinkedMaterial || chosenId != item.inventoryMaterialId) {
        throw const PurchaseException(
          PurchaseFailureCode.inventoryItemInactive,
          '原关联库存物资已停用，请确认恢复原物资或选择其他库存物资',
        );
      }
      await (_db.update(
        _db.inventoryMaterials,
      )..where((t) => t.id.equals(chosenId))).write(
        InventoryMaterialsCompanion(
          status: const Value('active'),
          updatedAt: Value(now),
        ),
      );
    }
    if (chosenId != item.inventoryMaterialId) {
      await (_db.update(
        _db.purchaseRequestItems,
      )..where((t) => t.id.equals(item.id))).write(
        PurchaseRequestItemsCompanion(
          inventoryMaterialId: Value(chosenId),
          updatedAt: Value(now),
        ),
      );
    }
    return chosenId;
  }

  @override
  Future<void> softDelete(int requestId) async {
    await _db.transaction(() async {
      final request = await _requireRequest(requestId);
      final hasEntries =
          await (_db.select(_db.purchaseStockEntries)
                ..where((t) => t.requestId.equals(requestId))
                ..limit(1))
              .getSingleOrNull();
      if (hasEntries != null) {
        throw const PurchaseException(
          PurchaseFailureCode.deletionForbidden,
          '当前采购记录已产生库存入库数据，不能直接删除；请先处理对应库存记录',
        );
      }
      await (_db.update(
        _db.purchaseRequests,
      )..where((t) => t.id.equals(request.id))).write(
        PurchaseRequestsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Stream<List<PurchaseRequestSummary>> watchRequests(PurchaseFilter filter) =>
      _db
          .customSelect(
            'SELECT id FROM purchase_requests LIMIT 1',
            readsFrom: _watchedTables,
          )
          .watch()
          .asyncMap((_) => _loadRequests(filter));

  Future<List<PurchaseRequestSummary>> _loadRequests(
    PurchaseFilter filter,
  ) async {
    final query = _db.select(_db.purchaseRequests)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      ]);
    if (filter.statuses.isNotEmpty) {
      query.where(
        (t) => t.status.isIn(filter.statuses.map((s) => s.storageValue)),
      );
    }
    if (filter.startDate != null) {
      final start = _dayStart(filter.startDate!);
      query.where((t) => t.requestDate.isBiggerOrEqualValue(start));
    }
    if (filter.endDate != null) {
      final endExclusive = _dayStart(filter.endDate!)
          .add(const Duration(days: 1));
      query.where((t) => t.requestDate.isSmallerThanValue(endExclusive));
    }
    final requests = await query.get();
    final result = <PurchaseRequestSummary>[];
    for (final request in requests) {
      final items = await _itemsForRequest(request.id);
      if (filter.inventoryMaterialId != null &&
          !items.any(
            (item) => item.inventoryMaterialId == filter.inventoryMaterialId,
          )) {
        continue;
      }
      if (_clean(filter.purchaserName) case final name?) {
        if (!(request.purchaserName ?? '').toLowerCase().contains(
          name.toLowerCase(),
        )) {
          continue;
        }
      }
      if (_clean(filter.demandReason) case final reason?) {
        if (!(request.demandReason ?? '').contains(reason)) continue;
      }
      final keyword = filter.keyword.trim().toLowerCase();
      if (keyword.isNotEmpty) {
        final searchable = <String?>[
          request.title,
          request.demandReason,
          request.oaRequestNo,
          request.oaTitle,
          request.purchaserName,
          request.purchaseDepartment,
          ...items.expand((item) => [item.itemName, item.specification]),
        ].whereType<String>().join(' ').toLowerCase();
        if (!searchable.contains(keyword)) continue;
      }
      final reminder = await hasReminder(request.id);
      result.add(_summary(request, items, reminder));
    }
    return result;
  }

  @override
  Stream<PurchaseRequestDetail?> watchDetail(int requestId) => _db
      .customSelect(
        'SELECT id FROM purchase_requests WHERE id = ?',
        variables: [Variable.withInt(requestId)],
        readsFrom: _watchedTables,
      )
      .watch()
      .asyncMap((_) => _loadDetail(requestId));

  Future<PurchaseRequestDetail?> _loadDetail(int requestId) async {
    final request =
        await (_db.select(
              _db.purchaseRequests,
            )..where((t) => t.id.equals(requestId) & t.isDeleted.equals(false)))
            .getSingleOrNull();
    if (request == null) return null;
    final items = await _itemsForRequest(requestId);
    final logs =
        await (_db.select(_db.purchaseStatusLogs)
              ..where((t) => t.requestId.equals(requestId))
              ..orderBy([
                (t) => OrderingTerm(expression: t.changedAt),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    final entries = await _loadStockEntries(requestId);
    final reminder = await hasReminder(requestId);
    final summary = _summary(request, items, reminder);
    return PurchaseRequestDetail(
      summary: summary,
      items: [for (final item in items) _itemView(item)],
      statusLogs: [
        for (final log in logs)
          PurchaseStatusLogView(
            id: log.id,
            changedAt: log.changedAt,
            oldStatus: log.oldStatus == null
                ? null
                : PurchaseStatus.parse(log.oldStatus!),
            newStatus: PurchaseStatus.parse(log.newStatus),
            remark: log.remark,
          ),
      ],
      stockEntries: entries,
      oaRequestNo: request.oaRequestNo,
      oaTitle: request.oaTitle,
      oaUrl: request.oaUrl,
      purchaseDepartment: request.purchaseDepartment,
      demandReason: request.demandReason,
      remark: request.remark,
      completedAt: request.completedAt,
    );
  }

  @override
  Stream<PurchaseDashboardData> watchDashboard() => _db
      .customSelect(
        'SELECT id FROM purchase_requests LIMIT 1',
        readsFrom: _watchedTables,
      )
      .watch()
      .asyncMap((_) => _loadDashboard());

  Future<PurchaseDashboardData> _loadDashboard() async {
    final requests = await _loadRequests(const PurchaseFilter());
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final completedThisMonth =
        await (_db.select(_db.purchaseRequests)..where(
              (t) =>
                  t.isDeleted.equals(false) &
                  t.status.equals(PurchaseStatus.stocked.storageValue) &
                  t.completedAt.isBiggerOrEqualValue(monthStart) &
                  t.completedAt.isSmallerThanValue(nextMonth),
            ))
            .get();
    final byStatus = <PurchaseStatus, int>{
      for (final status in PurchaseStatus.values)
        status: requests.where((r) => r.status == status).length,
    };
    final priority = <PurchaseStatus>[
      PurchaseStatus.pendingReceive,
      PurchaseStatus.purchasing,
      PurchaseStatus.applied,
      PurchaseStatus.pendingApply,
    ];
    final actionRequired =
        requests.where((r) => priority.contains(r.status)).toList()
          ..sort((a, b) {
            final diff = priority
                .indexOf(a.status)
                .compareTo(priority.indexOf(b.status));
            if (diff != 0) return diff;
            return _waitingSince(a).compareTo(_waitingSince(b));
          });
    return PurchaseDashboardData(
      pendingApplyCount: byStatus[PurchaseStatus.pendingApply] ?? 0,
      appliedCount: byStatus[PurchaseStatus.applied] ?? 0,
      purchasingCount: byStatus[PurchaseStatus.purchasing] ?? 0,
      pendingReceiveCount: byStatus[PurchaseStatus.pendingReceive] ?? 0,
      stockedThisMonthCount: completedThisMonth.length,
      actionRequired: actionRequired.take(12).toList(),
    );
  }

  @override
  Stream<List<PurchaseHistoryRow>> watchHistory(PurchaseHistoryFilter filter) =>
      _db
          .customSelect(
            'SELECT id FROM purchase_requests LIMIT 1',
            readsFrom: _watchedTables,
          )
          .watch()
          .asyncMap((_) => _loadHistory(filter));

  Future<List<PurchaseHistoryRow>> _loadHistory(
    PurchaseHistoryFilter filter,
  ) async {
    final requestsQuery = _db.select(_db.purchaseRequests)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([
        (t) => OrderingTerm(expression: t.requestDate, mode: OrderingMode.desc),
      ]);
    if (filter.historyStatus.isNotEmpty) {
      requestsQuery.where(
        (t) => t.status.isIn(filter.historyStatus.map((s) => s.storageValue)),
      );
    }
    final requests = await requestsQuery.get();
    final rows = <PurchaseHistoryRow>[];
    for (final request in requests) {
      final items = await _itemsForRequest(request.id);
      final actualCompletion = await _actualCompletionDate(request.id);
      final rangeDate =
          actualCompletion ?? request.appliedDate ?? request.requestDate;
      final start = filter.startDate == null
          ? null
          : _dayStart(filter.startDate!);
      final endExclusive = filter.endDate == null
          ? null
          : _dayStart(filter.endDate!).add(const Duration(days: 1));
      if (filter.startDate != null &&
          (rangeDate == null || rangeDate.isBefore(start!))) {
        continue;
      }
      if (filter.endDate != null &&
          (rangeDate == null || !rangeDate.isBefore(endExclusive!))) {
        continue;
      }
      for (final item in items) {
        if (filter.inventoryMaterialId != null &&
            item.inventoryMaterialId != filter.inventoryMaterialId) {
          continue;
        }
        final searchable = [
          request.title,
          request.demandReason ?? '',
          request.oaRequestNo ?? '',
          request.oaTitle ?? '',
          request.purchaserName ?? '',
          request.purchaseDepartment ?? '',
          item.itemName,
          item.specification ?? '',
        ].join(' ').toLowerCase();
        if (filter.keyword.trim().isNotEmpty &&
            !searchable.contains(filter.keyword.trim().toLowerCase())) {
          continue;
        }
        if (filter.purchaserName != null &&
            !(request.purchaserName ?? '').toLowerCase().contains(
              filter.purchaserName!.trim().toLowerCase(),
            )) {
          continue;
        }
        final entries =
            await (_db.select(_db.purchaseStockEntries)
                  ..where(
                    (t) =>
                        t.requestItemId.equals(item.id) &
                        t.isReversed.equals(false),
                  )
                  ..orderBy([
                    (t) => OrderingTerm(
                      expression: t.stockInDate,
                      mode: OrderingMode.desc,
                    ),
                  ]))
                .get();
        rows.add(
          PurchaseHistoryRow(
            requestId: request.id,
            requestItemId: item.id,
            inventoryMaterialId: item.inventoryMaterialId,
            itemName: item.itemName,
            specification: item.specification,
            unit: item.unit,
            requestQuantity: item.requestQuantity,
            receivedQuantity: item.receivedQuantity,
            requestDate: request.requestDate,
            appliedDate: request.appliedDate,
            lastStockInDate: entries.isEmpty ? null : entries.first.stockInDate,
            purchaserName: request.purchaserName,
            status: PurchaseStatus.parse(request.status),
            completedAt: actualCompletion,
            cycleDays: _cycleDays(request.appliedDate, actualCompletion),
            currentStock: await _currentStock(item.inventoryMaterialId),
          ),
        );
      }
    }
    rows.sort(
      (a, b) => (b.requestDate ?? DateTime(1970)).compareTo(
        a.requestDate ?? DateTime(1970),
      ),
    );
    return rows;
  }

  @override
  Stream<PurchaseItemHistory?> watchItemHistory(int inventoryMaterialId) =>
      watchHistory(
        PurchaseHistoryFilter(inventoryMaterialId: inventoryMaterialId),
      ).asyncMap((rows) async {
        final items = await (_db.select(
          _db.inventoryMaterials,
        )..where((t) => t.id.equals(inventoryMaterialId))).getSingleOrNull();
        if (items == null && rows.isEmpty) return null;
        final purchaseRows = rows
            .where((row) => row.inventoryMaterialId == inventoryMaterialId)
            .toList();
        final cyclesByRequest = <int, ({int days, DateTime completedAt})>{};
        for (final row in purchaseRows) {
          final days = row.cycleDays;
          final completed = row.completedAt;
          if (days != null && completed != null) {
            cyclesByRequest.putIfAbsent(
              row.requestId,
              () => (days: days, completedAt: completed),
            );
          }
        }
        final sortedCycles = cyclesByRequest.values.toList()
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
        final recentCycles = sortedCycles.reversed
            .take(3)
            .map((cycle) => cycle.days)
            .toList();
        final average = recentCycles.isEmpty
            ? null
            : recentCycles.reduce((a, b) => a + b) / recentCycles.length;
        final distinctRequests =
            <int, PurchaseHistoryRow>{
              for (final row in purchaseRows) row.requestId: row,
            }.values.toList()..sort(
              (a, b) => (b.appliedDate ?? b.requestDate ?? DateTime(1970))
                  .compareTo(a.appliedDate ?? a.requestDate ?? DateTime(1970)),
            );
        final latest = distinctRequests.firstOrNull;
        final stockDate = purchaseRows
            .map((row) => row.lastStockInDate)
            .whereType<DateTime>()
            .fold<DateTime?>(
              null,
              (latestDate, date) =>
                  latestDate == null || date.isAfter(latestDate)
                  ? date
                  : latestDate,
            );
        return PurchaseItemHistory(
          inventoryMaterialId: inventoryMaterialId,
          itemName:
              items?.materialName ?? purchaseRows.firstOrNull?.itemName ?? '',
          specification:
              items?.modelSpec ?? purchaseRows.firstOrNull?.specification,
          unit: items?.unitName ?? purchaseRows.firstOrNull?.unit ?? '',
          currentStock: items?.currentStock,
          mostRecentRequestDate: latest?.appliedDate ?? latest?.requestDate,
          mostRecentStockInDate: stockDate,
          rows: purchaseRows,
          recentCycleDays: recentCycles,
          averageCycleDays: average,
        );
      });

  @override
  Future<bool> hasReminder(int requestId) async => await _reminders
      .findBySource('purchase_request', requestId)
      .then(
        (item) =>
            item != null &&
            item.isEnabled &&
            !item.isCompleted &&
            item.archivedAt == null,
      );

  @override
  Future<int?> findReminderId(int requestId) async =>
      (await _reminders.findBySource('purchase_request', requestId))?.id;

  @override
  Future<bool> hasActiveRequest(int inventoryMaterialId) async =>
      await findActiveRequestId(inventoryMaterialId) != null;

  @override
  Future<int?> findActiveRequestId(int inventoryMaterialId) async {
    final rows = await _db
        .customSelect(
          '''SELECT r.id
         FROM purchase_requests r
         JOIN purchase_request_items i ON i.request_id = r.id
         WHERE r.is_deleted = 0
           AND r.status IN ('pending_apply', 'applied', 'purchasing', 'pending_receive')
           AND i.inventory_material_id = ?
         ORDER BY r.request_date ASC, r.id ASC
         LIMIT 1''',
          variables: [Variable.withInt(inventoryMaterialId)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<int>('id');
  }

  @override
  Future<void> reverseStockEntry(int stockEntryId) async {
    final entry =
        await (_db.select(_db.purchaseStockEntries)..where(
              (t) => t.id.equals(stockEntryId) & t.isReversed.equals(false),
            ))
            .getSingleOrNull();
    if (entry == null) {
      throw const PurchaseException(
        PurchaseFailureCode.notFound,
        '采购入库记录不存在或已撤销',
      );
    }
    // InventoryRepository owns stock and receipt reversal. Its transaction also
    // writes the purchase correction before it marks the receipt deleted.
    await _inventory.deleteReceipt(entry.inventoryReceiptId);
  }

  Future<void> _writeMetadata(
    int requestId,
    UpdatePurchaseMetadataInput input,
    DateTime now,
  ) async {
    await (_db.update(
      _db.purchaseRequests,
    )..where((t) => t.id.equals(requestId))).write(
      PurchaseRequestsCompanion(
        title: Value(input.title.trim()),
        requestDate: Value(input.requestDate),
        appliedDate: Value(input.appliedDate),
        oaRequestNo: Value(_clean(input.oaRequestNo)),
        oaTitle: Value(_clean(input.oaTitle)),
        oaUrl: Value(_clean(input.oaUrl)),
        purchaseDepartment: Value(_clean(input.purchaseDepartment)),
        purchaserName: Value(_clean(input.purchaserName)),
        assignedDate: Value(input.assignedDate),
        arrivalNoticeDate: Value(input.arrivalNoticeDate),
        receiveLocation: Value(_clean(input.receiveLocation)),
        demandReason: Value(_clean(input.demandReason)),
        remark: Value(_clean(input.remark)),
        updatedAt: Value(now),
      ),
    );
  }

  Future<PurchaseRequest> _requireRequest(int id) async {
    final request =
        await (_db.select(_db.purchaseRequests)
              ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
            .getSingleOrNull();
    if (request == null) {
      throw const PurchaseException(
        PurchaseFailureCode.notFound,
        '采购记录不存在或已删除',
      );
    }
    PurchaseStatus.parse(request.status);
    return request;
  }

  Future<List<PurchaseRequestItem>> _itemsForRequest(int requestId) =>
      (_db.select(_db.purchaseRequestItems)
            ..where((t) => t.requestId.equals(requestId))
            ..orderBy([(t) => OrderingTerm(expression: t.id)]))
          .get();

  Future<DateTime?> _actualCompletionDate(int requestId) async {
    final items = await _itemsForRequest(requestId);
    if (items.isEmpty ||
        items.any((item) => item.remainingQuantity > 0.000001)) {
      return null;
    }
    final entries =
        await (_db.select(_db.purchaseStockEntries)..where(
              (t) => t.requestId.equals(requestId) & t.isReversed.equals(false),
            ))
            .get();
    if (entries.isEmpty) return null;
    return entries
        .map((entry) => entry.stockInDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  DateTime _waitingSince(PurchaseRequestSummary request) =>
      switch (request.status) {
        PurchaseStatus.pendingReceive =>
          request.arrivalNoticeDate ?? request.requestDate ?? DateTime(1970),
        PurchaseStatus.purchasing =>
          request.assignedDate ??
              request.appliedDate ??
              request.requestDate ??
              DateTime(1970),
        PurchaseStatus.applied =>
          request.appliedDate ?? request.requestDate ?? DateTime(1970),
        _ => request.requestDate ?? DateTime(1970),
      };

  Future<List<PurchaseStockEntryView>> _loadStockEntries(int requestId) async {
    final entries =
        await (_db.select(_db.purchaseStockEntries)
              ..where((t) => t.requestId.equals(requestId))
              ..orderBy([
                (t) => OrderingTerm(expression: t.stockInDate),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    return [
      for (final entry in entries)
        PurchaseStockEntryView(
          id: entry.id,
          requestItemId: entry.requestItemId,
          inventoryMaterialId: entry.inventoryMaterialId,
          inventoryReceiptId: entry.inventoryReceiptId,
          inventoryTransactionId: entry.inventoryTransactionId,
          quantity: entry.quantity,
          stockInDate: entry.stockInDate,
          storageLocation: entry.storageLocation,
          remark: entry.remark,
          isReversed: entry.isReversed,
          reversedAt: entry.reversedAt,
        ),
    ];
  }

  PurchaseRequestSummary _summary(
    PurchaseRequest request,
    List<PurchaseRequestItem> items,
    bool hasReminder,
  ) {
    return PurchaseRequestSummary(
      id: request.id,
      title: request.title,
      status: PurchaseStatus.parse(request.status),
      requestDate: request.requestDate,
      itemCount: items.length,
      itemNames: [for (final item in items) item.itemName],
      items: [for (final item in items) _itemView(item)],
      appliedDate: request.appliedDate,
      purchaserName: request.purchaserName,
      assignedDate: request.assignedDate,
      arrivalNoticeDate: request.arrivalNoticeDate,
      receiveLocation: request.receiveLocation,
      hasReminder: hasReminder,
    );
  }

  PurchaseRequestItemView _itemView(PurchaseRequestItem item) =>
      PurchaseRequestItemView(
        id: item.id,
        inventoryMaterialId: item.inventoryMaterialId,
        itemName: item.itemName,
        specification: item.specification,
        unit: item.unit,
        currentStockSnapshot: item.currentStockSnapshot,
        requestQuantity: item.requestQuantity,
        receivedQuantity: item.receivedQuantity,
        remainingQuantity: item.remainingQuantity,
        remark: item.remark,
      );

  Future<double?> _currentStock(int? inventoryMaterialId) async {
    if (inventoryMaterialId == null) return null;
    return (await (_db.select(
          _db.inventoryMaterials,
        )..where((t) => t.id.equals(inventoryMaterialId))).getSingleOrNull())
        ?.currentStock;
  }

  Future<void> _writeStatusLog(
    int requestId, {
    required PurchaseStatus? oldStatus,
    required PurchaseStatus newStatus,
    required DateTime at,
    String? remark,
  }) async {
    await _db
        .into(_db.purchaseStatusLogs)
        .insert(
          PurchaseStatusLogsCompanion.insert(
            requestId: requestId,
            oldStatus: Value(oldStatus?.storageValue),
            newStatus: newStatus.storageValue,
            changedAt: at,
            remark: Value(_clean(remark)),
            createdAt: Value(at),
          ),
        );
  }

  void _validateRequest(String title, List<PurchaseItemDraft> items) {
    if (title.trim().isEmpty) {
      throw const PurchaseException(
        PurchaseFailureCode.invalidInput,
        '采购事项名称不能为空',
      );
    }
    if (items.isEmpty) {
      throw const PurchaseException(
        PurchaseFailureCode.invalidInput,
        '请至少添加一项采购物资',
      );
    }
    for (final item in items) {
      if (item.itemName.trim().isEmpty || item.unit.trim().isEmpty) {
        throw const PurchaseException(
          PurchaseFailureCode.invalidInput,
          '物资名称和单位不能为空',
        );
      }
      if (!item.requestQuantity.isFinite || item.requestQuantity <= 0) {
        throw const PurchaseException(
          PurchaseFailureCode.invalidInput,
          '申报数量必须大于 0',
        );
      }
      if (item.currentStockSnapshot != null &&
          (!item.currentStockSnapshot!.isFinite ||
              item.currentStockSnapshot! < 0)) {
        throw const PurchaseException(
          PurchaseFailureCode.invalidInput,
          '建单库存快照不能小于 0',
        );
      }
    }
  }

  PurchaseException _invalidStatus(String message) =>
      PurchaseException(PurchaseFailureCode.invalidState, message);

  String? _clean(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  int? _cycleDays(DateTime? applied, DateTime? completed) {
    if (applied == null || completed == null) return null;
    final days = completed.difference(applied).inDays;
    return days < 0 ? null : days;
  }

  DateTime _dayStart(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
