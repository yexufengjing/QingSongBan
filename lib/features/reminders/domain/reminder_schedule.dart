import 'dart:convert';

import 'package:rrule/rrule.dart';

enum ReminderRepeatUnit { day, week, month, year }

enum ReminderRepeatEnd { never, date, count }

class ReminderSchedule {
  const ReminderSchedule({
    this.repeatUnit,
    this.interval = 1,
    this.weekdays = const <int>{},
    this.monthDays = const <int>{},
    this.repeatEnd = ReminderRepeatEnd.never,
    this.endDate,
    this.endCount,
    this.alertMinutes = const <int>[0],
    this.ringEnabled = true,
  });

  final ReminderRepeatUnit? repeatUnit;
  final int interval;
  final Set<int> weekdays;
  final Set<int> monthDays;
  final ReminderRepeatEnd repeatEnd;
  final DateTime? endDate;
  final int? endCount;
  final List<int> alertMinutes;
  final bool ringEnabled;

  bool get repeats => repeatUnit != null;

  ReminderSchedule copyWith({
    ReminderRepeatUnit? repeatUnit,
    bool clearRepeatUnit = false,
    int? interval,
    Set<int>? weekdays,
    Set<int>? monthDays,
    ReminderRepeatEnd? repeatEnd,
    DateTime? endDate,
    bool clearEndDate = false,
    int? endCount,
    bool clearEndCount = false,
    List<int>? alertMinutes,
    bool? ringEnabled,
  }) {
    final nextAlertMinutes = alertMinutes ?? this.alertMinutes;
    return ReminderSchedule(
      repeatUnit: clearRepeatUnit ? null : repeatUnit ?? this.repeatUnit,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      monthDays: monthDays ?? this.monthDays,
      repeatEnd: repeatEnd ?? this.repeatEnd,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      endCount: clearEndCount ? null : endCount ?? this.endCount,
      alertMinutes: nextAlertMinutes,
      ringEnabled: nextAlertMinutes.isEmpty
          ? false
          : ringEnabled ?? this.ringEnabled,
    );
  }

  String encode() => jsonEncode({
    'version': 1,
    'repeatUnit': repeatUnit?.name,
    'interval': interval.clamp(1, 20),
    'weekdays': weekdays.toList()..sort(),
    'monthDays': monthDays.toList()..sort(),
    'repeatEnd': repeatEnd.name,
    'endDate': endDate?.toIso8601String(),
    'endCount': endCount,
    'alertMinutes': alertMinutes.toSet().toList()..sort(),
    'ringEnabled': alertMinutes.isNotEmpty && ringEnabled,
  });

