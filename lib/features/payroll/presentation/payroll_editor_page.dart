// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../personnel/application/personnel_providers.dart';
import '../../reminders/application/reminder_providers.dart';
import '../application/payroll_providers.dart';
import '../domain/payroll_calculator.dart';
import '../domain/payroll_options.dart';
import '../domain/payroll_models.dart';

class PayrollEditorPage extends ConsumerWidget {
  const PayrollEditorPage({required this.batchId, super.key});

  final int batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = ref.watch(payrollBatchProvider(batchId));
    final items = ref.watch(payrollItemsProvider(batchId));
    return SafeArea(
      child: batch.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('工资批次加载失败：$error')),
        data: (value) {
          if (value == null) return const Center(child: Text('工资批次不存在'));
          return _EditorContent(batch: value, items: items, ref: ref);
        },
      ),
    );
  }
}

class _EditorContent extends StatelessWidget {
  const _EditorContent({
    required this.batch,
    required this.items,
    required this.ref,
  });

  final PayrollBatche batch;
  final AsyncValue<List<PayrollItemWithEmployee>> items;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final editable =
        batch.status != PayrollStatus.confirmed &&
        batch.status != PayrollStatus.locked;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${PayrollOptions.statusLabel(batch.status)} · ${batch.employeeCount}人 · 最终 ${batch.finalWageTotal.toStringAsFixed(2)}元',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleAction(context, value),
                itemBuilder: (context) => [
                  if (editable)
                    const PopupMenuItem(
                      value: 'generate',
                      child: Text('重新生成名单'),
                    ),
                  if (editable)
                    const PopupMenuItem(value: 'sync', child: Text('同步最新考勤')),
                  if (editable)
                    const PopupMenuItem(value: 'check', child: Text('异常检查')),
                  if (batch.status == PayrollStatus.pendingReview ||
                      batch.status == PayrollStatus.draft)
                    const PopupMenuItem(value: 'confirm', child: Text('确认工资')),
                  if (batch.status == PayrollStatus.confirmed)
                    const PopupMenuItem(value: 'lock', child: Text('锁定工资')),
                  if (batch.status == PayrollStatus.confirmed ||
                      batch.status == PayrollStatus.locked)
                    const PopupMenuItem(
                      value: 'revoke',
                      child: Text('撤销确认 / 解锁'),
                    ),
                  if (batch.status == PayrollStatus.draft ||
                      batch.status == PayrollStatus.pendingReview)
                    const PopupMenuItem(value: 'delete', child: Text('删除工资草稿')),
                  const PopupMenuItem(
                    value: 'export',
                    child: Text('导出工资 Excel'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 18),
        Expanded(
          child: items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('工资明细加载失败：$error')),
            data: (values) => _ItemList(batch: batch, items: values, ref: ref),
          ),
        ),
        if (editable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _addEmployee(context),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('人工增加人员'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _handleAction(context, 'check'),
                  icon: const Icon(Icons.fact_check_outlined),
                  tooltip: '异常检查',
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final repo = ref.read(payrollRepositoryProvider);
    try {
      switch (action) {
        case 'generate':
          await repo.generateRoster(batch.id);
        case 'sync':
          await repo.syncAttendance(batch.id);
        case 'check':
          final result = await repo.validate(batch.id);
          await _showValidation(context, result);
        case 'confirm':
          final result = await repo.validate(batch.id);
          if (result.errors.isNotEmpty) {
            await _showValidation(context, result);
            return;
          }
          final reason = result.warnings.isEmpty
              ? null
              : await _askReason(context, '确认说明（存在警告）');
          if (result.warnings.isNotEmpty && reason == null) return;
          await repo.setStatus(
            batchId: batch.id,
            status: PayrollStatus.confirmed,
            reason: reason,
          );
        case 'lock':
          await repo.setStatus(batchId: batch.id, status: PayrollStatus.locked);
        case 'revoke':
          final reason = await _askReason(context, '撤销确认 / 解锁原因');
          if (reason == null) return;
          await repo.setStatus(
            batchId: batch.id,
            status: PayrollStatus.pendingReview,
            reason: reason,
          );
        case 'delete':
          final confirmed = await _confirmDelete(context);
          if (!confirmed) return;
          final reminder = await ref
              .read(reminderRepositoryProvider)
              .findBySource('payroll_batch', batch.id);
          if (reminder != null) {
            await ref.read(notificationServiceProvider).cancel(reminder.id);
          }
          await repo.deleteDraft(batch.id);
          if (context.mounted) context.pop();
          return;
        case 'export':
          if (context.mounted)
            context.push('/reports/payroll/export/${batch.id}');
          return;
      }
      await _syncReminderNotification(batch.id);
      ref.invalidate(payrollBatchProvider(batch.id));
      ref.invalidate(payrollItemsProvider(batch.id));
      ref.invalidate(payrollBatchesProvider);
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('操作已完成')));
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }

