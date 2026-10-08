import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/garden_tool_repair_providers.dart';
import '../domain/repair_models.dart';

class GardenToolRepairAttachmentsPage extends ConsumerWidget {
  const GardenToolRepairAttachmentsPage({required this.groupId, super.key});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(gardenToolRepairAttachmentsProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('维修附件预览')),
      body: attachments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('附件加载失败：$error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('该维修组暂无附件'))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.74,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => _AttachmentTile(
                  attachment: items[index],
                  onTap: () => _preview(context, ref, items[index]),
                ),
              ),
      ),
    );
  }

  Future<void> _preview(
    BuildContext context,
    WidgetRef ref,
    GardenToolRepairAttachment attachment,
  ) async {
    try {
      final file = await ref
          .read(gardenToolRepairAttachmentServiceProvider)
          .resolveFile(attachment);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(_typeLabel(attachment.attachmentType)),
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('无法打开附件：$error')));
      }
    }
  }
}

class _AttachmentTile extends ConsumerWidget {
  const _AttachmentTile({required this.attachment, required this.onTap});

  final GardenToolRepairAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FutureBuilder<File>(
              future: ref
                  .read(gardenToolRepairAttachmentServiceProvider)
                  .resolveFile(attachment),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Image.file(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 40),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Icon(
                  Icons.image_outlined,
                  color: AppColors.techBlue,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(child: Text(_typeLabel(attachment.attachmentType))),
                const Icon(
                  Icons.open_in_full,
                  color: AppColors.helper,
                  size: 17,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _typeLabel(String value) => switch (value) {
  'receipt' => GardenToolRepairAttachmentType.receipt.label,
  'before' => GardenToolRepairAttachmentType.before.label,
  'after' => GardenToolRepairAttachmentType.after.label,
  _ => GardenToolRepairAttachmentType.other.label,
};
