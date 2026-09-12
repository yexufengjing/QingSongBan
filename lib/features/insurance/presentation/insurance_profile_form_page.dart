import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../personnel/application/personnel_providers.dart';
import '../application/insurance_providers.dart';
import '../domain/insurance_options.dart';

class InsuranceProfileFormPage extends ConsumerStatefulWidget {
  const InsuranceProfileFormPage({super.key, this.employeeId});

  final int? employeeId;

  @override
  ConsumerState<InsuranceProfileFormPage> createState() =>
      _InsuranceProfileFormPageState();
}

class _InsuranceProfileFormPageState
    extends ConsumerState<InsuranceProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _baseController = TextEditingController();
  final _monthController = TextEditingController();
  final _remarkController = TextEditingController();
  int? _employeeId;
  bool _isInsured = false;
  String? _insuranceType;
  bool _saving = false;
  int? _loadedEmployeeId;

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
      appBar: AppBar(title: const Text('维护参保信息')),
      body: ref
          .watch(allPersonnelProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('人员列表加载失败：$error')),
            data: (employees) {
              if (employees.isEmpty) {
                return const Center(child: Text('暂无人员，请先建立人员档案。'));
              }
              final requestedEmployeeId = widget.employeeId;
              if (requestedEmployeeId != null &&
                  _loadedEmployeeId != requestedEmployeeId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadProfile(requestedEmployeeId);
                });
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
                                  '这里维护当前参保状态；需要留痕的新增、停保和恢复请通过“登记变更”办理。',
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
                                '当前参保',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                key: const Key(
                                  'insurance-profile-employee-field',
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
                                onChanged: (value) => _selectEmployee(value),
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('当前已参保'),
                                value: _isInsured,
                                onChanged: (value) =>
                                    setState(() => _isInsured = value),
                              ),
                              if (_isInsured) ...[
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  key: const Key(
                                    'insurance-profile-type-field',
                                  ),
                                  initialValue: _insuranceType,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '保险类型',
                                  ),
                                  hint: const Text('请选择保险类型'),
                                  validator: (value) =>
                                      _isInsured && value == null
                                      ? '请选择保险类型'
                                      : null,
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
                                  key: const Key(
                                    'insurance-profile-base-field',
                                  ),
                                  controller: _baseController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: '缴费基数',
                                    hintText: '可留空',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('insurance-profile-month-field'),
                                controller: _monthController,
                                decoration: const InputDecoration(
                                  labelText: '生效月份',
                                  hintText: 'YYYY-MM，例如 2026-09',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key(
                                  'insurance-profile-remark-field',
                                ),
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
                          key: const Key('insurance-profile-save-button'),
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
                          label: Text(_saving ? '保存中…' : '保存参保信息'),
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

  Future<void> _selectEmployee(int? employeeId) async {
    setState(() {
      _employeeId = employeeId;
      _loadedEmployeeId = null;
      _isInsured = false;
      _insuranceType = null;
      _baseController.clear();
      _monthController.clear();
      _remarkController.clear();
    });
    if (employeeId != null) await _loadProfile(employeeId);
  }

  Future<void> _loadProfile(int employeeId) async {
    final profile = await ref
        .read(insuranceRepositoryProvider)
        .findProfile(employeeId);
    if (!mounted) return;
    setState(() {
      _employeeId = employeeId;
      _loadedEmployeeId = employeeId;
      _isInsured = profile?.isInsured ?? false;
      _insuranceType = profile?.insuranceType;
      _baseController.text = profile?.contributionBase?.toString() ?? '';
      _monthController.text = profile?.effectiveMonth ?? '';
      _remarkController.text = profile?.remark ?? '';
    });
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
          .saveProfile(
            draft: InsuranceProfileDraft(
              employeeId: _employeeId!,
              isInsured: _isInsured,
              insuranceType: _insuranceType,
              contributionBase: base,
              effectiveMonth: _monthController.text,
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
}
