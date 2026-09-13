import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../personnel/application/personnel_providers.dart';
import '../application/attachment_providers.dart';
import '../domain/attachment_options.dart';

class EmployeeAttachmentsPage extends ConsumerStatefulWidget {
  const EmployeeAttachmentsPage({required this.employeeId, super.key});

  final int employeeId;

  @override
  ConsumerState<EmployeeAttachmentsPage> createState() =>
      _EmployeeAttachmentsPageState();
}

class _EmployeeAttachmentsPageState
    extends ConsumerState<EmployeeAttachmentsPage> {
  String? _category;
  bool _showDeleted = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeProvider(widget.employeeId));
    final attachments = ref.watch(
      employeeAttachmentsProvider(widget.employeeId),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('附件资料'),
        actions: [
          IconButton(
            key: const Key('attachment-add-button'),
            tooltip: '添加附件',
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: employee.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('人员加载失败：$error')),
        data: (person) {
          if (person == null) return const Center(child: Text('人员档案不存在'));
          return attachments.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('附件加载失败：$error')),
            data: (items) => _content(person, items),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _add,
        icon: const Icon(Icons.attach_file),
        label: const Text('添加附件'),
      ),
    );
  }

  Widget _content(Employee employee, List<EmployeeAttachment> currentItems) {
    return FutureBuilder<List<EmployeeAttachment>>(
      future: _showDeleted
          ? ref
                .read(attachmentRepositoryProvider)
                .listForEmployee(employee.id, includeDeleted: true)
          : Future.value(currentItems),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? currentItems;
        final items = [
          for (final item in allItems)
            if ((_showDeleted || !item.isDeleted) &&
                (_category == null || item.category == _category))
              item,
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
          children: [
            Card(
              color: AppColors.lightBlue,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(employee.name),
                subtitle: Text(
                  '${employee.employeeNo} · ${allItems.where((e) => !e.isDeleted).length} 个有效附件',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final value in AttachmentOptions.categories)
                  ChoiceChip(
                    label: Text(AttachmentOptions.categoryLabel(value)),
                    selected: _category == value,
                    onSelected: (_) => setState(() => _category = value),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示已删除附件'),
              value: _showDeleted,
              onChanged: (value) => setState(() => _showDeleted = value),
            ),
            if (items.isEmpty)
              const _AttachmentEmpty()
            else
              for (final item in items) ...[
                _AttachmentCard(
                  attachment: item,
                  onView: () => _view(item),
                  onExport: () => _export(item),
                  onDelete: () => _delete(item),
                  onRestore: () => _restore(item),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  Future<void> _add() async {
    final category = await _chooseCategory();
    if (category == null || !mounted) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AttachmentOptions.allowedExtensions,
    );
    if (result.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final selected in result) {
        if (selected.path == null) continue;
        await ref
            .read(attachmentRepositoryProvider)
            .importFile(
              employeeId: widget.employeeId,
              sourceFile: File(selected.path!),
              originalFileName: selected.name,
              category: category,
            );
      }
      ref.invalidate(employeeAttachmentsProvider(widget.employeeId));
      ref.invalidate(employeeAttachmentCountProvider(widget.employeeId));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('附件已保存')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('添加失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _chooseCategory() {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择附件类别'),
        children: [
          for (final value in AttachmentOptions.categories)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(AttachmentOptions.categoryLabel(value)),
            ),
        ],
      ),
    );
  }

  Future<void> _view(EmployeeAttachment item) async {
    if (!AttachmentOptions.isImage(item.extension)) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.originalFileName),
          content: Text(
            '${AttachmentOptions.categoryLabel(item.category)}\n${_sizeLabel(item.fileSize)}\n\n此类文件可导出副本后查看。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
      return;
    }
    if (AttachmentOptions.isSensitive(item.category)) {
      final reveal = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('查看敏感附件'),
          content: const Text('该图片可能包含身份证或银行卡信息，是否显示原图？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('显示原图'),
            ),
          ],
        ),
      );
      if (reveal != true) return;
    }
    final file = await ref.read(attachmentRepositoryProvider).resolveFile(item);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.file(
            file,
            errorBuilder: (_, error, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('图片读取失败：$error'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _export(EmployeeAttachment item) async {
    try {
      final file = await ref
          .read(attachmentRepositoryProvider)
          .resolveFile(item);
      if (!await file.exists()) throw StateError('附件文件已丢失');
      final path = await FilePicker.saveFile(
        dialogTitle: '导出附件副本',
        fileName: item.originalFileName,
        bytes: await file.readAsBytes(),
      );
      if (mounted && path != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已导出：$path')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$error')));
      }
    }
  }

  Future<void> _delete(EmployeeAttachment item) async {
    await ref.read(attachmentRepositoryProvider).softDelete(item);
    ref.invalidate(employeeAttachmentsProvider(widget.employeeId));
    ref.invalidate(employeeAttachmentCountProvider(widget.employeeId));
  }

  Future<void> _restore(EmployeeAttachment item) async {
    try {
      await ref.read(attachmentRepositoryProvider).restore(item);
      ref.invalidate(employeeAttachmentsProvider(widget.employeeId));
      ref.invalidate(employeeAttachmentCountProvider(widget.employeeId));
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('恢复失败：$error')));
      }
    }
  }

  String _sizeLabel(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(1)} KB';
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachment,
    required this.onView,
    required this.onExport,
    required this.onDelete,
    required this.onRestore,
  });
  final EmployeeAttachment attachment;
  final VoidCallback onView;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: attachment.isDeleted ? Colors.grey.shade100 : null,
      child: ListTile(
        key: Key('attachment-${attachment.id}'),
        leading: CircleAvatar(
          backgroundColor: AppColors.lightGreen,
          child: Icon(
            AttachmentOptions.isSensitive(attachment.category)
                ? Icons.shield_outlined
                : Icons.description_outlined,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          attachment.originalFileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${AttachmentOptions.categoryLabel(attachment.category)}${attachment.isDeleted ? ' · 已删除' : ''}',
        ),
        onTap: attachment.isDeleted ? null : onView,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'view') onView();
            if (value == 'export') onExport();
            if (value == 'delete') onDelete();
            if (value == 'restore') onRestore();
          },
          itemBuilder: (_) => attachment.isDeleted
              ? const [PopupMenuItem(value: 'restore', child: Text('恢复'))]
              : const [
                  PopupMenuItem(value: 'view', child: Text('查看')),
                  PopupMenuItem(value: 'export', child: Text('导出副本')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
        ),
      ),
    );
  }
}

class _AttachmentEmpty extends StatelessWidget {
  const _AttachmentEmpty();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(Icons.folder_open_outlined, size: 52, color: AppColors.helper),
        SizedBox(height: 12),
        Text('暂无附件资料'),
        SizedBox(height: 4),
        Text('可添加身份证、银行卡、保险或离职材料'),
      ],
    ),
  );
}
