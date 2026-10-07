import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/inventory/data/inventory_repository.dart';
import 'package:qingsongban/features/inventory/domain/inventory_models.dart';
import 'package:qingsongban/features/purchase/data/purchase_repository_impl.dart';
import 'package:qingsongban/features/purchase/domain/purchase_models.dart';
import 'package:qingsongban/features/purchase/domain/purchase_status.dart';
import 'package:qingsongban/features/reminders/data/reminder_repository.dart';
import 'package:qingsongban/features/reminders/domain/reminder_options.dart';

void main() {
  late AppDatabase db;
  late InventoryRepository inventory;
  late PurchaseRepositoryImpl purchases;

  setUp(() {
    db = AppDatabase.forTesting();
    inventory = InventoryRepository(db);
    purchases = PurchaseRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  test(
    'creates multi-item request and lets metadata edits preserve status',
    () async {
      final materialId = await _createMaterial(inventory, 'MAT-01', '扫路车边刷');
      final requestId = await purchases.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '扫路车边刷补充',
          requestDate: DateTime(2026, 1, 3),
          items: [
            _line('扫路车边刷', materialId: materialId, quantity: 20),
            _line('手套', quantity: 4, unit: '双'),
          ],
        ),
      );

      await purchases.confirmApplied(
        requestId,
        ConfirmAppliedInput(
          appliedDate: DateTime(2026, 1, 4),
          oaRequestNo: 'OA-1001',
        ),
      );
      await purchases.updatePurchaseMetadata(
        requestId,
        UpdatePurchaseMetadataInput(
          title: '扫路车边刷补充（修订）',
          requestDate: DateTime(2026, 1, 3),
          appliedDate: DateTime(2026, 1, 4),
          oaRequestNo: 'OA-1001',
          oaTitle: '道路清扫物资申报',
          oaUrl: 'https://oa.example/1001',
          purchaseDepartment: '资材一部',
          purchaserName: '李采购',
          assignedDate: DateTime(2026, 1, 6),
          arrivalNoticeDate: null,
          receiveLocation: null,
          demandReason: '耗材不足',
          remark: '更新OA标题',
        ),
      );

      final request = await db.select(db.purchaseRequests).getSingle();
      expect(request.status, PurchaseStatus.applied.storageValue);
      expect(request.title, '扫路车边刷补充（修订）');
      expect(request.oaTitle, '道路清扫物资申报');
      expect(await db.select(db.purchaseRequestItems).get(), hasLength(2));
      expect(await db.select(db.purchaseStatusLogs).get(), hasLength(2));
      final filteredHistory = await purchases
          .watchHistory(
            const PurchaseHistoryFilter(
              keyword: 'OA-1001',
              purchaserName: '李采购',
              historyStatus: {PurchaseStatus.applied},
            ),
          )
          .first;
      expect(filteredHistory, hasLength(2));
    },
  );

  test('stock-in is transactional with receipts, stock, batches and completion date', () async {
    final materialId = await _createMaterial(inventory, 'MAT-02', '边刷');
    final requestId = await _createRequest(purchases, materialId, quantity: 5);
    await _moveToPendingReceive(purchases, requestId);
    final item = await _purchaseItem(db, requestId);

    await purchases.stockIn(
      StockInInput(
        requestId: requestId,
        stockInDate: DateTime(2026, 2, 2),
        lines: [PurchaseStockInLineInput(requestItemId: item.id, quantity: 2)],
      ),
    );
    var updatedItem = await _purchaseItem(db, requestId);
    var request = await _purchaseRequest(db, requestId);
    expect(updatedItem.receivedQuantity, 2);
    expect(updatedItem.remainingQuantity, 3);
    expect(request.status, PurchaseStatus.pendingReceive.storageValue);
    expect(request.completedAt, isNull);

    await purchases.stockIn(
      StockInInput(
        requestId: requestId,
        stockInDate: DateTime(2026, 2, 8),
        lines: [PurchaseStockInLineInput(requestItemId: item.id, quantity: 3)],
      ),
    );
    updatedItem = await _purchaseItem(db, requestId);
    request = await _purchaseRequest(db, requestId);
    final stock = await inventory.getMaterial(materialId);
    final entries = await db.select(db.purchaseStockEntries).get();
    final receipts = await db.select(db.inventoryReceipts).get();
    final transactionRows = await db.select(db.inventoryTransactions).get();
    expect(updatedItem.receivedQuantity, 5);
    expect(updatedItem.remainingQuantity, 0);
    expect(request.status, PurchaseStatus.stocked.storageValue);
    expect(request.completedAt, DateTime(2026, 2, 8));
    expect(stock?.currentStock, 5);
    expect(receipts, hasLength(2));
    expect(
      receipts.every((receipt) => receipt.receiptType == 'purchase'),
      isTrue,
    );
    expect(entries, hasLength(2));
    expect(entries.every((entry) => entry.inventoryReceiptId > 0), isTrue);
    expect(
      entries.every((entry) => entry.inventoryTransactionId != null),
      isTrue,
    );
    expect(
      transactionRows.fold<double>(0, (sum, row) => sum + row.quantityChange),
      5,
    );
  });

  test(
    'excess stock requires confirmation and accepted excess remains traceable',
    () async {
      final materialId = await _createMaterial(inventory, 'MAT-03', '滤芯');
      final requestId = await _createRequest(
        purchases,
        materialId,
        quantity: 3,
      );
      await _moveToPendingReceive(purchases, requestId);
      final item = await _purchaseItem(db, requestId);
      final input = StockInInput(
        requestId: requestId,
        stockInDate: DateTime(2026, 3, 10),
        lines: [PurchaseStockInLineInput(requestItemId: item.id, quantity: 4)],
      );

      await expectLater(
        purchases.stockIn(input),
        throwsA(isA<PurchaseException>()),
      );
      expect(await db.select(db.inventoryReceipts).get(), isEmpty);
      expect((await inventory.getMaterial(materialId))?.currentStock, 0);

      await purchases.stockIn(
        StockInInput(
          requestId: requestId,
          stockInDate: input.stockInDate,
          lines: [
            PurchaseStockInLineInput(
              requestItemId: item.id,
              quantity: 4,
              confirmExcess: true,
            ),
          ],
        ),
      );
      final updatedItem = await _purchaseItem(db, requestId);
      expect(updatedItem.receivedQuantity, 4);
      expect(updatedItem.remainingQuantity, -1);
      expect((await _purchaseRequest(db, requestId)).status, 'stocked');
    },
  );

  test('failure after a prior line rolls back receipts, balance and purchase totals', () async {
    final materialId = await _createMaterial(inventory, 'MAT-04', '螺丝');
    final requestId = await _createRequest(purchases, materialId, quantity: 5);
    await _moveToPendingReceive(purchases, requestId);
    final item = await _purchaseItem(db, requestId);

    await expectLater(
      purchases.stockIn(
        StockInInput(
          requestId: requestId,
          stockInDate: DateTime(2026, 4, 1),
          lines: [
            PurchaseStockInLineInput(requestItemId: item.id, quantity: 2),
            PurchaseStockInLineInput(requestItemId: -1, quantity: 1),
          ],
        ),
      ),
      throwsA(isA<PurchaseException>()),
    );

    expect((await inventory.getMaterial(materialId))?.currentStock, 0);
    expect(await db.select(db.inventoryReceipts).get(), isEmpty);
    expect(await db.select(db.inventoryTransactions).get(), isEmpty);
    expect(await db.select(db.purchaseStockEntries).get(), isEmpty);
    expect((await _purchaseItem(db, requestId)).receivedQuantity, 0);
  });

  test('reversing excess stock preserves completion and rejects duplicate reversal', () async {
    final materialId = await _createMaterial(inventory, 'MAT-13', '链条');
    final requestId = await _createRequest(purchases, materialId, quantity: 3);
    await _moveToPendingReceive(purchases, requestId);
    final item = await _purchaseItem(db, requestId);
    await purchases.stockIn(
      StockInInput(
        requestId: requestId,
        stockInDate: DateTime(2026, 9, 1),
        lines: [PurchaseStockInLineInput(requestItemId: item.id, quantity: 3)],
      ),
    );
    await purchases.stockIn(
      StockInInput(
        requestId: requestId,
        confirmedNonPending: true,
        stockInDate: DateTime(2026, 9, 3),
        lines: [
          PurchaseStockInLineInput(
            requestItemId: item.id,
            quantity: 1,
            confirmExcess: true,
          ),
        ],
      ),
    );
    final entries = await db.select(db.purchaseStockEntries).get();
    final excessEntry = entries.singleWhere((entry) => entry.quantity == 1);
    expect(
      (await _purchaseRequest(db, requestId)).completedAt,
      DateTime(2026, 9, 3),
    );

    await purchases.reverseStockEntry(excessEntry.id);
    await expectLater(
      purchases.reverseStockEntry(excessEntry.id),
      throwsA(isA<PurchaseException>()),
    );

    final request = await _purchaseRequest(db, requestId);
    final updatedItem = await _purchaseItem(db, requestId);
    expect(request.status, PurchaseStatus.stocked.storageValue);
    expect(request.completedAt, DateTime(2026, 9, 1));
    expect(updatedItem.receivedQuantity, 3);
    expect(updatedItem.remainingQuantity, 0);
    expect((await inventory.getMaterial(materialId))?.currentStock, 3);
    expect(
      (await (db.select(
        db.purchaseStockEntries,
      )..where((t) => t.id.equals(excessEntry.id))).getSingle()).isReversed,
      isTrue,
    );
  });

  test('manual status correction changes timeline only, and entry reversal rolls back stock', () async {
    final materialId = await _createMaterial(inventory, 'MAT-05', '轴承');
    final requestId = await _createRequest(purchases, materialId, quantity: 2);
    await purchases.changeStatusManually(
      ManualPurchaseStatusInput(
        requestId: requestId,
        targetStatus: PurchaseStatus.stocked,
        confirmed: true,
      ),
    );
    var request = await _purchaseRequest(db, requestId);
    expect(request.status, 'stocked');
    expect(request.completedAt, isNull);
    expect((await inventory.getMaterial(materialId))?.currentStock, 0);

    final item = await _purchaseItem(db, requestId);
    await purchases.stockIn(
      StockInInput(
        requestId: requestId,
        confirmedNonPending: true,
        stockInDate: DateTime(2026, 5, 4),
        lines: [PurchaseStockInLineInput(requestItemId: item.id, quantity: 2)],
      ),
    );
    final stockEntry = await db.select(db.purchaseStockEntries).getSingle();
    await purchases.reverseStockEntry(stockEntry.id);

    final reversedEntry = await (db.select(
      db.purchaseStockEntries,
    )..where((t) => t.id.equals(stockEntry.id))).getSingle();
    request = await _purchaseRequest(db, requestId);
    expect(reversedEntry.isReversed, isTrue);
    expect(reversedEntry.reversedAt, isNotNull);
    expect((await _purchaseItem(db, requestId)).receivedQuantity, 0);
    expect((await inventory.getMaterial(materialId))?.currentStock, 0);
    expect(request.status, PurchaseStatus.pendingReceive.storageValue);
    expect(request.completedAt, isNull);
  });

  test(
    'purchase with any stock history cannot be directly soft deleted',
    () async {
      final materialId = await _createMaterial(inventory, 'MAT-06', '电缆');
      final requestId = await _createRequest(
        purchases,
        materialId,
        quantity: 1,
      );
      await _moveToPendingReceive(purchases, requestId);
      final item = await _purchaseItem(db, requestId);
      await purchases.stockIn(
        StockInInput(
          requestId: requestId,
          stockInDate: DateTime(2026, 6, 1),
          lines: [
            PurchaseStockInLineInput(requestItemId: item.id, quantity: 1),
          ],
        ),
      );
      final entry = await db.select(db.purchaseStockEntries).getSingle();
      await purchases.reverseStockEntry(entry.id);
      await expectLater(
        purchases.softDelete(requestId),
        throwsA(isA<PurchaseException>()),
      );
      expect((await _purchaseRequest(db, requestId)).isDeleted, isFalse);
    },
  );

  test(
    'disabled links can be restored, replaced, or built as a new material',
    () async {
      final disabledId = await _createMaterial(inventory, 'MAT-09', '旧物资');
      await inventory.updateMaterial(
        disabledId,
        const InventoryMaterialDraft(
          materialCode: 'MAT-09',
          materialName: '旧物资',
          unitName: '个',
          status: 'disabled',
        ),
      );
      final replacementId = await _createMaterial(inventory, 'MAT-10', '替代物资');
      final replaceRequest = await _createRequest(
        purchases,
        disabledId,
        quantity: 1,
      );
      await _moveToPendingReceive(purchases, replaceRequest);
      final replaceItem = await _purchaseItem(db, replaceRequest);
      await expectLater(
        purchases.stockIn(
          StockInInput(
            requestId: replaceRequest,
            stockInDate: DateTime(2026, 8, 1),
            lines: [
              PurchaseStockInLineInput(
                requestItemId: replaceItem.id,
                quantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<PurchaseException>()),
      );
      await purchases.stockIn(
        StockInInput(
          requestId: replaceRequest,
          stockInDate: DateTime(2026, 8, 1),
          lines: [
            PurchaseStockInLineInput(
              requestItemId: replaceItem.id,
              quantity: 1,
              inventoryMaterialId: replacementId,
            ),
          ],
        ),
      );
      expect(
        (await _purchaseItem(db, replaceRequest)).inventoryMaterialId,
        replacementId,
      );
      expect((await inventory.getMaterial(disabledId))?.status, 'disabled');
      expect((await inventory.getMaterial(replacementId))?.currentStock, 1);

      final restoreRequest = await _createRequest(
        purchases,
        disabledId,
        quantity: 1,
      );
      await _moveToPendingReceive(purchases, restoreRequest);
      final restoreItem = await _purchaseItem(db, restoreRequest);
      await purchases.stockIn(
        StockInInput(
          requestId: restoreRequest,
          stockInDate: DateTime(2026, 8, 2),
          lines: [
            PurchaseStockInLineInput(
              requestItemId: restoreItem.id,
              quantity: 1,
              restoreLinkedMaterial: true,
            ),
          ],
        ),
      );
      expect((await inventory.getMaterial(disabledId))?.status, 'active');
      expect((await inventory.getMaterial(disabledId))?.currentStock, 1);

      final manualRequest = await purchases.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '新建库存物资',
          items: [_line('新物资', quantity: 2)],
        ),
      );
      await _moveToPendingReceive(purchases, manualRequest);
      final manualItem = await _purchaseItem(db, manualRequest);
      await purchases.stockIn(
        StockInInput(
          requestId: manualRequest,
          stockInDate: DateTime(2026, 8, 3),
          lines: [
            PurchaseStockInLineInput(
              requestItemId: manualItem.id,
              quantity: 2,
              createInventoryMaterial: true,
              newMaterialCode: 'PUR-NEW-01',
            ),
          ],
        ),
      );
      final newMaterialId = (await _purchaseItem(
        db,
        manualRequest,
      )).inventoryMaterialId;
      expect(newMaterialId, isNotNull);
      expect((await inventory.getMaterial(newMaterialId!))?.currentStock, 2);
    },
  );

  test('history uses a single real date inside the selected range', () async {
    final materialId = await _createMaterial(inventory, 'MAT-07', '轴套');
    final requestId = await purchases.createPurchaseRequest(
      CreatePurchaseRequestInput(
        title: '跨界日期记录',
        requestDate: DateTime(2026, 7, 1),
        items: [_line('轴套', materialId: materialId, quantity: 1)],
      ),
    );
    await purchases.updatePurchaseMetadata(
      requestId,
      UpdatePurchaseMetadataInput(
        title: '跨界日期记录',
        requestDate: DateTime(2026, 7, 1),
        appliedDate: DateTime(2026, 7, 25),
      ),
    );
    final boundaryRequest = await purchases.createPurchaseRequest(
      CreatePurchaseRequestInput(
        title: '结束日边界记录',
        requestDate: DateTime(2026, 7, 1),
        items: [_line('轴套', materialId: materialId, quantity: 1)],
      ),
    );
    await purchases.updatePurchaseMetadata(
      boundaryRequest,
      UpdatePurchaseMetadataInput(
        title: '结束日边界记录',
        requestDate: DateTime(2026, 7, 1),
        appliedDate: DateTime(2026, 7, 20, 23, 59),
      ),
    );

    final rows = await purchases
        .watchHistory(
          PurchaseHistoryFilter(
            startDate: DateTime(2026, 7, 10),
            endDate: DateTime(2026, 7, 20),
          ),
        )
        .first;
    expect(rows, hasLength(1));
    expect(rows.single.requestId, boundaryRequest);
  });

  test(
    'recent cycles follow completion chronology and count one request once',
    () async {
      final materialId = await _createMaterial(inventory, 'MAT-11', '轴承');
      final completed = <(DateTime applied, DateTime received)>[
        (DateTime(2026, 1, 1), DateTime(2026, 1, 11)),
        (DateTime(2026, 1, 5), DateTime(2026, 1, 16)),
        (DateTime(2026, 1, 20), DateTime(2026, 2, 14)),
        (DateTime(2026, 2, 20), DateTime(2026, 2, 28)),
      ];
      for (var index = 0; index < completed.length; index++) {
        final requestId = await _createRequest(
          purchases,
          materialId,
          quantity: 1,
        );
        await purchases.confirmApplied(
          requestId,
          ConfirmAppliedInput(appliedDate: completed[index].$1),
        );
        await purchases.assignPurchaser(
          requestId,
          AssignPurchaserInput(
            assignedDate: completed[index].$1.add(const Duration(days: 1)),
          ),
        );
        await purchases.markPendingReceive(
          requestId,
          PendingReceiveInput(
            arrivalNoticeDate: completed[index].$1.add(const Duration(days: 2)),
          ),
        );
        final purchaseItem = await _purchaseItem(db, requestId);
        await purchases.stockIn(
          StockInInput(
            requestId: requestId,
            stockInDate: completed[index].$2,
            lines: [
              PurchaseStockInLineInput(
                requestItemId: purchaseItem.id,
                quantity: 1,
              ),
            ],
          ),
        );
      }
      final repeatedLineRequest = await purchases.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '同物资多明细',
          items: [
            _line('轴承', materialId: materialId, quantity: 1),
            _line('轴承', materialId: materialId, quantity: 2),
          ],
        ),
      );
      final history = await purchases.watchItemHistory(materialId).first;
      expect(history, isNotNull);
      expect(history!.purchaseCount, 5);
      expect(history.recentCycleDays, [8, 25, 11]);
      expect(history.averageCycleDays, closeTo(44 / 3, 0.0001));
      expect(
        history.rows.where((row) => row.requestId == repeatedLineRequest),
        hasLength(2),
      );
    },
  );

  test(
    'manual stocked state is excluded from real completion statistics',
    () async {
      final materialId = await _createMaterial(inventory, 'MAT-12', '铜套');
      final requestId = await _createRequest(
        purchases,
        materialId,
        quantity: 2,
      );
      await purchases.changeStatusManually(
        ManualPurchaseStatusInput(
          requestId: requestId,
          targetStatus: PurchaseStatus.stocked,
          confirmed: true,
        ),
      );
      expect((await _purchaseRequest(db, requestId)).completedAt, isNull);
      expect((await purchases.watchDashboard().first).stockedThisMonthCount, 0);
      final history = await purchases
          .watchHistory(const PurchaseHistoryFilter())
          .first;
      expect(history.single.completedAt, isNull);
      expect(history.single.cycleDays, isNull);
    },
  );

  test(
    'reminder visibility ignores disabled and completed reminders',
    () async {
      final materialId = await _createMaterial(inventory, 'MAT-08', '灯泡');
      final requestId = await _createRequest(
        purchases,
        materialId,
        quantity: 1,
      );
      final reminders = ReminderRepository(db);
      await reminders.save(
        draft: ReminderDraft(
          title: '领取采购物资',
          reminderType: 'custom',
          leadDays: 0,
          isEnabled: false,
          sourceEntityType: 'purchase_request',
          sourceEntityId: requestId,
        ),
      );
      expect(await purchases.hasReminder(requestId), isFalse);
      expect(await purchases.findReminderId(requestId), isNotNull);
    },
  );
}

