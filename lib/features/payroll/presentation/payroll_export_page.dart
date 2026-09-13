// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/payroll_excel_providers.dart';

class PayrollExportPage extends ConsumerStatefulWidget {
  const PayrollExportPage({required this.batchId, super.key});

  final int batchId;

  @override
  ConsumerState<PayrollExportPage> createState() => _PayrollExportPageState();
}

class _PayrollExportPageState extends ConsumerState<PayrollExportPage> {
  bool exporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导出工资 Excel'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: FilledButton.icon(
          onPressed: exporting ? null : _export,
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
    );
  }

  Future<void> _export() async {
    setState(() => exporting = true);
    try {
      final file = await ref
          .read(payrollExcelServiceProvider)
          .exportToFile(batchId: widget.batchId);
      if (mounted) {
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
