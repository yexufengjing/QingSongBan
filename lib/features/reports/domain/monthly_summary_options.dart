import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';

abstract final class MonthlySummaryOptions {
  static String statusLabel(MonthlySummaryStatus status) {
    return switch (status) {
      MonthlySummaryStatus.notGenerated => '未生成',
      MonthlySummaryStatus.pendingReview => '待检查',
      MonthlySummaryStatus.confirmed => '已确认',
      MonthlySummaryStatus.locked => '已锁定',
    };
  }

  static String anomalyLabel(MonthlySummaryAnomalyKind kind) {
    return switch (kind) {
      MonthlySummaryAnomalyKind.unregistered => '未登记',
      MonthlySummaryAnomalyKind.preHire => '入职前考勤',
      MonthlySummaryAnomalyKind.postTermination => '离职后考勤',
      MonthlySummaryAnomalyKind.leaveConflict => '请假冲突',
      MonthlySummaryAnomalyKind.overtimeOverlap => '加班重叠',
      MonthlySummaryAnomalyKind.rosterStatusMismatch => '名单与状态异常',
    };
  }
}

enum MonthlySummaryAnomalyKind {
  unregistered,
  preHire,
  postTermination,
  leaveConflict,
  overtimeOverlap,
  rosterStatusMismatch,
}

class MonthlySummaryAnomaly {
  const MonthlySummaryAnomaly({
    required this.kind,
    required this.employee,
    required this.message,
    this.date,
  });

  final MonthlySummaryAnomalyKind kind;
  final Employee employee;
  final String message;
  final DateTime? date;

  String get dateLabel => date == null ? '' : AppDateUtils.formatDate(date);
}

class MonthlySummaryRowView {
  const MonthlySummaryRowView({
    required this.summary,
    required this.employee,
    required this.group,
  });

  final MonthlyAttendanceSummary summary;
  final Employee employee;
  final AttendanceGroup? group;
}

class MonthlySummaryView {
  const MonthlySummaryView({
    required this.yearMonth,
    required this.status,
    required this.rows,
    required this.anomalies,
  });

  const MonthlySummaryView.empty({required this.yearMonth})
    : status = MonthlySummaryStatus.notGenerated,
      rows = const [],
      anomalies = const [];

  final String yearMonth;
  final MonthlySummaryStatus status;
  final List<MonthlySummaryRowView> rows;
  final List<MonthlySummaryAnomaly> anomalies;

  double get attendanceDays =>
      rows.fold(0, (total, row) => total + row.summary.attendanceDays);

  double get leaveDays =>
      rows.fold(0, (total, row) => total + row.summary.leaveDays);

  int get overtimeMinutes =>
      rows.fold(0, (total, row) => total + row.summary.overtimeMinutes);

  int get overtimeCount =>
      rows.fold(0, (total, row) => total + row.summary.overtimeCount);
}

class MonthlySummaryDraft {
  const MonthlySummaryDraft({
    required this.yearMonth,
    required this.employeeId,
    required this.attendanceGroupId,
    required this.participates,
    required this.attendanceDays,
    required this.leaveDays,
    required this.absentDays,
    required this.restDays,
    required this.stoppedDays,
    required this.overtimeCount,
    required this.overtimeMinutes,
    required this.monthStartStatus,
    required this.monthEndStatus,
    required this.joinedDuringMonth,
    required this.terminatedDuringMonth,
    required this.isComplete,
    required this.anomalyCount,
  });

  final String yearMonth;
  final int employeeId;
  final int? attendanceGroupId;
  final bool participates;
  final double attendanceDays;
  final double leaveDays;
  final double absentDays;
  final double restDays;
  final double stoppedDays;
  final int overtimeCount;
  final int overtimeMinutes;
  final String? monthStartStatus;
  final String? monthEndStatus;
  final bool joinedDuringMonth;
  final bool terminatedDuringMonth;
  final bool isComplete;
  final int anomalyCount;
}
