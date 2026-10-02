import 'package:drift/drift.dart';

import '../../features/inventory/data/inventory_repository.dart';
import '../../features/inventory/domain/inventory_models.dart';
import '../../features/purchase/data/purchase_repository_impl.dart';
import '../../features/purchase/domain/purchase_models.dart';
import '../../features/purchase/domain/purchase_status.dart';
import '../../features/reminders/data/reminder_repository.dart';
import '../../features/reminders/domain/reminder_options.dart';
import 'app_database.dart';

/// Creates explicitly fictional Chinese purchase records for manual UI review.
///
/// Run with `--dart-define=QSB_SEED_PURCHASE_DATA=true`. The data uses the
/// existing schema and repositories, and is isolated by its marker and title
/// prefix. It never removes or rewrites existing purchase records.
abstract final class PurchaseDemoDataSeeder {
  static const markerKey = 'purchase_demo_data_seed_v1';
  static const titlePrefix = '【演示】';

  static Future<bool> seed(AppDatabase database) async {
    final marker = await (database.select(
      database.appSettings,
    )..where((row) => row.settingKey.equals(markerKey))).getSingleOrNull();
    if (marker != null) return false;

    final existing = await (database.select(
      database.purchaseRequests,
    )..where((row) => row.title.like('$titlePrefix%'))).get();
    if (existing.isNotEmpty) return false;

    return database.transaction(() async {
      final purchases = PurchaseRepositoryImpl(database);
      final inventory = InventoryRepository(database);
      final now = DateTime.now();

      await purchases.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '$titlePrefix待申报·保洁班日常耗材补充',
          requestDate: _daysAgo(now, 1),
          demandReason: '库存不足',
          remark: '演示数据：日常作业库存低于班组备货需求，多物资采购申报草稿。',
          items: const [
            PurchaseItemDraft(
              itemName: '加厚垃圾袋',
              specification: '黑色，大号，50只/捆',
              unit: '捆',
              currentStockSnapshot: 6,
              requestQuantity: 20,
              remark: '用于道路保洁班组日常作业。',
            ),
            PurchaseItemDraft(
              itemName: '棉线拖把替换头',
              specification: '中号，棉线吸水款',
              unit: '个',
              currentStockSnapshot: 4,
              requestQuantity: 12,
            ),
            PurchaseItemDraft(
              itemName: '长柄扫帚',
              specification: '竹柄，硬毛头',
              unit: '把',
              currentStockSnapshot: 3,
              requestQuantity: 8,
            ),
          ],
        ),
      );

      final appliedId = await purchases.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '$titlePrefix已申报·维修班常用备件',
          requestDate: _daysAgo(now, 8),
          demandReason: '设备维修',
          remark: '演示数据：设备巡检发现常用紧固件和绝缘耗材余量不足。',
          items: const [
            PurchaseItemDraft(
              itemName: '镀锌螺栓螺母套件',
              specification: 'M8/M10组合装',
              unit: '套',
              currentStockSnapshot: 5,
              requestQuantity: 10,
            ),
            PurchaseItemDraft(
              itemName: '耐候绝缘胶带',
              specification: '黑色，宽20毫米',
              unit: '卷',
              currentStockSnapshot: 7,
              requestQuantity: 15,
            ),
          ],
        ),
      );
      await purchases.confirmApplied(
        appliedId,
        ConfirmAppliedInput(
          appliedDate: _daysAgo(now, 7),
          oaRequestNo: '演示OA-2026-001',
          oaTitle: '维修班常用备件申报',
          oaUrl: 'https://example.test/oa/demo-2026-001',
        ),
      );

      final purchasingId = await purchases.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '$titlePrefix采购中·环卫车辆保养用品',
          requestDate: _daysAgo(now, 6),
          demandReason: '临时需求',
          remark: '演示数据：本月车辆例行保养使用。',
          items: const [
            PurchaseItemDraft(
              itemName: '柴油机油',
              specification: '柴油设备适用，4升装',
              unit: '桶',
              currentStockSnapshot: 2,
              requestQuantity: 8,
            ),
            PurchaseItemDraft(
              itemName: '通用润滑脂',
              specification: '锂基润滑脂，2公斤装',
              unit: '桶',
              currentStockSnapshot: 1,
              requestQuantity: 6,
            ),
          ],
        ),
      );
      await purchases.confirmApplied(
        purchasingId,
        ConfirmAppliedInput(
          appliedDate: _daysAgo(now, 5),
          oaRequestNo: '演示OA-2026-002',
          oaTitle: '环卫车辆保养用品申报',
          oaUrl: 'https://example.test/oa/demo-2026-002',
        ),
      );
      await purchases.assignPurchaser(
        purchasingId,
        AssignPurchaserInput(
          purchaseDepartment: '综合保障部',
          purchaserName: '演示采购员甲',
          assignedDate: _daysAgo(now, 4),
        ),
      );

      final partialMaterialId = await _createDemoMaterial(
        inventory,
        code: 'DEMO-PUR-PARTIAL-01',
        name: '防护手套',
        specification: '耐磨型，棉纱内衬',
        unit: '双',
        location: '北库房·劳保架一层',
        remark: '分批入库采购演示物资。',
      );
      final partialId = await purchases.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '$titlePrefix待领取·防护用品分批到货',
          requestDate: _daysAgo(now, 12),
          demandReason: '库存不足',
          remark: '演示数据：首批到货后仍有明细待入库。',
          items: [
            PurchaseItemDraft(
              inventoryMaterialId: partialMaterialId,
              itemName: '防护手套',
              specification: '耐磨型，棉纱内衬',
              unit: '双',
              currentStockSnapshot: 5,
              requestQuantity: 10,
            ),
            PurchaseItemDraft(
              itemName: '防尘口罩',
              specification: '折叠款，可更换滤片',
              unit: '只',
              currentStockSnapshot: 8,
              requestQuantity: 20,
            ),
          ],
        ),
      );
      await purchases.confirmApplied(
        partialId,
        ConfirmAppliedInput(
          appliedDate: _daysAgo(now, 10),
          oaRequestNo: '演示OA-2026-003',
          oaTitle: '班组防护用品补充申报',
          oaUrl: 'https://example.test/oa/demo-2026-003',
        ),
      );
      await purchases.assignPurchaser(
        partialId,
        AssignPurchaserInput(
          purchaseDepartment: '综合保障部',
          purchaserName: '演示采购员乙',
          assignedDate: _daysAgo(now, 9),
        ),
      );
      await purchases.markPendingReceive(
        partialId,
        PendingReceiveInput(
          arrivalNoticeDate: _daysAgo(now, 2),
          receiveLocation: '北库房收货区',
        ),
      );
      final partialDetail = await purchases.watchDetail(partialId).first;
      final firstPartialItem = partialDetail!.items.first;
      await purchases.stockIn(
        StockInInput(
          requestId: partialId,
          stockInDate: _daysAgo(now, 1),
          remark: '演示数据：第一批到货，另一项尚未入库。',
          lines: [
            PurchaseStockInLineInput(
              requestItemId: firstPartialItem.id,
              quantity: 4,
              storageLocation: '北库房·劳保架一层',
              remark: '演示数据：首批清点合格，余量待到货。',
            ),
          ],
        ),
      );

      final historyMaterialId = await _createDemoMaterial(
        inventory,
        code: 'DEMO-PUR-HISTORY-01',
        name: '应急手电筒',
        specification: '充电款，防水外壳',
        unit: '个',
        location: '应急仓库·手电筒货架',
        remark: '近三周期采购历史演示物资。',
      );
      final emergencyBagMaterialId = await _createDemoMaterial(
        inventory,
        code: 'DEMO-PUR-STOCKED-02',
        name: '急救包',
        specification: '基础外伤用品组合',
        unit: '包',
        location: '应急仓库·急救用品货架',
        remark: '已入库状态演示物资。',
      );
      final stockedId = await purchases.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '$titlePrefix已入库·应急物资补充',
          requestDate: _daysAgo(now, 20),
          demandReason: '其他',
          remark: '演示数据：应急柜季度检查后补齐消耗物资。',
          items: [
            PurchaseItemDraft(
              inventoryMaterialId: historyMaterialId,
              itemName: '应急手电筒',
              specification: '充电款，防水外壳',
              unit: '个',
              currentStockSnapshot: 1,
              requestQuantity: 5,
            ),
            PurchaseItemDraft(
              inventoryMaterialId: emergencyBagMaterialId,
              itemName: '急救包',
              specification: '基础外伤用品组合',
              unit: '包',
              currentStockSnapshot: 2,
              requestQuantity: 4,
            ),
          ],
        ),
      );
      await purchases.confirmApplied(
        stockedId,
        ConfirmAppliedInput(
          appliedDate: _daysAgo(now, 18),
          oaRequestNo: '演示OA-2026-004',
          oaTitle: '应急物资补充申报',
          oaUrl: 'https://example.test/oa/demo-2026-004',
        ),
      );
      await purchases.assignPurchaser(
        stockedId,
        AssignPurchaserInput(
          purchaseDepartment: '安全管理组',
          purchaserName: '演示采购员丙',
          assignedDate: _daysAgo(now, 17),
        ),
      );
      await purchases.markPendingReceive(
        stockedId,
        PendingReceiveInput(
          arrivalNoticeDate: _daysAgo(now, 5),
          receiveLocation: '应急仓库收货区',
        ),
      );
      final stockedDetail = await purchases.watchDetail(stockedId).first;
      await purchases.stockIn(
        StockInInput(
          requestId: stockedId,
          stockInDate: _daysAgo(now, 3),
          remark: '演示数据：两种应急物资均已清点入库。',
          lines: [
            for (var index = 0; index < stockedDetail!.items.length; index++)
              PurchaseStockInLineInput(
                requestItemId: stockedDetail.items[index].id,
                quantity: stockedDetail.items[index].requestQuantity,
                storageLocation: '应急仓库·货架${index + 1}层',
                remark: '演示数据：收货，数量核对完成。',
              ),
          ],
        ),
      );

      await _seedCompletedHistory(
        purchases,
        now: now,
        requestTitle: '$titlePrefix历史周期一·应急手电筒',
        materialId: historyMaterialId,
        requestDaysAgo: 150,
        appliedDaysAgo: 140,
        assignedDaysAgo: 139,
        arrivalDaysAgo: 135,
        stockInDaysAgo: 132,
        requestQuantity: 3,
        oaRequestNo: '演示OA-历史-001',
      );
      await _seedCompletedHistory(
        purchases,
        now: now,
        requestTitle: '$titlePrefix历史周期二·应急手电筒',
        materialId: historyMaterialId,
        requestDaysAgo: 80,
        appliedDaysAgo: 70,
        assignedDaysAgo: 69,
        arrivalDaysAgo: 60,
        stockInDaysAgo: 57,
        requestQuantity: 4,
        oaRequestNo: '演示OA-历史-002',
      );

      final disabledMaterialId = await inventory.createMaterial(
        const InventoryMaterialDraft(
          materialCode: 'DEMO-PUR-STOPPED-01',
          materialName: '耐油密封圈',
          modelSpec: '【演示】旧规格，仅用于处理分支验证',
          unitName: '个',
          storageLocation: '演示库位',
          status: 'stopped',
          remark: '演示数据：用于停用关联物资的入库处理分支。',
        ),
      );
      final stoppedId = await purchases.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '$titlePrefix待领取·原关联物资已停用',
          requestDate: _daysAgo(now, 9),
          demandReason: '设备维修',
          remark: '演示数据：可测试恢复原物资、改选其他物资或新建物资。',
          items: [
            PurchaseItemDraft(
              inventoryMaterialId: disabledMaterialId,
              itemName: '耐油密封圈',
              specification: '内径32毫米，耐油橡胶',
              unit: '个',
              currentStockSnapshot: 0,
              requestQuantity: 6,
              remark: '关联物资已停用，入库处理时由操作人员选择解决方式。',
            ),
          ],
        ),
      );
      await purchases.confirmApplied(
        stoppedId,
        ConfirmAppliedInput(
          appliedDate: _daysAgo(now, 8),
          oaRequestNo: '演示OA-2026-005',
          oaTitle: '设备密封圈补充申报',
          oaUrl: 'https://example.test/oa/demo-2026-005',
        ),
      );
      await purchases.assignPurchaser(
        stoppedId,
        AssignPurchaserInput(
          purchaseDepartment: '设备保障组',
          purchaserName: '演示采购员丁',
          assignedDate: _daysAgo(now, 7),
        ),
      );
      await purchases.markPendingReceive(
        stoppedId,
        PendingReceiveInput(
          arrivalNoticeDate: _daysAgo(now, 1),
          receiveLocation: '设备库房收货区',
        ),
      );

      final cancelledId = await purchases.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '$titlePrefix已取消·办公耗材临时申报',
          requestDate: _daysAgo(now, 3),
          demandReason: '临时需求',
          remark: '演示数据：需求调整后取消。',
          items: const [
            PurchaseItemDraft(
              itemName: '打印纸',
              specification: 'A4，80克，每箱8包',
              unit: '箱',
              currentStockSnapshot: 3,
              requestQuantity: 5,
            ),
            PurchaseItemDraft(
              itemName: '黑色记号笔',
              specification: '粗头，油性',
              unit: '支',
              currentStockSnapshot: 6,
              requestQuantity: 12,
            ),
          ],
        ),
      );
      await purchases.changeStatusManually(
        ManualPurchaseStatusInput(
          requestId: cancelledId,
          targetStatus: PurchaseStatus.cancelled,
          confirmed: true,
          remark: '演示数据：需求调整，停止本次采购。',
        ),
      );

      await ReminderRepository(database).save(
        draft: ReminderDraft(
          title: '$titlePrefix防护用品待领取',
          reminderType: 'custom',
          category: 'plan',
          priority: 'important',
          dueDate: now.add(const Duration(days: 1)),
          leadDays: 0,
          isEnabled: true,
          sourceEntityType: 'purchase_request',
          sourceEntityId: partialId,
          remark: '演示提醒：待领取采购到货后通知班组领用。',
        ),
      );

      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              settingKey: markerKey,
              settingValue: Value(now.toIso8601String()),
              updatedAt: Value(now),
            ),
          );
      return true;
    });
  }

  static Future<int> _createDemoMaterial(
    InventoryRepository inventory, {
    required String code,
    required String name,
    required String specification,
    required String unit,
    required String location,
    required String remark,
  }) => inventory.createMaterial(
    InventoryMaterialDraft(
      materialCode: code,
      materialName: name,
      modelSpec: specification,
      unitName: unit,
      storageLocation: location,
      warningEnabled: true,
      isCommon: false,
      remark: '演示数据：$remark',
    ),
  );

  static Future<void> _seedCompletedHistory(
    PurchaseRepositoryImpl purchases, {
    required DateTime now,
    required String requestTitle,
    required int materialId,
    required int requestDaysAgo,
    required int appliedDaysAgo,
    required int assignedDaysAgo,
    required int arrivalDaysAgo,
    required int stockInDaysAgo,
    required double requestQuantity,
    required String oaRequestNo,
  }) async {
    final requestId = await purchases.createPurchaseRequest(
      CreatePurchaseRequestInput(
        title: requestTitle,
        requestDate: _daysAgo(now, requestDaysAgo),
        demandReason: '库存不足',
        remark: '演示数据：同一应急手电筒的历史采购周期。',
        items: [
          PurchaseItemDraft(
            inventoryMaterialId: materialId,
            itemName: '应急手电筒',
            specification: '充电款，防水外壳',
            unit: '个',
            currentStockSnapshot: 1,
            requestQuantity: requestQuantity,
            remark: '演示历史采购明细。',
          ),
        ],
      ),
    );
    await purchases.confirmApplied(
      requestId,
      ConfirmAppliedInput(
        appliedDate: _daysAgo(now, appliedDaysAgo),
        oaRequestNo: oaRequestNo,
        oaTitle: '应急手电筒历史申报（演示）',
        oaUrl: 'https://example.test/oa/$oaRequestNo',
      ),
    );
    await purchases.assignPurchaser(
      requestId,
      AssignPurchaserInput(
        purchaseDepartment: '安全管理组',
        purchaserName: '演示采购员甲',
        assignedDate: _daysAgo(now, assignedDaysAgo),
      ),
    );
    await purchases.markPendingReceive(
      requestId,
      PendingReceiveInput(
        arrivalNoticeDate: _daysAgo(now, arrivalDaysAgo),
        receiveLocation: '应急仓库收货区',
      ),
    );
    final detail = await purchases.watchDetail(requestId).first;
    final item = detail!.items.single;
    await purchases.stockIn(
      StockInInput(
        requestId: requestId,
        stockInDate: _daysAgo(now, stockInDaysAgo),
        remark: '演示数据：历史采购已完成入库。',
        lines: [
          PurchaseStockInLineInput(
            requestItemId: item.id,
            quantity: requestQuantity,
            storageLocation: '应急仓库·手电筒货架',
            remark: '演示历史入库记录。',
          ),
        ],
      ),
    );
  }

  static DateTime _daysAgo(DateTime date, int days) =>
      date.subtract(Duration(days: days));
}
