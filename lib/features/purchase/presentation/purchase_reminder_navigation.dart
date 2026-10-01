import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/purchase_providers.dart';
import '../../reminders/application/reminder_providers.dart';

Future<void> openPurchaseReminder(
  BuildContext context,
  WidgetRef ref, {
  required int requestId,
  required String content,
}) async {
  try {
    ref.invalidate(purchaseReminderIdProvider(requestId));
    final reminderId = await ref.read(
      purchaseReminderIdProvider(requestId).future,
    );
    if (!context.mounted) return;
    final route = reminderId == null
        ? Uri(
            path: '/settings/reminders/new',
            queryParameters: {
              'title': '领取采购物资',
              'remark': content,
              'sourceType': 'purchase_request',
              'sourceId': '$requestId',
            },
          ).toString()
        : '/settings/reminders/$reminderId/edit';
    await context.push(route);
    if (context.mounted) {
      if (reminderId != null) {
        ref.invalidate(reminderItemProvider(reminderId));
      }
      ref.invalidate(remindersProvider);
      ref.invalidate(reminderItemsProvider);
      ref.invalidate(purchaseReminderIdProvider(requestId));
      ref.invalidate(purchaseReminderExistsProvider(requestId));
      ref.invalidate(purchaseDetailProvider(requestId));
      ref.invalidate(purchaseDashboardProvider);
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('采购状态已更新，但领取提醒创建失败，可稍后重新设置。')),
      );
    }
  }
}
