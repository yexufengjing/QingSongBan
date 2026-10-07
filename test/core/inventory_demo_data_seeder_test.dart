import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/inventory_demo_data_seeder.dart';
import 'package:qingsongban/features/inventory/data/inventory_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() async {
    await database.close();
  });

  test('seeds Chinese inventory scenarios once without duplicates', () async {
    expect(await InventoryDemoDataSeeder.seed(database), isTrue);

    final inventory = InventoryRepository(database);
    final materials = await inventory.getMaterials();
    final receipts = await inventory.getReceipts();
    final issues = await inventory.getIssues();
    final stocktakes = await inventory.getStocktakes();
    final replenishments = await inventory.getReplenishments();
    final warnings = await inventory.getCurrentStock(warningsOnly: true);
    final transactions = await inventory.getTransactions();
    final categories = await inventory.getCategories();

    expect(materials, hasLength(30));
    expect(materials.map((item) => item.materialName).toSet(), hasLength(30));
    expect(categories, hasLength(6));
    expect(receipts, hasLength(6));
    expect(issues, hasLength(6));
    expect(stocktakes, hasLength(2));
    expect(
      stocktakes.map((row) => row.status),
      containsAll(['draft', 'confirmed']),
    );
    expect(replenishments, hasLength(5));
    expect(warnings, hasLength(5));
    expect(materials.where((item) => item.currentStock == 0), hasLength(2));
    expect(
      materials.where(
        (item) => item.currentStock > 0 && item.currentStock <= item.minStock,
      ),
      hasLength(3),
    );
    expect(transactions, hasLength(52));
    expect(
      materials.map((item) => item.materialCode),
      everyElement(startsWith(InventoryDemoDataSeeder.materialCodePrefix)),
    );

    expect(await InventoryDemoDataSeeder.seed(database), isFalse);
    expect(await inventory.getMaterials(), hasLength(30));
    expect(await inventory.getReceipts(), hasLength(6));
    expect(await inventory.getIssues(), hasLength(6));
  });
}
