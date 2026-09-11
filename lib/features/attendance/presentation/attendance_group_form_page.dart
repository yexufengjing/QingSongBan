import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/attendance_group_providers.dart';
import '../domain/attendance_group_options.dart';

class AttendanceGroupFormPage extends ConsumerStatefulWidget {
  const AttendanceGroupFormPage({this.groupId, super.key});

  final int? groupId;

  bool get isEditing => groupId != null;

  @override
  ConsumerState<AttendanceGroupFormPage> createState() =>
      _AttendanceGroupFormPageState();
}

class _AttendanceGroupFormPageState
    extends ConsumerState<AttendanceGroupFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');
  final _remarkController = TextEditingController();

  late final Future<AttendanceGroup?> _groupFuture;
  bool _enabled = true;
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _groupFuture = widget.groupId == null
        ? Future<AttendanceGroup?>.value(null)
        : ref.read(attendanceGroupRepositoryProvider).findById(widget.groupId!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sortOrderController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AttendanceGroup?>(
      future: _groupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.isEditing ? '编辑考勤组' : '新增考勤组')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.isEditing ? '编辑考勤组' : '新增考勤组')),
            body: Center(child: Text('考勤组加载失败：${snapshot.error}')),
          );
        }
        if (widget.isEditing && snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('编辑考勤组')),
            body: const Center(child: Text('考勤组不存在或已被移除')),
          );
        }

        _initialize(snapshot.data);
        return _buildForm(context);
      },
    );
  }

  void _initialize(AttendanceGroup? group) {
    if (_initialized) {
      return;
    }
    _nameController.text = group?.name ?? '';
    _sortOrderController.text = '${group?.sortOrder ?? 0}';
    _remarkController.text = group?.remark ?? '';
    _enabled = group?.isEnabled ?? true;
    _initialized = true;
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑考勤组' : '新增考勤组'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Card(
              color: AppColors.lightGreen,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.groups_outlined, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '考勤组用于配置人员的默认考勤范围。临时工的全量筛选仍按“用工类型”动态完成，不建立“全部临时工”实体组。',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.ink),
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
                    Text('基本设置', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('attendance-group-name-field'),
                      controller: _nameController,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请填写考勤组名称'
                          : null,
                      decoration: const InputDecoration(
                        labelText: '考勤组名称',
                        hintText: '例如：特钢临时工组、司机组',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '考勤组类型',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      child: Text(
                        '手动分组',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('attendance-group-sort-field'),
                      controller: _sortOrderController,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final number = int.tryParse(value?.trim() ?? '');
                        return number == null || number < 0
                            ? '请输入不小于 0 的整数'
                            : null;
                      },
                      decoration: const InputDecoration(
                        labelText: '排序值',
                        hintText: '数值越小越靠前',
                        prefixIcon: Icon(Icons.sort_outlined),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用考勤组'),
                      subtitle: const Text('停用后不会出现在新的默认组选择中'),
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('attendance-group-remark-field'),
                      controller: _remarkController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        hintText: '可填写适用区域、负责人等补充说明',
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
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
                label: Text(_saving ? '保存中…' : '保存考勤组'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final group = await ref
          .read(attendanceGroupRepositoryProvider)
          .save(
            id: widget.groupId,
            draft: AttendanceGroupDraft(
              name: _nameController.text,
              isEnabled: _enabled,
              sortOrder: int.parse(_sortOrderController.text.trim()),
              remark: _remarkController.text,
            ),
          );
      if (!mounted) {
        return;
      }
      context.go('/attendance/groups/${group.id}');
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
  }
}
