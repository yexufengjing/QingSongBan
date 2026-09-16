import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../attendance/application/attendance_group_providers.dart';
import '../application/personnel_providers.dart';
import '../domain/personnel_options.dart';

class PersonnelFormPage extends ConsumerStatefulWidget {
  const PersonnelFormPage({
    this.employeeId,
    this.fromHomeShortcut = false,
    super.key,
  });

  final int? employeeId;
  final bool fromHomeShortcut;

  bool get isEditing => employeeId != null;

  @override
  ConsumerState<PersonnelFormPage> createState() => _PersonnelFormPageState();
}

class _PersonnelFormPageState extends ConsumerState<PersonnelFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _employeeNoController = TextEditingController();
  final _nameController = TextEditingController();
  final _idCardController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _positionController = TextEditingController();
  final _teamController = TextEditingController();
  final _workAreaController = TextEditingController();
  final _managerController = TextEditingController();
  final _employmentTypeController = TextEditingController();
  final _remarkController = TextEditingController();

  late final Future<Employee?> _employeeFuture;
  DateTime? _birthDate;
  late DateTime _hireDate;
  EmployeeStatus _status = EmployeeStatus.active;
  String? _gender;
  int? _attendanceGroupId;
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _employeeFuture = widget.employeeId == null
        ? Future<Employee?>.value(null)
        : ref.read(personnelRepositoryProvider).findById(widget.employeeId!);
  }

  @override
  void dispose() {
    _employeeNoController.dispose();
    _nameController.dispose();
    _idCardController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _positionController.dispose();
    _teamController.dispose();
    _workAreaController.dispose();
    _managerController.dispose();
    _employmentTypeController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _withBackBehavior(
      FutureBuilder<Employee?>(
        future: _employeeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              appBar: AppBar(
                leading: _backButton(context),
                title: Text(widget.isEditing ? '编辑人员' : '新增人员'),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(
                leading: _backButton(context),
                title: Text(widget.isEditing ? '编辑人员' : '新增人员'),
              ),
              body: Center(child: Text('档案加载失败：${snapshot.error}')),
            );
          }
          if (widget.isEditing && snapshot.data == null) {
            return Scaffold(
              appBar: AppBar(
                leading: _backButton(context),
                title: const Text('编辑人员'),
              ),
              body: const Center(child: Text('档案不存在或已被移除')),
            );
          }

          _initialize(snapshot.data);
          final activeGroups = ref
              .watch(attendanceGroupsProvider)
              .maybeWhen(
                data: (items) => items,
                orElse: () => const <AttendanceGroup>[],
              );
          final currentGroup = _attendanceGroupId == null
              ? null
              : ref
                    .watch(attendanceGroupProvider(_attendanceGroupId!))
                    .maybeWhen(data: (item) => item, orElse: () => null);
          final groups = [
            ...activeGroups,
            if (currentGroup != null &&
                !activeGroups.any((group) => group.id == currentGroup.id))
              currentGroup,
          ];
          return _buildForm(context, groups);
        },
      ),
    );
  }

  Widget _withBackBehavior(Widget child) {
    return PopScope(
      canPop: !widget.fromHomeShortcut,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.fromHomeShortcut && mounted) {
          context.go('/home');
        }
      },
      child: child,
    );
  }

  Widget _backButton(BuildContext context) {
    return IconButton(
      tooltip: widget.fromHomeShortcut ? '返回首页' : '返回',
      onPressed: () =>
          widget.fromHomeShortcut ? context.go('/home') : context.pop(),
      icon: const Icon(Icons.arrow_back),
    );
  }

  void _initialize(Employee? employee) {
    if (_initialized) {
      return;
    }
    _employeeNoController.text = employee?.employeeNo ?? '';
    _nameController.text = employee?.name ?? '';
    _idCardController.text = employee?.idCardNumber ?? '';
    _phoneController.text = employee?.phone ?? '';
    _addressController.text = employee?.address ?? '';
    _positionController.text = employee?.position ?? '';
    _teamController.text = employee?.team ?? '';
    _workAreaController.text = employee?.workArea ?? '';
    _managerController.text = employee?.manager ?? '';
    _employmentTypeController.text = employee?.employmentType ?? '';
    _remarkController.text = employee?.remark ?? '';
    _birthDate = employee?.birthDate;
    _hireDate = employee?.hireDate ?? AppDateUtils.dateOnly(DateTime.now());
    _status = employee?.status ?? EmployeeStatus.active;
    _gender = employee?.gender;
    _attendanceGroupId = employee?.defaultAttendanceGroupId;
    _initialized = true;
  }

  Widget _buildForm(BuildContext context, List<AttendanceGroup> groups) {
    return Scaffold(
      appBar: AppBar(
        leading: _backButton(context),
        title: Text(widget.isEditing ? '编辑人员' : '新增人员'),
        actions: [
          if (!widget.isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: Text(
                  '本地保存',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormHint(editing: widget.isEditing),
              const SizedBox(height: 18),
              _FormSection(
                title: '基本信息',
                icon: Icons.badge_outlined,
                children: [
                  _textField(
                    controller: _nameController,
                    label: '姓名',
                    hint: '请输入真实姓名',
                    key: const Key('personnel-name-field'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '请填写姓名' : null,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _employeeNoController,
                    label: '人员编号',
                    hint: '留空将自动生成，如 EMP-0001',
                    key: const Key('personnel-number-field'),
                  ),
                  const SizedBox(height: 12),
                  _choiceChips(
                    label: '性别',
                    options: PersonnelOptions.genders,
                    selected: _gender,
                    onSelected: (value) => setState(() => _gender = value),
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _idCardController,
                    label: '身份证号',
                    hint: '默认脱敏显示',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField(
                          label: '出生日期',
                          value: _birthDate,
                          onTap: () => _pickBirthDate(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: '自动年龄'),
                          child: Text(
                            _birthDate == null
                                ? '未填写'
                                : '${AppDateUtils.ageAt(_birthDate!)} 岁',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _phoneController,
                    label: '联系电话',
                    hint: '默认脱敏显示',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _addressController,
                    label: '家庭住址',
                    hint: '请输入详细地址',
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FormSection(
                title: '工作信息',
                icon: Icons.work_outline,
                children: [
                  _dateField(
                    label: '入职日期',
                    value: _hireDate,
                    onTap: () => _pickHireDate(context),
                  ),
                  const SizedBox(height: 12),
                  _choiceChips(
                    label: '当前状态',
                    options: EmployeeStatus.values,
                    selected: _status,
                    labelBuilder: PersonnelOptions.statusLabel,
                    onSelected: (value) => setState(() => _status = value),
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _positionController,
                    label: '岗位',
                    hint: '例如：操作工、司机',
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _teamController,
                    label: '所属班组',
                    hint: '请输入班组名称',
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _workAreaController,
                    label: '工作区域',
                    hint: '例如：特钢、重科、管业',
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _managerController,
                    label: '负责人',
                    hint: '请输入负责人',
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _employmentTypeController,
                    label: '用工类型',
                    hint: '临时工 / 正式工 / 其他',
                  ),
                  const SizedBox(height: 12),
                  if (groups.isEmpty)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '默认考勤组',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      child: Text(
                        '暂无可用考勤组，请先在考勤页建立',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    DropdownButtonFormField<int>(
                      initialValue:
                          _attendanceGroupId != null &&
                              groups.any(
                                (group) => group.id == _attendanceGroupId,
                              )
                          ? _attendanceGroupId
                          : 0,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '默认考勤组',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      hint: const Text('请选择考勤组'),
                      items: [
                        const DropdownMenuItem(value: 0, child: Text('暂不指定')),
                        for (final group in groups)
                          DropdownMenuItem(
                            value: group.id,
                            child: Text(
                              group.isEnabled
                                  ? group.name
                                  : '${group.name}（已停用，保留当前配置）',
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _attendanceGroupId = value == 0 ? null : value,
                      ),
                    ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _remarkController,
                    label: '备注',
                    hint: '可填写补充说明',
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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
                  label: Text(_saving ? '保存中…' : '保存档案'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '保存后可在人员名单中搜索和筛选。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    Key? key,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _choiceChips<T>({
    required String label,
    required List<T> options,
    required T? selected,
    required ValueChanged<T> onSelected,
    String Function(T value)? labelBuilder,
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
                label: Text(labelBuilder?.call(option) ?? option.toString()),
                selected: selected == option,
                onSelected: (_) => onSelected(option),
                selectedColor: AppColors.lightGreen,
                side: BorderSide(
                  color: selected == option
                      ? AppColors.primary
                      : AppColors.divider,
                ),
                labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected == option
                      ? AppColors.primary
                      : AppColors.body,
                  fontWeight: selected == option
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 19),
        ),
        child: Text(
          AppDateUtils.formatDate(value),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: value == null ? AppColors.helper : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Future<void> _pickBirthDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      initialDate: _birthDate ?? DateTime(1990),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _pickHireDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1940),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _hireDate,
    );
    if (picked != null) {
      setState(() => _hireDate = picked);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final employee = await ref
          .read(personnelRepositoryProvider)
          .save(
            id: widget.employeeId,
            draft: EmployeeDraft(
              employeeNo: _employeeNoController.text,
              name: _nameController.text,
              gender: _gender,
              idCardNumber: _idCardController.text,
              birthDate: _birthDate,
              phone: _phoneController.text,
              address: _addressController.text,
              hireDate: _hireDate,
              status: _status,
              position: _positionController.text,
              team: _teamController.text,
              workArea: _workAreaController.text,
              manager: _managerController.text,
              employmentType: _employmentTypeController.text,
              defaultAttendanceGroupId: _attendanceGroupId,
              remark: _remarkController.text,
            ),
          );
      if (!mounted) {
        return;
      }
      if (widget.employeeId != null) {
        ref.invalidate(employeeProvider(widget.employeeId!));
      }
      context.go(
        widget.fromHomeShortcut ? '/home' : '/personnel/${employee.id}',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
  }
}

class _FormHint extends StatelessWidget {
  const _FormHint({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightGreen,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.save_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                editing
                    ? '修改会直接保存到本地档案，历史考勤数据不会因状态变化被覆盖。'
                    : '人员编号可留空，系统会在保存时自动生成；其他字段可随后补充。',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 9),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
