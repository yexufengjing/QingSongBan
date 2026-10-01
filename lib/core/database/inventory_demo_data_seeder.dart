import 'package:drift/drift.dart';

import '../../features/inventory/data/inventory_repository.dart';
import '../../features/inventory/domain/inventory_models.dart';
import 'app_database.dart';
import 'database_enums.dart';

/// Creates fictional Chinese inventory records for manual UI verification.
///
/// Run with `--dart-define=QSB_SEED_INVENTORY_DATA=true`. The seed is isolated
/// from existing business rows and guarded by both a marker and its own codes.
abstract final class InventoryDemoDataSeeder {
  static const markerKey = 'inventory_demo_data_seed_v1';
  static const materialCodePrefix = '演示库存物资-';

  static const _categoryNames = [
    '劳保用品',
    '清洁工具',
    '维修耗材',
    '卫生用品',
    '办公用品',
    '应急物资',
  ];

  static const _materials = <_MaterialSeed>[
    _MaterialSeed('安全帽', '黄色，加厚型', '顶', 12, 10, 3200, 0, '劳保用品'),
    _MaterialSeed('防护手套', '耐磨型，棉纱内衬', '双', 8, 6, 850, 1, '劳保用品'),
    _MaterialSeed('防尘口罩', '可更换滤片，折叠款', '只', 18, 15, 1200, 2, '劳保用品'),
    _MaterialSeed('防护眼镜', '透明镜片，防飞溅', '副', 7, 5, 1800, 3, '劳保用品'),
    _MaterialSeed('反光背心', '荧光黄，均码', '件', 6, 4, 2600, 4, '劳保用品'),
    _MaterialSeed('长柄扫帚', '竹柄，硬毛头', '把', 45, 10, 1800, 5, '清洁工具'),
    _MaterialSeed('环卫簸箕', '加厚塑料，长柄款', '把', 52, 12, 2200, 6, '清洁工具'),
    _MaterialSeed('垃圾夹', '不锈钢夹头，长柄', '把', 54, 12, 2500, 7, '清洁工具'),
    _MaterialSeed('地面刷', '宽刷头，硬毛', '把', 56, 12, 2100, 8, '清洁工具'),
    _MaterialSeed('吸水拖把头', '棉线替换头', '个', 58, 12, 1600, 9, '清洁工具'),
    _MaterialSeed('润滑脂', '通用型，五公斤装', '桶', 60, 15, 9800, 10, '维修耗材'),
    _MaterialSeed('发动机机油', '柴油设备专用，四升装', '桶', 62, 15, 16800, 11, '维修耗材'),
    _MaterialSeed('轮胎修补胶', '快干型，小支装', '支', 64, 16, 1300, 12, '维修耗材'),
    _MaterialSeed('螺栓螺母套件', '镀锌钢，多规格组合', '套', 66, 16, 3600, 13, '维修耗材'),
    _MaterialSeed('绝缘胶带', '黑色，耐候型', '卷', 68, 16, 600, 14, '维修耗材'),
    _MaterialSeed('垃圾袋', '加厚型，黑色大号', '捆', 70, 18, 2400, 15, '卫生用品'),
    _MaterialSeed('洗手液', '清香型，五百毫升', '瓶', 72, 18, 1500, 16, '卫生用品'),
    _MaterialSeed('消毒液', '含氯型，五升装', '桶', 74, 18, 5600, 17, '卫生用品'),
    _MaterialSeed('清洁抹布', '超细纤维，蓝色', '条', 76, 18, 900, 18, '卫生用品'),
    _MaterialSeed('洗衣粉', '低泡型，三公斤装', '袋', 78, 18, 2100, 19, '卫生用品'),
    _MaterialSeed('记号笔', '黑色，粗头', '支', 80, 20, 500, 20, '办公用品'),
    _MaterialSeed('标签纸', '白色，不干胶，每包五百张', '包', 82, 20, 1800, 21, '办公用品'),
    _MaterialSeed('工作记录本', '横线页，八十页', '本', 84, 20, 700, 22, '办公用品'),
    _MaterialSeed('五号电池', '碱性电池，四节装', '板', 86, 20, 1200, 23, '办公用品'),
    _MaterialSeed('打印纸', '白色，八十克，每箱八包', '箱', 88, 20, 19800, 24, '办公用品'),
    _MaterialSeed('灭火器检查标签', '耐水贴纸，红边款', '张', 90, 20, 300, 25, '应急物资'),
    _MaterialSeed('急救包', '基础外伤用品组合', '包', 92, 20, 8600, 26, '应急物资'),
    _MaterialSeed('应急手电筒', '充电款，防水外壳', '个', 94, 20, 6800, 27, '应急物资'),
    _MaterialSeed('警戒带', '红白相间，五十米装', '卷', 96, 20, 3200, 28, '应急物资'),
    _MaterialSeed('绝缘手套', '耐压型，橡胶材质', '双', 98, 20, 4600, 29, '应急物资'),
  ];

