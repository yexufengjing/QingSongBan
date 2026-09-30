import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/inventory_models.dart';
import 'inventory_excel_service.dart';
import 'inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>(
  (ref) => InventoryService(ref.watch(appDatabaseProvider)),
);

final inventoryOverviewProvider = FutureProvider<InventoryOverview>(
  (ref) => ref.watch(inventoryServiceProvider).getOverview(),
);
final inventoryMaterialsProvider = FutureProvider<List<InventoryMaterial>>(
  (ref) => ref.watch(inventoryServiceProvider).getMaterials(),
);
final inventoryCategoriesProvider = FutureProvider<List<InventoryCategory>>(
  (ref) => ref.watch(inventoryServiceProvider).getCategories(),
);
final inventoryStockProvider = FutureProvider<List<InventoryStockRow>>(
  (ref) => ref.watch(inventoryServiceProvider).getCurrentStock(),
);
final inventoryWarningsProvider = FutureProvider<List<InventoryStockRow>>(
  (ref) =>
      ref.watch(inventoryServiceProvider).getCurrentStock(warningsOnly: true),
);
final inventoryReceiptsProvider = FutureProvider<List<InventoryReceipt>>(
  (ref) => ref.watch(inventoryServiceProvider).getReceipts(),
);
final inventoryReceiptItemsProvider =
    FutureProvider.family<List<InventoryReceiptItem>, int>(
      (ref, receiptId) =>
          ref.watch(inventoryServiceProvider).getReceiptItems(receiptId),
    );
final inventoryIssuesProvider = FutureProvider<List<InventoryIssue>>(
  (ref) => ref.watch(inventoryServiceProvider).getIssues(),
);
final inventoryIssueItemsProvider =
    FutureProvider.family<List<InventoryIssueItem>, int>(
      (ref, issueId) =>
          ref.watch(inventoryServiceProvider).getIssueItems(issueId),
    );
final inventoryTransactionsProvider =
    FutureProvider<List<InventoryTransaction>>(
      (ref) => ref.watch(inventoryServiceProvider).getTransactions(),
    );
final inventoryStocktakesProvider = FutureProvider<List<InventoryStocktake>>(
  (ref) => ref.watch(inventoryServiceProvider).getStocktakes(),
);
final inventoryStocktakeItemsProvider =
    FutureProvider.family<List<InventoryStocktakeItem>, int>(
      (ref, stocktakeId) =>
          ref.watch(inventoryServiceProvider).getStocktakeItems(stocktakeId),
    );
final inventoryReplenishmentsProvider =
    FutureProvider<List<InventoryReplenishmentItem>>(
      (ref) => ref.watch(inventoryServiceProvider).getReplenishments(),
    );
final employeeMaterialHistoryProvider =
    FutureProvider.family<List<InventoryEmployeeHistoryItem>, int>(
      (ref, employeeId) => ref
          .watch(inventoryServiceProvider)
          .getEmployeeMaterialHistory(employeeId),
    );

final inventoryExcelServiceProvider = Provider<InventoryExcelService>(
  (ref) => InventoryExcelService(ref.watch(appDatabaseProvider)),
);
