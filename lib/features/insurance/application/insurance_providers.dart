import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/insurance_repository.dart';
import '../domain/insurance_options.dart';

final insuranceRepositoryProvider = Provider<InsuranceRepository>((ref) {
  return InsuranceRepository(ref.watch(appDatabaseProvider));
});

final insuranceMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final insuranceProfilesProvider =
    StreamProvider.autoDispose<List<InsuranceProfileView>>((ref) {
      return ref.watch(insuranceRepositoryProvider).watchProfiles();
    });

final insuranceProfileProvider = FutureProvider.autoDispose
    .family<InsuranceProfile?, int>(
      (ref, employeeId) =>
          ref.watch(insuranceRepositoryProvider).findProfile(employeeId),
    );

final insuranceChangesProvider =
    StreamProvider.autoDispose<List<InsuranceChangeView>>((ref) {
      return ref
          .watch(insuranceRepositoryProvider)
          .watchChanges(month: ref.watch(insuranceMonthProvider));
    });

final insuranceBaseHistoryProvider =
    StreamProvider.autoDispose<List<InsuranceHistoryView>>((ref) {
      return ref.watch(insuranceRepositoryProvider).watchBaseHistory();
    });

String insuranceMonthLabel(DateTime month) {
  return '${month.year}年${month.month.toString().padLeft(2, '0')}月';
}
