import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../../personnel/application/personnel_providers.dart';
import '../application/overtime_providers.dart';
import '../domain/overtime_options.dart';

class OvertimeFormPage extends ConsumerStatefulWidget {
  const OvertimeFormPage({super.key, this.overtimeId});

  final int? overtimeId;

  bool get isEditing => overtimeId != null;

  @override
  ConsumerState<OvertimeFormPage> createState() => _OvertimeFormPageState();
}

class _OvertimeFormPageState extends ConsumerState<OvertimeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();
  final _registrantController = TextEditingController();
  final _remarkController = TextEditingController();
  late final Future<OvertimeRecord?> _overtimeFuture;
  late DateTime _overtimeDate;
  late DateTime _startTime;
  late DateTime _endTime;
  String _overtimeType = OvertimeOptions.types.first;
  int? _employeeId;
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _overtimeDate = AppDateUtils.dateOnly(now);
    _startTime = DateTime(now.year, now.month, now.day, 18);
    _endTime = DateTime(now.year, now.month, now.day, 20);
    _overtimeFuture = widget.overtimeId == null
        ? Future<OvertimeRecord?>.value(null)
        : ref.read(overtimeRepositoryProvider).findById(widget.overtimeId!);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _locationController.dispose();
    _registrantController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OvertimeRecord?>(
      future: _overtimeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _loadingScaffold();
        }
        if (snapshot.hasError) {
          return _errorScaffold('加班记录加载失败：${snapshot.error}');
        }
        if (widget.isEditing && snapshot.data == null) {
          return _errorScaffold('加班记录不存在或已被删除');
        }
        _initialize(snapshot.data);
        return ref
            .watch(allPersonnelProvider)
            .when(
              loading: () => _loadingScaffold(),
              error: (error, _) => _errorScaffold('人员列表加载失败：$error'),
              data: (items) => _buildForm(context, items),
            );
      },
    );
  }

  void _initialize(OvertimeRecord? record) {
    if (_initialized) return;
    if (record != null) {
      _employeeId = record.employeeId;
      _overtimeDate = AppDateUtils.dateOnly(record.overtimeDate);
      _startTime = record.startTime;
      _endTime = record.endTime;
      _overtimeType = OvertimeOptions.types.contains(record.overtimeType)
          ? record.overtimeType
          : 'other';
      _contentController.text = record.workContent ?? '';
      _locationController.text = record.workLocation ?? '';
      _registrantController.text = record.registrant ?? '';
      _remarkController.text = record.remark ?? '';
    }
    _initialized = true;
  }

  Widget _buildForm(BuildContext context, List<Employee> employees) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑加班' : '新增加班'),
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppColors.lightGreen,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('同一人员同一天可以登记多段加班，但时间段不能重叠；加班不会改变基础出勤天数。'),
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
                        '加班信息',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (employees.isEmpty)
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '加班人员',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          child: const Text('暂无可用人员，请先建立人员档案。'),
                        )
                      else
                        DropdownButtonFormField<int>(
                          key: const Key('overtime-employee-field'),
                          initialValue:
                              _employeeId != null &&
                                  employees.any(
                                    (item) => item.id == _employeeId,
                                  )
                              ? _employeeId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '加班人员',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          hint: const Text('请选择人员'),
                          validator: (value) => value == null ? '请选择人员' : null,
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
                      const SizedBox(height: 12),
                      _dateField(
                        context: context,
                        key: const Key('overtime-date-field'),
                        label: '加班日期',
                        value: _overtimeDate,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _timeField(
                              context: context,
                              key: const Key('overtime-start-time-field'),
                              label: '开始时间',
                              value: _startTime,
                              onTap: () => _pickTime(context, isStart: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _timeField(
                              context: context,
                              key: const Key('overtime-end-time-field'),
                              label: '结束时间',
                              value: _endTime,
                              onTap: () => _pickTime(context, isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _DurationHint(start: _startTime, end: _endTime),
                      const SizedBox(height: 16),
                      _choiceChips(
                        context: context,
                        label: '加班类型',
                        options: OvertimeOptions.types,
                        selected: _overtimeType,
                        onSelected: (value) =>
                            setState(() => _overtimeType = value),
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        controller: _contentController,
                        label: '工作内容',
                        hint: '例如：设备检修、现场清理',
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        controller: _locationController,
                        label: '工作地点',
                        hint: '可填写区域或项目名称',
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        controller: _registrantController,
                        label: '登记人',
                        hint: '可填写登记人员姓名',
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
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('overtime-save-button'),
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
                  label: Text(_saving ? '保存中…' : '保存加班'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceChips({
    required BuildContext context,
    required String label,
    required List<String> options,
    required String selected,
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
                label: Text(OvertimeOptions.typeLabel(option)),
                selected: option == selected,
                onSelected: (_) => onSelected(option),
                selectedColor: AppColors.lightGreen,
                side: BorderSide(
                  color: option == selected
                      ? AppColors.primary
                      : AppColors.divider,
                ),
              ),
          ],
        ),
      ],
    );
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 19),
        ),
        child: Text(AppDateUtils.formatDate(value)),
      ),
    );
  }

  Widget _timeField({
    required BuildContext context,
    required Key key,
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule_outlined, size: 19),
        ),
        child: Text(
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }

  TextFormField _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _overtimeDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _overtimeDate = AppDateUtils.dateOnly(picked);
      _startTime = _withDate(_startTime, _overtimeDate);
      _endTime = _withDate(_endTime, _overtimeDate);
    });
  }

  Future<void> _pickTime(BuildContext context, {required bool isStart}) async {
    final current = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null || !mounted) return;
    final value = DateTime(
      _overtimeDate.year,
      _overtimeDate.month,
      _overtimeDate.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = value;
      } else {
        _endTime = value;
      }
    });
  }

  DateTime _withDate(DateTime time, DateTime date) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(overtimeRepositoryProvider)
          .save(
            id: widget.overtimeId,
            draft: OvertimeRecordDraft(
              employeeId: _employeeId!,
              overtimeDate: _overtimeDate,
              startTime: _startTime,
              endTime: _endTime,
              overtimeType: _overtimeType,
              workContent: _contentController.text,
              workLocation: _locationController.text,
              registrant: _registrantController.text,
              remark: _remarkController.text,
            ),
          );
      if (mounted) context.go('/attendance/overtime');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  Scaffold _loadingScaffold() {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '编辑加班' : '新增加班')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '编辑加班' : '新增加班')),
      body: Center(child: Text(message)),
    );
  }
}

class _DurationHint extends StatelessWidget {
  const _DurationHint({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final minutes = end.difference(start).inMinutes;
    final label = minutes > 0
        ? OvertimeOptions.formatDuration(minutes)
        : '时间无效';
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 18, color: AppColors.helper),
        const SizedBox(width: 6),
        Text('自动计算：$label', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
