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
import 'payroll_group_filter.dart';

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('工资编辑', style: Theme.of(context).textTheme.titleLarge),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${PayrollOptions.statusLabel(batch.status)} · ${batch.employeeCount}人 · 出勤 ${(batch.attendanceHalfDaysTotal / 2).toStringAsFixed(1)}天 · 最终${batch.finalWageTotal.toStringAsFixed(2)}元',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        PayrollGroupFilter(batchId: batch.id),
        Expanded(
          child: items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('工资明细加载失败：$error')),
            data: (values) {
              final selectedGroupId = ref.watch(
                payrollGroupFilterProvider(batch.id),
              );
              final employeeGroups = ref
                  .watch(payrollBatchEmployeeGroupsProvider(batch.id))
                  .valueOrNull;
              final visible = selectedGroupId == null || employeeGroups == null
                  ? values
                  : values
                        .where(
                          (value) =>
                              employeeGroups[value.item.employeeId]?.contains(
                                selectedGroupId,
                              ) ??
                              false,
                        )
                        .toList();
              return _ItemList(
                batch: batch,
                items: visible,
                ref: ref,
                reorderable: selectedGroupId == null,
              );
            },
          ),
        ),
        if (editable)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleAction(context, 'check'),
                    icon: const Icon(Icons.fact_check_outlined, size: 20),
                    label: const Text('异常检查'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _addEmployee(context),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('人工增加人员'),
                  ),
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
        title: const Text('删除工资草稿？', textAlign: TextAlign.center),
        content: const Text('工资草稿会被软删除，之后重新进入该月份时可以恢复原批次。'),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('确认删除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _addEmployee(BuildContext context) async {
    final employees = (await ref.read(allPersonnelProvider.future))
        .where((employee) => employee.employmentType == '临时工')
        .toList();
    if (!context.mounted) return;
    final selected = await showDialog<Employee>(
      context: context,
      builder: (context) => _EmployeePicker(employees: employees),
    );
    if (selected == null) return;
    try {
      final repo = ref.read(payrollRepositoryProvider);
      final attendanceHalfDays = await repo.attendanceHalfDaysForEmployee(
        batchId: batch.id,
        employeeId: selected.id,
      );
      if (attendanceHalfDays == 0) {
        final confirmed = await _confirmZeroAttendance(context, selected);
        if (!confirmed) return;
      }
      await repo.addEmployee(batchId: batch.id, employeeId: selected.id);
      ref.invalidate(payrollItemsProvider(batch.id));
      ref.invalidate(payrollBatchProvider(batch.id));
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('增加人员失败：$error')));
    }
  }

  Future<bool> _confirmZeroAttendance(
    BuildContext context,
    Employee employee,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认加入工资名单？', textAlign: TextAlign.center),
        content: Text('${employee.name} 本月实际出勤为 0 天，请确认是否仍加入工资造资。'),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('确认加入'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
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
    var reasonText = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, textAlign: TextAlign.center),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('原因'),
            const SizedBox(height: 6),
            TextField(
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              onChanged: (value) => reasonText = value,
              decoration: const InputDecoration(),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(reasonText.trim()),
                  child: const Text('确认'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result == null || result.isEmpty ? null : result;
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.batch,
    required this.items,
    required this.ref,
    required this.reorderable,
  });

  final PayrollBatche batch;
  final List<PayrollItemWithEmployee> items;
  final WidgetRef ref;
  final bool reorderable;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const Center(child: Text('当前工资名单为空，请重新生成或人工增加人员'));
    final editable =
        batch.status != PayrollStatus.confirmed &&
        batch.status != PayrollStatus.locked;
    final jobTypes =
        ref.watch(wageJobTypesProvider).valueOrNull ?? const <WageJobType>[];
    Widget itemBuilder(BuildContext context, int index) {
      final value = items[index];
      final item = value.item;
      final removed = item.isManuallyRemoved;
      return Card(
        key: ValueKey(item.id),
        margin: const EdgeInsets.only(bottom: 12),
        color: removed ? Colors.grey.shade100 : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: editable
              ? () => _edit(context, value, jobTypes)
              : () => context.push('/reports/payroll/item/${item.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 10),
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.lightBlue,
                      child: Icon(
                        Icons.person_outline,
                        color: AppColors.techBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.employeeNameSnapshot,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.employeeNoSnapshot} · ${item.jobTypeNameSnapshot ?? '未配置工种'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => context.push(
                            '/attendance/monthly-table?month=${batch.payrollMonth}',
                          ),
                          icon: const Icon(Icons.calendar_month_outlined),
                          tooltip: '查看本月考勤',
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'detail') {
                              if (context.mounted)
                                context.push(
                                  '/reports/payroll/item/${item.id}',
                                );
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
                            const PopupMenuItem(
                              value: 'detail',
                              child: Text('查看明细'),
                            ),
                            if (editable)
                              PopupMenuItem(
                                value: removed ? 'restore' : 'remove',
                                child: Text(removed ? '恢复到工资名单' : '移出工资名单'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      '出勤${_days(item.attendanceHalfDaysSnapshot)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '日薪${item.dailyWage.toStringAsFixed(2)}元',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '实发${item.finalWage.toStringAsFixed(2)}元',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!reorderable || !editable) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        itemCount: items.length,
        itemBuilder: itemBuilder,
      );
    }
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
      itemBuilder: itemBuilder,
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
    final saved = await showModalBottomSheet<bool>(
      isScrollControlled: true,
      showDragHandle: true,
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final calculation = _tryCalculate(
            item,
            daily.text,
            subsidy.text,
            insurance.text,
          );
          return FractionallySizedBox(
            heightFactor: .9,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  children: [
                    Text(
                      '${item.employeeNameSnapshot} 工资明细',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.employeeNoSnapshot,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _readOnly(
                              '出勤天数',
                              _days(item.attendanceHalfDaysSnapshot),
                            ),
                            _referenceField(
                              '工种',
                              DropdownButtonFormField<int>(
                                initialValue:
                                    jobTypes.any(
                                      (type) => type.id == selectedJobTypeId,
                                    )
                                    ? selectedJobTypeId
                                    : null,
                                decoration: const InputDecoration(),
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
                            ),
                            _field(
                              daily,
                              '日薪',
                              onChanged: () => setState(() {}),
                            ),
                            _readOnly(
                              '基础工资',
                              calculation?.baseWage.toStringAsFixed(2) ??
                                  '输入有效金额',
                            ),
                            _field(
                              subsidy,
                              '补助',
                              onChanged: () => setState(() {}),
                            ),
                            _field(
                              insurance,
                              '保险扣除',
                              onChanged: () => setState(() {}),
                            ),
                            _readOnly(
                              '最终工资',
                              calculation?.finalWage.toStringAsFixed(2) ??
                                  '输入有效金额',
                            ),
                            _referenceField(
                              '备注',
                              TextField(
                                controller: remark,
                                decoration: const InputDecoration(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: calculation == null
                                ? null
                                : () => Navigator.of(context).pop(true),
                            child: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (saved != true) {
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
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    VoidCallback? onChanged,
  }) => _referenceField(
    label,
    TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged == null ? null : (_) => onChanged(),
      decoration: InputDecoration(suffixText: '元'),
    ),
  );

  Widget _readOnly(String label, String value) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.lightBlue,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Text(label),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: label == '最终工资' ? AppColors.success : AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );

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

Widget _referenceField(String label, Widget field) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    const SizedBox(height: 8),
    field,
  ],
);