Future<int> _createMaterial(
  InventoryRepository repository,
  String code,
  String name,
) => repository.createMaterial(
  InventoryMaterialDraft(materialCode: code, materialName: name, unitName: '个'),
);

PurchaseItemDraft _line(
  String name, {
  int? materialId,
  required double quantity,
  String unit = '个',
}) => PurchaseItemDraft(
  inventoryMaterialId: materialId,
  itemName: name,
  unit: unit,
  requestQuantity: quantity,
);

Future<int> _createRequest(
  PurchaseRepositoryImpl repository,
  int materialId, {
  required double quantity,
}) => repository.createPurchaseRequest(
  CreatePurchaseRequestInput(
    title: '测试采购',
    requestDate: DateTime(2026, 1, 1),
    items: [_line('测试物资', materialId: materialId, quantity: quantity)],
  ),
);

Future<void> _moveToPendingReceive(
  PurchaseRepositoryImpl repository,
  int requestId,
) async {
  await repository.confirmApplied(
    requestId,
    ConfirmAppliedInput(appliedDate: DateTime(2026, 1, 2)),
  );
  await repository.assignPurchaser(
    requestId,
    AssignPurchaserInput(
      purchaserName: null,
      assignedDate: DateTime(2026, 1, 3),
    ),
  );
  await repository.markPendingReceive(
    requestId,
    PendingReceiveInput(arrivalNoticeDate: DateTime(2026, 1, 4)),
  );
}

Future<PurchaseRequestItem> _purchaseItem(AppDatabase db, int requestId) =>
    (db.select(
      db.purchaseRequestItems,
    )..where((t) => t.requestId.equals(requestId))).getSingle();

Future<PurchaseRequest> _purchaseRequest(AppDatabase db, int requestId) =>
    (db.select(
      db.purchaseRequests,
    )..where((t) => t.id.equals(requestId))).getSingle();
