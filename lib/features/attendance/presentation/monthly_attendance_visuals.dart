import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_enums.dart';
import '../domain/monthly_attendance_table_options.dart';

Color monthlyAttendanceCellColor(MonthlyAttendanceCell cell) {
  if (!cell.isEditable) return AppColors.helper;
  if (cell.attendanceDays == 1) return AppColors.success;
  if (cell.attendanceDays > 0) return AppColors.warning;
  if (cell.leaveDays > 0) return AppColors.danger;
  if (cell.morningStatus == AttendanceHalfStatus.absent ||
      cell.afternoonStatus == AttendanceHalfStatus.absent) {
    return AppColors.danger;
  }
  if (cell.morningStatus == AttendanceHalfStatus.rest &&
      cell.afternoonStatus == AttendanceHalfStatus.rest) {
    return AppColors.purple;
  }
  if (cell.morningStatus == AttendanceHalfStatus.stopped &&
      cell.afternoonStatus == AttendanceHalfStatus.stopped) {
    return const Color(0xFFE98500);
  }
  return AppColors.helper;
}

String monthlyAttendanceFormatDays(double value) =>
    value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String monthlyAttendanceWeekday(int weekday) =>
    const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
