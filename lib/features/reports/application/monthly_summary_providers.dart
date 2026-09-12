import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/monthly_summary_repository.dart';
import '../domain/monthly_summary_options.dart';

final monthlySummaryRepositoryProvider = Provider<MonthlySummaryRepository>((
  ref,
) {
  return MonthlySummaryRepository(ref.watch(appDatabaseProvider));
});

final monthlySummaryMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthlySummaryProvider = StreamProvider.autoDispose<MonthlySummaryView>((
  ref,
) {
  final month = ref.watch(monthlySummaryMonthProvider);
  return ref
      .watch(monthlySummaryRepositoryProvider)
      .watchSummary(yearMonth: _yearMonth(month));
});

String monthlySummaryMonthLabel(DateTime month) {
  return '${month.year}年${month.month.toString().padLeft(2, '0')}月';
}

String _yearMonth(DateTime month) {
  return '${month.year}-${month.month.toString().padLeft(2, '0')}';
}
