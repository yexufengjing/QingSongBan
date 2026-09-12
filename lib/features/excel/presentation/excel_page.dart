import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../application/excel_providers.dart';
import '../application/excel_service.dart';

class ExcelPage extends ConsumerStatefulWidget {
  const ExcelPage({super.key});

  @override
  ConsumerState<ExcelPage> createState() => _ExcelPageState();
}

class _ExcelPageState extends ConsumerState<ExcelPage> {
  late DateTime _month;
  PersonnelImportPreview? _preview;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final yearMonth = AppDateUtils.yearMonth(_month);
    return Scaffold(
      appBar: AppBar(title: const Text('Excel 导入导出')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Card(
            color: AppColors.lightBlue,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '导出文件包含人员名单、月考勤表、月度汇总、请假、加班、离职和保险变更工作表。导入人员前会先完成必填项、重复值和考勤组校验。',
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
                  Text('月度导出', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '当前选择：$yearMonth',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        key: const Key('excel-previous-month'),
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _month = DateTime(
                                  _month.year,
                                  _month.month - 1,
                                ),
                              ),
                        icon: const Icon(Icons.chevron_left),
                        tooltip: '上个月',
                      ),
                      Expanded(child: Center(child: Text(yearMonth))),
                      IconButton(
                        key: const Key('excel-next-month'),
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _month = DateTime(
                                  _month.year,
                                  _month.month + 1,
                                ),
                              ),
                        icon: const Icon(Icons.chevron_right),
                        tooltip: '下个月',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('excel-export-button'),
                      onPressed: _busy ? null : () => _export(yearMonth),
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('导出 Excel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('人员名单导入', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '支持列：工号、姓名、性别、身份证号、出生日期、手机号、入职日期、岗位、班组、工作区域、负责人、用工类型、默认考勤组、备注。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('excel-import-button'),
                      onPressed: _busy ? null : _pickImportFile,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('选择人员名单文件'),
                    ),
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: 14),
                    _PreviewCard(preview: _preview!),
                    if (_preview!.canImport) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('excel-confirm-import-button'),
                          onPressed: _busy ? null : _import,
                          child: Text('确认导入 ${_preview!.rows.length} 人'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回我的'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(String yearMonth) async {
    setState(() => _busy = true);
    try {
      final file = await ref
          .read(excelServiceProvider)
          .exportToFile(yearMonth: yearMonth);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出成功：${file.path}')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImportFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    setState(() => _busy = true);
    try {
      final preview = await ref
          .read(excelServiceProvider)
          .previewPersonnelImport(bytes);
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) {
        setState(
          () => _preview = PersonnelImportPreview(
            rows: const [],
            issues: [PersonnelImportIssue(rowNumber: 1, message: '$error')],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null || !preview.canImport) return;
    setState(() => _busy = true);
    try {
      final count = await ref
          .read(excelServiceProvider)
          .importPersonnel(preview);
      if (!mounted) return;
      setState(() => _preview = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导入 $count 人')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final PersonnelImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final color = preview.issues.isEmpty ? AppColors.primary : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.issues.isEmpty
                ? '校验通过，可导入 ${preview.rows.length} 人'
                : '发现 ${preview.issues.length} 个问题，暂不能导入',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          if (preview.issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final issue in preview.issues.take(8))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(issue.toString()),
              ),
            if (preview.issues.length > 8)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('还有 ${preview.issues.length - 8} 个问题未展开'),
              ),
          ],
        ],
      ),
    );
  }
}
