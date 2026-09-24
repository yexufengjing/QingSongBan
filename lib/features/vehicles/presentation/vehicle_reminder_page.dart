import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/reminder_options.dart';
import '../application/vehicle_providers.dart';
import 'vehicle_navigation_bar.dart';

class VehicleReminderPage extends ConsumerStatefulWidget {
  const VehicleReminderPage({super.key});

  @override
  ConsumerState<VehicleReminderPage> createState() =>
      _VehicleReminderPageState();
}

class _VehicleReminderPageState extends ConsumerState<VehicleReminderPage> {
  String _filter = '全部';

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(reminderItemsProvider);
    final vehicles = ref.watch(allVehiclesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒中心'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/settings/reminders'),
            style: TextButton.styleFrom(foregroundColor: AppColors.techBlue),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('提醒规则'),
          ),
        ],
      ),
      bottomNavigationBar: const VehicleNavigationBar(),
      body: reminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('提醒加载失败：$error')),
        data: (items) => _content(items, vehicles.valueOrNull ?? const []),
      ),
    );
  }

  Widget _content(List<ReminderItem> items, List<Vehicle> vehicles) {
    final vehicleItems = items
        .where(
          (item) =>
              item.links.any((link) => link.entityType == 'vehicle') &&
              item.isPending,
        )
        .toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final soon = today.add(const Duration(days: 7));
    final todayCount = vehicleItems
        .where(
          (item) =>
              item.scheduledAt != null &&
              item.scheduledAt!.year == today.year &&
              item.scheduledAt!.month == today.month &&
              item.scheduledAt!.day == today.day,
        )
        .length;
    final overdueCount = vehicleItems
        .where((item) => item.scheduledAt?.isBefore(today) == true)
        .length;
    final soonCount = vehicleItems
        .where(
          (item) =>
              item.scheduledAt != null &&
              !item.scheduledAt!.isBefore(today) &&
              !item.scheduledAt!.isAfter(soon),
        )
        .length;
    final visible = vehicleItems
        .where((item) => _filter == '全部' || _category(item) == _filter)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final category in ['全部', '保养', '年检', '保险', '异常']) ...[
                if (category != '全部') const SizedBox(width: 7),
                ChoiceChip(
                  label: Text(category),
                  selected: _filter == category,
                  showCheckmark: false,
                  selectedColor: AppColors.techBlue,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: _filter == category ? Colors.white : AppColors.body,
                  ),
                  onSelected: (_) => setState(() => _filter = category),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ReminderMetric(
                label: '今日提醒',
                value: todayCount,
                icon: Icons.notifications_none,
                color: AppColors.techBlue,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _ReminderMetric(
                label: '即将到期',
                value: soonCount,
                icon: Icons.schedule,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _ReminderMetric(
                label: '已逾期',
                value: overdueCount,
                icon: Icons.error_outline,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('提醒列表', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('当前没有车辆提醒', style: TextStyle(color: AppColors.body)),
            ),
          )
        else
          for (final item in visible) ...[
            _VehicleReminderCard(
              item: item,
              vehicle: _linkedVehicle(item, vehicles),
              onSkip: () async {
                await ref
                    .read(reminderRepositoryProvider)
                    .skip(item.reminder.id, occurrenceId: item.occurrence?.id);
                ref.invalidate(reminderItemsProvider);
              },
            ),
            const SizedBox(height: 9),
          ],
      ],
    );
  }

  Vehicle? _linkedVehicle(ReminderItem item, List<Vehicle> vehicles) {
    final id = item.links
        .where((link) => link.entityType == 'vehicle')
        .firstOrNull
        ?.entityId;
    return vehicles.where((vehicle) => vehicle.id == id).firstOrNull;
  }

  String _category(ReminderItem item) {
    final value = '${item.reminder.reminderType} ${item.reminder.title}';
    if (value.contains('保险')) return '保险';
    if (value.contains('年检')) return '年检';
    if (value.contains('异常')) return '异常';
    return '保养';
  }
}

class _ReminderMetric extends StatelessWidget {
  const _ReminderMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(width: 5),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.body),
            ),
          ],
        ),
      ],
    ),
  );
}

class _VehicleReminderCard extends StatelessWidget {
  const _VehicleReminderCard({
    required this.item,
    required this.vehicle,
    required this.onSkip,
  });

  final ReminderItem item;
  final Vehicle? vehicle;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheduled = item.scheduledAt;
    final overdue = scheduled?.isBefore(DateTime.now()) == true;
    final color = overdue ? AppColors.danger : Colors.orange;
    final vehicleId = vehicle?.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 12, 11, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (vehicle != null) ...[
                  SizedBox(
                    width: 84,
                    height: 65,
                    child: Image.asset(
                      vehicle!.vehicleType.name == 'sweeper'
                          ? 'assets/vehicles/sweeper-truck.png'
                          : 'assets/vehicles/water-truck.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle?.name ?? '车辆提醒',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.reminder.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    overdue ? '已逾期' : '待处理',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              scheduled == null
                  ? '未设置到期时间'
                  : '到期时间  ${scheduled.year}-${scheduled.month.toString().padLeft(2, '0')}-${scheduled.day.toString().padLeft(2, '0')}',
              style: const TextStyle(color: AppColors.body, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (sheet) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.reminder.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.reminder.remark ??
                                  '关联车辆：${vehicle?.name ?? '未知'}',
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('查看详情'),
                ),
                const Spacer(),
                OutlinedButton(onPressed: onSkip, child: const Text('忽略')),
                const SizedBox(width: 7),
                FilledButton(
                  onPressed: vehicleId == null
                      ? null
                      : () => context.push(
                          '/vehicles/$vehicleId?tab=maintenance',
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.techBlue,
                  ),
                  child: const Text('去处理'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
