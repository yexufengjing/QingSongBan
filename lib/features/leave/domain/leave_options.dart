import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';

enum LeaveDurationType { fullDay, morning, afternoon, multiDay }

abstract final class LeaveOptions {
  static const types = LeaveType.values;
  static const durations = LeaveDurationType.values;

  static String typeLabel(LeaveType type) {
    return switch (type) {
      LeaveType.personal => '事假',
      LeaveType.sick => '病假',
      LeaveType.other => '其他',
      LeaveType.custom => '自定义',
    };
  }

  static String durationLabel(LeaveDurationType duration) {
    return switch (duration) {
      LeaveDurationType.fullDay => '全天',
      LeaveDurationType.morning => '上午',
      LeaveDurationType.afternoon => '下午',
      LeaveDurationType.multiDay => '跨天',
    };
  }

  static String periodLabel(LeaveHalfPeriod period) {
    return switch (period) {
      LeaveHalfPeriod.morning => '上午',
      LeaveHalfPeriod.afternoon => '下午',
    };
  }

  static LeaveDurationType durationOf(LeaveRecord leave) {
    if (leave.startDate == leave.endDate) {
      if (leave.startPeriod == LeaveHalfPeriod.morning &&
          leave.endPeriod == LeaveHalfPeriod.afternoon) {
        return LeaveDurationType.fullDay;
      }
      if (leave.startPeriod == LeaveHalfPeriod.morning) {
        return LeaveDurationType.morning;
      }
      return LeaveDurationType.afternoon;
    }
    return LeaveDurationType.multiDay;
  }

  static String dateRangeLabel(LeaveRecord leave) {
    final start = AppDateUtils.formatDate(leave.startDate);
    final end = AppDateUtils.formatDate(leave.endDate);
    final duration = durationOf(leave);
    if (duration != LeaveDurationType.multiDay) {
      return '$start ${durationLabel(duration)}';
    }
    return '$start ${periodLabel(leave.startPeriod)} 至 $end ${periodLabel(leave.endPeriod)}';
  }

  static double halfDays(LeaveRecord leave) {
    var total = 0.0;
    var date = AppDateUtils.dateOnly(leave.startDate);
    final end = AppDateUtils.dateOnly(leave.endDate);
    while (!date.isAfter(end)) {
      if (covers(leave, date, LeaveHalfPeriod.morning)) total += 0.5;
      if (covers(leave, date, LeaveHalfPeriod.afternoon)) total += 0.5;
      date = date.add(const Duration(days: 1));
    }
    return total;
  }

  static bool covers(LeaveRecord leave, DateTime date, LeaveHalfPeriod period) {
    final day = AppDateUtils.dateOnly(date);
    final start = AppDateUtils.dateOnly(leave.startDate);
    final end = AppDateUtils.dateOnly(leave.endDate);
    if (day.isBefore(start) || day.isAfter(end)) return false;

    if (start == end) {
      return _periodRank(period) >= _periodRank(leave.startPeriod) &&
          _periodRank(period) <= _periodRank(leave.endPeriod);
    }
    if (day == start && _periodRank(period) < _periodRank(leave.startPeriod)) {
      return false;
    }
    if (day == end && _periodRank(period) > _periodRank(leave.endPeriod)) {
      return false;
    }
    return true;
  }

  static int _periodRank(LeaveHalfPeriod period) {
    return period == LeaveHalfPeriod.morning ? 0 : 1;
  }
}

class LeaveRecordView {
  const LeaveRecordView({required this.leave, required this.employee});

  final LeaveRecord leave;
  final Employee employee;
}

class LeaveRecordDraft {
  const LeaveRecordDraft({
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.startPeriod,
    required this.endPeriod,
    this.remark,
  });

  final int employeeId;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final LeaveHalfPeriod startPeriod;
  final LeaveHalfPeriod endPeriod;
  final String? remark;
}
