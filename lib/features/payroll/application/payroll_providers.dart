import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/payroll_repository.dart';
import '../data/wage_settings_repository.dart';
import '../domain/payroll_models.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return PayrollRepository(ref.watch(appDatabaseProvider));
});

final wageSettingsRepositoryProvider = Provider<WageSettingsRepository>((ref) {
  return WageSettingsRepository(ref.watch(appDatabaseProvider));
});

final payrollBatchesProvider = StreamProvider.autoDispose<List<PayrollBatche>>((
  ref,
) {
  return ref.watch(payrollRepositoryProvider).watchBatches();
});

final payrollBatchProvider = FutureProvider.autoDispose
    .family<PayrollBatche?, int>(
      (ref, batchId) => ref.watch(payrollRepositoryProvider).findBatch(batchId),
    );

final payrollItemsProvider = StreamProvider.autoDispose
    .family<List<PayrollItemWithEmployee>, int>(
      (ref, batchId) =>
          ref.watch(payrollRepositoryProvider).watchItems(batchId),
    );

final payrollValidationProvider = FutureProvider.autoDispose
    .family<PayrollValidationResult, int>((ref, batchId) {
      ref.watch(payrollBatchProvider(batchId));
      return ref.watch(payrollRepositoryProvider).previewValidation(batchId);
    });

final payrollEmployeeHistoryProvider = StreamProvider.autoDispose
    .family<List<PayrollHistoryEntry>, int>(
      (ref, employeeId) =>
          ref.watch(payrollRepositoryProvider).watchEmployeeHistory(employeeId),
    );

final wageDefaultsProvider = FutureProvider.autoDispose<void>((ref) {
  return ref.watch(wageSettingsRepositoryProvider).ensureDefaultJobTypes();
});

final wageJobTypesProvider = StreamProvider.autoDispose<List<WageJobType>>((
  ref,
) {
  ref.watch(wageDefaultsProvider);
  return ref
      .watch(wageSettingsRepositoryProvider)
      .watchJobTypes(includeInactive: true);
});

final employeeWageProfileProvider = FutureProvider.autoDispose
    .family<EmployeeWageProfile?, int>(
      (ref, employeeId) =>
          ref.watch(wageSettingsRepositoryProvider).findProfile(employeeId),
    );

final payrollMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

String payrollYearMonth(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';

String payrollMonthLabel(DateTime month) =>
    '${month.year}年${month.month.toString().padLeft(2, '0')}月';
