import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/vehicle_providers.dart';
import '../domain/repair_options.dart';
import 'vehicle_metric_grid.dart';

class VehicleRepairTab extends ConsumerStatefulWidget {
  const VehicleRepairTab({required this.vehicle, super.key});

  final Vehicle vehicle;

  @override
  ConsumerState<VehicleRepairTab> createState() => _VehicleRepairTabState();
}

class _VehicleRepairTabState extends ConsumerState<VehicleRepairTab> {
  VehicleRepairStatus? _status;
  DateTime? _month;
  bool _amountDescending = false;

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final orders = ref.watch(vehicleRepairOrdersProvider(vehicle.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        orders.when(
          loading: () => const _RepairLoading(),
          error: (error, _) => _RepairError(message: error.toString()),
          data: (items) => _RepairContent(
            items: items,
            vehicle: vehicle,
            onCreate: () => context.push('/vehicles/${vehicle.id}/repair/new'),
            status: _status,
            month: _month,
            amountDescending: _amountDescending,
            onStatusChanged: (value) => setState(() => _status = value),
            onMonthChanged: (value) => setState(() => _month = value),
            onSortChanged: (value) => setState(() => _amountDescending = value),
          ),
        ),
      ],
    );
  }
}

class _RepairContent extends StatelessWidget {
  const _RepairContent({
    required this.items,
    required this.vehicle,
    required this.onCreate,
    required this.status,
    required this.month,
    required this.amountDescending,
    required this.onStatusChanged,
    required this.onMonthChanged,
    required this.onSortChanged,
  });

  final List<RepairOrder> items;
  final Vehicle vehicle;
  final VoidCallback onCreate;
  final VehicleRepairStatus? status;
  final DateTime? month;
  final bool amountDescending;
  final ValueChanged<VehicleRepairStatus?> onStatusChanged;
  final ValueChanged<DateTime?> onMonthChanged;
  final ValueChanged<bool> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final pending = items
        .where((item) => item.status == VehicleRepairStatus.reported)
        .length;
    final repairing = items
        .where((item) => item.status == VehicleRepairStatus.repairing)
        .length;
    final completed = items
        .where((item) => item.status == VehicleRepairStatus.completed)
        .length;
    final currentMonth = DateTime.now();
    final monthTotal = items
        .where(
          (item) =>
              item.reportDate.year == currentMonth.year &&
              item.reportDate.month == currentMonth.month,
        )
        .fold<int>(0, (sum, item) => sum + item.actualAmountCents);
    final visibleItems = items.where((item) {
      if (status != null && item.status != status) return false;
      if (month != null &&
          (item.reportDate.year != month!.year ||
              item.reportDate.month != month!.month)) {
        return false;
      }
      return true;
    }).toList();
    visibleItems.sort(
      (a, b) => amountDescending
          ? b.actualAmountCents.compareTo(a.actualAmountCents)
          : b.reportDate.compareTo(a.reportDate),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('维修概览', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.techBlue,
              ),
              icon: const Icon(Icons.add),
              label: const Text('新建报修'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        VehicleMetricGrid(
          items: [
            VehicleMetricData(
              label: '待维修',
              value: '$pending',
              color: Colors.orange,
              icon: Icons.build_outlined,
            ),
            VehicleMetricData(
              label: '维修中',
              value: '$repairing',
              color: AppColors.techBlue,
              icon: Icons.settings_outlined,
            ),
            VehicleMetricData(
              label: '已完成',
              value: '$completed',
              color: AppColors.success,
              icon: Icons.check_circle_outline,
            ),
            VehicleMetricData(
              label: '本月费用',
              value: '¥${(monthTotal / 100).toStringAsFixed(0)}',
              color: AppColors.purple,
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('维修单列表', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _RepairFilterChip(
                      label: '全部',
                      selected: status == null,
                      onTap: () => onStatusChanged(null),
                    ),
                    for (final value in [
                      VehicleRepairStatus.reported,
                      VehicleRepairStatus.repairing,
                      VehicleRepairStatus.completed,
                    ])
                      _RepairFilterChip(
                        label: RepairOptions.statusLabel(value),
                        selected: status == value,
                        onTap: () => onStatusChanged(value),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: month == null ? '按月份筛选' : '清除月份筛选',
              onPressed: () async {
                if (month != null) {
                  onMonthChanged(null);
                  return;
                }
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  helpText: '选择月份中的任意日期',
                );
                if (picked != null) {
                  onMonthChanged(DateTime(picked.year, picked.month));
                }
              },
              icon: Icon(
                month == null
                    ? Icons.calendar_month_outlined
                    : Icons.event_available,
              ),
            ),
            PopupMenuButton<bool>(
              tooltip: '排序维修单',
              onSelected: onSortChanged,
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: false,
                  checked: !amountDescending,
                  child: const Text('按日期排序'),
                ),
                CheckedPopupMenuItem(
                  value: true,
                  checked: amountDescending,
                  child: const Text('按金额排序'),
                ),
              ],
              icon: const Icon(Icons.swap_vert),
            ),
          ],
        ),
        if (visibleItems.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
              child: Column(
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    size: 44,
                    color: AppColors.helper,
                  ),
                  const SizedBox(height: 8),
                  const Text('暂无维修记录'),
                  const SizedBox(height: 6),
                  Text(
                    '从车况问题或这里直接创建报修单。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: onCreate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.techBlue,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('新建报修'),
                  ),
                ],
              ),
            ),
          )
        else
          for (final order in visibleItems) ...[
            _RepairCard(order: order, vehicle: vehicle),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _RepairCard extends StatelessWidget {
  const _RepairCard({required this.order, required this.vehicle});

  final RepairOrder order;
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final color = switch (order.status) {
      VehicleRepairStatus.completed => AppColors.success,
      VehicleRepairStatus.cancelled => AppColors.body,
      VehicleRepairStatus.repairing => AppColors.techBlue,
      _ => Colors.orange,
    };
    return Card(
      child: InkWell(
        onTap: () => context.push('/vehicles/repairs/${order.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 78,
                    height: 68,
                    child: Image.asset(
                      vehicle.vehicleType == VehicleType.sweeper
                          ? 'assets/vehicles/sweeper-truck.png'
                          : 'assets/vehicles/water-truck.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vehicle.licensePlate ?? vehicle.vehicleNo,
                          style: const TextStyle(
                            color: AppColors.techBlue,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.symptom,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _RepairStatusChip(
                    label: RepairOptions.statusLabel(order.status),
                    color: color,
                  ),
                ],
              ),
              const Divider(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: AppColors.helper,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _date(order.reportDate),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '¥${((order.actualAmountCents > 0 ? order.actualAmountCents : order.reportedAmountCents) / 100).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              if (order.vendor?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  '维修地点：${order.vendor}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (order.manager?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  '维修负责人：${order.manager}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (order.project?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  '维修项目：${order.project}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _RepairStatusChip extends StatelessWidget {
  const _RepairStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _RepairFilterChip extends StatelessWidget {
  const _RepairFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.body,
        fontSize: 12,
      ),
      selectedColor: AppColors.techBlue,
      side: BorderSide.none,
      onSelected: (_) => onTap(),
    ),
  );
}

class _RepairLoading extends StatelessWidget {
  const _RepairLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 180,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _RepairError extends StatelessWidget {
  const _RepairError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: AppColors.danger),
      title: const Text('维修记录加载失败'),
      subtitle: Text(message),
    ),
  );
}
