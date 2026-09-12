import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';

abstract final class OvertimeOptions {
  static const types = <String>['weekday', 'weekend', 'holiday', 'other'];

  static String typeLabel(String type) {
    return switch (type) {
      'weekday' => '工作日延时',
      'weekend' => '休息日',
      'holiday' => '法定节假日',
      _ => '其他',
    };
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (remainder == 0) return '$hours小时';
    return '$hours小时$remainder分钟';
  }

  static String timeRangeLabel(OvertimeRecord record) {
    final start = _time(record.startTime);
    final end = _time(record.endTime);
    return '${AppDateUtils.formatDate(record.overtimeDate)} $start-$end';
  }

  static String _time(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class OvertimeRecordView {
  const OvertimeRecordView({required this.overtime, required this.employee});

  final OvertimeRecord overtime;
  final Employee employee;
}

class OvertimeRecordDraft {
  const OvertimeRecordDraft({
    required this.employeeId,
    required this.overtimeDate,
    required this.startTime,
    required this.endTime,
    required this.overtimeType,
    this.workContent,
    this.workLocation,
    this.registrant,
    this.remark,
  });

  final int employeeId;
  final DateTime overtimeDate;
  final DateTime startTime;
  final DateTime endTime;
  final String overtimeType;
  final String? workContent;
  final String? workLocation;
  final String? registrant;
  final String? remark;

  int get durationMinutes => endTime.difference(startTime).inMinutes;
}
