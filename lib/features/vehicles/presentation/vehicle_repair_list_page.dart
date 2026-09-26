import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../application/vehicle_providers.dart';
import '../domain/repair_options.dart';

class VehicleRepairListPage extends ConsumerStatefulWidget {
  const VehicleRepairListPage({super.key});

  @override
  ConsumerState<VehicleRepairListPage> createState() =>
      _VehicleRepairListPageState();
}

class _VehicleRepairListPageState extends ConsumerState<VehicleRepairListPage> {
  final _search = TextEditingController();
  int? _vehicleId;
  VehicleRepairStatus? _status;
  RepairTicketStatus? _ticket;
  bool? _settled;
  bool? _paid;

  int get _activeFilterCount => [
    _vehicleId,
    _status,
    _ticket,
    _settled,
    _paid,
  ].where((value) => value != null).length;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters(List<Vehicle> vehicles) async {
    final filters = _RepairFilterValues(
      vehicleId: _vehicleId,
      status: _status,
      ticket: _ticket,
      settled: _settled,
      paid: _paid,
    );
    final applied = await Navigator.of(context).push<_RepairFilterValues>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _RepairFilterPage(vehicles: vehicles, initial: filters),
      ),
    );
    if (applied != null && mounted) {
      setState(() {
        _vehicleId = applied.vehicleId;
        _status = applied.status;
        _ticket = applied.ticket;
        _settled = applied.settled;
        _paid = applied.paid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(allRepairOrdersProvider);
    final vehicles = ref.watch(allVehiclesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('全车维修单')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final list =
              ref.read(allVehiclesProvider).valueOrNull ?? const <Vehicle>[];
          if (list.isEmpty) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('请先新增车辆，再创建维修单。')));
            return;
          }
          final selected = await showDialog<int>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('选择车辆'),
              content: SizedBox(
                width: 380,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final vehicle in list)
                      ListTile(
                        title: Text(vehicle.name),
                        subtitle: Text(
                          vehicle.licensePlate ?? vehicle.vehicleNo,
                        ),
                        onTap: () => Navigator.pop(dialogContext, vehicle.id),
                      ),
                  ],
                ),
              ),
            ),
          );
          if (selected != null && context.mounted) {
            context.push('/vehicles/$selected/repair/new');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('新建维修单'),
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('维修单加载失败：$e')),
        data: (items) => vehicles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('车辆加载失败：$e')),
          data: (vehicleItems) {
            final byId = {for (final v in vehicleItems) v.id: v};
            final query = _search.text.trim().toLowerCase();
            final shown = items.where((o) {
              final v = byId[o.vehicleId];
              if (_vehicleId != null && o.vehicleId != _vehicleId) return false;
              if (_status != null && o.status != _status) return false;
              if (_ticket != null && o.ticketStatus != _ticket) return false;
              if (_settled != null && o.isSettled != _settled) return false;
              if (_paid != null && o.isPaid != _paid) return false;
              if (query.isEmpty) return true;
              return [
                o.repairNo,
                o.symptom,
                o.cause ?? '',
                o.vendor ?? '',
                v?.name ?? '',
                v?.licensePlate ?? '',
                v?.vehicleNo ?? '',
              ].any((s) => s.toLowerCase().contains(query));
            }).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: '搜索工单、车辆、故障或供应商',
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        count: _activeFilterCount,
                        onPressed: () => _openFilters(vehicleItems),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    items.isEmpty
                                        ? '暂无维修单，点击“新建维修单”开始记录。'
                                        : '没有符合筛选条件的维修单。',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 92),
                          itemCount: shown.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = shown[index];
                            return _RepairOrderCard(
                              number: index + 1,
                              order: order,
                              vehicle: byId[order.vehicleId],
                              onTap: () =>
                                  context.push('/vehicles/repairs/${order.id}'),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onPressed});
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(0, 48),
    ),
    icon: const Icon(Icons.tune, size: 19),
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('筛选'),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            constraints: const BoxConstraints(minWidth: 19),
            height: 19,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.techBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _RepairFilterValues {
  const _RepairFilterValues({
    this.vehicleId,
    this.status,
    this.ticket,
    this.settled,
    this.paid,
  });

  final int? vehicleId;
  final VehicleRepairStatus? status;
  final RepairTicketStatus? ticket;
  final bool? settled;
  final bool? paid;

  int get activeCount =>
      [vehicleId, status, ticket, settled, paid].where((v) => v != null).length;

  _RepairFilterValues reset() => const _RepairFilterValues();
}

class _RepairFilterPage extends StatefulWidget {
  const _RepairFilterPage({required this.vehicles, required this.initial});
  final List<Vehicle> vehicles;
  final _RepairFilterValues initial;

  @override
  State<_RepairFilterPage> createState() => _RepairFilterPageState();
}

