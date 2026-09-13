import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/backup_providers.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Card(
            color: AppColors.lightBlue,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '备份包包含本地 SQLite 数据库、应用配置和附件资料。恢复前会自动生成一份安全备份，恢复完成后请重启应用。',
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('backup-create-button'),
                      onPressed: _busy ? null : _createBackup,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('创建备份'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('backup-restore-button'),
                      onPressed: _busy ? null : _pickRestore,
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('选择备份并恢复'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '恢复会覆盖当前本地数据，确认前请检查备份日期。',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Colors.orange.shade800),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回我的'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final file = await ref.read(backupServiceProvider).createBackup();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('备份已创建：${file.path}')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建备份失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickRestore() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['qsbak'],
    );
    final path = files.isEmpty ? null : files.first.path;
    if (!mounted || path == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认恢复？'),
        content: const Text('当前本地数据将被备份包覆盖，恢复后需要重启应用。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(backupServiceProvider)
          .restoreFromFile(File(path));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('恢复完成'),
          content: Text('已生成恢复前安全备份：${result.safetyBackup.path}\n请关闭并重新打开应用。'),
          actions: [
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('恢复失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
