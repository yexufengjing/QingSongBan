import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/purchase_providers.dart';
import '../../../reminders/application/reminder_providers.dart';

class PurchaseReminderInfo extends ConsumerWidget {
  const PurchaseReminderInfo({required this.requestId, super.key});
  final int requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(purchaseReminderIdProvider(requestId));
    final reminderId = id.valueOrNull;
    if (reminderId == null) {
      if (id.isLoading) return const SizedBox.shrink();
      if (id.hasError) {
        return const Text(
          '提醒信息加载失败',
          style: TextStyle(color: Color(0xFFB54708)),
        );
      }
      return const Text('尚未设置领取提醒', style: TextStyle(color: Color(0xFF94A3B8)));
    }
    final item = ref.watch(reminderItemProvider(reminderId));
    return item.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const Text('提醒信息暂不可用'),
      data: (value) {
        if (value == null) return const Text('提醒信息暂不可用');
        final date = value.scheduledAt;
        final label = date == null
            ? '未设置时间'
            : '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        final status = value.reminder.archivedAt != null
            ? '已归档'
            : !value.reminder.isEnabled
            ? '已停用'
            : value.isCompleted
            ? '已完成'
            : value.isSkipped
            ? '已跳过'
            : '待提醒';
        return Text(
          '提醒：$label · $status',
          style: TextStyle(
            color: status == '待提醒'
                ? const Color(0xFF00A85D)
                : const Color(0xFF64748B),
          ),
          softWrap: true,
        );
      },
    );
  }
}
