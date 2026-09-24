import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../application/vehicle_providers.dart';
import '../data/lifecycle_repository.dart';
import '../data/maintenance_repository.dart';
import '../domain/maintenance_options.dart';
import 'vehicle_metric_grid.dart';

class VehicleMaintenanceTab extends ConsumerWidget {
  const VehicleMaintenanceTab({required this.vehicle, super.key});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(vehicleMaintenanceItemsProvider(vehicle.id));
    final lifecycle = ref.watch(vehicleLifecycleRecordsProvider(vehicle.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '保养/备件',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _seedDefaults(context, ref),
              icon: const Icon(Icons.playlist_add_outlined),
              label: const Text('初始化默认项目'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('保养项目加载失败：$error'),
          data: (rows) {
            return Column(
              children: [
                _MaintenanceOverview(rows: rows),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('还没有保养项目。可以先初始化主机和副机的机油、机油滤芯项目。'),
                    ),
                  )
                else
                  ...rows.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MaintenanceCard(item: item),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text('部件寿命', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        lifecycle.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('部件寿命加载失败：$error'),
          data: (rows) {
            if (rows.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('暂未登记寿命件。轮胎、滤芯等需要按实际更换或安装记录累计使用。'),
                ),
              );
            }
            return Column(
              children: rows.map((row) => _LifecycleCard(record: row)).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _seedDefaults(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .seedDefaultItems(vehicle.id);
      ref.invalidate(vehicleMaintenanceItemsProvider(vehicle.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('默认保养项目已初始化')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('初始化失败：$error')));
      }
    }
  }
}

class _MaintenanceOverview extends StatelessWidget {
  const _MaintenanceOverview({required this.rows});

  final List<VehicleMaintenanceItem> rows;

  @override
  Widget build(BuildContext context) {
    final dueSoon = rows
        .where(
          (row) =>
              MaintenanceRepository.dueStatus(row) ==
              MaintenanceDueStatus.dueSoon,
        )
        .length;
    final due = rows
        .where(
          (row) =>
              MaintenanceRepository.dueStatus(row) == MaintenanceDueStatus.due,
        )
        .length;
    final overdue = rows
        .where(
          (row) =>
              MaintenanceRepository.dueStatus(row) ==
              MaintenanceDueStatus.overdue,
        )
        .length;
    return VehicleMetricGrid(
      items: [
        VehicleMetricData(
          label: '即将到期',
          value: '$dueSoon',
          color: Colors.orange,
          icon: Icons.event_available_outlined,
        ),
        VehicleMetricData(
          label: '已到期',
          value: '$due',
          color: AppColors.danger,
          icon: Icons.error_outline,
        ),
        VehicleMetricData(
          label: '超期未处理',
          value: '$overdue',
          color: AppColors.danger,
          icon: Icons.notifications_active_outlined,
        ),
        VehicleMetricData(
          label: '保养项目',
          value: '${rows.length}',
          color: AppColors.techBlue,
          icon: Icons.bar_chart_outlined,
        ),
      ],
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.item});

  final VehicleMaintenanceItem item;

  @override
  Widget build(BuildContext context) {
    final status = MaintenanceRepository.dueStatus(item);
    final color = switch (status) {
      MaintenanceDueStatus.normal => Colors.green,
      MaintenanceDueStatus.dueSoon => Colors.orange,
      MaintenanceDueStatus.due || MaintenanceDueStatus.overdue => Colors.red,
      MaintenanceDueStatus.noRecord => Colors.grey,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.build_circle_outlined,
                    color: color,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    MaintenanceOptions.statusLabel(status),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _MaintenanceDetail(
                    label: '上次保养',
                    value: AppDateUtils.formatDate(item.lastServiceDate),
                  ),
                ),
                Expanded(
                  child: _MaintenanceDetail(
                    label: '保养周期',
                    value:
                        '${item.intervalValue}${MaintenanceOptions.unitLabel(item.intervalUnit)}',
                  ),
                ),
                Expanded(
                  child: _MaintenanceDetail(
                    label: '下次到期',
                    value: AppDateUtils.formatDate(item.nextDueDate),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceDetail extends StatelessWidget {
  const _MaintenanceDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.body, fontSize: 10)),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _LifecycleCard extends StatelessWidget {
  const _LifecycleCard({required this.record});

  final ComponentLifecycleRecord record;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.timelapse_outlined),
      title: Text(record.name),
      subtitle: Text(
        '安装：${AppDateUtils.formatDate(record.installedDate)} · 已使用 ${LifecycleRepository.usageDays(record)} 天',
      ),
      trailing: record.thresholdDays == null
          ? null
          : Text('阈值 ${record.thresholdDays} 天'),
    ),
  );
}
