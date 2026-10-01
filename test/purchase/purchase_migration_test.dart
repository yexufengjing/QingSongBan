import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/inventory/data/inventory_repository.dart';
import 'package:qingsongban/features/inventory/domain/inventory_models.dart';
import 'package:qingsongban/features/purchase/data/purchase_repository_impl.dart';
import 'package:qingsongban/features/purchase/domain/purchase_models.dart';
import 'package:qingsongban/features/reminders/data/reminder_repository.dart';
import 'package:qingsongban/features/reminders/domain/reminder_options.dart';

void main() {
  test(
    'schema 22 upgrade preserves current personnel, inventory and reminders',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'qsb-purchase-v23-',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}legacy.sqlite',
      );
      final current = AppDatabase.forTesting(executor: NativeDatabase(file));
      await current.customSelect('PRAGMA user_version').get();
      final employeeId = await current.insertEmployee(
        EmployeesCompanion.insert(
          employeeNo: 'MIG-P-01',
          name: '迁移人员',
          hireDate: DateTime(2026, 9, 1),
        ),
      );
      final materialId = await InventoryRepository(current).createMaterial(
        const InventoryMaterialDraft(
          materialCode: 'MIG-P-MAT-01',
          materialName: '迁移库存物资',
          unitName: '件',
        ),
      );
      final reminder = await ReminderRepository(current).save(
        draft: ReminderDraft(
          title: '迁移提醒',
          reminderType: 'custom',
          leadDays: 1,
          isEnabled: true,
          dueDate: DateTime(2026, 10, 5),
        ),
      );

      // Reconstruct the exact v22 boundary from a fully valid current database.
      await current.customStatement('DROP TABLE purchase_stock_entries');
      await current.customStatement('DROP TABLE purchase_status_logs');
      await current.customStatement('DROP TABLE purchase_request_items');
      await current.customStatement('DROP TABLE purchase_requests');
      await current.customStatement('PRAGMA user_version = 22');
      await current.customSelect('PRAGMA user_version').get();
      await current.close();

      final upgraded = AppDatabase.forTesting(executor: NativeDatabase(file));
      await upgraded.customSelect('PRAGMA user_version').get();
      final names =
          (await upgraded
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'table'",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      final indexes =
          (await upgraded
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'index'",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();

      expect(upgraded.schemaVersion, 23);
      expect(
        names,
        containsAll([
          'purchase_requests',
          'purchase_request_items',
          'purchase_status_logs',
          'purchase_stock_entries',
        ]),
      );
      expect(
        indexes,
        containsAll([
          'idx_purchase_requests_status_updated',
          'idx_purchase_request_items_request',
          'idx_purchase_request_items_material',
          'idx_purchase_status_logs_request_changed',
          'idx_purchase_stock_entries_request_item',
          'idx_purchase_stock_entries_receipt',
        ]),
      );
      expect((await upgraded.findEmployeeById(employeeId))?.name, '迁移人员');
      expect(
        (await InventoryRepository(upgraded).getMaterial(materialId))
            ?.materialName,
        '迁移库存物资',
      );
      expect(
        (await ReminderRepository(upgraded).findById(reminder.id))?.title,
        '迁移提醒',
      );
      expect(await upgraded.select(upgraded.purchaseRequests).get(), isEmpty);
      expect(
        await upgraded.select(upgraded.purchaseRequestItems).get(),
        isEmpty,
      );
      expect(await upgraded.select(upgraded.purchaseStatusLogs).get(), isEmpty);
      expect(
        await upgraded.select(upgraded.purchaseStockEntries).get(),
        isEmpty,
      );

      final repository = PurchaseRepositoryImpl(upgraded);
      final migratedPurchase = await repository.createPurchaseRequest(
        CreatePurchaseRequestInput(
          title: '迁移后新增采购',
          items: [
            PurchaseItemDraft(
              inventoryMaterialId: materialId,
              itemName: '迁移库存物资',
              unit: '件',
              requestQuantity: 2,
            ),
          ],
        ),
      );
      expect(
        (await upgraded.select(upgraded.purchaseRequests).getSingle()).id,
        migratedPurchase,
      );

      await upgraded.close();
      await directory.delete(recursive: true);
    },
  );
}
