import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'dart:io';

import '../domain/attachment_options.dart';

class AttachmentPickerCard extends StatelessWidget {
  const AttachmentPickerCard({
    required this.files,
    required this.onChanged,
    required this.title,
    super.key,
  });

  final List<PendingAttachment> files;
  final ValueChanged<List<PendingAttachment>> onChanged;
  final String title;

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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('attachment-pick-button'),
                  onPressed: () => _pick(context),
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('选择文件'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '支持图片、PDF、Word、Excel，单个文件不超过 20MB。文件将在保存业务记录后复制到应用内。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (files.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var index = 0; index < files.length; index++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(files[index].name),
                  subtitle: Text(_sizeLabel(files[index].size)),
                  trailing: IconButton(
                    tooltip: '移除待上传文件',
                    onPressed: () {
                      final next = [...files]..removeAt(index);
                      onChanged(next);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AttachmentOptions.allowedExtensions,
    );
    if (result.isEmpty) return;
    final next = [...files];
    for (final selected in result) {
      final path = selected.path;
      if (path == null) continue;
      final size = await File(path).length();
      if (size > AttachmentOptions.maxFileSize) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${selected.name} 超过 20MB，未加入')),
          );
        }
        continue;
      }
      next.add(PendingAttachment(path: path, name: selected.name, size: size));
    }
    onChanged(next);
  }

  String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}
