// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_utils.dart';
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
  List<List<String>>? previewRows;

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '模拟器未安装 Excel 时，也可以直接在轻松办内查看表格。',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '导出文件仍会保存到系统“下载”目录，方便后续传到电脑或用表格应用打开。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
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
          if (exportedPath != null) ...[
            const SizedBox(height: 16),
            _ExportedFileCard(path: exportedPath!),
          ],
          if (previewRows != null) ...[
            const SizedBox(height: 16),
            _PayrollPreviewCard(rows: previewRows!),
          ],
        ],
      ),
    );
  }

  Future<void> _preview() async {
    setState(() => previewing = true);
    try {
      final bytes = await ref
          .read(payrollExcelServiceProvider)
          .exportBytes(batchId: widget.batchId);
      final workbook = Excel.decodeBytes(bytes);
      final sheet = workbook['临时工工资'];
      final rows = sheet.rows
          .map((row) => row.map(_cellText).toList(growable: false))
          .toList(growable: false);
      if (mounted) setState(() => previewRows = rows);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('读取失败：$error')));
      }
    } finally {
      if (mounted) setState(() => previewing = false);
    }
  }

  String _cellText(Data? data) {
    final value = data?.value;
    return switch (value) {
      null => '',
      TextCellValue value => value.value.text ?? '',
      IntCellValue value => value.value.toString(),
      DoubleCellValue value => value.value.toString(),
      BoolCellValue value => value.value ? '是' : '否',
      DateCellValue value => AppDateUtils.formatDate(value.asDateTimeLocal()),
      DateTimeCellValue value => value.asDateTimeLocal().toString(),
      _ => value.toString(),
    };
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
      color: const Color(0xFFE8F8EF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00C16B)),
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

class _PayrollPreviewCard extends StatelessWidget {
  const _PayrollPreviewCard({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final visibleRows = rows.length > 12
        ? <List<String>>[rows.first, ...rows.skip(1).take(10), rows.last]
        : rows;
    final peopleCount = rows.length > 2 ? rows.length - 2 : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('工资表预览', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '共 $peopleCount 人，左右滑动查看完整列。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder.all(color: const Color(0xFFE5EAF0)),
                children: List.generate(
                  visibleRows.length,
                  (index) => TableRow(
                    decoration: BoxDecoration(
                      color: index == 0
                          ? const Color(0xFFE8F1FF)
                          : Colors.white,
                    ),
                    children: visibleRows[index]
                        .map(
                          (cell) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            child: Text(
                              cell,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF0F2746),
                                    fontWeight: index == 0
                                        ? FontWeight.w600
                                        : null,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            if (rows.length > visibleRows.length) ...[
              const SizedBox(height: 8),
              Text(
                '预览最多显示前 10 条明细，导出文件包含完整数据。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
