// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../personnel/application/personnel_providers.dart';
import '../application/payroll_providers.dart';
import '../data/wage_settings_repository.dart';

class EmployeePayrollPage extends ConsumerWidget {
  const EmployeePayrollPage({required this.employeeId, super.key});

  final int employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(employeeProvider(employeeId));
    final profile = ref.watch(employeeWageProfileProvider(employeeId));
    final types = ref.watch(wageJobTypesProvider);
    final history = ref.watch(payrollEmployeeHistoryProvider(employeeId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('工资资料与记录'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: employee.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('人员加载失败：$error')),
        data: (item) {
          if (item == null) return const Center(child: Text('人员不存在'));
          return profile.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('工资资料加载失败：$error')),
            data: (value) => types.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('工种加载失败：$error')),
              data: (jobTypes) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  _ProfileEditor(
                    employee: item,
                    profile: value,
                    jobTypes: jobTypes,
                    ref: ref,
                  ),
                  const SizedBox(height: 24),
                  Text('历史工资', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  history.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text('历史工资加载失败：$error'),
                    data: (values) => values.isEmpty
                        ? const Text('暂无工资记录')
                        : Column(
                            children: [
                              for (final entry in values)
                                Card(
                                  child: ListTile(
                                    title: Text(entry.batch.name),
                                    subtitle: Text(
                                      '${(entry.item.attendanceHalfDaysSnapshot / 2).toStringAsFixed(1)}天 · 日薪 ${entry.item.dailyWage.toStringAsFixed(2)}',
                                    ),
                                    trailing: Text(
                                      '${entry.item.finalWage.toStringAsFixed(2)}元',
                                    ),
                                    onTap: () => context.push(
                                      '/reports/payroll/item/${entry.item.id}',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({
    required this.employee,
    required this.profile,
    required this.jobTypes,
    required this.ref,
  });

  final Employee employee;
  final EmployeeWageProfile? profile;
  final List<WageJobType> jobTypes;
  final WidgetRef ref;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late bool participates;
  late bool useDefault;
  int? jobTypeId;
  late final TextEditingController personalWage;
  late final TextEditingController remark;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    participates =
        profile?.participatesInPayroll ??
        widget.employee.employmentType == '临时工';
    useDefault = profile?.useJobDefaultWage ?? true;
    jobTypeId = profile?.jobTypeId;
    personalWage = TextEditingController(
      text: profile?.personalDailyWage?.toStringAsFixed(2) ?? '',
    );
    remark = TextEditingController(text: profile?.remark ?? '');
  }

  @override
  void dispose() {
    personalWage.dispose();
    remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.employee.name} 工资资料',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('参与临时工工资核算'),
              value: participates,
              onChanged: (value) => setState(() => participates = value),
            ),
            DropdownButtonFormField<int>(
              initialValue: widget.jobTypes.any((type) => type.id == jobTypeId)
                  ? jobTypeId
                  : null,
              decoration: const InputDecoration(labelText: '工资工种'),
              items: [
                for (final type in widget.jobTypes.where(
                  (type) => type.isActive,
                ))
                  DropdownMenuItem(value: type.id, child: Text(type.name)),
              ],
              onChanged: (value) => setState(() => jobTypeId = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('使用工种默认日薪'),
              value: useDefault,
              onChanged: (value) => setState(() => useDefault = value),
            ),
            if (!useDefault)
              TextField(
                controller: personalWage,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '个人特殊日薪（元）'),
              ),
            TextField(
              controller: remark,
              decoration: const InputDecoration(labelText: '工资备注'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _save,
                child: const Text('保存工资资料'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      await widget.ref
          .read(wageSettingsRepositoryProvider)
          .saveProfile(
            EmployeeWageProfileDraft(
              employeeId: widget.employee.id,
              participatesInPayroll: participates,
              jobTypeId: jobTypeId,
              useJobDefaultWage: useDefault,
              personalDailyWage: useDefault
                  ? null
                  : double.tryParse(personalWage.text),
              remark: remark.text,
            ),
          );
      widget.ref.invalidate(employeeWageProfileProvider(widget.employee.id));
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('工资资料已保存')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }
}
