import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/vehicle_providers.dart';
import '../data/maintenance_repository.dart';
import '../domain/vehicle_options.dart';

class VehiclePage extends ConsumerStatefulWidget {
  const VehiclePage({super.key});

  @override
  ConsumerState<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends ConsumerState<VehiclePage> {
  _VehicleSort _sort = _VehicleSort.defaultOrder;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final vehicles = ref.watch(vehicleListProvider);
    final allVehicles = ref.watch(allVehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('车辆管理'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _VehicleSearchAndFilters(ref: ref),
                ),
              ),
              const SizedBox(height: 12),
              _SectionTitle(
                title: '车辆列表',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    vehicles.when(
                      data: (items) => Text(
                        '共 ${items.length} 辆',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<_VehicleSort>(
                      tooltip: '车辆排序',
                      initialValue: _sort,
                      onSelected: (value) => setState(() => _sort = value),
                      itemBuilder: (context) => [
                        for (final order in _VehicleSort.values)
                          PopupMenuItem(value: order, child: Text(order.label)),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.swap_vert,
                            size: 17,
                            color: AppColors.helper,
                          ),
                          Text(
                            _sort.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 17,
                            color: AppColors.helper,
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  items: _sortVehicles(items, _sort),
                  onAdd: () => context.push('/vehicles/new'),
                ),
              ),
            ],
          ),
        ),
      ),
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
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
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
          height: 48,
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
        fontSize: 12,
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      selectedColor: color == null ? AppColors.techBlue : accent,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
    final now = DateTime.now();
    var expenseCents = 0;
    var repairCents = 0;
    var expensesLoaded = true;
    for (final vehicle in items) {
      final rows = ref
          .watch(vehicleExpenseItemsProvider(vehicle.id))
          .valueOrNull;
      if (rows == null) {
        expensesLoaded = false;
        continue;
      }
      for (final row in rows) {
        if (row.date.year != now.year || row.date.month != now.month) continue;
        expenseCents += row.amountCents;
        if (row.category == '维修费用') repairCents += row.amountCents;
      }
    }
    final values = [
      ('车辆总数', items.length, AppColors.techBlue, Icons.local_shipping_outlined),
      (
        '正常',
        count(VehicleStatus.normal),
        AppColors.success,
        Icons.check_circle,
      ),
      ('待维修', count(VehicleStatus.pendingRepair), Colors.orange, Icons.build),
      ('保养到期', maintenanceDue, const Color(0xfff59e0b), Icons.event_available),
      ('油耗异常', fuelAnomalies, const Color(0xffef476f), Icons.water_drop),
    ];
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                final costs = [
                  _TopCost(
                    label: '本月维修费',
                    value: expensesLoaded
                        ? (repairCents / 100).toStringAsFixed(2)
                        : '—',
                    icon: Icons.build,
                    color: AppColors.primary,
                  ),
                  _TopCost(
                    label: '本月费用',
                    value: expensesLoaded
                        ? (expenseCents / 100).toStringAsFixed(2)
                        : '—',
                    icon: Icons.account_balance_wallet,
                    color: Colors.orange,
                  ),
                ];
                return compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          costs[0],
                          const SizedBox(height: 8),
                          costs[1],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: costs[0]),
                          const SizedBox(width: 8),
                          Expanded(child: costs[1]),
                        ],
                      );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('车辆统计', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth >= 320 &&
                            MediaQuery.textScalerOf(context).scale(14) <= 18
                        ? 4
                        : 2;
                    return Column(
                      children: [
                        for (
                          var start = 0;
                          start < values.length;
                          start += columns
                        ) ...[
                          if (start > 0) const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var index = start;
                                index < values.length &&
                                    index < start + columns;
                                index++
                              ) ...[
                                if (index > start) const SizedBox(width: 6),
                                Expanded(
                                  child: _StatTile(value: values[index]),
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
        ),
      ],
    );
  }
}

