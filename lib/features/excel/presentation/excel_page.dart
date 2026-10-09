import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../application/excel_providers.dart';
import '../application/excel_service.dart';

class ExcelPage extends ConsumerStatefulWidget {
  const ExcelPage({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  ConsumerState<ExcelPage> createState() => _ExcelPageState();
}

class _ExcelPageState extends ConsumerState<ExcelPage> {
  late DateTime _month;
  PersonnelImportPreview? _preview;
  bool _busy = false;
  String? _busyMessage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth ?? DateTime.now();
    _month = DateTime(initial.year, initial.month);
  }

  @override
  Widget build(BuildContext context) {
    final yearMonth = AppDateUtils.yearMonth(_month);
    return Scaffold(
      appBar: AppBar(title: const Text('Excel 导入导出'), centerTitle: true),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('返回我的'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (_busy && _busyMessage != null) ...[
            Card(
              key: const Key('excel-progress'),
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
            const SizedBox(height: 12),
          ],
          Card(
            color: AppColors.lightBlue,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '导出文件包含人员名单、月考勤表、月度汇总、请假、加班、离职和保险变更工作表。导入人员前会先完成必填项、重复值和考勤组校验。',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('月度导出', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('月份', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('人员名单导入', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final entry in const [
                        (0, '选文件'),
                        (1, '核验'),
                        (2, '导入'),
                      ])
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: entry.$1 == _activeImportStep
                                    ? AppColors.primary
                                    : AppColors.lightBlue,
                                child: Text(
                                  '${entry.$1 + 1}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: entry.$1 == _activeImportStep
                                        ? Colors.white
                                        : AppColors.body,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                entry.$2,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('支持字段（14项）'),
                    children: [
                      Text(
                        '支持列：工号、姓名、性别、身份证号、出生日期、手机号、入职日期、岗位、班组、工作区域、负责人、用工类型、默认考勤组、备注。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('excel-import-button'),
                      onPressed: _busy ? null : _pickImportFile,
                      icon:
                          _busy &&
                              (_busyMessage == '正在选择人员名单文件…' ||
                                  _busyMessage == '正在核验人员名单…')
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_upload_outlined),
                      label: Text(
                        _busy &&
                                (_busyMessage == '正在选择人员名单文件…' ||
                                    _busyMessage == '正在核验人员名单…')
                            ? _busyMessage!
                            : '选择人员名单文件',
                      ),
                    ),
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: 14),
                    _PreviewCard(preview: _preview!),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('excel-confirm-import-button'),
                        onPressed: _busy || !_preview!.canImport
                            ? null
                            : _import,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: _busy && _busyMessage == '正在导入人员…'
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text('确认导入 ${_preview!.rows.length} 人'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  int get _activeImportStep => _busy && _busyMessage == '正在导入人员…'
      ? 2
      : _preview == null
      ? 0
      : 1;

  Future<void> _export(String yearMonth) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = '正在生成 Excel…';
    });
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
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _pickImportFile() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = '正在选择人员名单文件…';
    });
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (!mounted || files.isEmpty) return;
      setState(() => _busyMessage = '正在核验人员名单…');
      final bytes = await files.first.readAsBytes();
      final preview = await ref
          .read(excelServiceProvider)
          .previewPersonnelImport(bytes);
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busyMessage = null;
          _preview = PersonnelImportPreview(
            rows: const [],
            issues: [PersonnelImportIssue(rowNumber: 1, message: '$error')],
          );
        });
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

  Future<void> _import() async {
    final preview = _preview;
    if (_busy || preview == null || !preview.canImport) return;
    setState(() {
      _busy = true;
      _busyMessage = '正在导入人员…';
    });
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
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final PersonnelImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final color = preview.issues.isEmpty
        ? AppColors.success
        : AppColors.warning;
    final status = preview.issues.isNotEmpty
        ? '发现 ${preview.issues.length} 个问题，暂不能导入'
        : preview.rows.isEmpty
        ? '没有可导入的人员记录'
        : '校验通过，可导入 ${preview.rows.length} 人';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                preview.issues.isEmpty
                    ? preview.rows.isEmpty
                          ? Icons.info_outline
                          : Icons.check_circle_outline
                    : Icons.error_outline,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
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
