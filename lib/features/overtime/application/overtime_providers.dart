import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/overtime_repository.dart';
import '../domain/overtime_options.dart';

final overtimeRepositoryProvider = Provider<OvertimeRepository>((ref) {
  return OvertimeRepository(ref.watch(appDatabaseProvider));
});

final overtimeMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final overtimeRecordsProvider =
    StreamProvider.autoDispose<List<OvertimeRecordView>>((ref) {
      return ref
          .watch(overtimeRepositoryProvider)
          .watchOvertime(month: ref.watch(overtimeMonthProvider));
    });

String overtimeMonthLabel(DateTime month) {
  return '${month.year}年${month.month.toString().padLeft(2, '0')}月';
}
