import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../personnel/application/personnel_providers.dart';
import '../application/leave_providers.dart';
import '../domain/leave_options.dart';

class LeaveFormPage extends ConsumerStatefulWidget {
  const LeaveFormPage({super.key, this.leaveId});

  final int? leaveId;

  bool get isEditing => leaveId != null;

  @override
  ConsumerState<LeaveFormPage> createState() => _LeaveFormPageState();
}

class _LeaveFormPageState extends ConsumerState<LeaveFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _remarkController = TextEditingController();
  late final Future<LeaveRecord?> _leaveFuture;
  late DateTime _startDate;
  late DateTime _endDate;
  LeaveType _leaveType = LeaveType.personal;
  LeaveDurationType _duration = LeaveDurationType.fullDay;
  LeaveHalfPeriod _startPeriod = LeaveHalfPeriod.morning;
  LeaveHalfPeriod _endPeriod = LeaveHalfPeriod.afternoon;
  int? _employeeId;
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final today = AppDateUtils.dateOnly(DateTime.now());
    _startDate = today;
    _endDate = today;
    _leaveFuture = widget.leaveId == null
        ? Future<LeaveRecord?>.value(null)
        : ref.read(leaveRepositoryProvider).findById(widget.leaveId!);
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LeaveRecord?>(
      future: _leaveFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _loadingScaffold();
        }
        if (snapshot.hasError) {
          return _errorScaffold('请假记录加载失败：${snapshot.error}');
        }
        if (widget.isEditing && snapshot.data == null) {
          return _errorScaffold('请假记录不存在或已被删除');
        }
        _initialize(snapshot.data);
        final employees = ref.watch(allPersonnelProvider);
        return employees.when(
          loading: () => _loadingScaffold(),
          error: (error, _) => _errorScaffold('人员列表加载失败：$error'),
          data: (items) => _buildForm(context, items),
        );
      },
    );
  }

  void _initialize(LeaveRecord? leave) {
    if (_initialized) return;
    if (leave != null) {
      _employeeId = leave.employeeId;
      _leaveType = leave.leaveType;
      _startDate = AppDateUtils.dateOnly(leave.startDate);
      _endDate = AppDateUtils.dateOnly(leave.endDate);
      _startPeriod = leave.startPeriod;
      _endPeriod = leave.endPeriod;
      _duration = LeaveOptions.durationOf(leave);
      _remarkController.text = leave.remark ?? '';
    }
    _initialized = true;
  }

  Widget _buildForm(BuildContext context, List<Employee> employees) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑请假' : '新增请假'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('leave-save-button'),
              onPressed: _saving || employees.isEmpty ? null : _save,
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
              label: Text(_saving ? '保存中…' : '保存请假'),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppColors.lightBlue,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.techBlue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('请假保存后会同步对应日期的上午、下午考勤。删除时会保留后来手动修改过的考勤状态。'),
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
                        '请假信息',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (employees.isEmpty)
                        _referenceField(
                          '请假人员',
                          InputDecorator(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            child: const Text('暂无可用人员，请先建立人员档案。'),
                          ),
                        )
                      else
                        _referenceField(
                          '请假人员',
                          DropdownButtonFormField<int>(
                            key: const Key('leave-employee-field'),
                            initialValue:
                                _employeeId != null &&
                                    employees.any(
                                      (item) => item.id == _employeeId,
                                    )
                                ? _employeeId
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
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
                        ),
                      const SizedBox(height: 16),
                      _choiceChips<LeaveType>(
                        context: context,
                        label: '请假类型',
                        options: LeaveOptions.types,
                        selected: _leaveType,
                        labelBuilder: LeaveOptions.typeLabel,
                        onSelected: (value) =>
                            setState(() => _leaveType = value),
                      ),
                      const SizedBox(height: 16),
                      _choiceChips<LeaveDurationType>(
                        context: context,
                        label: '请假时长',
                        options: LeaveOptions.durations,
                        selected: _duration,
                        labelBuilder: LeaveOptions.durationLabel,
                        onSelected: _selectDuration,
                      ),
                      const SizedBox(height: 16),
                      _dateField(
                        context: context,
                        key: const Key('leave-start-date-field'),
                        label: _duration == LeaveDurationType.multiDay
                            ? '开始日期'
                            : '请假日期',
                        value: _startDate,
                        onTap: () => _pickDate(context, isStart: true),
                      ),
                      if (_duration == LeaveDurationType.multiDay) ...[
                        const SizedBox(height: 20),
                        _periodField(
                          context: context,
                          key: const Key('leave-start-period-field'),
                          label: '开始时段',
                          value: _startPeriod,
                          onChanged: (value) =>
                              setState(() => _startPeriod = value!),
                        ),
                        const SizedBox(height: 20),
                        _dateField(
                          context: context,
                          key: const Key('leave-end-date-field'),
                          label: '结束日期',
                          value: _endDate,
                          onTap: () => _pickDate(context, isStart: false),
                        ),
                        const SizedBox(height: 20),
                        _periodField(
                          context: context,
                          key: const Key('leave-end-period-field'),
                          label: '结束时段',
                          value: _endPeriod,
                          onChanged: (value) =>
                              setState(() => _endPeriod = value!),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _referenceField(
                        '备注',
                        TextFormField(
                          key: const Key('leave-remark-field'),
                          controller: _remarkController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: '可填写请假说明',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceChips<T>({
    required BuildContext context,
    required String label,
    required List<T> options,
    required T selected,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(14) > 19
                ? 2
                : 4;
            return Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final option in options)
                  SizedBox(
                    width: (constraints.maxWidth - (columns - 1) * 6) / columns,
                    child: ChoiceChip(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      
                      label: SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 6) /
                                columns -
                            24,
                        child: Text(
                          labelBuilder(option),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      selected: option == selected,
                      onSelected: (_) => onSelected(option),
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.lightBlue,
                      labelStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: option == selected
                                ? Colors.white
                                : AppColors.ink,
                            fontWeight: option == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                      side: BorderSide(
                        color: option == selected
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _selectDuration(LeaveDurationType value) {
    setState(() {
      _duration = value;
      switch (value) {
        case LeaveDurationType.fullDay:
          _endDate = _startDate;
          _startPeriod = LeaveHalfPeriod.morning;
          _endPeriod = LeaveHalfPeriod.afternoon;
        case LeaveDurationType.morning:
          _endDate = _startDate;
          _startPeriod = LeaveHalfPeriod.morning;
          _endPeriod = LeaveHalfPeriod.morning;
        case LeaveDurationType.afternoon:
          _endDate = _startDate;
          _startPeriod = LeaveHalfPeriod.afternoon;
          _endPeriod = LeaveHalfPeriod.afternoon;
        case LeaveDurationType.multiDay:
          if (!_endDate.isAfter(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
          _startPeriod = LeaveHalfPeriod.morning;
          _endPeriod = LeaveHalfPeriod.afternoon;
      }
    });
  }

  Widget _dateField({
    required BuildContext context,
    required Key key,
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: _referenceField(
        label,
        InputDecorator(
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 19),
          ),
          child: Text(
            AppDateUtils.formatDate(value),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }

  Widget _periodField({
    required BuildContext context,
    required Key key,
    required String label,
    required LeaveHalfPeriod value,
    required ValueChanged<LeaveHalfPeriod?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        SegmentedButton<LeaveHalfPeriod>(
          key: key,
          segments: [
            for (final period in LeaveHalfPeriod.values)
              ButtonSegment(
                value: period,
                label: Text(LeaveOptions.periodLabel(period)),
              ),
          ],
          selected: {value},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: current,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = AppDateUtils.dateOnly(picked);
        if (_duration != LeaveDurationType.multiDay) _endDate = _startDate;
      } else {
        _endDate = AppDateUtils.dateOnly(picked);
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_duration != LeaveDurationType.multiDay) {
      _endDate = _startDate;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(leaveRepositoryProvider)
          .save(
            id: widget.leaveId,
            draft: LeaveRecordDraft(
              employeeId: _employeeId!,
              leaveType: _leaveType,
              startDate: _startDate,
              endDate: _endDate,
              startPeriod: _startPeriod,
              endPeriod: _endPeriod,
              remark: _remarkController.text,
            ),
          );
      if (mounted) context.go('/attendance/leave');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  Scaffold _loadingScaffold() {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '编辑请假' : '新增请假')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '编辑请假' : '新增请假')),
      body: Center(child: Text(message)),
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
