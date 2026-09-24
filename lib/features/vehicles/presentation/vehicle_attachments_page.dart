import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../attachments/domain/attachment_options.dart';
import '../application/vehicle_providers.dart';
import '../domain/vehicle_attachment_options.dart';

class VehicleAttachmentsPage extends ConsumerStatefulWidget {
  const VehicleAttachmentsPage({
    required this.vehicleId,
    this.repairOrderId,
    super.key,
  });

  final int vehicleId;
  final int? repairOrderId;

  @override
  ConsumerState<VehicleAttachmentsPage> createState() =>
      _VehicleAttachmentsPageState();
}

class _VehicleAttachmentsPageState
    extends ConsumerState<VehicleAttachmentsPage> {
  VehicleAttachmentCategory? _category;
  bool _showDeleted = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId));
    final attachments = ref.watch(
      vehicleAttachmentsProvider((widget.vehicleId, _showDeleted)),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('附件资料'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            tooltip: '添加附件',
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: vehicle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('车辆加载失败：$error')),
        data: (item) {
          if (item == null) return const Center(child: Text('车辆档案不存在'));
          return attachments.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('附件加载失败：$error')),
            data: (items) => _content(context, item, items),
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

  Widget _content(
    BuildContext context,
    Vehicle vehicle,
    List<VehicleAttachment> allItems,
  ) {
    final items = allItems.where((item) {
      if (!_showDeleted && item.isDeleted) return false;
      return _category == null || item.category == _category!.name;
    }).toList();
    final validCount = allItems.where((item) => !item.isDeleted).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        Card(
          color: AppColors.lightBlue,
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.local_shipping_outlined),
            ),
            title: Text(vehicle.name),
            subtitle: Text('${vehicle.vehicleNo} · $validCount 个有效附件'),
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
            for (final category in VehicleAttachmentOptions.categories)
              ChoiceChip(
                label: Text(VehicleAttachmentOptions.categoryLabel(category)),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 52),
            child: Column(
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 52,
                  color: AppColors.helper,
                ),
                SizedBox(height: 12),
                Text('暂无附件资料'),
              ],
            ),
          )
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
  }

  Future<void> _add() async {
    final category = await _chooseCategory();
    if (category == null || !mounted) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AttachmentOptions.allowedExtensions,
      // ignore: deprecated_member_use
      allowMultiple: true,
    );
    if (result.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final selected in result) {
        if (selected.path == null) continue;
        await ref
            .read(vehicleAttachmentServiceProvider)
            .importFile(
              vehicleId: widget.vehicleId,
              sourceFile: File(selected.path!),
              originalFileName: selected.name,
              category: category,
              repairOrderId: widget.repairOrderId,
            );
      }
      ref.invalidate(
        vehicleAttachmentsProvider((widget.vehicleId, _showDeleted)),
      );
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

  Future<VehicleAttachmentCategory?> _chooseCategory() {
    return showDialog<VehicleAttachmentCategory>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('选择附件类别'),
        children: [
          for (final category in VehicleAttachmentOptions.categories)
            SimpleDialogOption(
              onPressed: () => dialogContext.pop(category),
              child: Text(VehicleAttachmentOptions.categoryLabel(category)),
            ),
        ],
      ),
    );
  }

  Future<void> _view(VehicleAttachment item) async {
    final service = ref.read(vehicleAttachmentServiceProvider);
    final integrity = await service.checkIntegrity(item);
    if (!integrity.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('文件缺失，无法查看')));
      }
      return;
    }
    if (!mounted) return;
    final file = await service.resolveFile(item);
    if (!mounted) return;
    if (!VehicleAttachmentOptions.isImage(item.extension)) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(item.originalFileName),
          content: Text(
            '${_categoryLabel(item.category)}\n${_sizeLabel(item.fileSize)}\n\n'
            '该文件类型将通过导出副本或系统文件管理器查看。',
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () async {
                dialogContext.pop();
                final result = await OpenFilex.open(file.path);
                if (result.type != ResultType.done && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('系统打开失败：${result.message}')),
                  );
                }
              },
              child: const Text('系统打开'),
            ),
            OutlinedButton(
              onPressed: () {
                dialogContext.pop();
                _export(item);
              },
              child: const Text('导出副本'),
            ),
          ],
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
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

  Future<void> _export(VehicleAttachment item) async {
    try {
      final file = await ref
          .read(vehicleAttachmentServiceProvider)
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

  Future<void> _delete(VehicleAttachment item) async {
    await ref.read(vehicleAttachmentRepositoryProvider).softDelete(item);
    ref.invalidate(
      vehicleAttachmentsProvider((widget.vehicleId, _showDeleted)),
    );
  }

  Future<void> _restore(VehicleAttachment item) async {
    try {
      await ref.read(vehicleAttachmentRepositoryProvider).restore(item);
      ref.invalidate(
        vehicleAttachmentsProvider((widget.vehicleId, _showDeleted)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('恢复失败：$error')));
      }
    }
  }

  String _categoryLabel(String value) {
    return _vehicleAttachmentCategoryLabel(value);
  }

  String _sizeLabel(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(1)} KB';
}

String _vehicleAttachmentCategoryLabel(String value) {
  final category = VehicleAttachmentCategory.values.firstWhere(
    (item) => item.name == value,
    orElse: () => VehicleAttachmentCategory.other,
  );
  return VehicleAttachmentOptions.categoryLabel(category);
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachment,
    required this.onView,
    required this.onExport,
    required this.onDelete,
    required this.onRestore,
  });

  final VehicleAttachment attachment;
  final VoidCallback onView;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => Card(
    color: attachment.isDeleted ? Colors.grey.shade100 : null,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.lightGreen,
        child: Icon(
          VehicleAttachmentOptions.isImage(attachment.extension)
              ? Icons.image_outlined
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
        '${_vehicleAttachmentCategoryLabel(attachment.category)}${attachment.isDeleted ? ' · 已删除' : ''}',
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
