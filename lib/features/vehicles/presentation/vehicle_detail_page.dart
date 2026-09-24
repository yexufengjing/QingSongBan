import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/vehicle_providers.dart';
import '../data/maintenance_repository.dart';
import '../domain/vehicle_options.dart';
import 'vehicle_condition_tab.dart';
import 'vehicle_expense_tab.dart';
import 'vehicle_fuel_tab.dart';
import 'vehicle_maintenance_tab.dart';
import 'vehicle_metric_grid.dart';
import 'vehicle_navigation_bar.dart';
import 'vehicle_repair_tab.dart';

class VehicleDetailPage extends ConsumerWidget {
  const VehicleDetailPage({
    required this.vehicleId,
    this.initialTab,
    this.initialFuelYear,
    this.initialFuelMonth,
    super.key,
  });

  final int vehicleId;
  final String? initialTab;
  final int? initialFuelYear;
  final int? initialFuelMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider(vehicleId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('车辆详情'),
        actions: [
          IconButton(
            tooltip: '附件资料',
            onPressed: () => context.push('/vehicles/$vehicleId/attachments'),
            icon: const Icon(Icons.attach_file),
          ),
          IconButton(
            tooltip: '编辑车辆',
            onPressed: () async {
              await context.push('/vehicles/$vehicleId/edit');
              ref.invalidate(vehicleProvider(vehicleId));
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      bottomNavigationBar: const VehicleNavigationBar(),
      body: vehicle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (item) {
          if (item == null) return const Center(child: Text('车辆不存在'));
          return DefaultTabController(
            length: 6,
            initialIndex: _tabIndex(initialTab),
            child: Column(
              children: [
                _VehicleHeader(vehicle: item),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.techBlue,
                  unselectedLabelColor: AppColors.body,
                  indicatorColor: AppColors.techBlue,
                  tabs: [
                    Tab(text: '概览'),
                    Tab(text: '车况'),
                    Tab(text: '维修'),
                    Tab(text: '保养/备件'),
                    Tab(text: '油耗'),
                    Tab(text: '费用分析'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OverviewTab(
                        vehicle: item,
                        onStop: () => _stop(context, ref, item.id),
                        onAttachments: () =>
                            context.push('/vehicles/${item.id}/attachments'),
                      ),
                      VehicleConditionTab(vehicle: item),
                      VehicleRepairTab(vehicle: item),
                      VehicleMaintenanceTab(vehicle: item),
                      VehicleFuelTab(
                        vehicle: item,
                        initialYear: initialFuelYear,
                        initialMonth: initialFuelMonth,
                      ),
                      VehicleExpenseTab(vehicle: item),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _tabIndex(String? tab) => switch (tab) {
    'condition' => 1,
    'repair' => 2,
    'maintenance' => 3,
    'fuel' => 4,
    'expense' => 5,
    _ => 0,
  };

  Future<void> _stop(BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('将车辆标记为停用？'),
        content: const Text('车辆档案和历史数据会保留，状态会变为“停用”。'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('确认停用'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(vehicleRepositoryProvider)
        .setStatus(id, VehicleStatus.stopped);
    ref.invalidate(vehicleProvider(id));
  }
}

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final color = _vehicleStatusColor(vehicle.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: 72,
                child: Image.asset(
                  vehicle.vehicleType == VehicleType.sweeper
                      ? 'assets/vehicles/sweeper-truck.png'
                      : 'assets/vehicles/water-truck.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          vehicle.licensePlate ?? vehicle.vehicleNo,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 8),
                        _DetailStatusChip(
                          label: VehicleOptions.statusLabel(vehicle.status),
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${VehicleOptions.typeShortLabel(vehicle.vehicleType)} · ${vehicle.workArea ?? '未设置工作区域'} · ${vehicle.responsiblePerson ?? '未设置责任人'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.vehicle,
    required this.onStop,
    required this.onAttachments,
  });

  final Vehicle vehicle;
  final VoidCallback onStop;
  final VoidCallback onAttachments;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        _OverviewMetrics(vehicle: vehicle),
        const SizedBox(height: 12),
        _CurrentIssues(vehicle: vehicle),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('档案信息', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                _InfoRow(label: '工作区域', value: vehicle.workArea),
                _InfoRow(label: '责任人', value: vehicle.responsiblePerson),
                _InfoRow(label: '使用部门', value: vehicle.department),
                _InfoRow(
                  label: '品牌/型号',
                  value: [
                    vehicle.brand,
                    vehicle.model,
                  ].whereType<String>().where((v) => v.isNotEmpty).join(' / '),
                ),
                _InfoRow(label: '备注', value: vehicle.remark),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SizedBox(height: 8),
        Text('快捷操作', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    context.push('/vehicles/${vehicle.id}/repair/new'),
                icon: const Icon(Icons.build_outlined),
                label: const Text('立即报修'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => DefaultTabController.of(context).animateTo(3),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('记录保养'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onAttachments,
          icon: const Icon(Icons.attach_file),
          label: const Text('附件资料'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.pause_circle_outline),
          label: const Text('标记车辆停用'),
        ),
      ],
    );
  }
}

class _OverviewMetrics extends ConsumerWidget {
  const _OverviewMetrics({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditions = ref
        .watch(vehicleConditionItemsProvider(vehicle.id))
        .valueOrNull;
    final maintenance = ref
        .watch(vehicleMaintenanceItemsProvider(vehicle.id))
        .valueOrNull;
    final now = DateTime.now();
    final fuel = ref
        .watch(vehicleFuelProvider((vehicle.id, now.year)))
        .valueOrNull
        ?.where((item) => item.month == now.month)
        .firstOrNull;
    final issues = conditions
        ?.where(
          (item) =>
              item.status == VehicleConditionStatus.pendingRepair ||
              item.status == VehicleConditionStatus.repairing,
        )
        .length;
    final abnormal = conditions
        ?.where((item) => item.status != VehicleConditionStatus.normal)
        .length;
    final due = maintenance?.where((item) {
      final status = MaintenanceRepository.dueStatus(item);
      return status == MaintenanceDueStatus.due ||
          status == MaintenanceDueStatus.overdue;
    }).length;
    return VehicleMetricGrid(
      items: [
        VehicleMetricData(
          label: '待维修问题',
          value: issues?.toString() ?? '—',
          icon: Icons.warning_amber_outlined,
          color: AppColors.danger,
        ),
        VehicleMetricData(
          label: '保养到期',
          value: due?.toString() ?? '—',
          icon: Icons.event_available_outlined,
          color: Colors.orange,
        ),
        VehicleMetricData(
          label: '车况异常',
          value: abnormal?.toString() ?? '—',
          icon: Icons.report_problem_outlined,
          color: AppColors.danger,
        ),
        VehicleMetricData(
          label: '本月油耗',
          value: fuel == null ? '—' : '${fuel.liters.toStringAsFixed(0)} L',
          icon: Icons.water_drop_outlined,
          color: AppColors.techBlue,
        ),
      ],
    );
  }
}

class _CurrentIssues extends StatelessWidget {
  const _CurrentIssues({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final isNormal = vehicle.status == VehicleStatus.normal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (isNormal ? AppColors.primary : AppColors.danger)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                isNormal
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
                color: isNormal ? AppColors.primary : AppColors.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前发现问题',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isNormal
                        ? '暂无登记中的问题，建议按计划完成日常检查。'
                        : '当前状态：${VehicleOptions.statusLabel(vehicle.status)}，请及时跟进处理。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.helper),
          ],
        ),
      ),
    );
  }
}

class _DetailStatusChip extends StatelessWidget {
  const _DetailStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
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

Color _vehicleStatusColor(VehicleStatus status) => switch (status) {
  VehicleStatus.normal => AppColors.primary,
  VehicleStatus.pendingRepair => Colors.orange,
  VehicleStatus.repairing => AppColors.techBlue,
  VehicleStatus.stopped || VehicleStatus.scrapped => AppColors.body,
};

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value == null || value!.isEmpty ? '未填写' : value!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}
