import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../application/vehicle_providers.dart';
import '../domain/repair_options.dart';

class VehicleRepairFormPage extends ConsumerStatefulWidget {
  const VehicleRepairFormPage({required this.vehicleId, super.key});

  final int vehicleId;

  @override
  ConsumerState<VehicleRepairFormPage> createState() =>
      _VehicleRepairFormPageState();
}

class _VehicleRepairFormPageState extends ConsumerState<VehicleRepairFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _symptomController = TextEditingController();
  final _causeController = TextEditingController();
  final _projectController = TextEditingController();
  final _vendorController = TextEditingController();
  final _managerController = TextEditingController();
  final _remarkController = TextEditingController();
  final _reportedAmountController = TextEditingController(text: '0');
  final List<_CostLineState> _costLines = [_CostLineState()];
  DateTime _reportDate = DateTime.now();
  DateTime _faultFoundAt = DateTime.now();
  VehicleRepairStatus _status = VehicleRepairStatus.reported;
  RepairTicketStatus _ticketStatus = RepairTicketStatus.notRequired;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _symptomController,
      _causeController,
      _projectController,
      _vendorController,
      _managerController,
      _remarkController,
      _reportedAmountController,
    ]) {
      controller.dispose();
    }
    for (final line in _costLines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建报修/维修单')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _section('故障信息', Icons.warning_amber_outlined, [
              TextFormField(
                controller: _symptomController,
                decoration: const InputDecoration(labelText: '故障现象 *'),
                maxLines: 2,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请填写故障现象' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dateField(
                      context,
                      '报修日期',
                      _reportDate,
                      (value) => setState(() => _reportDate = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateField(
                      context,
                      '发现日期',
                      _faultFoundAt,
                      (value) => setState(() => _faultFoundAt = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _causeController,
                decoration: const InputDecoration(labelText: '故障原因'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _projectController,
                decoration: const InputDecoration(labelText: '维修项目'),
              ),
            ]),
            const SizedBox(height: 14),
            _section('维修安排', Icons.handyman_outlined, [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vendorController,
                      decoration: const InputDecoration(labelText: '维修地点/供应商'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _managerController,
                      decoration: const InputDecoration(labelText: '维修负责人'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<VehicleRepairStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: '维修状态'),
                items: [
                  for (final value in VehicleRepairStatus.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(RepairOptions.statusLabel(value)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RepairTicketStatus>(
                initialValue: _ticketStatus,
                decoration: const InputDecoration(labelText: '三联票状态'),
                items: [
                  for (final value in RepairTicketStatus.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(RepairOptions.ticketStatusLabel(value)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _ticketStatus = value ?? _ticketStatus),
              ),
            ]),
            const SizedBox(height: 14),
            _section('费用明细', Icons.receipt_long_outlined, [
              for (var index = 0; index < _costLines.length; index++)
                _CostLineEditor(
                  key: ObjectKey(_costLines[index]),
                  line: _costLines[index],
                  index: index,
                  canRemove: _costLines.length > 1,
                  onRemove: () => setState(() {
                    _costLines.removeAt(index).dispose();
                  }),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _costLines.add(_CostLineState())),
                  icon: const Icon(Icons.add),
                  label: const Text('添加费用明细'),
                ),
              ),
              TextFormField(
                controller: _reportedAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '申报金额（元）'),
              ),
            ]),
            const SizedBox(height: 14),
            _section('补充信息', Icons.notes_outlined, [
              TextFormField(
                controller: _remarkController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '备注'),
              ),
            ]),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '保存中...' : '保存维修单'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );

  Widget _dateField(
    BuildContext context,
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(AppDateUtils.formatDate(value)),
    trailing: IconButton(
      icon: const Icon(Icons.calendar_month_outlined),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDate: value,
        );
        if (picked != null) onChanged(picked);
      },
    ),
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final costs = <RepairCostDraft>[];
    for (final line in _costLines) {
      final quantity = double.tryParse(line.quantity.text.trim());
      final unitPrice = double.tryParse(line.unitPrice.text.trim());
      if (line.content.text.trim().isEmpty ||
          quantity == null ||
          quantity <= 0 ||
          unitPrice == null ||
          unitPrice < 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请完整填写费用明细')));
        return;
      }
      costs.add(
        RepairCostDraft(
          content: line.content.text,
          quantity: quantity,
          unit: line.unit.text,
          unitPriceCents: (unitPrice * 100).round(),
          costType: line.costType,
        ),
      );
    }
    final reported =
        double.tryParse(_reportedAmountController.text.trim()) ?? 0;
    if (reported < 0) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(repairRepositoryProvider)
          .save(
            draft: RepairOrderDraft(
              vehicleId: widget.vehicleId,
              reportDate: _reportDate,
              faultFoundAt: _faultFoundAt,
              symptom: _symptomController.text,
              cause: _causeController.text,
              project: _projectController.text,
              vendor: _vendorController.text,
              manager: _managerController.text,
              reportedAmountCents: (reported * 100).round(),
              ticketStatus: _ticketStatus,
              status: _status,
              remark: _remarkController.text,
              costs: costs,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CostLineState {
  final content = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unit = TextEditingController(text: '项');
  final unitPrice = TextEditingController(text: '0');
  RepairCostType costType = RepairCostType.other;

  void dispose() {
    content.dispose();
    quantity.dispose();
    unit.dispose();
    unitPrice.dispose();
  }
}

class _CostLineEditor extends StatefulWidget {
  const _CostLineEditor({
    required this.line,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    super.key,
  });

  final _CostLineState line;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  State<_CostLineEditor> createState() => _CostLineEditorState();
}

class _CostLineEditorState extends State<_CostLineEditor> {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.line.content,
                decoration: InputDecoration(
                  labelText: '项目 ${widget.index + 1}',
                ),
              ),
            ),
            IconButton(
              onPressed: widget.canRemove ? widget.onRemove : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.line.quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '数量'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.line.unit,
                decoration: const InputDecoration(labelText: '单位'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.line.unitPrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '单价/元'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RepairCostType>(
          initialValue: widget.line.costType,
          decoration: const InputDecoration(labelText: '费用类型'),
          items: [
            for (final value in RepairCostType.values)
              DropdownMenuItem(
                value: value,
                child: Text(RepairOptions.costTypeLabel(value)),
              ),
          ],
          onChanged: (value) => setState(
            () => widget.line.costType = value ?? widget.line.costType,
          ),
        ),
      ],
    ),
  );
}
