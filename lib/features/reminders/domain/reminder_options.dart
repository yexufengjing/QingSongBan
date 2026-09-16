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

  static const categories = <String>[
    'general',
    'plan',
    'personnel',
    'vehicle',
    'inventory',
    'equipment',
    'supplier',
    'custom',
  ];

  static const priorities = <String>['normal', 'important', 'urgent'];

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

  static String categoryLabel(String category) {
    return switch (category) {
      'plan' => '工作计划',
      'personnel' => '人员事务',
      'vehicle' => '车辆',
      'inventory' => '库存/物资',
      'equipment' => '园林设备',
      'supplier' => '财务往来',
      'custom' => '自定义',
      _ => '通用事项',
    };
  }

  static String priorityLabel(String priority) {
    return switch (priority) {
      'urgent' => '紧急',
      'important' => '重要',
      _ => '普通',
    };
  }

  static String leadLabel(int days) => days == 0 ? '当天' : '提前 $days 天';

  static String alertLabel(int minutes) {
    if (minutes == 0) return '到期时';
    final absolute = minutes.abs();
    if (absolute % 1440 == 0) {
      return minutes < 0
          ? '提前 ${absolute ~/ 1440} 天'
          : '到期后 ${absolute ~/ 1440} 天';
    }
    if (absolute % 60 == 0) {
      return minutes < 0
          ? '提前 ${absolute ~/ 60} 小时'
          : '到期后 ${absolute ~/ 60} 小时';
    }
    return minutes < 0 ? '提前 $absolute 分钟' : '到期后 $absolute 分钟';
  }

  static String repeatLabel(String? rule) {
    if (rule == null || rule.trim().isEmpty) return '不重复';
    final value = rule.toUpperCase();
    if (value.contains('FREQ=DAILY')) return '每天';
    if (value.contains('FREQ=WEEKLY')) {
      final days = <String>[];
      const labels = <String, String>{
        'MO': '一',
        'TU': '二',
        'WE': '三',
        'TH': '四',
        'FR': '五',
        'SA': '六',
        'SU': '日',
      };
      final match = RegExp(r'BYDAY=([^;]+)').firstMatch(value);
      for (final day in match?.group(1)?.split(',') ?? const <String>[]) {
        final label = labels[day];
        if (label != null) days.add(label);
      }
      return days.isEmpty ? '每周' : '每周${days.join('、')}';
    }
    if (value.contains('FREQ=MONTHLY;INTERVAL=3')) return '每季度';
    if (value.contains('FREQ=MONTHLY')) return '每月';
    if (value.contains('FREQ=YEARLY')) return '每年';
    return '自定义重复';
  }

  static String? buildRule({
    required DateTime start,
    required String repeat,
    Set<int> weekdays = const {},
    String? customRule,
    DateTime? until,
    int? count,
  }) {
    if (repeat == 'none') return null;
    // RFC 5545 does not allow UNTIL and COUNT together. The UI treats the
    // date as the preferred boundary when both values are supplied.
    final end = until == null
        ? ''
        : ';UNTIL=${_rruleDate(DateTime.utc(until.year, until.month, until.day, until.hour, until.minute))}';
    final countPart = until == null && count != null ? ';COUNT=$count' : '';
    return switch (repeat) {
      'daily' => 'RRULE:FREQ=DAILY$end$countPart',
      'weekly' =>
        'RRULE:FREQ=WEEKLY;BYDAY=${_weekdayCodes(weekdays.isEmpty ? {start.weekday} : weekdays)}$end$countPart',
      'monthly' => 'RRULE:FREQ=MONTHLY;BYMONTHDAY=${start.day}$end$countPart',
      'quarterly' =>
        'RRULE:FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=${start.day}$end$countPart',
      'yearly' =>
        'RRULE:FREQ=YEARLY;BYMONTH=${start.month};BYMONTHDAY=${start.day}$end$countPart',
      'custom' => _withRuleEnd(customRule, until: until, count: count),
      _ => null,
    };
  }

  static String? _withRuleEnd(String? rule, {DateTime? until, int? count}) {
    if (rule == null || rule.trim().isEmpty) return null;
    final base = rule.startsWith('RRULE:') ? rule : 'RRULE:$rule';
    final suffix = [
      if (until != null)
        'UNTIL=${_rruleDate(DateTime.utc(until.year, until.month, until.day, until.hour, until.minute))}'
      else if (count != null)
        'COUNT=$count',
    ];
    return suffix.isEmpty ? base : '$base;${suffix.join(';')}';
  }

  static String _weekdayCodes(Iterable<int> weekdays) {
    const codes = <int, String>{
      DateTime.monday: 'MO',
      DateTime.tuesday: 'TU',
      DateTime.wednesday: 'WE',
      DateTime.thursday: 'TH',
      DateTime.friday: 'FR',
      DateTime.saturday: 'SA',
      DateTime.sunday: 'SU',
    };
    final sorted = weekdays.toList()..sort();
    return sorted.map((day) => codes[day] ?? 'MO').join(',');
  }

  static String _rruleDate(DateTime value) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}T${two(value.hour)}${two(value.minute)}00Z';
  }

  static const templates = <ReminderTemplate>[
    ReminderTemplate(title: '车辆保养', category: 'vehicle', type: 'custom'),
    ReminderTemplate(title: '车辆年检', category: 'vehicle', type: 'custom'),
    ReminderTemplate(title: '车辆保险', category: 'vehicle', type: 'custom'),
    ReminderTemplate(title: '备件寿命到期', category: 'inventory', type: 'custom'),
    ReminderTemplate(title: '园林器械保养', category: 'equipment', type: 'custom'),
    ReminderTemplate(title: '待采购物资', category: 'inventory', type: 'custom'),
    ReminderTemplate(title: '供应商待结款', category: 'supplier', type: 'custom'),
    ReminderTemplate(title: '员工保险变更', category: 'personnel', type: 'custom'),
    ReminderTemplate(
      title: '每月福利领取',
      category: 'personnel',
      type: 'custom',
      repeat: 'monthly',
    ),
  ];
}

