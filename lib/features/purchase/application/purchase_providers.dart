import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/purchase_repository.dart';
import '../data/purchase_repository_impl.dart';
import '../domain/purchase_models.dart';
import '../domain/purchase_status.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepositoryImpl(ref.watch(appDatabaseProvider));
});

final purchaseDashboardProvider =
    StreamProvider.autoDispose<PurchaseDashboardData>((ref) {
      return ref.watch(purchaseRepositoryProvider).watchDashboard();
    });

final purchaseFilterProvider =
    NotifierProvider<PurchaseFilterNotifier, PurchaseFilter>(
      PurchaseFilterNotifier.new,
    );

class PurchaseFilterNotifier extends Notifier<PurchaseFilter> {
  @override
  PurchaseFilter build() => const PurchaseFilter();

  void setStatuses(Set<PurchaseStatus> statuses) =>
      state = state.copyWith(statuses: statuses);

  void setKeyword(String keyword) => state = state.copyWith(keyword: keyword);

  void setDateRange(DateTime? start, DateTime? end) => state = state.copyWith(
    startDate: start,
    endDate: end,
    clearDates: start == null && end == null,
  );

  void setPurchaser(String? name) =>
      state = state.copyWith(purchaserName: name, clearPurchaser: name == null);

  void setMaterial(int? id) => state = state.copyWith(
    inventoryMaterialId: id,
    clearMaterial: id == null,
  );

  void setDemandReason(String? reason) => state = state.copyWith(
    demandReason: reason,
    clearDemandReason: reason == null,
  );

  void reset() => state = const PurchaseFilter();
}

final purchaseListProvider =
    StreamProvider.autoDispose<List<PurchaseRequestSummary>>((ref) {
      final filter = ref.watch(purchaseFilterProvider);
      return ref.watch(purchaseRepositoryProvider).watchRequests(filter);
    });

final purchaseDetailProvider = StreamProvider.autoDispose
    .family<PurchaseRequestDetail?, int>((ref, id) {
      return ref.watch(purchaseRepositoryProvider).watchDetail(id);
    });

final purchaseHistoryFilterProvider =
    NotifierProvider<PurchaseHistoryFilterNotifier, PurchaseHistoryFilter>(
      PurchaseHistoryFilterNotifier.new,
    );

class PurchaseHistoryFilterNotifier extends Notifier<PurchaseHistoryFilter> {
  @override
  PurchaseHistoryFilter build() => const PurchaseHistoryFilter();

  void setKeyword(String keyword) => state = PurchaseHistoryFilter(
    keyword: keyword,
    startDate: state.startDate,
    endDate: state.endDate,
    purchaserName: state.purchaserName,
    inventoryMaterialId: state.inventoryMaterialId,
    historyStatus: state.historyStatus,
    mode: state.mode,
  );

  void setDateRange(DateTime? start, DateTime? end) =>
      state = PurchaseHistoryFilter(
        keyword: state.keyword,
        startDate: start,
        endDate: end,
        purchaserName: state.purchaserName,
        inventoryMaterialId: state.inventoryMaterialId,
        historyStatus: state.historyStatus,
        mode: state.mode,
      );

  void setMode(PurchaseHistoryMode mode) => state = PurchaseHistoryFilter(
    keyword: state.keyword,
    startDate: state.startDate,
    endDate: state.endDate,
    purchaserName: state.purchaserName,
    inventoryMaterialId: state.inventoryMaterialId,
    historyStatus: state.historyStatus,
    mode: mode,
  );

  void setStatuses(Set<PurchaseStatus> statuses) =>
      state = PurchaseHistoryFilter(
        keyword: state.keyword,
        startDate: state.startDate,
        endDate: state.endDate,
        purchaserName: state.purchaserName,
        inventoryMaterialId: state.inventoryMaterialId,
        historyStatus: statuses,
        mode: state.mode,
      );
}

final purchaseHistoryProvider =
    StreamProvider.autoDispose<List<PurchaseHistoryRow>>((ref) {
      final filter = ref.watch(purchaseHistoryFilterProvider);
      return ref.watch(purchaseRepositoryProvider).watchHistory(filter);
    });

final purchaseItemHistoryProvider = StreamProvider.autoDispose
    .family<PurchaseItemHistory?, int>((ref, id) {
      return ref.watch(purchaseRepositoryProvider).watchItemHistory(id);
    });

final purchaseReminderExistsProvider = FutureProvider.autoDispose
    .family<bool, int>((ref, id) {
      return ref.watch(purchaseRepositoryProvider).hasReminder(id);
    });

final purchaseReminderIdProvider = FutureProvider.autoDispose.family<int?, int>(
  (ref, id) {
    return ref.watch(purchaseRepositoryProvider).findReminderId(id);
  },
);
