import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/vehicle_providers.dart';
import '../data/maintenance_repository.dart';
import '../domain/vehicle_options.dart';
import 'vehicle_navigation_bar.dart';

class VehiclePage extends ConsumerWidget {
  const VehiclePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);
    final allVehicles = ref.watch(allVehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('车辆管理'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            tooltip: '年度油耗汇总',
            onPressed: () => context.push('/vehicles/fuel-summary'),
            icon: const Icon(Icons.table_chart_outlined),
          ),
          IconButton(
            tooltip: '新增车辆',
            onPressed: () => context.push('/vehicles/new'),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VehicleSearchAndFilters(ref: ref),
              const SizedBox(height: 12),
              allVehicles.when(
                loading: () => const _StatsLoading(),
                error: (error, _) => _ErrorCard(message: error.toString()),
                data: (items) => _VehicleStats(items: items),
              ),
              const SizedBox(height: 12),
              _BusinessEntryPanel(
                onOpenSummary: () => context.push('/vehicles/fuel-summary'),
                onOpenFirstVehicle: (tab) => _openFirstVehicle(
                  context,
                  allVehicles.valueOrNull,
                  tab: tab,
                ),
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                title: '车辆列表',
                trailing: vehicles.when(
                  data: (items) => Text(
                    '共 ${items.length} 辆',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 10),
              vehicles.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _ErrorCard(message: error.toString()),
                data: (items) => _VehicleList(
                  items: items,
                  onAdd: () => context.push('/vehicles/new'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const VehicleNavigationBar(),
    );
  }

  void _openFirstVehicle(
    BuildContext context,
    List<Vehicle>? vehicles, {
    String? tab,
  }) {
    final first = vehicles?.firstOrNull;
    if (first == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先新增车辆，再进入该业务页面')));
      return;
    }
    final query = tab == null ? '' : '?tab=$tab';
    context.push('/vehicles/${first.id}$query');
  }
}

class _VehicleSearchAndFilters extends ConsumerWidget {
  const _VehicleSearchAndFilters({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final selectedType = ref.watch(vehicleTypeFilterProvider);
    final selectedStatus = ref.watch(vehicleStatusFilterProvider);

    return Column(
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(Icons.search, color: AppColors.helper, size: 25),
              ),
              Expanded(
                child: TextField(
                  onChanged: (value) =>
                      ref.read(vehicleSearchQueryProvider.notifier).state =
                          value,
                  decoration: const InputDecoration(
                    hintText: '搜索车牌号、车辆名称或负责人',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: AppColors.divider),
              TextButton(
                onPressed: () => FocusScope.of(context).unfocus(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.techBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('搜索'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterPill(
                label: '全部',
                selected: selectedType == null && selectedStatus == null,
                onTap: () {
                  ref.read(vehicleTypeFilterProvider.notifier).state = null;
                  ref.read(vehicleStatusFilterProvider.notifier).state = null;
                },
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: '扫路车',
                selected: selectedType == VehicleType.sweeper,
                onTap: () =>
                    ref
                        .read(vehicleTypeFilterProvider.notifier)
                        .state = selectedType == VehicleType.sweeper
                    ? null
                    : VehicleType.sweeper,
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: '洒水车',
                selected: selectedType == VehicleType.waterTruck,
                onTap: () =>
                    ref
                        .read(vehicleTypeFilterProvider.notifier)
                        .state = selectedType == VehicleType.waterTruck
                    ? null
                    : VehicleType.waterTruck,
              ),
              const _FilterDivider(),
              for (final status in [
                VehicleStatus.normal,
                VehicleStatus.pendingRepair,
                VehicleStatus.repairing,
              ]) ...[
                _FilterPill(
                  label: VehicleOptions.statusLabel(status),
                  selected: selectedStatus == status,
                  color: _statusColor(status),
                  onTap: () =>
                      ref.read(vehicleStatusFilterProvider.notifier).state =
                          selectedStatus == status ? null : status,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.techBlue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      side: BorderSide.none,
      labelStyle: TextStyle(
        color: selected ? Colors.white : color ?? AppColors.body,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      selectedColor: color == null ? AppColors.techBlue : accent,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }
}

class _FilterDivider extends StatelessWidget {
  const _FilterDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 10),
    child: Center(child: SizedBox(height: 22, child: VerticalDivider())),
  );
}

class _VehicleStats extends ConsumerWidget {
  const _VehicleStats({required this.items});

  final List<Vehicle> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int count(VehicleStatus status) =>
        items.where((item) => item.status == status).length;
    final maintenanceDue = items.fold<int>(0, (total, vehicle) {
      final state = ref.watch(vehicleMaintenanceItemsProvider(vehicle.id));
      final due = state.valueOrNull?.where((item) {
        final status = MaintenanceRepository.dueStatus(item);
        return status == MaintenanceDueStatus.due ||
            status == MaintenanceDueStatus.overdue;
      }).length;
      return total + (due ?? 0);
    });
    final fuelAnomalies = items.where((vehicle) {
      final state = ref.watch(vehicleCurrentFuelAnomalyProvider(vehicle.id));
      return state.valueOrNull?.hasWarning ?? false;
    }).length;
    final values = [
      ('车辆总数', items.length, AppColors.techBlue, Icons.local_shipping_outlined),
      (
        '正常',
        count(VehicleStatus.normal),
        AppColors.primary,
        Icons.check_circle,
      ),
      ('待维修', count(VehicleStatus.pendingRepair), Colors.orange, Icons.build),
      ('保养到期', maintenanceDue, const Color(0xfff59e0b), Icons.event_available),
      ('油耗异常', fuelAnomalies, const Color(0xffef476f), Icons.water_drop),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 370;
        return Row(
          children: [
            for (var index = 0; index < values.length; index++) ...[
              if (index > 0) const SizedBox(width: 5),
              Expanded(
                child: _StatTile(value: values[index], compact: compact),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.compact});

  final (String, int, Color, IconData) value;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    height: compact ? 76 : 84,
    decoration: BoxDecoration(
      color: value.$3.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(13),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(value.$4, color: value.$3, size: compact ? 18 : 21),
        const SizedBox(height: 2),
        Text(
          '${value.$2}',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800),
        ),
        Text(
          value.$1,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.body, fontSize: compact ? 10 : 11),
        ),
      ],
    ),
  );
}

class _BusinessEntryPanel extends StatelessWidget {
  const _BusinessEntryPanel({
    required this.onOpenSummary,
    required this.onOpenFirstVehicle,
  });

  final VoidCallback onOpenSummary;
  final void Function(String? tab) onOpenFirstVehicle;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('车辆档案', '车辆信息管理', Icons.description_outlined, null),
      ('车况检查', '日常检查上报', Icons.verified_outlined, 'condition'),
      ('维修管理', '报修/维修记录', Icons.build_outlined, 'repair'),
      ('保养/备件', '保养计划与备件', Icons.settings_outlined, 'maintenance'),
      ('油耗管理', '加油记录与分析', Icons.water_drop_outlined, 'fuel'),
      ('费用分析', '用车成本统计', Icons.bar_chart_outlined, 'expense'),
      ('提醒中心', '保养/年检/保险', Icons.notifications_none, null),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Text('业务入口', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text(
                  '高效管理 · 保障车辆运行',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 340 ? 4 : 3;
                return Column(
                  children: [
                    for (
                      var start = 0;
                      start < entries.length;
                      start += columns
                    ) ...[
                      if (start > 0) const SizedBox(height: 6),
                      Row(
                        children: [
                          for (
                            var index = start;
                            index < entries.length && index < start + columns;
                            index++
                          ) ...[
                            if (index > start) const SizedBox(width: 6),
                            Expanded(
                              child: _entry(context, entries[index], index),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    (String, String, IconData, String?) entry,
    int index,
  ) => SizedBox(
    height: 88,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (entry.$1 == '油耗管理') {
          onOpenSummary();
        } else if (entry.$1 == '车辆档案') {
          context.push('/vehicles/archive');
        } else if (entry.$1 == '提醒中心') {
          context.push('/vehicles/reminders');
        } else {
          onOpenFirstVehicle(entry.$4);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(entry.$3, color: _businessColor(index), size: 24),
            const SizedBox(height: 3),
            Text(
              entry.$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              entry.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.body, fontSize: 10),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VehicleList extends StatelessWidget {
  const _VehicleList({required this.items, required this.onAdd});

  final List<Vehicle> items;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
          child: Column(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 48,
                color: AppColors.helper,
              ),
              const SizedBox(height: 10),
              Text('还没有车辆档案', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text(
                '新增第一辆车，开始记录车况、维修与油耗。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('新增车辆'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final vehicle in items) ...[
          _VehicleCard(vehicle: vehicle),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _VehicleCard extends ConsumerWidget {
  const _VehicleCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(vehicle.status);
    final now = DateTime.now();
    final fuelState = ref.watch(vehicleFuelProvider((vehicle.id, now.year)));
    final expenseState = ref.watch(vehicleExpenseItemsProvider(vehicle.id));
    final conditionState = ref.watch(vehicleConditionItemsProvider(vehicle.id));
    final repairState = ref.watch(vehicleRepairOrdersProvider(vehicle.id));
    final currentFuel = fuelState.valueOrNull
        ?.where((row) => row.month == now.month)
        .firstOrNull;
    final expenseRows = expenseState.valueOrNull;
    final expenseCents = expenseRows?.fold<int>(
      0,
      (sum, row) =>
          sum +
          (row.date.year == now.year && row.date.month == now.month
              ? row.amountCents
              : 0),
    );
    final issueCount = (conditionState.valueOrNull ?? const [])
        .where((item) => item.status != VehicleConditionStatus.normal)
        .length;
    final repairCount = (repairState.valueOrNull ?? const [])
        .where(
          (item) =>
              item.status == VehicleRepairStatus.reported ||
              item.status == VehicleRepairStatus.pendingRepair ||
              item.status == VehicleRepairStatus.repairing,
        )
        .length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/vehicles/${vehicle.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    height: 76,
                    child: Image.asset(
                      _vehicleAsset(vehicle.vehicleType),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vehicle.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            _StatusChip(
                              label: VehicleOptions.statusLabel(vehicle.status),
                              color: statusColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            _VehicleTag(
                              text: VehicleOptions.typeShortLabel(
                                vehicle.vehicleType,
                              ),
                              color: AppColors.techBlue,
                            ),
                            if (vehicle.licensePlate?.isNotEmpty == true) ...[
                              const SizedBox(width: 6),
                              _VehicleTag(text: vehicle.licensePlate!),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${vehicle.workArea?.isNotEmpty == true ? vehicle.workArea : '未设置工作区域'}  ·  ${vehicle.responsiblePerson?.isNotEmpty == true ? vehicle.responsiblePerson : '未设置责任人'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.helper),
                ],
              ),
              const Divider(height: 18),
              Row(
                children: [
                  _Metric(
                    icon: Icons.water_drop_outlined,
                    label: '本月油耗',
                    value: currentFuel == null
                        ? '—'
                        : '${currentFuel.liters.toStringAsFixed(0)}L',
                  ),
                  const _MetricDivider(),
                  _Metric(
                    icon: Icons.layers_outlined,
                    label: '本月费用',
                    value: expenseCents == null
                        ? '—'
                        : '¥${(expenseCents / 100).toStringAsFixed(0)}',
                  ),
                  const _MetricDivider(),
                  _Metric(
                    icon: Icons.warning_amber_outlined,
                    label: '问题数量',
                    value: '${issueCount + repairCount}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleTag extends StatelessWidget {
  const _VehicleTag({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: (color ?? AppColors.helper).withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color ?? AppColors.body,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.body),
        const SizedBox(width: 5),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 34, child: VerticalDivider());
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const Spacer(),
      trailing,
    ],
  );
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 104,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.lightDanger,
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: AppColors.danger),
      title: const Text('车辆数据暂时无法加载'),
      subtitle: Text(message),
    ),
  );
}

Color _statusColor(VehicleStatus status) => switch (status) {
  VehicleStatus.normal => AppColors.primary,
  VehicleStatus.pendingRepair => Colors.orange,
  VehicleStatus.repairing => AppColors.techBlue,
  VehicleStatus.stopped || VehicleStatus.scrapped => AppColors.body,
};

Color _businessColor(int index) => [
  AppColors.techBlue,
  AppColors.primary,
  Colors.orange,
  AppColors.purple,
  AppColors.techBlue,
  AppColors.purple,
  const Color(0xffef476f),
][index];

String _vehicleAsset(VehicleType type) => switch (type) {
  VehicleType.sweeper => 'assets/vehicles/sweeper-truck.png',
  VehicleType.waterTruck => 'assets/vehicles/water-truck.png',
};
