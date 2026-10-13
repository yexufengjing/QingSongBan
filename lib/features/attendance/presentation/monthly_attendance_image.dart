import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/table_image.dart';
import '../domain/monthly_attendance_table_options.dart';
import 'monthly_attendance_visuals.dart';

/// Materializes the displayed month once, so preview and saved PNG are identical.
class MonthlyAttendanceImageSnapshot {
  MonthlyAttendanceImageSnapshot({
    required this.groupName,
    required MonthlyAttendanceTableView table,
  }) : yearMonth = table.yearMonth,
       daysInMonth = table.daysInMonth,
       totalAttendanceDays = table.totalAttendanceDays,
       totalLeaveDays = table.totalLeaveDays,
       rows = List.unmodifiable([
         for (final row in table.rows)
           MonthlyAttendanceImageRow(
             name: row.employee.name,
             employeeNo: row.employee.employeeNo,
             attendanceDays: row.attendanceDays,
             leaveDays: row.leaveDays,
             cells: List.unmodifiable([
               for (var day = 1; day <= table.daysInMonth; day++)
                 row.cellForDay(
                   month: DateTime.parse('${table.yearMonth}-01'),
                   day: day,
                 ),
             ]),
           ),
       ]);

  final String groupName;
  final String yearMonth;
  final int daysInMonth;
  final List<MonthlyAttendanceImageRow> rows;
  final double totalAttendanceDays;
  final double totalLeaveDays;
  DateTime get month => DateTime.parse('$yearMonth-01');
}

class MonthlyAttendanceImageRow {
  const MonthlyAttendanceImageRow({
    required this.name,
    required this.employeeNo,
    required this.attendanceDays,
    required this.leaveDays,
    required this.cells,
  });

  final String name;
  final String employeeNo;
  final double attendanceDays;
  final double leaveDays;
  final List<MonthlyAttendanceCell> cells;
}

typedef MonthlyAttendanceImage = TableImage;

/// Paints the complete table without viewport clipping or scroll stitching.
class MonthlyAttendanceImageRenderer {
  static const _margin = 24.0;
  static const _dayWidth = 40.0;
  static const _tailWidth = 54.0;
  static const _rowHeight = 48.0;
  static const _headerHeight = 46.0;
  static const _totalHeight = 44.0;
  static const _scale = 3.0;