class _RepairFilterPageState extends State<_RepairFilterPage> {
  late int? _vehicleId = widget.initial.vehicleId;
  late VehicleRepairStatus? _status = widget.initial.status;
  late RepairTicketStatus? _ticket = widget.initial.ticket;
  late bool? _settled = widget.initial.settled;
  late bool? _paid = widget.initial.paid;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('筛选维修单'),
      leading: IconButton(
        tooltip: '返回',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _vehicleId = null;
            _status = null;
            _ticket = null;
            _settled = null;
            _paid = null;
          }),
          child: const Text('重置'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _FilterSection(
          title: '车辆',
          child: DropdownButtonFormField<int?>(
            key: ValueKey('vehicle-$_vehicleId'),
            initialValue: _vehicleId,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('全部车辆')),
              for (final vehicle in widget.vehicles)
                DropdownMenuItem(value: vehicle.id, child: Text(vehicle.name)),
            ],
            onChanged: (value) => setState(() => _vehicleId = value),
          ),
        ),
        _FilterSection(
          title: '维修状态',
          child: _ChoiceDropdown<VehicleRepairStatus?>(
            value: _status,
            allLabel: '全部状态',
            entries: {
              for (final value in VehicleRepairStatus.values)
                value: RepairOptions.statusLabel(value),
            },
            onChanged: (value) => setState(() => _status = value),
          ),
        ),
        _FilterSection(
          title: '三联票',
          child: _ChoiceDropdown<RepairTicketStatus?>(
            value: _ticket,
            allLabel: '全部票据',
            entries: {
              for (final value in RepairTicketStatus.values)
                value: RepairOptions.ticketStatusLabel(value),
            },
            onChanged: (value) => setState(() => _ticket = value),
          ),
        ),
        _FilterSection(
          title: '结算',
          child: _BoolChoice(
            completedLabel: '结算',
            value: _settled,
            onChanged: (v) => setState(() => _settled = v),
          ),
        ),
        _FilterSection(
          title: '结账',
          child: _BoolChoice(
            completedLabel: '结账',
            value: _paid,
            onChanged: (v) => setState(() => _paid = v),
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _RepairFilterValues(
            vehicleId: _vehicleId,
            status: _status,
            ticket: _ticket,
            settled: _settled,
            paid: _paid,
          ),
        ),
        child: const Text('应用筛选'),
      ),
    ),
  );
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        child,
      ],
    ),
  );
}

class _ChoiceDropdown<T> extends StatelessWidget {
  const _ChoiceDropdown({
    required this.value,
    required this.allLabel,
    required this.entries,
    required this.onChanged,
  });
  final T? value;
  final String allLabel;
  final Map<T, String> entries;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T?>(
    key: ValueKey('$allLabel-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(isDense: true),
    items: [
      DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
      for (final entry in entries.entries)
        DropdownMenuItem<T?>(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: onChanged,
  );
}

class _BoolChoice extends StatelessWidget {
  const _BoolChoice({
    required this.completedLabel,
    required this.value,
    required this.onChanged,
  });
  final String completedLabel;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool?>(
    segments: [
      const ButtonSegment(value: null, label: Text('全部')),
      ButtonSegment(value: true, label: Text('已$completedLabel')),
      ButtonSegment(value: false, label: Text('未$completedLabel')),
    ],
    selected: {value},
    showSelectedIcon: false,
    onSelectionChanged: (selection) => onChanged(selection.first),
  );
}

class _RepairOrderCard extends StatelessWidget {
  const _RepairOrderCard({
    required this.number,
    required this.order,
    this.vehicle,
    this.onTap,
  });

  final int number;
  final RepairOrder order;
  final Vehicle? vehicle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = (order.cause?.trim().isNotEmpty ?? false)
        ? order.cause!.trim()
        : order.symptom;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.divider.withValues(alpha: .75)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$number',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vehicle?.name ?? '车辆已删除',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _money(order.actualAmountCents),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.techBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '实际金额',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                '故障原因',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _RepairTag(
                    label: RepairOptions.statusLabel(order.status),
                    icon: Icons.build_outlined,
                    emphasized: true,
                  ),
                  _RepairTag(
                    label:
                        '三联票 ${RepairOptions.ticketStatusLabel(order.ticketStatus)}',
                    icon: Icons.confirmation_number_outlined,
                  ),
                  _RepairTag(
                    label: order.isSettled ? '已结算' : '未结算',
                    icon: Icons.task_alt_outlined,
                    emphasized: order.isSettled,
                  ),
                  _RepairTag(
                    label: order.isPaid ? '已结账' : '未结账',
                    icon: Icons.payments_outlined,
                    emphasized: order.isPaid,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              LayoutBuilder(
                builder: (context, constraints) {
                  final date = Text(
                    AppDateUtils.formatDate(order.reportDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                  final reported = Text(
                    '申报 ${_money(order.reportedAmountCents)}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.body,
                    ),
                  );
                  if (constraints.maxWidth < 220) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        date,
                        Align(
                          alignment: Alignment.centerRight,
                          child: reported,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: date),
                      const SizedBox(width: 12),
                      reported,
                    ],
                  );
                },
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Text(
                    '维修供应商',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.techBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      (order.vendor?.trim().isNotEmpty ?? false)
                          ? order.vendor!.trim()
                          : '未填写',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.ink,
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

  String _money(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';
}

class _RepairTag extends StatelessWidget {
  const _RepairTag({
    required this.label,
    required this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? AppColors.ink : AppColors.body;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.lightGreen : AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: emphasized ? AppColors.lightGreen : AppColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
