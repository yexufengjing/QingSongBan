import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../application/vehicle_providers.dart';
import '../domain/repair_options.dart';

class VehicleRepairDetailPage extends ConsumerStatefulWidget {
  const VehicleRepairDetailPage({required this.repairOrderId, super.key});
  final int repairOrderId;

  @override
  ConsumerState<VehicleRepairDetailPage> createState() =>
      _VehicleRepairDetailPageState();
}

class _VehicleRepairDetailPageState
    extends ConsumerState<VehicleRepairDetailPage> {
  late Future<_RepairDetails?> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _read();
  }

  Future<_RepairDetails?> _read() async {
    final repo = ref.read(repairRepositoryProvider);
    final order = await repo.findById(widget.repairOrderId);
    if (order == null) return null;
    final vehicle = await ref
        .read(vehicleRepositoryProvider)
        .findById(order.vehicleId);
    return _RepairDetails(
      order,
      vehicle,
      await repo.listCosts(order.id),
      await repo.listParts(order.id),
    );
  }

  Future<void> _change({
    VehicleRepairStatus? status,
    RepairTicketStatus? ticket,
    bool? settled,
    bool? paid,
  }) async {
    await ref
        .read(repairRepositoryProvider)
        .updateMarkers(
          id: widget.repairOrderId,
          status: status,
          ticketStatus: ticket,
          isSettled: settled,
          isPaid: paid,
        );
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('维修单详情'),
      actions: [
        IconButton(
          tooltip: '编辑维修单',
          onPressed: () async {
            final value = await context.push<bool>(
              '/vehicles/repairs/${widget.repairOrderId}/edit',
            );
            if (value == true && mounted) setState(_load);
          },
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: FutureBuilder<_RepairDetails?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snapshot.data;
        if (d == null) return const Center(child: Text('维修单不存在或已删除'));
        final order = d.order;
        final vehicleName = d.vehicle?.name ?? '车辆已删除';
        final vehicleId = d.vehicle?.licensePlate ?? d.vehicle?.vehicleNo ?? '';
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _summary(
              context,
              order: order,
              vehicleName: vehicleName,
              vehicleId: vehicleId,
            ),
            const SizedBox(height: 12),
            _statusControls(context, order),
            if (order.isPaid && !order.isSettled) ...[
              const SizedBox(height: 8),
              const _StatusNotice(
                icon: Icons.warning_amber_rounded,
                message: '此维修单已结账但未结算，请核对金额。',
                warning: true,
              ),
            ],
            const SizedBox(height: 16),
            Text('维修资料', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            _InfoGroup(
              fields: [
                _InfoField(
                  '故障发现日期',
                  AppDateUtils.formatDate(order.faultFoundAt),
                ),
                if (_hasText(order.cause)) _InfoField('故障原因', order.cause!),
                if (_hasText(order.project)) _InfoField('维修项目', order.project!),
                if (_hasText(order.vendor))
                  _InfoField('维修地点/供应商', order.vendor!),
                if (_hasText(order.manager))
                  _InfoField('维修负责人', order.manager!),
                if (_hasText(order.remark)) _InfoField('备注', order.remark!),
              ],
            ),
            if (_hasText(order.recordText))
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: const Text('维修记录'),
                  subtitle: const Text('查看完整记录'),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        order.recordText!,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            if (d.costs.isNotEmpty) ...[
              const SizedBox(height: 20),
              _costSection(context, d.costs),
            ],
            if (d.parts.isNotEmpty) ...[
              const SizedBox(height: 20),
              _partsSection(context, d.parts),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: d.vehicle == null
                  ? null
                  : () => context.push(
                      '/vehicles/${d.vehicle!.id}/attachments?repairOrderId=${order.id}',
                    ),
              icon: const Icon(Icons.attach_file),
              label: const Text('查看或添加维修附件'),
            ),
          ],
        );
      },
    ),
  );

  Widget _summary(
    BuildContext context, {
    required RepairOrder order,
    required String vehicleName,
    required String vehicleId,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  vehicleName,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (vehicleId.isNotEmpty)
                Text(vehicleId, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 14),
          Text('故障现象', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(
            order.symptom,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('实际金额', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      _money(order.actualAmountCents),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              Text(
                '申报 ${_money(order.reportedAmountCents)}',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatusTag(
                icon: Icons.build_outlined,
                label: RepairOptions.statusLabel(order.status),
                active: order.status == VehicleRepairStatus.completed,
              ),
              _StatusTag(
                icon: Icons.confirmation_number_outlined,
                label:
                    '三联票 ${RepairOptions.ticketStatusLabel(order.ticketStatus)}',
              ),
              _StatusTag(
                icon: Icons.task_alt_outlined,
                label: order.isSettled ? '已结算' : '未结算',
                active: order.isSettled,
              ),
              _StatusTag(
                icon: Icons.payments_outlined,
                label: order.isPaid ? '已结账' : '未结账',
                active: order.isPaid,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.repairNo}  ·  ${AppDateUtils.formatDate(order.reportDate)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.body),
          ),
        ],
      ),
    ),
  );

  Widget _statusControls(BuildContext context, RepairOrder order) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('更新业务状态', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _LabeledDropdown<VehicleRepairStatus>(
            label: '维修进度',
            key: ValueKey(order.status),
            value: order.status,
            items: [
              for (final value in VehicleRepairStatus.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(RepairOptions.statusLabel(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) _change(status: value);
            },
          ),
          const SizedBox(height: 10),
          _LabeledDropdown<RepairTicketStatus>(
            label: '三联票据',
            key: ValueKey(order.ticketStatus),
            value: order.ticketStatus,
            items: [
              for (final value in RepairTicketStatus.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(RepairOptions.ticketStatusLabel(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) _change(ticket: value);
            },
          ),
          const SizedBox(height: 6),
          _MarkerSwitch(
            title: '结算',
            value: order.isSettled,
            date: order.settledAt,
            onChanged: (value) => _change(settled: value),
          ),
          _MarkerSwitch(
            title: '结账',
            value: order.isPaid,
            date: order.paidAt,
            onChanged: (value) => _change(paid: value),
          ),
        ],
      ),
    ),
  );

  Widget _costSection(BuildContext context, List<RepairCostItem> costs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('费用明细', style: Theme.of(context).textTheme.titleMedium),
            for (final item in costs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item.content}  ${item.quantity}${item.unit}'),
                subtitle: Text(
                  '${RepairOptions.costTypeLabel(item.costType)} · 单价 ${_money(item.unitPriceCents)}',
                ),
                trailing: Text(_money(item.subtotalCents)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _partsSection(BuildContext context, List<RepairPart> parts) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('备件', style: Theme.of(context).textTheme.titleMedium),
          for (final part in parts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${part.name}  ${part.quantity}${part.unit}'),
              subtitle: Text(
                [part.componentType, part.remark]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
              ),
              trailing: Text(_money(part.amountCents)),
            ),
        ],
      ),
    ),
  );

  bool _hasText(String? value) => value?.trim().isNotEmpty == true;

  String _money(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
        ),
      ),
      DropdownButtonFormField<T>(
        initialValue: value,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items,
        onChanged: onChanged,
      ),
    ],
  );
}

class _MarkerSwitch extends StatelessWidget {
  const _MarkerSwitch({
    required this.title,
    required this.value,
    required this.date,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final DateTime? date;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            Text(
              date == null
                  ? (value ? '已标记完成' : '尚未完成')
                  : '完成于 ${AppDateUtils.formatDate(date!)}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.body),
            ),
          ],
        ),
      ),
      Text(value ? '已$title' : '未$title'),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.ink : AppColors.body;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.lightGreen : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.lightGreen : AppColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({
    required this.icon,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: warning ? AppColors.lightOrange : AppColors.lightBlue,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: warning ? Colors.deepOrange : AppColors.techBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: const TextStyle(color: AppColors.ink)),
        ),
      ],
    ),
  );
}

class _InfoField {
  const _InfoField(this.label, this.value);
  final String label;
  final String value;
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.fields});
  final List<_InfoField> fields;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          for (var index = 0; index < fields.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _InfoRow(label: fields[index].label, value: fields[index].value),
          ],
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.body),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _RepairDetails {
  const _RepairDetails(this.order, this.vehicle, this.costs, this.parts);
  final RepairOrder order;
  final Vehicle? vehicle;
  final List<RepairCostItem> costs;
  final List<RepairPart> parts;
}