class ReminderTemplate {
  const ReminderTemplate({
    required this.title,
    required this.category,
    required this.type,
    this.repeat = 'none',
  });

  final String title;
  final String category;
  final String type;
  final String repeat;
}

class ReminderLinkDraft {
  const ReminderLinkDraft({
    required this.entityType,
    required this.entityId,
    required this.displayNameSnapshot,
  });

  final String entityType;
  final int entityId;
  final String displayNameSnapshot;
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
    this.repeatMode = 'fixedSchedule',
    this.repeatEndsAt,
    this.repeatCount,
    this.alertOffsetsMinutes,
    this.nagRepeatIntervalMinutes,
    this.nagMaxRepeatCount,
    this.nagEndsAfterMinutes,
    this.links,
  });

  final String title;
  final String reminderType;
  // Kept for backwards compatibility with existing business modules. New
  // reminders use alertOffsetsMinutes, which can contain multiple offsets.
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
  final String repeatMode;
  final DateTime? repeatEndsAt;
  final int? repeatCount;
  final List<int>? alertOffsetsMinutes;
  final int? nagRepeatIntervalMinutes;
  final int? nagMaxRepeatCount;
  final int? nagEndsAfterMinutes;
  final List<ReminderLinkDraft>? links;
}

class ReminderLinkDisplay {
  const ReminderLinkDisplay({
    required this.entityType,
    required this.entityId,
    required this.displayName,
    this.status,
  });

  final String entityType;
  final int entityId;
  final String displayName;
  final String? status;
}

class ReminderListItem {
  const ReminderListItem({
    required this.reminder,
    required this.occurrence,
    this.links = const [],
  });

  final Reminder reminder;
  final ReminderOccurrence occurrence;
  final List<ReminderLinkDisplay> links;

  DateTime get scheduledAt => occurrence.scheduledAt;
  bool get isCompleted => occurrence.status == 'completed';
  bool get isSkipped => occurrence.status == 'skipped';
  bool get isPending => occurrence.status == 'pending';
  bool get isOverdue => isPending && scheduledAt.isBefore(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return scheduledAt.year == now.year &&
        scheduledAt.month == now.month &&
        scheduledAt.day == now.day;
  }

  bool get isRecurring => reminder.repeatRule?.isNotEmpty ?? false;
}
