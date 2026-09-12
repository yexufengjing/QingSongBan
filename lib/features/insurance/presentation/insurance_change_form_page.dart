import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../personnel/application/personnel_providers.dart';
import '../application/insurance_providers.dart';
import '../domain/insurance_options.dart';

class InsuranceChangeFormPage extends ConsumerStatefulWidget {
  const InsuranceChangeFormPage({super.key, this.changeId});

  final int? changeId;

  @override
  ConsumerState<InsuranceChangeFormPage> createState() =>
      _InsuranceChangeFormPageState();
}

class _InsuranceChangeFormPageState
    extends ConsumerState<InsuranceChangeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _baseController = TextEditingController();
  final _monthController = TextEditingController();
  final _remarkController = TextEditingController();
  int? _employeeId;
  String _changeType = InsuranceOptions.changeTypes.first;
  String _processingStatus = 'pending';
  String? _insuranceType;
  bool _saving = false;
  bool _loadingChange = false;

  @override
  void initState() {
    super.initState();
    _monthController.text = AppDateUtils.yearMonth(DateTime.now());
    if (widget.changeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadChange());
    }
  }

  @override
  void dispose() {
    _baseController.dispose();
    _monthController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.changeId == null ? '登记保险变更' : '编辑保险变更'),
      ),
      body: ref
          .watch(allPersonnelProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('人员列表加载失败：$error')),
            data: (employees) {
              if (employees.isEmpty) {
                return const Center(child: Text('暂无人员，请先建立人员档案。'));
              }
              if (_loadingChange) {
                return const Center(child: CircularProgressIndicator());
              }
              return Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    children: [
                      Card(
                        color: AppColors.lightBlue,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.techBlue,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '保险变更先记录办理状态，标记为“已完成”时才会更新当前参保信息和基数历史。',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '变更信息',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                key: const Key(
                                  'insurance-change-employee-field',
                                ),
                                initialValue: _employeeId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '人员',
                                ),
                                hint: const Text('请选择人员'),
                                validator: (value) =>
                                    value == null ? '请选择人员' : null,
                                items: [
                                  for (final employee in employees)
                                    DropdownMenuItem(
                                      value: employee.id,
                                      child: Text(
                                        '${employee.name} · ${employee.employeeNo}',
                                      ),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _employeeId = value),
                              ),
                              const SizedBox(height: 16),
                              _choiceChips(
                                context: context,
                                label: '变更类型',
                                options: InsuranceOptions.changeTypes,
                                selected: _changeType,
                                labelBuilder: InsuranceOptions.changeTypeLabel,
                                onSelected: (value) =>
                                    setState(() => _changeType = value),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                key: const Key('insurance-change-status-field'),
                                initialValue: _processingStatus,
                                decoration: const InputDecoration(
                                  labelText: '办理状态',
                                ),
                                items: [
                                  for (final status
                                      in InsuranceOptions.processingStatuses)
                                    DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        InsuranceOptions.statusLabel(status),
                                      ),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _processingStatus = value!),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('insurance-change-month-field'),
                                controller: _monthController,
                                decoration: const InputDecoration(
                                  labelText: '生效月份',
                                  hintText: 'YYYY-MM，例如 2026-09',
                                ),
                                validator: (value) {
                                  try {
                                    AppDateUtils.parseYearMonth(
                                      value?.trim() ?? '',
                                    );
                                    return null;
                                  } catch (_) {
                                    return '请输入有效的 YYYY-MM';
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: const Key('insurance-change-type-field'),
                                initialValue: _insuranceType,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '保险类型（可选）',
                                ),
                                hint: const Text('请选择或留空'),
                                items: [
                                  for (final type in InsuranceOptions.types)
                                    DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        InsuranceOptions.typeLabel(type),
                                      ),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _insuranceType = value),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('insurance-change-base-field'),
                                controller: _baseController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: '缴费基数（可选）',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('insurance-change-remark-field'),
                                controller: _remarkController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: '备注',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('insurance-change-save-button'),
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_saving ? '保存中…' : '保存保险变更'),
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

  Widget _choiceChips({
    required BuildContext context,
    required String label,
    required List<String> options,
    required String selected,
    required String Function(String) labelBuilder,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(labelBuilder(option)),
                selected: option == selected,
                onSelected: (_) => onSelected(option),
                selectedColor: AppColors.lightGreen,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final baseText = _baseController.text.trim();
    final base = baseText.isEmpty ? null : double.tryParse(baseText);
    if (baseText.isNotEmpty && base == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('缴费基数格式不正确')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(insuranceRepositoryProvider)
          .saveChange(
            id: widget.changeId,
            draft: InsuranceChangeDraft(
              employeeId: _employeeId!,
              changeType: _changeType,
              processingStatus: _processingStatus,
              effectiveMonth: _monthController.text,
              insuranceType: _insuranceType,
              contributionBase: base,
              remark: _remarkController.text,
            ),
          );
      if (mounted) context.go('/settings/insurance');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  Future<void> _loadChange() async {
    final change = await ref
        .read(insuranceRepositoryProvider)
        .findChange(widget.changeId!);
    if (!mounted) return;
    if (change == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('保险变更记录不存在或已被删除')));
      context.pop();
      return;
    }
    setState(() {
      _loadingChange = false;
      _employeeId = change.employeeId;
      _changeType = change.changeType;
      _processingStatus = change.processingStatus;
      _insuranceType = change.insuranceType;
      _baseController.text = change.contributionBase?.toString() ?? '';
      _monthController.text = change.effectiveMonth;
      _remarkController.text = change.remark ?? '';
    });
  }
}
