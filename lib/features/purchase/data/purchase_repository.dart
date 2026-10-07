import '../domain/purchase_models.dart';

/// Purchase data boundary used by providers and screens.
abstract interface class PurchaseRepository {
  Future<int> createPurchaseRequest(CreatePurchaseRequestInput input);
  Future<void> updatePurchaseRequest(
    int requestId,
    UpdatePurchaseRequestInput input,
  );
  Future<void> updatePurchaseMetadata(
    int requestId,
    UpdatePurchaseMetadataInput input,
  );
  Future<void> confirmApplied(int requestId, ConfirmAppliedInput input);
  Future<void> assignPurchaser(int requestId, AssignPurchaserInput input);
  Future<void> markPendingReceive(int requestId, PendingReceiveInput input);
  Future<void> stockIn(StockInInput input);
  Future<void> changeStatusManually(ManualPurchaseStatusInput input);
  Future<void> softDelete(int requestId);

  Stream<List<PurchaseRequestSummary>> watchRequests(PurchaseFilter filter);
  Stream<PurchaseRequestDetail?> watchDetail(int requestId);
  Stream<PurchaseDashboardData> watchDashboard();
  Stream<List<PurchaseHistoryRow>> watchHistory(PurchaseHistoryFilter filter);
  Stream<PurchaseItemHistory?> watchItemHistory(int inventoryMaterialId);
  Future<bool> hasReminder(int requestId);
  Future<int?> findReminderId(int requestId);
  Future<bool> hasActiveRequest(int inventoryMaterialId);
  Future<int?> findActiveRequestId(int inventoryMaterialId);
  Future<void> reverseStockEntry(int stockEntryId);
}
