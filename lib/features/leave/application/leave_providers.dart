import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../data/leave_repository.dart';
import '../domain/leave_options.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(ref.watch(appDatabaseProvider));
});

final leaveMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final leaveRecordsProvider = StreamProvider.autoDispose<List<LeaveRecordView>>((
  ref,
) {
  return ref
      .watch(leaveRepositoryProvider)
      .watchLeaves(month: ref.watch(leaveMonthProvider));
});

String leaveMonthLabel(DateTime month) {
  return '${month.year}年${month.month.toString().padLeft(2, '0')}月';
}

String leaveYearMonth(DateTime month) => AppDateUtils.yearMonth(month);
