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
  DateTime? _month;
  _RepairSort _sort = _RepairSort.newest;

  int get _activeFilterCount => [
    _vehicleId,
    _status,
    _ticket,
    _settled,
    _paid,
    _month,
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
      month: _month,
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
        _month = applied.month;
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
              if (_month != null &&
                  (o.reportDate.year != _month!.year ||
                      o.reportDate.month != _month!.month)) {
                return false;
              }
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
            switch (_sort) {
              case _RepairSort.newest:
                shown.sort((a, b) => b.reportDate.compareTo(a.reportDate));
              case _RepairSort.oldest:
                shown.sort((a, b) => a.reportDate.compareTo(b.reportDate));
              case _RepairSort.amountHigh:
                shown.sort(
                  (a, b) => b.actualAmountCents.compareTo(a.actualAmountCents),
                );
              case _RepairSort.amountLow:
                shown.sort(
                  (a, b) => a.actualAmountCents.compareTo(b.actualAmountCents),
                );
            }
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
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final status in <VehicleRepairStatus?>[
                          null,
                          VehicleRepairStatus.reported,
                          VehicleRepairStatus.repairing,
                          VehicleRepairStatus.completed,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                '${status == null ? '全部' : RepairOptions.statusLabel(status)} ${status == null ? items.length : items.where((order) => order.status == status).length}单',
                              ),
                              selected: _status == status,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _status = status),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.lightBlue,
                              labelStyle: TextStyle(
                                color: _status == status
                                    ? Colors.white
                                    : AppColors.body,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide.none,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('repair-filter-vehicle-$_vehicleId'),
                          initialValue: _vehicleId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: '车辆'),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('全部'),
                            ),
                            for (final vehicle in vehicleItems)
                              DropdownMenuItem(
                                value: vehicle.id,
                                child: Text(
                                  vehicle.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _vehicleId = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _FilterButton(
                        count: _activeFilterCount,
                        onPressed: () => _openFilters(vehicleItems),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                  child: Row(
                    children: [
                      Text(
                        '共 ${shown.length} 单',
                        style: const TextStyle(
                          color: AppColors.body,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<_RepairSort>(
                        tooltip: '排序维修单',
                        onSelected: (sort) => setState(() => _sort = sort),
                        itemBuilder: (context) => [
                          for (final sort in _RepairSort.values)
                            CheckedPopupMenuItem(
                              value: sort,
                              checked: _sort == sort,
                              child: Text(sort.label),
                            ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.swap_vert,
                              size: 16,
                              color: AppColors.body,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sort.label,
                              style: const TextStyle(
                                color: AppColors.body,
                                fontSize: 12,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: AppColors.body,
                            ),
                          ],
                        ),
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
                fontSize: 13,
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
    this.month,
  });

  final int? vehicleId;
  final VehicleRepairStatus? status;
  final RepairTicketStatus? ticket;
  final bool? settled;
  final bool? paid;
  final DateTime? month;

  int get activeCount => [
    vehicleId,
    status,
    ticket,
    settled,
    paid,
    month,
  ].where((v) => v != null).length;

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
  late DateTime? _month = widget.initial.month;

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
            _month = null;
          }),
          child: const Text('重置'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _FilterSection(
          title: '维修月份',
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _month == null ? '全部月份' : '${_month!.year}年${_month!.month}月',
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _month ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                helpText: '选择月份中的任意日期',
              );
              if (picked != null) {
                setState(() => _month = DateTime(picked.year, picked.month));
              }
            },
          ),
        ),
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
            month: _month,
          ),
        ),
        child: const Text('应用筛选'),
      ),
    ),
  );
}

enum _RepairSort {
  newest('最新日期'),
  oldest('最早日期'),
  amountHigh('金额从高到低'),
  amountLow('金额从低到高');

  const _RepairSort(this.label);
  final String label;
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
    final statusColor = switch (order.status) {
      VehicleRepairStatus.completed => AppColors.success,
      VehicleRepairStatus.repairing => AppColors.primary,
      VehicleRepairStatus.cancelled => AppColors.body,
      _ => AppColors.warning,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_shipping,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.repairNo,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${vehicle?.licensePlate ?? vehicle?.vehicleNo ?? ''} · ${vehicle?.name ?? '车辆已删除'}',
                          style: const TextStyle(
                            color: AppColors.body,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      RepairOptions.statusLabel(order.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.helper,
                  ),
                ],
              ),
              const Divider(height: 20),
              _recordField('故障内容', order.symptom),
              if (order.cause?.trim().isNotEmpty == true)
                _recordField('故障原因', order.cause!),
              _recordField('报修时间', AppDateUtils.formatDate(order.reportDate)),
              _recordField(
                '维修厂商',
                order.vendor?.trim().isNotEmpty == true ? order.vendor! : '未填写',
              ),
              _recordField('申报金额', _money(order.reportedAmountCents)),
              _recordField('实际金额', _money(order.actualAmountCents)),
              if (order.manager?.trim().isNotEmpty == true)
                _recordField('维修负责人', order.manager!),
              if (order.project?.trim().isNotEmpty == true)
                _recordField('维修项目', order.project!),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _RepairTag(
                    label:
                        '三联票 ${RepairOptions.ticketStatusLabel(order.ticketStatus)}',
                    icon: Icons.description_outlined,
                    emphasized: order.ticketStatus == RepairTicketStatus.issued,
                  ),
                  _RepairTag(
                    label: order.isSettled ? '已结算' : '未结算',
                    icon: Icons.payments_outlined,
                    emphasized: order.isSettled,
                  ),
                  _RepairTag(
                    label: order.isPaid ? '已结账' : '未结账',
                    icon: Icons.receipt_long_outlined,
                    emphasized: order.isPaid,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordField(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.body, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.ink, fontSize: 14),
          ),
        ),
      ],
    ),
  );

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
    final color = emphasized
        ? AppColors.success
        : label.startsWith('三联票')
        ? AppColors.danger
        : label == '未结算'
        ? Colors.orange
        : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}