  static Future<MonthlyAttendanceImage> render(
    MonthlyAttendanceImageSnapshot snapshot,
  ) async {
    final painters = <TextPainter>[];
    TextPainter text(
      String value,
      double fontSize, {
      Color color = AppColors.ink,
      FontWeight weight = FontWeight.w400,
      double maxWidth = double.infinity,
    }) {
      final painter = _text(
        value,
        fontSize,
        color: color,
        weight: weight,
        maxWidth: maxWidth,
      );
      painters.add(painter);
      return painter;
    }

    final nameWidth = snapshot.rows.fold<double>(112, (width, row) {
      return math.max(
        width,
        math.max(text(row.name, 14).width, text(row.employeeNo, 10).width) + 24,
      );
    });
    final tableWidth =
        nameWidth + snapshot.daysInMonth * _dayWidth + _tailWidth * 2;
    final title = text(
      '${snapshot.month.year}年${snapshot.month.month}月考勤表',
      24,
      weight: FontWeight.w700,
    );
    final subtitle = text(
      '${snapshot.groupName} · ${snapshot.rows.length}人',
      14,
      color: AppColors.body,
      maxWidth: tableWidth,
    );
    final tableTop = _margin + title.height + 8 + subtitle.height + 20;
    final tableBottom =
        tableTop +
        _headerHeight +
        snapshot.rows.length * _rowHeight +
        _totalHeight;
    final legend = text(
      '符号说明：力 全天出勤    半 半天出勤    🔺 缺勤    休 公休    '
      '停 停工    假 请假    · 未登记    未 入职前    离 离职后',
      13,
      color: AppColors.body,
      maxWidth: tableWidth,
    );
    final width = ((tableWidth + _margin * 2) * _scale).ceil();
    final height = ((tableBottom + 16 + legend.height + _margin) * _scale)
        .ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    canvas.drawColor(AppColors.card, BlendMode.src);
    title.paint(canvas, const Offset(_margin, _margin));
    subtitle.paint(canvas, Offset(_margin, _margin + title.height + 8));

    void box(double x, double y, double w, double h, Color background) {
      final rect = Rect.fromLTWH(x, y, w, h);
      canvas.drawRect(rect, Paint()..color = background);
      canvas.drawRect(
        rect,
        Paint()
          ..color = AppColors.divider
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
    }

    void centered(
      String value,
      double x,
      double y,
      double w,
      double h, {
      Color color = AppColors.ink,
      FontWeight weight = FontWeight.w400,
    }) {
      final label = text(value, 14, color: color, weight: weight);
      label.paint(
        canvas,
        Offset(x + (w - label.width) / 2, y + (h - label.height) / 2),
      );
    }

    var x = _margin;
    box(x, tableTop, nameWidth, _headerHeight, AppColors.lightBlue);
    centered('姓名 / 工号', x, tableTop, nameWidth, _headerHeight);
    x += nameWidth;
    for (var day = 1; day <= snapshot.daysInMonth; day++) {
      box(x, tableTop, _dayWidth, _headerHeight, AppColors.lightBlue);
      centered('$day', x, tableTop + 4, _dayWidth, 22);
      final weekday = text(
        monthlyAttendanceWeekday(
          DateTime(snapshot.month.year, snapshot.month.month, day).weekday,
        ),
        10,
        color: AppColors.body,
      );
      weekday.paint(
        canvas,
        Offset(x + (_dayWidth - weekday.width) / 2, tableTop + 27),
      );
      x += _dayWidth;
    }
    box(x, tableTop, _tailWidth, _headerHeight, AppColors.lightGreen);
    centered('出勤', x, tableTop, _tailWidth, _headerHeight);
    box(
      x + _tailWidth,
      tableTop,
      _tailWidth,
      _headerHeight,
      const Color(0xFFF0EAFF),
    );
    centered('请假', x + _tailWidth, tableTop, _tailWidth, _headerHeight);

    var y = tableTop + _headerHeight;
    for (final row in snapshot.rows) {
      x = _margin;
      box(x, y, nameWidth, _rowHeight, AppColors.card);
      final name = text(row.name, 14, weight: FontWeight.w600);
      final employeeNo = text(row.employeeNo, 10, color: AppColors.body);
      final nameTop =
          y + (_rowHeight - name.height - 3 - employeeNo.height) / 2;
      name.paint(canvas, Offset(x + 12, nameTop));
      employeeNo.paint(canvas, Offset(x + 12, nameTop + name.height + 3));
      x += nameWidth;
      for (final cell in row.cells) {
        box(x, y, _dayWidth, _rowHeight, AppColors.card);
        final color = monthlyAttendanceCellColor(cell);
        final symbol = text(
          cell.symbol,
          14,
          color: color,
          weight: FontWeight.w700,
        );
        final badge = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + _dayWidth / 2, y + _rowHeight / 2),
            width: symbol.width + 14,
            height: symbol.height + 8,
          ),
          const Radius.circular(7),
        );
        canvas.drawRRect(badge, Paint()..color = color.withValues(alpha: .12));
        symbol.paint(
          canvas,
          Offset(
            x + (_dayWidth - symbol.width) / 2,
            y + (_rowHeight - symbol.height) / 2,
          ),
        );
        x += _dayWidth;
      }
      box(x, y, _tailWidth, _rowHeight, AppColors.lightGreen);
      centered(
        monthlyAttendanceFormatDays(row.attendanceDays),
        x,
        y,
        _tailWidth,
        _rowHeight,
      );
      box(x + _tailWidth, y, _tailWidth, _rowHeight, const Color(0xFFF0EAFF));
      centered(
        monthlyAttendanceFormatDays(row.leaveDays),
        x + _tailWidth,
        y,
        _tailWidth,
        _rowHeight,
      );
      y += _rowHeight;
    }
    box(_margin, y, nameWidth, _totalHeight, AppColors.lightGreen);
    centered(
      '合计',
      _margin,
      y,
      nameWidth,
      _totalHeight,
      weight: FontWeight.w600,
    );
    x = _margin + nameWidth;
    for (var day = 1; day <= snapshot.daysInMonth; day++) {
      box(x, y, _dayWidth, _totalHeight, AppColors.card);
      x += _dayWidth;
    }
    box(x, y, _tailWidth, _totalHeight, AppColors.lightGreen);
    centered(
      monthlyAttendanceFormatDays(snapshot.totalAttendanceDays),
      x,
      y,
      _tailWidth,
      _totalHeight,
      weight: FontWeight.w600,
    );
    box(x + _tailWidth, y, _tailWidth, _totalHeight, const Color(0xFFF0EAFF));
    centered(
      monthlyAttendanceFormatDays(snapshot.totalLeaveDays),
      x + _tailWidth,
      y,
      _tailWidth,
      _totalHeight,
      weight: FontWeight.w600,
    );
    legend.paint(canvas, Offset(_margin, tableBottom + 16));
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('无法生成考勤图片');
        return MonthlyAttendanceImage(data.buffer.asUint8List(), width, height);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
      for (final painter in painters) {
        painter.dispose();
      }
    }
  }

  static TextPainter _text(
    String value,
    double fontSize, {
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w400,
    double maxWidth = double.infinity,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: weight,
        height: 1.4,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
}
