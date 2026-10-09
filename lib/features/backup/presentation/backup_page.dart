import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/platform/app_restart.dart';
import '../application/backup_providers.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  String? _busyMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Card(
            color: AppColors.lightBlue,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '备份包包含本地 SQLite 数据库、应用配置和附件资料。恢复前会自动生成一份安全备份，恢复完成后请重启应用。',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('backup-create-button'),
                      onPressed: _busy ? null : _createBackup,
                      icon: _busy && _busyMessage == '正在创建备份…'
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.archive_outlined),
                      label: Text(
                        _busy && _busyMessage == '正在创建备份…' ? '正在创建…' : '创建备份',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('backup-restore-button'),
                      onPressed: _busy ? null : _pickRestore,
                      icon: _busy && _busyMessage == '正在恢复备份…'
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore_outlined),
                      label: Text(
                        _busy && _busyMessage == '正在恢复备份…'
                            ? '正在恢复…'
                            : '选择备份并恢复',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Card(
                    color: AppColors.lightOrange,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '恢复会覆盖当前本地数据，确认前请检查备份日期。',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_busy && _busyMessage != null) ...[
            const SizedBox(height: 12),
            Card(
              key: const Key('backup-progress'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_busyMessage!),
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
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
    final password = await _requestPassword(confirm: true);
    if (!mounted || password == null) return;
    setState(() {
      _busy = true;
      _busyMessage = '正在创建备份…';
    });
    try {
      final file = await ref
          .read(backupServiceProvider)
          .createBackup(password: password);
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
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _pickRestore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = '正在选择备份文件…';
    });
    final files =
        await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['qsbak'],
            )
            .catchError((Object error) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('打开备份文件失败：$error')));
              }
              return <PlatformFile>[];
            })
            .whenComplete(() {
              if (mounted) {
                setState(() {
                  _busy = false;
                  _busyMessage = null;
                });
              }
            });
    final path = files.isEmpty ? null : files.first.path;
    if (!mounted || path == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text('确认恢复？', textAlign: TextAlign.center),
          ],
        ),
        content: const Text(
          '当前本地数据将被备份包覆盖，恢复后需要重启应用。是否继续？',
          textAlign: TextAlign.center,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => context.pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('确认恢复'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final password = await _requestPassword();
    if (!mounted || password == null) return;
    setState(() {
      _busy = true;
      _busyMessage = '正在恢复备份…';
    });
    try {
      final result = await ref
          .read(backupServiceProvider)
          .restoreFromFile(File(path), password: password);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyMessage = null;
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              const Text('恢复完成', textAlign: TextAlign.center),
            ],
          ),
          content: Text(
            '已生成恢复前安全备份：\n${result.safetyBackup.path}\n点击确认后应用将安全重启。',
            textAlign: TextAlign.center,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      AppRestart.restart();
                    }
                  });
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('重启应用'),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('恢复失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<String?> _requestPassword({bool confirm = false}) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _BackupPasswordDialog(confirm: confirm),
    );
  }
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.confirm});

  final bool confirm;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmationVisible = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fieldStyle = Theme.of(context).textTheme.bodyMedium;
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      title: Text(
        widget.confirm ? '设置备份密码' : '输入备份密码',
        textAlign: TextAlign.center,
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.58,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('密码（至少 8 个字符）', style: fieldStyle),
              const SizedBox(height: 8),
              TextField(
                key: const Key('backup-password-field'),
                controller: _passwordController,
                obscureText: !_passwordVisible,
                autofocus: true,
                autofillHints: [
                  widget.confirm
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                textInputAction: widget.confirm
                    ? TextInputAction.next
                    : TextInputAction.done,
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  hintText: '请输入备份密码',
                  constraints: const BoxConstraints(minHeight: 56),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _passwordVisible ? '隐藏密码' : '显示密码',
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              if (widget.confirm) ...[
                const SizedBox(height: 16),
                Text('再次输入密码', style: fieldStyle),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('backup-password-confirmation-field'),
                  controller: _confirmationController,
                  obscureText: !_confirmationVisible,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    hintText: '请再次输入备份密码',
                    constraints: const BoxConstraints(minHeight: 56),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: IconButton(
                      tooltip: _confirmationVisible ? '隐藏密码' : '显示密码',
                      onPressed: () => setState(
                        () => _confirmationVisible = !_confirmationVisible,
                      ),
                      icon: Icon(
                        _confirmationVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('backup-password-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('backup-password-cancel'),
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('backup-password-submit'),
                onPressed: () {
                  final password = _passwordController.text;
                  if (password.length < 8) {
                    setState(() => _error = '密码至少需要 8 个字符');
                    return;
                  }
                  if (widget.confirm &&
                      password != _confirmationController.text) {
                    setState(() => _error = '两次输入的密码不一致');
                    return;
                  }
                  context.pop(password);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('继续'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