  static const _receiptTypes = [
    'purchase',
    'purchase',
    'central_store',
    'transfer_in',
    'return_in',
    'purchase',
  ];

  static const _receiptSources = [
    '广源劳保用品商行',
    '城北清洁设备供应站',
    '市政综合物资仓库',
    '东区作业仓调拨',
    '环卫班组退回物资',
    '安泰办公用品商店',
  ];

  static const _issueSeeds = <_IssueSeed>[
    _IssueSeed('employee_claim', 'employee', '班组日常防护用品', [
      _IssueLineSeed(0, 3),
      _IssueLineSeed(5, 5),
      _IssueLineSeed(9, 8),
    ]),
    _IssueSeed('department_use', 'department', '道路保洁作业补充', [
      _IssueLineSeed(0, 4),
      _IssueLineSeed(6, 4),
      _IssueLineSeed(10, 3),
    ]),
    _IssueSeed('employee_claim', 'employee', '夜班清洁用品领用', [
      _IssueLineSeed(1, 3),
      _IssueLineSeed(7, 8),
      _IssueLineSeed(11, 5),
    ]),
    _IssueSeed('department_use', 'department', '卫生间日常补给', [
      _IssueLineSeed(1, 3),
      _IssueLineSeed(8, 6),
      _IssueLineSeed(12, 6),
    ]),
    _IssueSeed('other', 'public', '应急柜定期补充', [
      _IssueLineSeed(2, 8),
      _IssueLineSeed(13, 6),
      _IssueLineSeed(16, 4),
      _IssueLineSeed(4, 6),
    ]),
    _IssueSeed('transfer_out', 'department', '支援南区临时调拨', [
      _IssueLineSeed(2, 8),
      _IssueLineSeed(14, 8),
      _IssueLineSeed(18, 7),
      _IssueLineSeed(3, 7),
    ]),
  ];