  Future<void> _syncReminderNotification(int batchId) async {
    final reminder = await ref
        .read(reminderRepositoryProvider)
        .findBySource('payroll_batch', batchId);
    if (reminder != null) {
      await ref.read(notificationServiceProvider).sync(reminder);
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除工资草稿？'),
        content: const Text('工资草稿会被软删除，之后重新进入该月份时可以恢复原批次。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _addEmployee(BuildContext context) async {
    final employees = await ref.read(allPersonnelProvider.future);
    if (!context.mounted) return;
    final selected = await showDialog<Employee>(
      context: context,
      builder: (context) => _EmployeePicker(employees: employees),
    );
    if (selected == null) return;
    try {
      await ref
          .read(payrollRepositoryProvider)
          .addEmployee(batchId: batch.id, employeeId: selected.id);
      ref.invalidate(payrollItemsProvider(batch.id));
      ref.invalidate(payrollBatchProvider(batch.id));
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('增加人员失败：$error')));
    }
  }

  Future<void> _showValidation(
    BuildContext context,
    PayrollValidationResult result,
  ) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.errors.isEmpty ? '异常检查' : '存在阻断问题'),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final issue in result.errors)
                ListTile(
                  leading: const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                  ),
                  title: Text(issue.message),
                  onTap: issue.employeeId == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          context.push(
                            '/personnel/${issue.employeeId}/payroll',
                          );
                        },
                ),
              for (final issue in result.warnings)
                ListTile(
                  leading: const Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.orange,
                  ),
                  title: Text(issue.message),
                  onTap: issue.employeeId == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          context.push(
                            '/personnel/${issue.employeeId}/payroll',
                          );
                        },
                ),
              if (result.errors.isEmpty && result.warnings.isEmpty)
                const ListTile(
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: AppColors.primary,
                  ),
                  title: Text('未发现异常'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askReason(BuildContext context, String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '原因'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.batch,
    required this.items,
    required this.ref,
  });

  final PayrollBatche batch;
  final List<PayrollItemWithEmployee> items;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const Center(child: Text('当前工资名单为空，请重新生成或人工增加人员'));
    final jobTypes =
        ref.watch(wageJobTypesProvider).valueOrNull ?? const <WageJobType>[];
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) async {
        final reordered = [...items];
        final moved = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, moved);
        await ref
            .read(payrollRepositoryProvider)
            .reorder(
              batchId: batch.id,
              itemIds: reordered.map((value) => value.item.id).toList(),
            );
        ref.invalidate(payrollItemsProvider(batch.id));
      },
      itemBuilder: (context, index) {
        final value = items[index];
        final item = value.item;
        final removed = item.isManuallyRemoved;
        return Card(
          key: ValueKey(item.id),
          color: removed ? Colors.grey.shade100 : null,
          child: ListTile(
            onTap: () => _edit(context, value, jobTypes),
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(
              '${item.employeeNameSnapshot} · ${item.employeeNoSnapshot}',
            ),
            subtitle: Text(
              '${item.jobTypeNameSnapshot ?? '未配置工种'} · ${_days(item.attendanceHalfDaysSnapshot)} · 日薪 ${item.dailyWage.toStringAsFixed(2)} · 实发 ${item.finalWage.toStringAsFixed(2)}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'detail') {
                  if (context.mounted)
                    context.push('/reports/payroll/item/${item.id}');
                } else {
                  await ref
                      .read(payrollRepositoryProvider)
                      .setItemRemoved(
                        itemId: item.id,
                        removed: action == 'remove',
                      );
                  ref.invalidate(payrollItemsProvider(batch.id));
                  ref.invalidate(payrollBatchProvider(batch.id));
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'detail', child: Text('查看明细')),
                PopupMenuItem(
                  value: removed ? 'restore' : 'remove',
                  child: Text(removed ? '恢复到工资名单' : '移出工资名单'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _edit(
    BuildContext context,
    PayrollItemWithEmployee value,
    List<WageJobType> jobTypes,
  ) async {
    final item = value.item;
    var selectedJobTypeId = item.jobTypeId;
    final daily = TextEditingController(
      text: item.dailyWage.toStringAsFixed(2),
    );
    final subsidy = TextEditingController(
      text: item.subsidy.toStringAsFixed(2),
    );
    final insurance = TextEditingController(
      text: item.insuranceDeduction.toStringAsFixed(2),
    );
    final remark = TextEditingController(text: item.remark ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final calculation = _tryCalculate(
            item,
            daily.text,
            subsidy.text,
            insurance.text,
          );
          return AlertDialog(
            title: Text('${item.employeeNameSnapshot} 工资明细'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _readOnly('出勤天数', _days(item.attendanceHalfDaysSnapshot)),
                  DropdownButtonFormField<int>(
                    initialValue:
                        jobTypes.any((type) => type.id == selectedJobTypeId)
                        ? selectedJobTypeId
                        : null,
                    decoration: const InputDecoration(labelText: '工种'),
                    items: [
                      for (final type in jobTypes.where(
                        (type) => type.isActive,
                      ))
                        DropdownMenuItem(
                          value: type.id,
                          child: Text(type.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => selectedJobTypeId = value),
                  ),
                  _field(daily, '日薪', onChanged: () => setState(() {})),
                  _readOnly(
                    '基础工资',
                    calculation?.baseWage.toStringAsFixed(2) ?? '输入有效金额',
                  ),
                  _field(subsidy, '补助', onChanged: () => setState(() {})),
                  _field(insurance, '保险扣除', onChanged: () => setState(() {})),
                  _readOnly(
                    '最终工资',
                    calculation?.finalWage.toStringAsFixed(2) ?? '输入有效金额',
                  ),
                  TextField(
                    controller: remark,
                    decoration: const InputDecoration(labelText: '备注'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: calculation == null
                    ? null
                    : () => Navigator.of(context).pop(true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true) {
      daily.dispose();
      subsidy.dispose();
      insurance.dispose();
      remark.dispose();
      return;
    }
    try {
      await ref
          .read(payrollRepositoryProvider)
          .updateItem(
            itemId: item.id,
            dailyWage: _parseMoney(daily.text),
            subsidy: _parseMoney(subsidy.text),
            insuranceDeduction: _parseMoney(insurance.text),
            jobTypeId: selectedJobTypeId,
            jobTypeNameSnapshot: selectedJobTypeId == null
                ? null
                : jobTypes
                      .firstWhere((type) => type.id == selectedJobTypeId)
                      .name,
            remark: remark.text,
          );
      ref.invalidate(payrollItemsProvider(batch.id));
      ref.invalidate(payrollBatchProvider(batch.id));
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      daily.dispose();
      subsidy.dispose();
      insurance.dispose();
      remark.dispose();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    VoidCallback? onChanged,
  }) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: onChanged == null ? null : (_) => onChanged(),
    decoration: InputDecoration(labelText: label),
  );

  Widget _readOnly(String label, String value) =>
      ListTile(dense: true, title: Text(label), trailing: Text(value));

  double _parseMoney(String value) =>
      double.tryParse(value.trim()) ?? double.nan;

  PayrollCalculation? _tryCalculate(
    PayrollItem item,
    String daily,
    String subsidy,
    String insurance,
  ) {
    final dailyValue = double.tryParse(daily.trim());
    final subsidyValue = double.tryParse(subsidy.trim());
    final insuranceValue = double.tryParse(insurance.trim());
    if (dailyValue == null ||
        subsidyValue == null ||
        insuranceValue == null ||
        !dailyValue.isFinite ||
        !subsidyValue.isFinite ||
        !insuranceValue.isFinite ||
        dailyValue < 0 ||
        subsidyValue < 0 ||
        insuranceValue < 0) {
      return null;
    }
    return PayrollCalculator.calculate(
      attendanceHalfDays: item.attendanceHalfDaysSnapshot,
      dailyWage: dailyValue,
      subsidy: subsidyValue,
      insuranceDeduction: insuranceValue,
    );
  }

  String _days(int halfDays) => halfDays.isEven
      ? '${halfDays ~/ 2}天'
      : '${(halfDays / 2).toStringAsFixed(1)}天';
}

class _EmployeePicker extends StatelessWidget {
  const _EmployeePicker({required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择人员'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: ListView.builder(
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            return ListTile(
              title: Text(employee.name),
              subtitle: Text(
                '${employee.employeeNo} · ${employee.employmentType ?? '未设置用工类型'}',
              ),
              onTap: () => Navigator.of(context).pop(employee),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
