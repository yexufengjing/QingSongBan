import '../../../core/database/app_database.dart';

abstract final class ReminderOptions {
  static const types = <String>[
    'dailyAttendance',
    'monthlyRoster',
    'monthlySummary',
    'payroll',
    'insuranceChange',
    'documentExpiry',
    'custom',
  ];

  static String typeLabel(String type) {
    return switch (type) {
      'dailyAttendance' => '每日考勤提醒',
      'monthlyRoster' => '月度名单提醒',
      'monthlySummary' => '月度汇总提醒',
      'payroll' => '工资造资提醒',
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
    this.priority = 'normal',
    this.category = 'general',
    this.timezoneId,
    this.links = const <ReminderLinkDraft>[],
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
  final String priority;
  final String category;
  final String? timezoneId;
  final List<ReminderLinkDraft> links;
}

class ReminderLinkDraft {
  const ReminderLinkDraft({
    required this.entityType,
    required this.entityId,
    required this.displayName,
  });

  final String entityType;
  final int entityId;
  final String displayName;
}

class ReminderItem {
  const ReminderItem({
    required this.reminder,
    required this.links,
    this.occurrence,
  });

  final Reminder reminder;
  final ReminderOccurrence? occurrence;
  final List<ReminderLink> links;

  DateTime? get scheduledAt => occurrence?.scheduledAt ?? reminder.dueDate;
  String get status =>
      occurrence?.status ?? (reminder.isCompleted ? 'completed' : 'pending');
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isSkipped => status == 'skipped';
}

abstract final class ReminderPriorities {
  static const values = <String>['normal', 'important', 'urgent'];

  static String label(String value) => switch (value) {
    'important' => '重要',
    'urgent' => '紧急',
    _ => '普通',
  };
}

abstract final class ReminderCategories {
  static const values = <String>['general', 'plan', 'periodic', 'custom'];

  static String label(String value) => switch (value) {
    'plan' => '工作计划',
    'periodic' => '定期事项',
    'custom' => '自定义',
    _ => '临时事项',
  };
}