class _TopCost extends StatelessWidget {
  const _TopCost({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.body, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value 元',
              softWrap: false,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value});
  final (String, int, Color, IconData) value;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 72),
    decoration: BoxDecoration(
      color: value.$3.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(value.$4, color: value.$3, size: 18),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value.$1,
                style: const TextStyle(color: AppColors.body, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${value.$2} ${value.$1 == '保养到期' ? '项' : '辆'}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
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
      ('车辆档案', '车辆信息管理', Icons.local_shipping, null),
      ('维修管理', '报修/维修记录', Icons.build, 'repair'),
      ('费用分析', '用车成本统计', Icons.account_balance_wallet, 'expense'),
      ('车况检查', '日常检查上报', Icons.directions_car, 'condition'),
      ('保养/备件', '保养计划与备件', Icons.settings, 'maintenance'),
      ('油耗管理', '加油记录与分析', Icons.local_gas_station, 'fuel'),
      ('提醒中心', '保养/年检/保险', Icons.notifications, null),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '业务入口',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 320 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 18
                    ? 4
                    : 2;
                return Column(
                  children: [
                    for (
                      var start = 0;
                      start < entries.length;
                      start += columns
                    ) ...[
                      if (start > 0) const SizedBox(height: 4),
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
    height: 76 * (MediaQuery.textScalerOf(context).scale(14) / 14),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (entry.$1 == '油耗管理') {
          onOpenSummary();
        } else if (entry.$1 == '车辆档案') {
          context.push('/vehicles/archive');
        } else if (entry.$1 == '提醒中心') {
          context.push('/vehicles/reminders');
        } else if (entry.$1 == '维修管理') {
          context.push('/vehicles/repairs');
        } else {
          onOpenFirstVehicle(entry.$4);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(entry.$3, color: _businessColor(index), size: 22),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    entry.$1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
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
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            _StatusChip(
                              label: VehicleOptions.statusLabel(vehicle.status),
                              color: statusColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _VehicleTag(
                              text: VehicleOptions.typeShortLabel(
                                vehicle.vehicleType,
                              ),
                              color: AppColors.techBlue,
                            ),
                            if (vehicle.licensePlate?.isNotEmpty == true) ...[
                              _VehicleTag(text: vehicle.licensePlate!),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: _VehicleIdentity(
                                icon: Icons.location_on,
                                label: vehicle.workArea?.isNotEmpty == true
                                    ? vehicle.workArea!
                                    : '未设置区域',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _VehicleIdentity(
                                icon: Icons.person,
                                label:
                                    vehicle.responsiblePerson?.isNotEmpty ==
                                        true
                                    ? vehicle.responsiblePerson!
                                    : '未设置责任人',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.helper),
                ],
              ),
              const Divider(height: 10),
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

class _VehicleIdentity extends StatelessWidget {
  const _VehicleIdentity({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.helper, size: 14),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
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
        Icon(
          icon,
          size: 18,
          color: label == '本月油耗'
              ? AppColors.success
              : label == '本月费用'
              ? Colors.orange
              : AppColors.danger,
        ),
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
  VehicleStatus.normal => AppColors.success,
  VehicleStatus.pendingRepair => Colors.orange,
  VehicleStatus.repairing => AppColors.techBlue,
  VehicleStatus.stopped || VehicleStatus.scrapped => AppColors.body,
};

Color _businessColor(int index) => [
  AppColors.success,
  AppColors.primary,
  Colors.orange,
  AppColors.purple,
  const Color(0xfff59e0b),
  AppColors.success,
  const Color(0xffef476f),
][index];

enum _VehicleSort {
  defaultOrder('默认排序'),
  name('按名称'),
  vehicleNo('按编号'),
  status('按状态');

  const _VehicleSort(this.label);

  final String label;
}

List<Vehicle> _sortVehicles(List<Vehicle> vehicles, _VehicleSort sort) {
  final items = [...vehicles];
  switch (sort) {
    case _VehicleSort.defaultOrder:
      break;
    case _VehicleSort.name:
      items.sort((a, b) => a.name.compareTo(b.name));
    case _VehicleSort.vehicleNo:
      items.sort((a, b) => a.vehicleNo.compareTo(b.vehicleNo));
    case _VehicleSort.status:
      items.sort((a, b) => a.status.index.compareTo(b.status.index));
  }
  return items;
}

String _vehicleAsset(VehicleType type) => switch (type) {
  VehicleType.sweeper => 'assets/vehicles/sweeper-truck.png',
  VehicleType.waterTruck => 'assets/vehicles/water-truck.png',
};
