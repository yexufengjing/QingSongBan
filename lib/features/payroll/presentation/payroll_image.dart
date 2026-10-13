import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/table_image.dart';
import '../domain/payroll_export_snapshot.dart';

class PayrollImageRenderer {
  static const _margin = 24.0;
  static const _scale = 3.0;

  static Future<TableImage> render(PayrollExportSnapshot snapshot) async {
    final painters = <TextPainter>[];
    TextPainter text(
      String value, {
      double size = 14,
      double maxWidth = double.infinity,
      FontWeight weight = FontWeight.w400,
      Color color = AppColors.ink,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            color: color,
            height: 1.4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      painters.add(painter);
      return painter;
    }

    final rows = [
      for (final row in [...snapshot.rows, snapshot.totalRow])
        [
          for (var col = 0; col < row.length; col++)
            PayrollExportSnapshot.formatCell(row[col], col),
        ],
    ];
    // Text columns wrap without ellipses; numeric columns fit every amount.
    final widths = <double>[56, 112, 120, 112, 88, 96, 112, 96, 112, 128, 240];
    for (var col = 0; col < widths.length - 1; col++) {
      for (final row in rows) {
        final measured = text(row[col]).width + 24;
        widths[col] = math.max(
          widths[col],
          col < 4 ? math.min(200, measured) : measured,
        );
      }
    }
    final tableWidth = widths.fold<double>(0, (sum, width) => sum + width);
    final month = DateTime.parse('${snapshot.payrollMonth}-01');
    final title = text(
      '${month.year}年${month.month}月工资表',
      size: 24,
      weight: FontWeight.w700,
    );
    final subtitle = text(
      '${snapshot.batchName} · ${snapshot.rows.length}人',
      color: AppColors.body,
      maxWidth: tableWidth,
    );
    final tableTop = _margin + title.height + 8 + subtitle.height + 20;
    final cells = [
      for (var row = 0; row < rows.length; row++)
        [
          for (var col = 0; col < widths.length; col++)
            text(
              rows[row][col],
              maxWidth: widths[col] - 24,
              weight: row == rows.length - 1 || col == 9
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: col == 9 ? AppColors.primary : AppColors.ink,
            ),
        ],
    ];
    final rowHeights = [
      for (final row in cells)
        math.max(
          48.0,
          row.fold<double>(0, (height, cell) => math.max(height, cell.height)) +
              24,
        ),
    ];
    const headerHeight = 48.0;
    final footer = text('金额单位：元 · 出勤单位：天', size: 12, color: AppColors.body);
    final tableBottom =
        tableTop +
        headerHeight +
        rowHeights.fold<double>(0, (sum, height) => sum + height);
    final width = ((tableWidth + _margin * 2) * _scale).ceil();
    final height = ((tableBottom + 16 + footer.height + _margin) * _scale)
        .ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    canvas.drawColor(AppColors.card, BlendMode.src);
    title.paint(canvas, const Offset(_margin, _margin));
    subtitle.paint(canvas, Offset(_margin, _margin + title.height + 8));
    void box(double x, double y, double w, double h, Color color) {
      final rect = Rect.fromLTWH(x, y, w, h);
      canvas.drawRect(rect, Paint()..color = color);
      canvas.drawRect(
        rect,
        Paint()
          ..color = AppColors.divider
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    }

    var x = _margin;
    for (var col = 0; col < widths.length; col++) {
      box(
        x,
        tableTop,
        widths[col],
        headerHeight,
        col == 9 ? AppColors.primary : AppColors.lightBlue,
      );
      final label = text(
        PayrollExportSnapshot.headers[col],
        weight: FontWeight.w600,
        color: col == 9 ? AppColors.card : AppColors.ink,
      );
      label.paint(
        canvas,
        Offset(
          x + (widths[col] - label.width) / 2,
          tableTop + (headerHeight - label.height) / 2,
        ),
      );
      x += widths[col];
    }
    var y = tableTop + headerHeight;
    for (var row = 0; row < cells.length; row++) {
      x = _margin;
      for (var col = 0; col < widths.length; col++) {
        final cell = cells[row][col];
        box(
          x,
          y,
          widths[col],
          rowHeights[row],
          row == cells.length - 1 || col == 9
              ? AppColors.lightBlue
              : AppColors.card,
        );
        final offsetX = col >= 4 && col <= 9
            ? x + widths[col] - 12 - cell.width
            : col == 0
            ? x + (widths[col] - cell.width) / 2
            : x + 12;
        cell.paint(
          canvas,
          Offset(offsetX, y + (rowHeights[row] - cell.height) / 2),
        );
        x += widths[col];
      }
      y += rowHeights[row];
    }
    footer.paint(canvas, Offset(_margin, tableBottom + 16));
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('工资图片生成失败');
        return TableImage(bytes.buffer.asUint8List(), width, height);
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
}
