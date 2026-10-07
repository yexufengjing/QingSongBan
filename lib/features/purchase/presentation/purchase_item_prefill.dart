import '../../../core/database/app_database.dart';
import '../domain/purchase_models.dart';

/// A light route payload for starting a request from inventory or item history.
class PurchaseItemPrefill {
  const PurchaseItemPrefill({
    required this.inventoryMaterialId,
    required this.itemName,
    required this.unit,
    required this.currentStock,
    this.specification,
  });

  factory PurchaseItemPrefill.fromInventoryMaterial(InventoryMaterial item) =>
      PurchaseItemPrefill(
        inventoryMaterialId: item.id,
        itemName: item.materialName,
        specification: item.modelSpec,
        unit: item.unitName,
        currentStock: item.currentStock,
      );

  factory PurchaseItemPrefill.fromItemHistory(PurchaseItemHistory item) =>
      PurchaseItemPrefill(
        inventoryMaterialId: item.inventoryMaterialId,
        itemName: item.itemName,
        specification: item.specification,
        unit: item.unit,
        currentStock: item.currentStock ?? 0,
      );

  final int inventoryMaterialId;
  final String itemName;
  final String? specification;
  final String unit;
  final double currentStock;
}
