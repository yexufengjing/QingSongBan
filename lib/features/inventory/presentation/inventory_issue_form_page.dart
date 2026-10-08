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
      appBar: AppBar(title: const Text('领用登记'), centerTitle: false),
      bottomNavigationBar:
          materials.valueOrNull?.isNotEmpty == true && personnel.hasValue
          ? InventoryFormFooter(
              label: '登记',
              icon: Icons.outbox_outlined,
              subtitle: '保存领用记录并更新库存',
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
                    key: const Key('inventory-issue-form-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                        child: Text(
                          '共用信息与物资明细',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.body),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_add_alt_1_outlined,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      '共用信息',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _IssueFieldRow(
                                label: '领取日期',
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 0,
                                    ),
                                    suffixIcon: Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: _pickDate,
                                    child: SizedBox(
                                      height: 48,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                            color: AppColors.ink,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _IssueFieldRow(
                                label: '出库类型',
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  key: const Key('inventory-issue-type'),
                                  initialValue: _issueType,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    constraints: BoxConstraints(minHeight: 48),
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.ink,
                                      ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'employee_claim',
                                      child: Text('员工领取'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'department_use',
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
                              ),
                              _IssueFieldRow(
                                label: '领取对象类型',
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _receiverType,
                                  key: const Key('inventory-receiver-type'),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    constraints: BoxConstraints(minHeight: 48),
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.ink,
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
                              ),
                              if (_receiverType == 'employee')
                                _IssueFieldRow(
                                  label: '领取人',
                                  child: FormField<int>(
                                    key: const Key('inventory-employee-select'),
                                    initialValue: _employeeId,
                                    validator: (value) =>
                                        value == null ? '请选择领取人' : null,
                                    builder: (field) {
                                      final selected = people
                                          .where(
                                            (person) =>
                                                person.id == field.value,
                                          )
                                          .firstOrNull;
                                      return InputDecorator(
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 0,
                                              ),
                                          errorText: field.errorText,
                                          suffixIcon: const Icon(
                                            Icons.person_outline,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () async {
                                            final person =
                                                await _showSearchPicker<
                                                  Employee
                                                >(
                                                  context,
                                                  title: '选择领取人',
                                                  options: [
                                                    for (final item
                                                        in people.where(
                                                          (item) =>
                                                              !item.isDeleted,
                                                        ))
                                                      (
                                                        item,
                                                        '${item.name} · ${item.team ?? item.workArea ?? '未填写单位'}',
                                                      ),
                                                  ],
                                                );
                                            if (person != null && mounted) {
                                              field.didChange(person.id);
                                              setState(
                                                () => _employeeId = person.id,
                                              );
                                            }
                                          },
                                          child: SizedBox(
                                            height: 48,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                selected == null
                                                    ? '搜索并选择领取人'
                                                    : selected.name,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              if (_receiverType == 'manual' ||
                                  _receiverType == 'department')
                                _IssueFieldRow(
                                  label: _receiverType == 'department'
                                      ? '部门或领取对象'
                                      : '领取人姓名',
                                  child: TextFormField(
                                    key: const Key('inventory-manual-receiver'),
                                    controller: _manualReceiver,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 0,
                                      ),
                                      constraints: BoxConstraints(
                                        minHeight: 48,
                                      ),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? '请填写领取人或领取对象'
                                        : null,
                                  ),
                                ),
                              _IssueFieldRow(
                                label: '用途（可选）',
                                child: TextFormField(
                                  controller: _purpose,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 0,
                                    ),
                                    constraints: BoxConstraints(minHeight: 48),
                                  ),
                                ),
                              ),
                              _IssueFieldRow(
                                label: '经办人（可选）',
                                child: TextFormField(
                                  controller: _operator,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InventorySection(
                        title: '物资明细 · ${_lines.length}',
                        icon: Icons.inventory_2_outlined,
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
                      const SizedBox(height: 14),
                      _IssueFieldRow(
                        label: '公共备注',
                        child: TextField(
                          controller: _remark,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: '可选',
                            isDense: true,
                          ),
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
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _IssueFieldRow(
                    label: '物资名称',
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                      ),
                      child: InkWell(
                        key: const Key('inventory-issue-material-select'),
                        onTap: () async {
                          final selected =
                              await _showSearchPicker<InventoryMaterial>(
                                context,
                                title: '选择物资',
                                options: [
                                  for (final item in widget.materials)
                                    (
                                      item,
                                      '${item.materialName} · ${item.modelSpec ?? '未填写规格'} · ${item.unitName}',
                                    ),
                                ],
                              );
                          if (selected != null && mounted) {
                            setState(
                              () => widget.state.materialId = selected.id,
                            );
                          }
                        },
                        child: SizedBox(
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              material?.materialName ?? '搜索并选择物资',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
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
            _IssueFieldRow(
              label: '规格',
              child: InputDecorator(
                decoration: const InputDecoration(
                  isDense: true,
                  fillColor: AppColors.lightBlue,
                ),
                child: Text(material?.modelSpec ?? '选择物资后显示规格'),
              ),
            ),
            _IssueFieldRow(
              label: '当前库存',
              child: Text(
                material == null
                    ? '选择物资后显示库存'
                    : '${material.currentStock}${material.unitName}',
                style: const TextStyle(color: AppColors.body),
              ),
            ),
            const SizedBox(height: 12),
            _IssueFieldRow(
              label: '数量',
              child: TextFormField(
                key: const Key('inventory-issue-quantity'),
                controller: widget.state.quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  suffixText: material?.unitName,
                  hintText: '大于 0',
                  isDense: true,
                ),
                validator: (value) {
                  final quantity = double.tryParse(value ?? '');
                  return quantity == null || quantity <= 0
                      ? '请输入大于 0 的数量'
                      : null;
                },
              ),
            ),
            const SizedBox(height: 12),
            _IssueFieldRow(
              label: '明细备注',
              child: TextField(
                controller: widget.state.remark,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '可选',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueFieldRow extends StatelessWidget {
  const _IssueFieldRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              fontSize: label.contains('可选') ? 11 : 13,
              color: label.contains('可选') ? AppColors.body : AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    ),
  );
}

Future<T?> _showSearchPicker<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _SearchPickerSheet<T>(title: title, options: options),
);

class _SearchPickerSheet<T> extends StatefulWidget {
  const _SearchPickerSheet({required this.title, required this.options});

  final String title;
  final List<(T, String)> options;

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom - 24;
    final sheetHeight = availableHeight.clamp(220.0, media.size.height * 0.82);
    final query = _controller.text.trim().toLowerCase();
    final filtered = widget.options
        .where((entry) => entry.$2.toLowerCase().contains(query))
        .toList(growable: false);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '输入名称搜索',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('没有匹配项'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => ListTile(
                          title: Text(filtered[index].$2),
                          onTap: () =>
                              Navigator.pop(context, filtered[index].$1),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
