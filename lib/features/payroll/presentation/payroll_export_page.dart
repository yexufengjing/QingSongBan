// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import 'payroll_image_preview_page.dart';
import '../application/payroll_providers.dart';
import '../application/payroll_excel_providers.dart';

class PayrollExportPage extends ConsumerStatefulWidget {
  const PayrollExportPage({required this.batchId, super.key});

  final int batchId;

  @override
  ConsumerState<PayrollExportPage> createState() => _PayrollExportPageState();
}

class _PayrollExportPageState extends ConsumerState<PayrollExportPage> {
  bool exporting = false;
  bool previewing = false;
  String? exportedPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导出工资表'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: exporting || previewing ? null : _export,
                  icon: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined),
                  label: Text(exporting ? '正在生成…' : '导出临时工工资表'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('payroll-preview-button'),
                  onPressed: exporting || previewing ? null : _preview,
                  icon: previewing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.table_view_outlined),
                  label: Text(previewing ? '正在读取…' : '在应用内查看表格'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          ref
              .watch(payrollBatchProvider(widget.batchId))
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
                data: (batch) => batch == null
                    ? const SizedBox.shrink()
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batch.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${batch.employeeCount}人',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
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
                    '文件保存到系统下载目录，导出包含完整数据。',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '完整工资表可放大预览，并保存图片到相册。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (exportedPath != null) ...[
            const SizedBox(height: 16),
            _ExportedFileCard(path: exportedPath!),
          ],
        ],
      ),
    );
  }

  Future<void> _preview() async {
    setState(() => previewing = true);
    try {
      final snapshot = await ref
          .read(payrollExcelServiceProvider)
          .loadSnapshot(batchId: widget.batchId);
      if (!mounted) return;
      if (snapshot.rows.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('当前工资批次暂无可导出人员')));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PayrollImagePreviewPage(snapshot: snapshot),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('读取失败：$error')));
      }
    } finally {
      if (mounted) setState(() => previewing = false);
    }
  }

  Future<void> _export() async {
    setState(() => exporting = true);
    try {
      final file = await ref
          .read(payrollExcelServiceProvider)
          .exportToFile(batchId: widget.batchId);
      if (mounted) {
        setState(() => exportedPath = file.path);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已导出：${file.path}')));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$error')));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }
}

class _ExportedFileCard extends StatelessWidget {
  const _ExportedFileCard({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightGreen,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '文件已保存到：\n$path',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
