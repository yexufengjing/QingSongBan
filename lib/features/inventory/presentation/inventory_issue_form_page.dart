import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';

import '../../../core/database/app_database.dart';
import '../../personnel/application/personnel_providers.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_widgets.dart';

class InventoryIssueFormPage extends ConsumerStatefulWidget {
  const InventoryIssueFormPage({super.key});

  @override
  ConsumerState<InventoryIssueFormPage> createState() =>
      _InventoryIssueFormPageState();
}

class _InventoryIssueFormPageState
    extends ConsumerState<InventoryIssueFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _manualReceiver = TextEditingController();
  final _purpose = TextEditingController();
  final _operator = TextEditingController();
  final _remark = TextEditingController();
  final List<_IssueLineState> _lines = [_IssueLineState()];
  DateTime _date = DateTime.now();
  String _issueType = 'employee_claim';
  String _receiverType = 'employee';
  int? _employeeId;
  bool _saving = false;

  @override
  void dispose() {
    _manualReceiver.dispose();
    _purpose.dispose();
    _operator.dispose();
    _remark.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save(
    List<InventoryMaterial> materials,
    List<Employee> people,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    if (_receiverType == 'employee' && _employeeId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请选择领取员工')));
      return;
    }
    final lines = <InventoryIssueLineDraft>[];
    for (final line in _lines) {
      final id = line.materialId;
      final quantity = double.tryParse(line.quantity.text.trim());
      if (id == null || quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请选择物资并填写大于 0 的数量')));
        return;
      }
      lines.add(
        InventoryIssueLineDraft(
          materialId: id,
          quantity: quantity,
          remark: line.remark.text.trim().isEmpty
              ? null
              : line.remark.text.trim(),
        ),
      );
    }
    Employee? employee;
    for (final person in people) {
      if (person.id == _employeeId) {
        employee = person;
        break;
      }
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(inventoryServiceProvider)
          .createIssue(
            InventoryIssueDraft(
              issueDate: _date,
              issueType: _issueType,
              receiverType: _receiverType,
              employeeId: employee?.id,
              employeeName: employee?.name,
              departmentName: employee?.team ?? employee?.workArea,
              manualReceiverName: _receiverType == 'public'
                  ? null
                  : (_manualReceiver.text.trim().isEmpty
                        ? null
                        : _manualReceiver.text.trim()),
              purpose: _purpose.text.trim().isEmpty
                  ? null
                  : _purpose.text.trim(),
              operatorName: _operator.text.trim().isEmpty
                  ? null
                  : _operator.text.trim(),
              remark: _remark.text.trim().isEmpty ? null : _remark.text.trim(),
              items: lines,
            ),
          );
      _invalidateLists();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('出库已保存，库存和流水已更新')));
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('出库失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _invalidateLists() {
    ref.invalidate(inventoryOverviewProvider);
    ref.invalidate(inventoryStockProvider);
    ref.invalidate(inventoryMaterialsProvider);
    ref.invalidate(inventoryWarningsProvider);
    ref.invalidate(inventoryIssuesProvider);
    ref.invalidate(inventoryTransactionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final materials = ref.watch(inventoryMaterialsProvider);
    final personnel = ref.watch(allPersonnelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('领用出库')),
      bottomNavigationBar:
          materials.valueOrNull?.isNotEmpty == true && personnel.hasValue
          ? InventoryFormFooter(
              label: '确认出库',
              icon: Icons.outbox_outlined,
              saving: _saving,
              buttonKey: const Key('inventory-issue-submit'),
              onSave: () =>
                  _save(materials.valueOrNull!, personnel.valueOrNull!),
            )
          : null,
      body: materials.when(
        loading: () => const InventoryLoadingState(),
        error: (_, _) => InventoryErrorState(
          onRetry: () => ref.invalidate(inventoryMaterialsProvider),
        ),
        data: (items) => personnel.when(
          loading: () => const InventoryLoadingState(),
          error: (_, _) => InventoryErrorState(
            onRetry: () => ref.invalidate(allPersonnelProvider),
          ),
          data: (people) => items.isEmpty
              ? InventoryEmptyState(
                  title: '先新增物资档案',
                  message: '出库单需要关联已有物资。',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/inventory/materials/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('新增物资'),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.calendar_month_outlined,
                                ),
                                title: const Text('领取日期'),
                                subtitle: Text(_dateLabel(_date)),
                                trailing: const Icon(
                                  Icons.edit_calendar_outlined,
                                ),
                                onTap: _pickDate,
                              ),
                              DropdownButtonFormField<String>(
                                key: const Key('inventory-issue-type'),
                                initialValue: _issueType,
                                decoration: const InputDecoration(
                                  labelText: '出库类型',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'employee_claim',
                                    child: Text('员工领取'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'department_public',
                                    child: Text('部门/公用领取'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'transfer_out',
                                    child: Text('调拨出库'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'other',
                                    child: Text('其他出库'),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _issueType = value ?? _issueType,
                                ),
                              ),
                              DropdownButtonFormField<String>(
                                initialValue: _receiverType,
                                key: const Key('inventory-receiver-type'),
                                decoration: const InputDecoration(
                                  labelText: '领取对象类型',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'employee',
                                    child: Text('员工领取'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'manual',
                                    child: Text('手工填写领取人'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'department',
                                    child: Text('部门/公用领取'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'public',
                                    child: Text('公用物资'),
                                  ),
                                ],
                                onChanged: (value) => setState(() {
                                  _receiverType = value ?? 'employee';
                                  _employeeId = null;
                                }),
                              ),
                              if (_receiverType == 'employee')
                                DropdownButtonFormField<int>(
                                  key: const Key('inventory-employee-select'),
                                  initialValue: _employeeId,
                                  decoration: const InputDecoration(
                                    labelText: '领取人（可搜索人员档案）',
                                  ),
                                  items: [
                                    for (final person in people.where(
                                      (person) => !person.isDeleted,
                                    ))
                                      DropdownMenuItem(
                                        value: person.id,
                                        child: Text(
                                          '${person.name} · ${person.team ?? person.workArea ?? '未填写单位'}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _employeeId = value),
                                  validator: (value) =>
                                      value == null ? '请选择领取人' : null,
                                ),
                              if (_receiverType == 'manual' ||
                                  _receiverType == 'department')
                                TextFormField(
                                  key: const Key('inventory-manual-receiver'),
                                  controller: _manualReceiver,
                                  decoration: InputDecoration(
                                    labelText: _receiverType == 'department'
                                        ? '部门或领取对象'
                                        : '领取人姓名',
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? '请填写领取人或领取对象'
                                      : null,
                                ),
                              TextFormField(
                                controller: _purpose,
                                decoration: const InputDecoration(
                                  labelText: '用途（可选）',
                                ),
                              ),
                              TextFormField(
                                controller: _operator,
                                decoration: const InputDecoration(
                                  labelText: '经办人（可选）',
                                ),
                              ),
                              TextFormField(
                                controller: _remark,
                                decoration: const InputDecoration(
                                  labelText: '备注（可选）',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InventorySection(
                        title: '领用明细',
                        icon: Icons.list_alt_outlined,
                        trailing: IconButton(
                          tooltip: '添加明细',
                          onPressed: () =>
                              setState(() => _lines.add(_IssueLineState())),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        child: Column(
                          children: [
                            for (var index = 0; index < _lines.length; index++)
                              _IssueLineEditor(
                                key: ValueKey(_lines[index]),
                                state: _lines[index],
                                materials: items,
                                onRemove: _lines.length == 1
                                    ? null
                                    : () => setState(
                                        () => _lines.removeAt(index).dispose(),
                                      ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _IssueLineState {
  int? materialId;
  final quantity = TextEditingController();
  final remark = TextEditingController();
  void dispose() {
    quantity.dispose();
    remark.dispose();
  }
}

class _IssueLineEditor extends StatefulWidget {
  const _IssueLineEditor({
    required this.state,
    required this.materials,
    this.onRemove,
    super.key,
  });
  final _IssueLineState state;
  final List<InventoryMaterial> materials;
  final VoidCallback? onRemove;

  @override
  State<_IssueLineEditor> createState() => _IssueLineEditorState();
}

class _IssueLineEditorState extends State<_IssueLineEditor> {
  @override
  Widget build(BuildContext context) {
    final material = widget.materials
        .where((item) => item.id == widget.state.materialId)
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: widget.state.materialId,
                    decoration: const InputDecoration(labelText: '物资'),
                    items: [
                      for (final material in widget.materials)
                        DropdownMenuItem(
                          value: material.id,
                          child: Text(
                            material.materialName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => widget.state.materialId = value),
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    tooltip: '移除明细',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '规格',
                fillColor: AppColors.lightBlue,
              ),
              child: Text(material?.modelSpec ?? '选择物资后显示规格'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('inventory-issue-quantity'),
              controller: widget.state.quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                suffixText: material?.unitName,
                labelText: '领取数量',
                hintText: '大于 0',
              ),
              validator: (value) {
                final quantity = double.tryParse(value ?? '');
                return quantity == null || quantity <= 0 ? '请输入大于 0 的数量' : null;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.state.remark,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '明细备注（可选）'),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value) =>
    '${value.year}年${value.month.toString().padLeft(2, '0')}月${value.day.toString().padLeft(2, '0')}日';
