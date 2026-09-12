import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';

abstract final class DailyAttendanceOptions {
  static const editableStatuses = [
    AttendanceHalfStatus.unregistered,
    AttendanceHalfStatus.present,
    AttendanceHalfStatus.leave,
    AttendanceHalfStatus.absent,
    AttendanceHalfStatus.rest,
    AttendanceHalfStatus.stopped,
  ];

  static String statusLabel(AttendanceHalfStatus status) {
    return switch (status) {
      AttendanceHalfStatus.unregistered => '未登记',
      AttendanceHalfStatus.present => '出勤',
      AttendanceHalfStatus.leave => '请假',
      AttendanceHalfStatus.absent => '缺勤',
      AttendanceHalfStatus.rest => '公休',
      AttendanceHalfStatus.stopped => '停工',
      AttendanceHalfStatus.notEmployed => '未入职',
      AttendanceHalfStatus.terminated => '已离职',
    };
  }

  static String actionLabel(DailyAttendanceAction action) {
    return switch (action) {
      DailyAttendanceAction.allPresent => '一键全勤',
      DailyAttendanceAction.copyPrevious => '复制前一天',
      DailyAttendanceAction.rest => '批量公休',
      DailyAttendanceAction.stopped => '批量停工',
    };
  }
}

enum DailyAttendanceAction { allPresent, copyPrevious, rest, stopped }

class DailyAttendanceEntryView {
  const DailyAttendanceEntryView({
    required this.employee,
    required this.attendanceDate,
    required this.morningStatus,
    required this.afternoonStatus,
    required this.remark,
    required this.record,
    required this.isEditable,
    this.lockReason,
  });

  final Employee employee;
  final DateTime attendanceDate;
  final AttendanceHalfStatus morningStatus;
  final AttendanceHalfStatus afternoonStatus;
  final String? remark;
  final AttendanceRecord? record;
  final bool isEditable;
  final String? lockReason;

  bool get isRegistered =>
      isEditable &&
      (morningStatus != AttendanceHalfStatus.unregistered ||
          afternoonStatus != AttendanceHalfStatus.unregistered);
}

class DailyAttendanceDraft {
  const DailyAttendanceDraft({
    required this.employeeId,
    required this.attendanceDate,
    required this.morningStatus,
    required this.afternoonStatus,
    this.remark,
  });

  final int employeeId;
  final DateTime attendanceDate;
  final AttendanceHalfStatus morningStatus;
  final AttendanceHalfStatus afternoonStatus;
  final String? remark;
}
