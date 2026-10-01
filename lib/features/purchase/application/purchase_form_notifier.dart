import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/purchase_models.dart';
import 'purchase_providers.dart';

class PurchaseFormState {
  const PurchaseFormState({
    this.title = '',
    this.demandReason = '',
    this.requestDate,
    this.remark = '',
    this.items = const [],
    this.isSaving = false,
    this.errorMessage,
  });

  final String title;
  final String demandReason;
  final DateTime? requestDate;
  final String remark;
  final List<PurchaseItemDraft> items;
  final bool isSaving;
  final String? errorMessage;

  PurchaseFormState copyWith({
    String? title,
    String? demandReason,
    DateTime? requestDate,
    String? remark,
    List<PurchaseItemDraft>? items,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    bool clearRequestDate = false,
  }) => PurchaseFormState(
    title: title ?? this.title,
    demandReason: demandReason ?? this.demandReason,
    requestDate: clearRequestDate ? null : requestDate ?? this.requestDate,
    remark: remark ?? this.remark,
    items: items ?? this.items,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

final purchaseFormProvider =
    NotifierProvider.autoDispose<PurchaseFormNotifier, PurchaseFormState>(
      PurchaseFormNotifier.new,
    );

class PurchaseFormNotifier extends AutoDisposeNotifier<PurchaseFormState> {
  @override
  PurchaseFormState build() => PurchaseFormState(requestDate: DateTime.now());

  void setTitle(String value) =>
      state = state.copyWith(title: value, clearError: true);
  void setDemandReason(String value) =>
      state = state.copyWith(demandReason: value);
  void setRequestDate(DateTime? value) => state = state.copyWith(
    requestDate: value,
    clearRequestDate: value == null,
  );
  void setRemark(String value) => state = state.copyWith(remark: value);

  void addItem(PurchaseItemDraft item) =>
      state = state.copyWith(items: [...state.items, item], clearError: true);

  void updateItem(int index, PurchaseItemDraft item) {
    if (index < 0 || index >= state.items.length) return;
    final items = [...state.items]..[index] = item;
    state = state.copyWith(items: items, clearError: true);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final items = [...state.items]..removeAt(index);
    state = state.copyWith(items: items, clearError: true);
  }

  String? validate() {
    if (state.title.trim().isEmpty) return '采购事项名称不能为空';
    if (state.items.isEmpty) return '请至少添加一项采购物资';
    for (final item in state.items) {
      if (item.itemName.trim().isEmpty) return '物资名称不能为空';
      if (item.unit.trim().isEmpty) return '单位不能为空';
      if (!item.requestQuantity.isFinite || item.requestQuantity <= 0) {
        return '申报数量必须大于 0';
      }
    }
    return null;
  }

  Future<int?> save() async {
    if (state.isSaving) return null;
    final validation = validate();
    if (validation != null) {
      state = state.copyWith(errorMessage: validation);
      return null;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final id = await ref
          .read(purchaseRepositoryProvider)
          .createPurchaseRequest(
            CreatePurchaseRequestInput(
              title: state.title,
              demandReason: state.demandReason,
              requestDate: state.requestDate,
              remark: state.remark,
              items: List.unmodifiable(state.items),
            ),
          );
      state = PurchaseFormState(requestDate: DateTime.now());
      return id;
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      return null;
    }
  }
}
