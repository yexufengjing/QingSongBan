import '../../../core/database/app_database.dart';

abstract final class ReminderOptions {
  static const types = <String>[
    'dailyAttendance',
    'monthlyRoster',
    'monthlySummary',
    'insuranceChange',
    'documentExpiry',
    'custom',
  ];

  static String typeLabel(String type) {
    return switch (type) {
      'dailyAttendance' => '每日考勤提醒',
      'monthlyRoster' => '月度名单提醒',
      'monthlySummary' => '月度汇总提醒',
      'insuranceChange' => '保险变更提醒',
      'documentExpiry' => '证件到期提醒',
      _ => '自定义提醒',
    };
  }

  static String leadLabel(int days) => days == 0 ? '当天' : '提前 $days 天';
}

class ReminderDraft {
  const ReminderDraft({
    required this.title,
    required this.reminderType,
    required this.leadDays,
    required this.isEnabled,
    this.dueDate,
    this.repeatRule,
    this.sourceEntityType,
    this.sourceEntityId,
    this.remark,
  });

  final String title;
  final String reminderType;
  final int leadDays;
  final bool isEnabled;
  final DateTime? dueDate;
  final String? repeatRule;
  final String? sourceEntityType;
  final int? sourceEntityId;
  final String? remark;
}

class ReminderView {
  const ReminderView(this.reminder);

  final Reminder reminder;
}
