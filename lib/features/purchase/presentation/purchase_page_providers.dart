import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/purchase_providers.dart';
import '../domain/purchase_models.dart';

/// Screen-scoped query families keep one page's filters independent from others.
final purchaseRequestsByFilterProvider = StreamProvider.autoDispose
    .family<List<PurchaseRequestSummary>, PurchaseFilter>(
      (ref, filter) =>
          ref.watch(purchaseRepositoryProvider).watchRequests(filter),
    );

final purchaseHistoryByFilterProvider = StreamProvider.autoDispose
    .family<List<PurchaseHistoryRow>, PurchaseHistoryFilter>(
      (ref, filter) =>
          ref.watch(purchaseRepositoryProvider).watchHistory(filter),
    );
