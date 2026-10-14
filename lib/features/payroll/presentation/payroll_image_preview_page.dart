import 'package:flutter/material.dart';

import '../../../core/widgets/table_image_preview_page.dart';
import '../domain/payroll_export_snapshot.dart';
import 'payroll_image.dart';

class PayrollImagePreviewPage extends StatelessWidget {
  const PayrollImagePreviewPage({super.key, required this.snapshot});
  final PayrollExportSnapshot snapshot;

  @override
  Widget build(BuildContext context) => TableImagePreviewPage(
    title: '工资图片预览',
    heading: snapshot.batchName,
    description: '${snapshot.payrollMonth} · ${snapshot.rows.length}人 · 一张完整图片',
    fileNamePrefix: '工资表_${snapshot.payrollMonth}_${snapshot.batchName}',
    semanticLabel: '${snapshot.batchName}${snapshot.payrollMonth}完整工资表',
    previewKey: const Key('payroll-image-preview'),
    saveKey: const Key('payroll-image-save'),
    generate: () => PayrollImageRenderer.render(snapshot),
  );
}
