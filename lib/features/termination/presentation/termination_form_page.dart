import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../personnel/application/personnel_providers.dart';
import '../../attachments/application/attachment_providers.dart';
import '../../attachments/domain/attachment_options.dart';
import '../../attachments/presentation/attachment_picker_card.dart';
import '../../reminders/application/reminder_providers.dart';
import '../application/termination_providers.dart';
import '../domain/termination_options.dart';

class TerminationFormPage extends ConsumerStatefulWidget {
  const TerminationFormPage({
    super.key,
    this.terminationId,
    this.fromHomeShortcut = false,
  });

  final int? terminationId;
  final bool fromHomeShortcut;

  bool get isEditing => terminationId != null;

  @override
  ConsumerState<TerminationFormPage> createState() =>
      _TerminationFormPageState();
}

class _TerminationFormPageState extends ConsumerState<TerminationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _stopMonthController = TextEditingController();
  final _remarkController = TextEditingController();
  late final Future<TerminationRecord?> _terminationFuture;
  late DateTime _terminationDate;
  String _terminationType = TerminationOptions.types.first;
  int? _employeeId;
  bool _isInsuranceStopped = false;
  bool _toolsReturned = false;
  bool _materialsTransferred = false;
  bool _hasUnsettledItems = false;
  bool _initialized = false;
  bool _saving = false;
  List<PendingAttachment> _pendingAttachments = const [];

  @override
  void initState() {
    super.initState();
    _terminationDate = AppDateUtils.dateOnly(DateTime.now());
    _terminationFuture = widget.terminationId == null
        ? Future<TerminationRecord?>.value(null)
        : ref
              .read(terminationRepositoryProvider)
              .findById(widget.terminationId!);
  }

  @override
  void dispose() {
    _stopMonthController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _withBackBehavior(
      FutureBuilder<TerminationRecord?>(
        future: _terminationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _loadingScaffold();
          }
          if (snapshot.hasError) {
            return _errorScaffold('离职记录加载失败：${snapshot.error}');
          }
          if (widget.isEditing && snapshot.data == null) {
            return _errorScaffold('离职记录不存在或已被撤销');
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

  void _initialize(TerminationRecord? record) {
    if (_initialized) return;
    if (record != null) {
      _employeeId = record.employeeId;
      _terminationDate = AppDateUtils.dateOnly(record.terminationDate);
      _terminationType =
          TerminationOptions.types.contains(record.terminationType)
          ? record.terminationType
          : 'other';
      _isInsuranceStopped = record.isInsuranceStopped;
      _stopMonthController.text = record.stopInsuranceMonth ?? '';
      _toolsReturned = record.toolsReturned;
      _materialsTransferred = record.materialsTransferred;
      _hasUnsettledItems = record.hasUnsettledItems;
      _remarkController.text = record.remark ?? '';
    }
    _initialized = true;
  }

  Widget _buildForm(BuildContext context, List<Employee> allEmployees) {
    final employees = [
      for (final employee in allEmployees)
        if (employee.status != EmployeeStatus.terminated ||
            employee.id == _employeeId)
          employee,
    ];
    return Scaffold(
      appBar: AppBar(
        leading: _backButton(context),
        title: Text(widget.isEditing ? '编辑离职' : '登记离职'),
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
                color: AppColors.lightOrange,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFE98500)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '离职日当天仍可保留历史考勤，离职日之后不能登记正常考勤。停保和交接事项请按实际情况确认。',
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
                        '离职信息',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (employees.isEmpty)
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '离职人员',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          child: const Text('暂无可登记离职的在岗人员。'),
                        )
                      else
                        DropdownButtonFormField<int>(
                          key: const Key('termination-employee-field'),
                          initialValue:
                              _employeeId != null &&
                                  employees.any(
                                    (item) => item.id == _employeeId,
                                  )
                              ? _employeeId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '离职人员',
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
                          onChanged: widget.isEditing
                              ? null
                              : (value) => setState(() => _employeeId = value),
                        ),
                      const SizedBox(height: 12),
                      _dateField(
                        context: context,
                        key: const Key('termination-date-field'),
                        label: '正式离职日期',
                        value: _terminationDate,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 16),
                      _choiceChips(
                        context: context,
                        label: '离职类型',
                        options: TerminationOptions.types,
                        selected: _terminationType,
                        onSelected: (value) =>
                            setState(() => _terminationType = value),
                      ),
                      const SizedBox(height: 16),
                      _checkTile(
                        title: '已办理停保',
                        subtitle: '未勾选时将在离职列表中显示“待停保”提示。',
                        value: _isInsuranceStopped,
                        onChanged: (value) =>
                            setState(() => _isInsuranceStopped = value),
                      ),
                      if (_isInsuranceStopped) ...[
                        const SizedBox(height: 4),
                        TextFormField(
                          key: const Key('termination-stop-month-field'),
                          controller: _stopMonthController,
                          decoration: const InputDecoration(
                            labelText: '停保月份',
                            hintText: 'YYYY-MM，例如 2026-09',
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _checkTile(
                        title: '工具已归还',
                        value: _toolsReturned,
                        onChanged: (value) =>
                            setState(() => _toolsReturned = value),
                      ),
                      _checkTile(
                        title: '物资已交接',
                        value: _materialsTransferred,
                        onChanged: (value) =>
                            setState(() => _materialsTransferred = value),
                      ),
                      _checkTile(
                        title: '存在未结事项',
                        value: _hasUnsettledItems,
                        onChanged: (value) =>
                            setState(() => _hasUnsettledItems = value),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('termination-remark-field'),
                        controller: _remarkController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '离职说明',
                          hintText: '可填写交接、未结事项等说明',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AttachmentPickerCard(
                title: '离职材料',
                files: _pendingAttachments,
                onChanged: (value) =>
                    setState(() => _pendingAttachments = value),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('termination-save-button'),
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
                  label: Text(_saving ? '保存中…' : '保存离职'),
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
                label: Text(TerminationOptions.typeLabel(option)),
                selected: option == selected,
                onSelected: (_) => onSelected(option),
                selectedColor: AppColors.lightGreen,
              ),
          ],
        ),
      ],
    );
  }

  Widget _checkTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: (value) => onChanged(value ?? false),
      controlAffinity: ListTileControlAffinity.leading,
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _terminationDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _terminationDate = AppDateUtils.dateOnly(picked));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(terminationRepositoryProvider)
          .save(
            id: widget.terminationId,
            draft: TerminationRecordDraft(
              employeeId: _employeeId!,
              terminationDate: _terminationDate,
              terminationType: _terminationType,
              isInsuranceStopped: _isInsuranceStopped,
              stopInsuranceMonth: _stopMonthController.text,
              toolsReturned: _toolsReturned,
              materialsTransferred: _materialsTransferred,
              hasUnsettledItems: _hasUnsettledItems,
              remark: _remarkController.text,
            ),
          );
      final reminder = await ref
          .read(reminderRepositoryProvider)
          .findBySource('termination', saved.id);
      if (reminder != null) {
        await ref.read(reminderSchedulerProvider).reschedule(reminder.id);
      }
      await ref
          .read(attachmentRepositoryProvider)
          .importPending(
            employeeId: saved.employeeId,
            files: _pendingAttachments,
            category: 'termination',
            sourceEntityType: 'termination',
            sourceEntityId: saved.id,
          );
      if (mounted) {
        context.go(
          widget.fromHomeShortcut ? '/home' : '/attendance/termination',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  Scaffold _loadingScaffold() {
    return Scaffold(
      appBar: AppBar(
        leading: _backButton(context),
        title: Text(widget.isEditing ? '编辑离职' : '登记离职'),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(
        leading: _backButton(context),
        title: Text(widget.isEditing ? '编辑离职' : '登记离职'),
      ),
      body: Center(child: Text(message)),
    );
  }
}
