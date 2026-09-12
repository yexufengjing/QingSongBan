import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import 'daily_attendance_options.dart';

class MonthlyAttendanceTableView {
  const MonthlyAttendanceTableView({
    required this.yearMonth,
    required this.daysInMonth,
    required this.rows,
  });

  const MonthlyAttendanceTableView.empty({required this.yearMonth})
    : daysInMonth = 0,
      rows = const [];

  final String yearMonth;
  final int daysInMonth;
  final List<MonthlyAttendanceTableRow> rows;

  double get totalAttendanceDays =>
      rows.fold<double>(0, (sum, row) => sum + row.attendanceDays);

  double get totalLeaveDays =>
      rows.fold<double>(0, (sum, row) => sum + row.leaveDays);
}

class MonthlyAttendanceTableRow {
  MonthlyAttendanceTableRow({
    required this.employee,
    this.terminationDate,
    Map<int, AttendanceRecord>? records,
  }) : _records = records ?? {};

  final Employee employee;
  final DateTime? terminationDate;
  final Map<int, AttendanceRecord> _records;

  MonthlyAttendanceCell cellForDay({
    required DateTime month,
    required int day,
  }) {
    final date = DateTime(month.year, month.month, day);
    final record = _records[day];
    if (AppDateUtilsForMonthly.isBeforeHire(employee, date)) {
      return MonthlyAttendanceCell(
        date: date,
        morningStatus: AttendanceHalfStatus.notEmployed,
        afternoonStatus: AttendanceHalfStatus.notEmployed,
        remark: record?.remark,
        record: record,
        isEditable: false,
        lockReason: '入职前不能登记考勤',
      );
    }
    if (_isAfterTermination(date)) {
      return MonthlyAttendanceCell(
        date: date,
        morningStatus: AttendanceHalfStatus.terminated,
        afternoonStatus: AttendanceHalfStatus.terminated,
        remark: record?.remark,
        record: record,
        isEditable: false,
        lockReason: '已离职人员不能登记考勤',
      );
    }
    return MonthlyAttendanceCell(
      date: date,
      morningStatus: record?.morningStatus ?? AttendanceHalfStatus.unregistered,
      afternoonStatus:
          record?.afternoonStatus ?? AttendanceHalfStatus.unregistered,
      remark: record?.remark,
      record: record,
      isEditable: true,
    );
  }

  double get attendanceDays {
    return _records.values.fold<double>(0, (sum, record) {
      if (_isRecordAfterTermination(record)) return sum;
      var value = sum;
      if (record.morningStatus == AttendanceHalfStatus.present) value += 0.5;
      if (record.afternoonStatus == AttendanceHalfStatus.present) value += 0.5;
      return value;
    });
  }

  double get leaveDays {
    return _records.values.fold<double>(0, (sum, record) {
      if (_isRecordAfterTermination(record)) return sum;
      var value = sum;
      if (record.morningStatus == AttendanceHalfStatus.leave) value += 0.5;
      if (record.afternoonStatus == AttendanceHalfStatus.leave) value += 0.5;
      return value;
    });
  }

  void addRecord(AttendanceRecord record) {
    _records[record.attendanceDate.day] = record;
  }

  bool _isAfterTermination(DateTime date) {
    if (employee.status != EmployeeStatus.terminated) return false;
    if (terminationDate == null) return true;
    return AppDateUtils.dateOnly(terminationDate!)
        .isBefore(AppDateUtils.dateOnly(date));
  }

  bool _isRecordAfterTermination(AttendanceRecord record) {
    return _isAfterTermination(record.attendanceDate);
  }
}

class MonthlyAttendanceCell {
  const MonthlyAttendanceCell({
    required this.date,
    required this.morningStatus,
    required this.afternoonStatus,
    required this.remark,
    required this.record,
    required this.isEditable,
    this.lockReason,
  });

  final DateTime date;
  final AttendanceHalfStatus morningStatus;
  final AttendanceHalfStatus afternoonStatus;
  final String? remark;
  final AttendanceRecord? record;
  final bool isEditable;
  final String? lockReason;

  double get attendanceDays => _halfDayCount(AttendanceHalfStatus.present);

  double get leaveDays => _halfDayCount(AttendanceHalfStatus.leave);

  double _halfDayCount(AttendanceHalfStatus status) {
    var count = 0;
    if (morningStatus == status) count++;
    if (afternoonStatus == status) count++;
    return count / 2;
  }

  String get symbol {
    if (morningStatus == AttendanceHalfStatus.notEmployed ||
        afternoonStatus == AttendanceHalfStatus.notEmployed) {
      return '未';
    }
    if (morningStatus == AttendanceHalfStatus.terminated ||
        afternoonStatus == AttendanceHalfStatus.terminated) {
      return '离';
    }
    final presentCount = _statusCount(AttendanceHalfStatus.present);
    if (presentCount == 2) return '力';
    if (presentCount == 1) return '半';
    if (_statusCount(AttendanceHalfStatus.leave) > 0) return '假';
    if (morningStatus == AttendanceHalfStatus.rest &&
        afternoonStatus == AttendanceHalfStatus.rest) {
      return '休';
    }
    if (morningStatus == AttendanceHalfStatus.stopped &&
        afternoonStatus == AttendanceHalfStatus.stopped) {
      return '停';
    }
    if (_statusCount(AttendanceHalfStatus.absent) > 0) return '🔺';
    return '·';
  }

  int _statusCount(AttendanceHalfStatus status) {
    var count = 0;
    if (morningStatus == status) count++;
    if (afternoonStatus == status) count++;
    return count;
  }
}

abstract final class AppDateUtilsForMonthly {
  static bool isBeforeHire(Employee employee, DateTime date) {
    return DateTime(
      employee.hireDate.year,
      employee.hireDate.month,
      employee.hireDate.day,
    ).isAfter(DateTime(date.year, date.month, date.day));
  }
}

String monthlyAttendanceStatusLabel(AttendanceHalfStatus status) {
  return DailyAttendanceOptions.statusLabel(status);
}
