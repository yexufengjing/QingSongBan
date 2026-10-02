import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/purchase_demo_data_seeder.dart';
import 'package:qingsongban/features/purchase/data/purchase_repository_impl.dart';
import 'package:qingsongban/features/purchase/domain/purchase_models.dart';
import 'package:qingsongban/features/purchase/domain/purchase_status.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'seeds labeled Chinese purchase scenarios once with repository history',
    () async {
      final purchases = PurchaseRepositoryImpl(database);

      expect(await PurchaseDemoDataSeeder.seed(database), isTrue);

      final requests = await purchases
          .watchRequests(const PurchaseFilter())
          .first;
      expect(requests, hasLength(9));
      expect(
        requests.map((request) => request.status).toSet(),
        containsAll(PurchaseStatus.values),
      );
      expect(
        requests.every((request) => request.title.startsWith('【演示】')),
        isTrue,
      );
      expect(requests.where((request) => request.itemCount > 1), hasLength(6));
      final seededRows = await database.select(database.purchaseRequests).get();
      expect(
        seededRows.map((request) => request.demandReason).toSet(),
        containsAll(['库存不足', '临时需求', '设备维修', '其他']),
      );
      final demoMaterials = await (database.select(
        database.inventoryMaterials,
      )..where((row) => row.materialCode.like('DEMO-PUR-%'))).get();
      expect(demoMaterials, hasLength(4));
      expect(
        demoMaterials.every((material) => material.remark!.contains('演示数据')),
        isTrue,
      );

      final partial = requests.singleWhere(
        (request) => request.title.contains('分批到货'),
      );
      final partialDetail = await purchases.watchDetail(partial.id).first;
      expect(partialDetail, isNotNull);
      expect(partialDetail!.items, hasLength(2));
      expect(
        partialDetail.items.map((item) => item.receivedQuantity),
        contains(4),
      );
      expect(
        partialDetail.items.map((item) => item.remainingQuantity),
        contains(6),
      );
      expect(
        partialDetail.items.map((item) => item.remainingQuantity),
        contains(20),
      );
      expect(partialDetail.stockEntries, hasLength(1));
      expect(partialDetail.statusLogs.map((log) => log.newStatus), [
        PurchaseStatus.pendingApply,
        PurchaseStatus.applied,
        PurchaseStatus.purchasing,
        PurchaseStatus.pendingReceive,
        PurchaseStatus.pendingReceive,
      ]);
      expect(await purchases.hasReminder(partial.id), isTrue);

      final stopped = requests.singleWhere(
        (request) => request.title.contains('原关联物资已停用'),
      );
      expect(stopped.status, PurchaseStatus.pendingReceive);
      final stoppedDetail = await purchases.watchDetail(stopped.id).first;
      expect(stoppedDetail!.items, hasLength(1));
      final stoppedMaterial =
          await (database.select(database.inventoryMaterials)..where(
                (row) => row.id.equals(
                  stoppedDetail.items.single.inventoryMaterialId!,
                ),
              ))
              .getSingle();
      expect(stoppedMaterial.status, 'stopped');

      final stocked = requests.singleWhere(
        (request) => request.title.contains('已入库·应急物资补充'),
      );
      final stockedDetail = await purchases.watchDetail(stocked.id).first;
      expect(stockedDetail!.items, hasLength(2));
      expect(
        stockedDetail.items.every((item) => item.remainingQuantity == 0),
        isTrue,
      );
      expect(stockedDetail.stockEntries, hasLength(2));
      expect(stockedDetail.statusLogs.map((log) => log.newStatus), [
        PurchaseStatus.pendingApply,
        PurchaseStatus.applied,
        PurchaseStatus.purchasing,
        PurchaseStatus.pendingReceive,
        PurchaseStatus.stocked,
      ]);

      final historyMaterial =
          await (database.select(
                database.inventoryMaterials,
              )..where((row) => row.materialCode.equals('DEMO-PUR-HISTORY-01')))
              .getSingle();
      final itemHistory = await purchases
          .watchItemHistory(historyMaterial.id)
          .first;
      expect(itemHistory, isNotNull);
      expect(itemHistory!.purchaseCount, 3);
      expect(itemHistory.rows, hasLength(3));
      expect(itemHistory.rows.every((row) => row.completedAt != null), isTrue);
      expect(itemHistory.recentCycleDays, hasLength(3));
      expect(itemHistory.recentCycleDays.toSet(), hasLength(3));
      expect(
        itemHistory.averageCycleDays,
        itemHistory.recentCycleDays.reduce((a, b) => a + b) /
            itemHistory.recentCycleDays.length,
      );

      final cancelled = requests.singleWhere(
        (request) => request.status == PurchaseStatus.cancelled,
      );
      final cancelledDetail = await purchases.watchDetail(cancelled.id).first;
      expect(cancelledDetail!.statusLogs.map((log) => log.newStatus), [
        PurchaseStatus.pendingApply,
        PurchaseStatus.cancelled,
      ]);
      expect(
        await database.select(database.purchaseStatusLogs).get(),
        hasLength(32),
      );
      expect(
        await database.select(database.purchaseStockEntries).get(),
        hasLength(5),
      );
      expect(await database.select(database.reminders).get(), hasLength(1));

      expect(await PurchaseDemoDataSeeder.seed(database), isFalse);
      expect(
        await purchases.watchRequests(const PurchaseFilter()).first,
        hasLength(9),
      );
      expect(
        await database.select(database.purchaseStatusLogs).get(),
        hasLength(32),
      );
      expect(
        await database.select(database.purchaseStockEntries).get(),
        hasLength(5),
      );
    },
  );

  test('preserves existing purchases when adding demo fixtures', () async {
    final purchases = PurchaseRepositoryImpl(database);
    await purchases.createPurchaseRequest(
      const CreatePurchaseRequestInput(
        title: '用户已有采购申请',
        items: [
          PurchaseItemDraft(itemName: '真实业务物资', unit: '个', requestQuantity: 1),
        ],
      ),
    );

    expect(await PurchaseDemoDataSeeder.seed(database), isTrue);
    final requests = await purchases
        .watchRequests(const PurchaseFilter())
        .first;
    expect(requests, hasLength(10));
    expect(
      requests.where((request) => request.title == '用户已有采购申请'),
      hasLength(1),
    );
  });
}
