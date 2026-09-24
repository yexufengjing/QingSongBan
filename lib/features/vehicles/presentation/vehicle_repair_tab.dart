import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/vehicle_providers.dart';
import '../domain/repair_options.dart';
import 'vehicle_metric_grid.dart';

class VehicleRepairTab extends ConsumerWidget {
  const VehicleRepairTab({required this.vehicle, super.key});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
  });

  final List<RepairOrder> items;
  final Vehicle vehicle;
  final VoidCallback onCreate;

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
    final total = items.fold<int>(
      0,
      (sum, item) => sum + item.actualAmountCents,
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
              color: AppColors.primary,
              icon: Icons.check_circle_outline,
            ),
            VehicleMetricData(
              label: '累计费用',
              value: '¥${(total / 100).toStringAsFixed(0)}',
              color: AppColors.purple,
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('维修单列表', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (items.isEmpty)
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
          for (final order in items) ...[
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
      VehicleRepairStatus.completed => AppColors.primary,
      VehicleRepairStatus.cancelled => AppColors.body,
      VehicleRepairStatus.repairing => AppColors.techBlue,
      _ => Colors.orange,
    };
    return Card(
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
                          fontSize: 11,
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
          ],
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
