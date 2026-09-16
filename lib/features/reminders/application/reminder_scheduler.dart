import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/reminder_repository.dart';
import '../domain/reminder_options.dart';
import 'notification_service.dart';

/// Coordinates occurrence generation and all local notification work.
/// Calling rescheduleAll is deliberately idempotent: the plugin is cleared,
/// then at most 50 near-term notifications are rebuilt from database truth.
class ReminderScheduler {
  ReminderScheduler(this._repository, this._notifications);

  final ReminderRepository _repository;
  final NotificationService _notifications;
  bool _initialized = false;
  bool _rescheduling = false;
  bool _rescheduleAgain = false;
  void Function(int reminderId)? _onOpenReminder;

  NotificationService get notifications => _notifications;

  Future<void> initialize({
    void Function(int reminderId)? onOpenReminder,
  }) async {
    _onOpenReminder = onOpenReminder;
    if (_initialized) return;
    await _notifications.initialize(onResponse: _handleResponse);
    _initialized = true;
    final launchResponse = await _notifications.launchResponse();
    if (launchResponse != null) {
      await _handleResponse(launchResponse);
    }
  }

  Future<void> rescheduleAll() async {
    if (_rescheduling) {
      _rescheduleAgain = true;
      return;
    }
    _rescheduling = true;
    try {
      await initialize(onOpenReminder: _onOpenReminder);
      final reminders = await _repository.watchReminders().first;
      for (final reminder in reminders.where(
        (item) => item.isEnabled && !item.isDeleted && item.dueDate != null,
      )) {
        await _repository.ensureOccurrences(reminder.id);
      }
      final now = DateTime.now();
      final items = await _repository.listPendingItems(
        from: now.subtract(const Duration(days: 31)),
        until: now.add(const Duration(days: 30)),
        limit: 200,
      );
      final scheduled = <_NotificationPlan>[];
      for (final item in items) {
        final rules = await _repository.findAlertRules(item.reminder.id);
        if (item.occurrence.snoozedUntil != null) {
          final snooze = item.occurrence.snoozedUntil!;
          if (snooze.isAfter(now)) {
            scheduled.add(
              _NotificationPlan(
                id: _notificationId(item.occurrence.id, 0, 0),
                item: item,
                at: snooze,
                label: '稍后提醒',
              ),
            );
          }
          continue;
        }
        for (final rule in rules) {
          if (!rule.isEnabled) continue;
          if (rule.isNagRule) {
            final interval = rule.repeatIntervalMinutes ?? 1440;
            final maxCount = (rule.maxRepeatCount ?? 3).clamp(1, 20);
            for (var index = 0; index < maxCount; index++) {
              final at = item.scheduledAt.add(
                Duration(minutes: interval * (index + 1)),
              );
              if (rule.nagEndsAfterMinutes != null &&
                  at.isAfter(
                    item.scheduledAt.add(
                      Duration(minutes: rule.nagEndsAfterMinutes!),
                    ),
                  )) {
                break;
              }
              if (at.isAfter(now) &&
                  at.isBefore(now.add(const Duration(days: 30)))) {
                scheduled.add(
                  _NotificationPlan(
                    id: _notificationId(item.occurrence.id, rule.id, index),
                    item: item,
                    at: at,
                    label: '逾期催办',
                  ),
                );
              }
            }
          } else {
            final at = item.scheduledAt.add(
              Duration(minutes: rule.offsetMinutes),
            );
            if (at.isAfter(now) &&
                at.isBefore(now.add(const Duration(days: 30)))) {
              scheduled.add(
                _NotificationPlan(
                  id: _notificationId(item.occurrence.id, rule.id, 0),
                  item: item,
                  at: at,
                  label: ReminderOptions.alertLabel(rule.offsetMinutes),
                ),
              );
            }
          }
        }
      }
      scheduled.sort((a, b) => a.at.compareTo(b.at));
      await _notifications.cancelAll();
      for (final plan in scheduled.take(50)) {
        await _notifications.schedule(
          id: plan.id,
          title: plan.item.reminder.title,
          body: _body(plan.item, plan.label),
          at: _asDeviceTime(plan.at),
          payload:
              'reminder=${plan.item.reminder.id}&occurrence=${plan.item.occurrence.id}',
        );
      }
    } finally {
      _rescheduling = false;
      if (_rescheduleAgain) {
        _rescheduleAgain = false;
        unawaited(rescheduleAll());
      }
    }
  }

  Future<void> reschedule(int reminderId) async {
    await _repository.ensureOccurrences(reminderId);
    await rescheduleAll();
  }

  Future<void> _handleResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;
    final reminderId = int.tryParse(
      RegExp(r'reminder=(\d+)').firstMatch(payload)?.group(1) ?? '',
    );
    final occurrenceId = int.tryParse(
      RegExp(r'occurrence=(\d+)').firstMatch(payload)?.group(1) ?? '',
    );
    if (reminderId == null || occurrenceId == null) return;
    switch (response.actionId) {
      case 'complete':
        await _repository.completeOccurrence(occurrenceId);
        await rescheduleAll();
      case 'snooze':
        await _repository.snoozeOccurrence(
          occurrenceId,
          DateTime.now().add(const Duration(hours: 1)),
        );
        await rescheduleAll();
      default:
        _onOpenReminder?.call(reminderId);
    }
  }

  String _body(ReminderListItem item, String label) {
    final due = item.scheduledAt;
    final time =
        '${due.month}/${due.day} ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
    final linked = item.links.isEmpty
        ? ''
        : ' · ${item.links.map((link) => link.displayName).join('、')}';
    final details = item.reminder.remark?.trim();
    final detail = details == null || details.isEmpty
        ? ''
        : ' · ${_summary(details)}';
    return '$label · 到期 $time$linked$detail';
  }

  String _summary(String value) =>
      value.length <= 40 ? value : '${value.substring(0, 40)}…';

  tz.TZDateTime _asDeviceTime(DateTime value) => tz.TZDateTime(
    tz.local,
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
  );

  int _notificationId(int occurrenceId, int ruleId, int sequence) {
    final value = occurrenceId * 1000 + ruleId * 21 + sequence + 100;
    return value % 2147483000;
  }
}

class _NotificationPlan {
  const _NotificationPlan({
    required this.id,
    required this.item,
    required this.at,
    required this.label,
  });

  final int id;
  final ReminderListItem item;
  final DateTime at;
  final String label;
}
