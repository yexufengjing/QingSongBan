import 'package:flutter/material.dart';

import '../../../core/widgets/table_image_preview_page.dart';
import 'monthly_attendance_image.dart';

class MonthlyAttendanceImagePreviewPage extends StatelessWidget {
  const MonthlyAttendanceImagePreviewPage({super.key, required this.snapshot});
  final MonthlyAttendanceImageSnapshot snapshot;

  @override
  Widget build(BuildContext context) => TableImagePreviewPage(
    title: '考勤图片预览',
    heading:
        '${snapshot.month.year}年${snapshot.month.month}月 · ${snapshot.groupName}',
    description: '${snapshot.rows.length}人 · ${snapshot.daysInMonth}天 · 一张完整图片',
    fileNamePrefix: '月考勤表_${snapshot.yearMonth}_${snapshot.groupName}',
    semanticLabel: '${snapshot.groupName}${snapshot.yearMonth}完整月考勤表',
    previewKey: const Key('monthly-attendance-image-preview'),
    saveKey: const Key('monthly-attendance-image-save'),
    generate: () => MonthlyAttendanceImageRenderer.render(snapshot),
  );
}