  static ReminderSchedule decode(String? value, {int legacyLeadDays = 0}) {
    final fallback = ReminderSchedule(
      alertMinutes: <int>[legacyLeadDays * 24 * 60],
    );
    if (value == null || value.trim().isEmpty) return fallback;
    final legacyUnit = switch (value) {
      'daily' => ReminderRepeatUnit.day,
      'weekly' => ReminderRepeatUnit.week,
      'monthly' => ReminderRepeatUnit.month,
      'yearly' => ReminderRepeatUnit.year,
      _ => null,
    };
    if (legacyUnit != null) return fallback.copyWith(repeatUnit: legacyUnit);
    try {
      final map = jsonDecode(value) as Map<String, dynamic>;
      final unitName = map['repeatUnit'] as String?;
      final alerts =
          (map['alertMinutes'] as List<dynamic>? ?? const [0])
              .whereType<num>()
              .map((value) => value.toInt().clamp(0, 525600).toInt())
              .toSet()
              .toList()
            ..sort();
      return ReminderSchedule(
        repeatUnit: ReminderRepeatUnit.values
            .where((unit) => unit.name == unitName)
            .firstOrNull,
        interval: ((map['interval'] as num?)?.toInt() ?? 1)
            .clamp(1, 20)
            .toInt(),
        weekdays: (map['weekdays'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((value) => value.toInt())
            .where((value) => value >= 1 && value <= 7)
            .toSet(),
        monthDays: (map['monthDays'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((value) => value.toInt())
            .where((value) => value >= 1 && value <= 31)
            .toSet(),
        repeatEnd:
            ReminderRepeatEnd.values
                .where((end) => end.name == map['repeatEnd'])
                .firstOrNull ??
            ReminderRepeatEnd.never,
        endDate: DateTime.tryParse(map['endDate'] as String? ?? ''),
        endCount: (map['endCount'] as num?)?.toInt(),
        alertMinutes: alerts,
        ringEnabled: alerts.isEmpty
            ? false
            : map['ringEnabled'] as bool? ?? true,
      );
    } catch (_) {
      return fallback;
    }
  }

  String repeatLabel(DateTime start) {
    if (!repeats) return '仅一次';
    if (interval == 1) {
      return switch (repeatUnit!) {
        ReminderRepeatUnit.day => '每天',
        ReminderRepeatUnit.week => '每周${_weekdaySuffix(start)}',
        ReminderRepeatUnit.month => '每月${_monthDaySuffix(start)}',
        ReminderRepeatUnit.year => '每年',
      };
    }
    final unit = switch (repeatUnit!) {
      ReminderRepeatUnit.day => '天',
      ReminderRepeatUnit.week => '周',
      ReminderRepeatUnit.month => '月',
      ReminderRepeatUnit.year => '年',
    };
    return '每 $interval $unit${repeatUnit == ReminderRepeatUnit.week ? _weekdaySuffix(start) : ''}';
  }

  String get alertLabel {
    if (alertMinutes.isEmpty) return '不提醒';
    if (alertMinutes.length > 1) return '已设置 ${alertMinutes.length} 个提醒';
    return alertMinuteLabel(alertMinutes.single);
  }

  static String alertMinuteLabel(int minutes) {
    if (minutes == 0) return '待办发生时';
    if (minutes % 10080 == 0) return '${minutes ~/ 10080} 周前';
    if (minutes % 1440 == 0) return '${minutes ~/ 1440} 天前';
    if (minutes % 60 == 0) return '${minutes ~/ 60} 小时前';
    return '$minutes 分钟前';
  }

  List<DateTime> upcoming(DateTime start, {int limit = 12}) {
    if (!repeats) return <DateTime>[start];
    final utcStart = DateTime.utc(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
    );
    final rule = RecurrenceRule(
      frequency: switch (repeatUnit!) {
        ReminderRepeatUnit.day => Frequency.daily,
        ReminderRepeatUnit.week => Frequency.weekly,
        ReminderRepeatUnit.month => Frequency.monthly,
        ReminderRepeatUnit.year => Frequency.yearly,
      },
      interval: interval,
      byWeekDays: repeatUnit == ReminderRepeatUnit.week
          ? (weekdays.isEmpty ? {start.weekday} : weekdays)
                .map(ByWeekDayEntry.new)
                .toList()
          : const [],
      byMonthDays: repeatUnit == ReminderRepeatUnit.month
          ? (monthDays.isEmpty ? <int>[start.day] : monthDays.toList())
          : const [],
      until: repeatEnd == ReminderRepeatEnd.date && endDate != null
          ? DateTime.utc(
              endDate!.year,
              endDate!.month,
              endDate!.day,
              23,
              59,
              59,
            )
          : null,
      count: repeatEnd == ReminderRepeatEnd.count ? endCount : null,
    );
    return rule
        .getInstances(start: utcStart)
        .take(limit)
        .map(
          (value) => DateTime(
            value.year,
            value.month,
            value.day,
            value.hour,
            value.minute,
          ),
        )
        .toList();
  }

  String _weekdaySuffix(DateTime start) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    final values = weekdays.isEmpty ? {start.weekday} : weekdays;
    return values.map((value) => '周${labels[value - 1]}').join('、');
  }

  String _monthDaySuffix(DateTime start) {
    final values = monthDays.isEmpty ? {start.day} : monthDays;
    return values.map((value) => '$value 日').join('、');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