  static Future<bool> seed(AppDatabase database) async {
    final marker = await (database.select(
      database.appSettings,
    )..where((row) => row.settingKey.equals(markerKey))).getSingleOrNull();
    if (marker != null) return false;

    final existing = await (database.select(
      database.inventoryMaterials,
    )..where((row) => row.materialCode.like('$materialCodePrefix%'))).get();
    if (existing.isNotEmpty) return false;

    return database.transaction(() async {
      final inventory = InventoryRepository(database);
      final now = DateTime.now();
      final categoryIds = await _ensureCategories(database, inventory);
      final materialIds = <int>[];

      for (var index = 0; index < _materials.length; index++) {
        final item = _materials[index];
        materialIds.add(
          await inventory.createMaterial(
            InventoryMaterialDraft(
              materialCode:
                  '$materialCodePrefix${(item.categoryOrder + 1).toString().padLeft(3, '0')}',
              materialName: item.name,
              categoryId: categoryIds[item.category],
              modelSpec: item.specification,
              unitName: item.unit,
              storageLocation:
                  '${_warehouseArea(item.category)}·${index % 3 + 1}层',
              minStock: item.minimumStock,
              maxStock: item.initialStock + 40,
              defaultSource: _receiptSources[index ~/ 5],
              referencePriceCent: item.unitPriceCent,
              warningEnabled: true,
              isCommon: item.categoryOrder % 3 != 1,
              remark: '测试数据：用于库存页面、筛选和预警验证。',
            ),
          ),
        );
      }

      final employee = await _firstActiveEmployee(database);
      for (var batch = 0; batch < _receiptTypes.length; batch++) {
        final start = batch * 5;
        final lines = <InventoryReceiptLineDraft>[];
        for (var index = start; index < start + 5; index++) {
          final item = _materials[index];
          lines.add(
            InventoryReceiptLineDraft(
              materialId: materialIds[index],
              quantity: item.initialStock,
              referencePriceCent: item.unitPriceCent,
              remark: '检验合格，数量已清点。',
            ),
          );
        }
        await inventory.createReceipt(
          InventoryReceiptDraft(
            receiptNo: '演示入库单-${(batch + 1).toString().padLeft(3, '0')}',
            receiptDate: _receiptDate(now, batch),
            receiptType: _receiptTypes[batch],
            sourceName: _receiptSources[batch],
            operatorId: employee?.id,
            operatorName: employee?.name ?? '陈晓梅',
            items: lines,
            remark: '中文测试入库数据，覆盖多来源和日期筛选。',
          ),
        );
      }

      for (var index = 0; index < _issueSeeds.length; index++) {
        final seed = _issueSeeds[index];
        final receiverType = seed.receiverType == 'employee' && employee == null
            ? 'department'
            : seed.receiverType;
        final employeeId = receiverType == 'employee' ? employee!.id : null;
        final departmentName = receiverType == 'department'
            ? (index.isEven ? '道路保洁一组' : '设备维修班')
            : employee?.team ?? employee?.workArea;
        await inventory.createIssue(
          InventoryIssueDraft(
            issueNo: '演示出库单-${(index + 1).toString().padLeft(3, '0')}',
            issueDate: _issueDate(now, index),
            issueType: seed.issueType,
            receiverType: receiverType,
            employeeId: employeeId,
            employeeName: employeeId == null ? null : employee!.name,
            departmentName: departmentName,
            manualReceiverName: switch (receiverType) {
              'employee' || 'public' => null,
              'department' => departmentName,
              _ => '应急值班人员',
            },
            purpose: seed.purpose,
            operatorId: employee?.id,
            operatorName: employee?.name ?? '陈晓梅',
            remark: '测试数据：出库后库存自动扣减。',
            items: [
              for (final line in seed.items)
                InventoryIssueLineDraft(
                  materialId: materialIds[line.materialIndex],
                  quantity: line.quantity,
                  remark: '已交接并登记领用用途。',
                ),
            ],
          ),
        );
      }

      final draftItems = <InventoryStocktakeLineDraft>[];
      for (final index in [5, 6, 7, 8]) {
        final item = await inventory.getMaterial(materialIds[index]);
        draftItems.add(
          InventoryStocktakeLineDraft(
            materialId: materialIds[index],
            actualQuantity: item!.currentStock + (index.isEven ? -1 : 1),
            remark: '待复核货架实数。',
          ),
        );
      }
      await inventory.createStocktakeDraft(
        InventoryStocktakeDraft(
          stocktakeNo: '演示盘点单-待复核',
          stocktakeDate: now.subtract(const Duration(days: 2)),
          operatorId: employee?.id,
          operatorName: employee?.name ?? '陈晓梅',
          items: draftItems,
          remark: '测试草稿：尚未确认，不调整当前库存。',
        ),
      );

      final confirmedId = await inventory.createStocktakeDraft(
        InventoryStocktakeDraft(
          stocktakeNo: '演示盘点单-已确认',
          stocktakeDate: now.subtract(const Duration(days: 5)),
          operatorId: employee?.id,
          operatorName: employee?.name ?? '陈晓梅',
          items: [
            for (final index in [9, 10, 11, 12])
              InventoryStocktakeLineDraft(
                materialId: materialIds[index],
                actualQuantity:
                    (await inventory.getMaterial(materialIds[index]))!
                        .currentStock +
                    (index == 9
                        ? -1
                        : index == 10
                        ? 2
                        : 0),
                remark: index == 9
                    ? '实盘少一件，复核后按盘亏登记。'
                    : index == 10
                    ? '实盘多两件，复核后按盘盈登记。'
                    : '实物与账面一致。',
              ),
          ],
          remark: '测试记录：已完成实物盘点。',
        ),
      );
      await inventory.confirmStocktake(confirmedId);

      for (final index in [0, 1, 2, 3, 4]) {
        final replenishmentId = await inventory.addWarningToReplenishment(
          materialIds[index],
          plannedQuantity: _materials[index].minimumStock * 2,
        );
        if (index == 0) {
          await inventory.updateReplenishmentStatus(
            replenishmentId,
            'submitted',
            plannedQuantity: 20,
            remark: '已提交采购申请，等待审批。',
          );
        } else if (index == 1) {
          await inventory.updateReplenishmentStatus(
            replenishmentId,
            'ordered',
            plannedQuantity: 12,
            remark: '供应商已确认供货。',
          );
        }
      }

      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              settingKey: markerKey,
              settingValue: const Value('已写入中文库存测试数据'),
              updatedAt: Value(now),
            ),
          );
      return true;
    });
  }

  static Future<Map<String, int>> _ensureCategories(
    AppDatabase database,
    InventoryRepository inventory,
  ) async {
    final existing = await database.select(database.inventoryCategories).get();
    final ids = <String, int>{};
    for (final name in _categoryNames) {
      var resolved = false;
      for (final candidate in [name, '$name（演示）', '$name（测试）']) {
        InventoryCategory? found;
        for (final category in existing) {
          if (category.name == candidate) {
            found = category;
            break;
          }
        }

        if (found != null) {
          if (!found.isDeleted) {
            ids[name] = found.id;
            resolved = true;
            break;
          }
          continue;
        }

        ids[name] = await inventory.createCategory(candidate, remark: '库存测试分类');
        resolved = true;
        break;
      }
      if (!resolved) throw StateError('无法创建库存测试分类：$name');
    }
    return ids;
  }

  static Future<Employee?> _firstActiveEmployee(AppDatabase database) async {
    final employees = await (database.select(
      database.employees,
    )..where((row) => row.isDeleted.equals(false))).get();
    for (final employee in employees) {
      if (employee.status == EmployeeStatus.active) return employee;
    }
    return null;
  }

  static DateTime _receiptDate(DateTime now, int batch) {
    if (batch < 3) {
      return DateTime(
        now.year,
        now.month,
        (now.day - batch).clamp(1, now.day).toInt(),
      );
    }
    return DateTime(now.year, now.month - 1, 22 + batch - 3);
  }

  static DateTime _issueDate(DateTime now, int batch) {
    if (batch < 3) {
      return DateTime(
        now.year,
        now.month,
        (now.day - batch).clamp(1, now.day).toInt(),
      );
    }
    return DateTime(now.year, now.month - 1, 18 + batch - 3);
  }

  static String _warehouseArea(String category) => switch (category) {
    '劳保用品' => '劳保区',
    '清洁工具' => '清洁区',
    '维修耗材' => '维修区',
    '卫生用品' => '卫生区',
    '办公用品' => '办公区',
    _ => '应急区',
  };
}

class _MaterialSeed {
  const _MaterialSeed(
    this.name,
    this.specification,
    this.unit,
    this.initialStock,
    this.minimumStock,
    this.unitPriceCent,
    this.categoryOrder,
    this.category,
  );

  final String name;
  final String specification;
  final String unit;
  final double initialStock;
  final double minimumStock;
  final int unitPriceCent;
  final int categoryOrder;
  final String category;
}

class _IssueSeed {
  const _IssueSeed(this.issueType, this.receiverType, this.purpose, this.items);

  final String issueType;
  final String receiverType;
  final String purpose;
  final List<_IssueLineSeed> items;
}

class _IssueLineSeed {
  const _IssueLineSeed(this.materialIndex, this.quantity);

  final int materialIndex;
  final double quantity;
}
