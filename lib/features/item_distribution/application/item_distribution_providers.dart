import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/item_distribution_repository.dart';
import '../domain/item_distribution_models.dart';

final itemDistributionRepositoryProvider = Provider<ItemDistributionRepository>((ref) {
  return ItemDistributionRepository(ref.watch(appDatabaseProvider));
});

final distributionGroupsProvider = FutureProvider.family<List<DistributionRecipientGroup>, String>((ref, month) {
  return ref.watch(itemDistributionRepositoryProvider).listGroupsForMonth(month);
});

final distributionSummaryProvider = FutureProvider.family<DistributionSummary, String>((ref, month) {
  return ref.watch(itemDistributionRepositoryProvider).summaryForMonth(month);
});

final temporaryWelfareCandidatesProvider = FutureProvider.family<List<WelfareCandidate>, String>((ref, month) {
  return ref.watch(itemDistributionRepositoryProvider).listTemporaryCandidates(month);
});
