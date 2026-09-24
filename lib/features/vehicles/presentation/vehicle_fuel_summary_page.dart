import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/vehicle_providers.dart';
import '../domain/fuel_year_summary_options.dart';
import 'vehicle_navigation_bar.dart';
import 'vehicle_metric_grid.dart';

class VehicleFuelSummaryPage extends ConsumerStatefulWidget {
  const VehicleFuelSummaryPage({super.key});

  @override
  ConsumerState<VehicleFuelSummaryPage> createState() =>
      _VehicleFuelSummaryPageState();
}

class _VehicleFuelSummaryPageState
    extends ConsumerState<VehicleFuelSummaryPage> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(fuelYearSummaryProvider(_year));
    return Scaffold(
      appBar: AppBar(
        title: const Text('年度油耗汇总'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            tooltip: '选择年份',
            onPressed: _pickYear,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      bottomNavigationBar: const VehicleNavigationBar(),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('年度油耗加载失败：$error')),
        data: (value) => _content(context, value),
      ),
    );
  }

  Widget _content(BuildContext context, FuelYearSummary summary) {
    final current = summary.currentMonth;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _YearBar(
            year: _year,
            onPrevious: () => setState(() => _year--),
            onNext: () => setState(() => _year++),
            onPick: _pickYear,
          ),
          const SizedBox(height: 12),
          _MetricGrid(summary: summary, current: current),
          if (summary.anomalies.isNotEmpty) ...[
            const SizedBox(height: 16),
            _NoticeCard(
              title: '数据异常提示',
              color: AppColors.lightOrange,
              icon: Icons.warning_amber_outlined,
              children: [
                for (final item in summary.anomalies.take(8))
                  Text('${item.vehicleName} ${item.month}月：${item.message}'),
              ],
            ),
          ],
          if (_missingForDisplay(summary).isNotEmpty) ...[
            const SizedBox(height: 12),
            _NoticeCard(
              title: '缺失记录提示',
              color: AppColors.lightBlue,
              icon: Icons.info_outline,
              children: [
                for (final item in _missingForDisplay(summary).take(8))
                  Text(item.label),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Text('年度油耗费用统计', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (summary.vehicles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('当前年份暂无可统计车辆。'),
              ),
            )
          else
            _PivotTable(summary: summary),
          const SizedBox(height: 16),
          _FuelTrendCard(months: summary.months),
        ],
      ),
    );
  }

  List<FuelMissingRecord> _missingForDisplay(FuelYearSummary summary) {
    final currentMonth = _year == DateTime.now().year
        ? DateTime.now().month
        : 12;
    return [
      for (final item in summary.missingRecords)
        if (item.month <= currentMonth) item,
    ];
  }

  Future<void> _pickYear() async {
    final controller = TextEditingController(text: '$_year');
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择年份'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '年份'),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => dialogContext.pop(int.tryParse(controller.text)),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value >= 2000 && value <= 2200) {
      setState(() => _year = value);
    }
  }
}

class _FuelTrendCard extends StatelessWidget {
  const _FuelTrendCard({required this.months});

  final List<FuelMonthSummary> months;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('全部车辆年度油耗趋势', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SizedBox(
            height: 125,
            width: double.infinity,
            child: CustomPaint(
              painter: _FuelTrendPainter([
                for (final month in months) month.totalLiters,
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var month = 1; month <= 12; month++)
                Expanded(
                  child: Text(
                    '$month',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: AppColors.body),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _FuelTrendPainter extends CustomPainter {
  const _FuelTrendPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maximum = math.max(1.0, values.reduce(math.max));
    final plot = Rect.fromLTWH(12, 8, size.width - 24, size.height - 18);
    final gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var index = 0; index <= 3; index++) {
      final y = plot.top + plot.height * index / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }
    final points = [
      for (var index = 0; index < values.length; index++)
        Offset(
          plot.left + plot.width * index / math.max(values.length - 1, 1),
          plot.bottom - plot.height * values[index] / maximum,
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.techBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (final point in points) {
      canvas.drawCircle(point, 3.5, Paint()..color = AppColors.techBlue);
    }
  }

  @override
  bool shouldRepaint(covariant _FuelTrendPainter oldDelegate) =>
      !listEquals(values, oldDelegate.values);
}

class _YearBar extends StatelessWidget {
  const _YearBar({
    required this.year,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final int year;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Card(
    child: Row(
      children: [
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Center(
            child: TextButton(
              onPressed: onPick,
              child: Text(
                '$year 年',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary, required this.current});

  final FuelYearSummary summary;
  final FuelMonthSummary current;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('年度总油耗', '${summary.totalLiters.toStringAsFixed(2)} L'),
      ('年度总油费', _money(summary.totalAmountCents)),
      ('统计车辆数', '${summary.vehicles.length} 辆'),
      ('已录入月份', '${summary.recordedMonthCount}/12'),
      ('本月录入车辆', '${current.validVehicleCount} 辆'),
      ('本月总油耗', '${current.totalLiters.toStringAsFixed(2)} L'),
      ('本月总油费', _money(current.totalAmountCents)),
      ('数据完整度', '${summary.completenessPercent.toStringAsFixed(1)}%'),
    ];
    const colors = [
      AppColors.techBlue,
      Colors.orange,
      AppColors.primary,
      AppColors.purple,
      AppColors.techBlue,
      Colors.orange,
      AppColors.primary,
      AppColors.purple,
    ];
    const icons = [
      Icons.water_drop_outlined,
      Icons.payments_outlined,
      Icons.local_shipping_outlined,
      Icons.calendar_month_outlined,
      Icons.check_circle_outline,
      Icons.water_drop_outlined,
      Icons.payments_outlined,
      Icons.pie_chart_outline,
    ];
    return VehicleMetricGrid(
      items: [
        for (var index = 0; index < metrics.length; index++)
          VehicleMetricData(
            label: metrics[index].$1,
            value: metrics[index].$2,
            icon: icons[index],
            color: colors[index],
          ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.children,
  });

  final String title;
  final Color color;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _PivotTable extends StatelessWidget {
  const _PivotTable({required this.summary});

  final FuelYearSummary summary;

  static const headerHeight = 56.0;
  static const monthRowHeight = 48.0;
  static const summaryRowHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final rowCount = 12 + 2;
    final leftWidth = 72.0;
    final rightWidth = 156.0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SizedBox(
          height: headerHeight + monthRowHeight * 12 + summaryRowHeight * 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: leftWidth,
                child: _LeftTable(
                  rowCount: rowCount,
                  headerHeight: headerHeight,
                  monthRowHeight: monthRowHeight,
                  summaryRowHeight: summaryRowHeight,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _VehicleTable(
                    summary: summary,
                    headerHeight: headerHeight,
                    monthRowHeight: monthRowHeight,
                    summaryRowHeight: summaryRowHeight,
                  ),
                ),
              ),
              SizedBox(
                width: rightWidth,
                child: _RightTable(
                  summary: summary,
                  headerHeight: headerHeight,
                  monthRowHeight: monthRowHeight,
                  summaryRowHeight: summaryRowHeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeftTable extends StatelessWidget {
  const _LeftTable({
    required this.rowCount,
    required this.headerHeight,
    required this.monthRowHeight,
    required this.summaryRowHeight,
  });

  final int rowCount;
  final double headerHeight;
  final double monthRowHeight;
  final double summaryRowHeight;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _TableCell(text: '月份', height: headerHeight, header: true),
      for (var month = 1; month <= 12; month++)
        _TableCell(text: '$month月', height: monthRowHeight),
      _TableCell(text: '车辆总计', height: summaryRowHeight, header: true),
      _TableCell(text: '有效月份平均', height: summaryRowHeight, header: true),
    ],
  );
}

class _VehicleTable extends StatelessWidget {
  const _VehicleTable({
    required this.summary,
    required this.headerHeight,
    required this.monthRowHeight,
    required this.summaryRowHeight,
  });

  final FuelYearSummary summary;
  final double headerHeight;
  final double monthRowHeight;
  final double summaryRowHeight;

  @override
  Widget build(BuildContext context) {
    final width = summary.vehicles.length * 180.0;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(
            height: headerHeight,
            child: Row(
              children: [
                for (final vehicle in summary.vehicles)
                  SizedBox(
                    width: 180,
                    child: _TableCell(
                      text: vehicle.vehicle.name,
                      secondary: vehicle.vehicle.vehicleNo,
                      height: headerHeight,
                      header: true,
                    ),
                  ),
              ],
            ),
          ),
          for (var month = 1; month <= 12; month++)
            SizedBox(
              height: monthRowHeight,
              child: Row(
                children: [
                  for (final vehicle in summary.vehicles)
                    _FuelPair(
                      vehicle: vehicle,
                      year: summary.year,
                      month: month,
                      width: 180,
                      height: monthRowHeight,
                    ),
                ],
              ),
            ),
          SizedBox(
            height: summaryRowHeight,
            child: Row(
              children: [
                for (final vehicle in summary.vehicles)
                  _PairValues(
                    first: _liters(vehicle.totalLiters),
                    second: _money(vehicle.totalAmountCents),
                    width: 180,
                    height: summaryRowHeight,
                  ),
              ],
            ),
          ),
          SizedBox(
            height: summaryRowHeight,
            child: Row(
              children: [
                for (final vehicle in summary.vehicles)
                  _PairValues(
                    first: _liters(vehicle.averageLiters),
                    second: _money(vehicle.averageAmountCents),
                    width: 180,
                    height: summaryRowHeight,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RightTable extends StatelessWidget {
  const _RightTable({
    required this.summary,
    required this.headerHeight,
    required this.monthRowHeight,
    required this.summaryRowHeight,
  });

  final FuelYearSummary summary;
  final double headerHeight;
  final double monthRowHeight;
  final double summaryRowHeight;

  static const width = 156.0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: headerHeight,
        child: Row(
          children: [
            Expanded(
              child: _TableCell(
                text: '月度合计',
                height: headerHeight,
                header: true,
              ),
            ),
          ],
        ),
      ),
      for (final month in summary.months)
        _PairValues(
          first: _liters(month.totalLiters),
          second: _money(month.totalAmountCents),
          width: width,
          height: monthRowHeight,
        ),
      _PairValues(
        first: _liters(summary.totalLiters),
        second: _money(summary.totalAmountCents),
        width: width,
        height: summaryRowHeight,
      ),
      _PairValues(
        first: _liters(
          summary.months.isEmpty
              ? 0
              : summary.months
                        .map((item) => item.averageLiters)
                        .fold<double>(0, (a, b) => a + b) /
                    summary.months.length,
        ),
        second: _money(
          summary.months.isEmpty
              ? 0
              : (summary.months
                            .map((item) => item.averageAmountCents)
                            .fold<int>(0, (a, b) => a + b) /
                        summary.months.length)
                    .round(),
        ),
        width: width,
        height: summaryRowHeight,
      ),
    ],
  );
}

class _FuelPair extends StatelessWidget {
  const _FuelPair({
    required this.vehicle,
    required this.year,
    required this.month,
    required this.width,
    required this.height,
  });

  final FuelVehicleSummary vehicle;
  final int year;
  final int month;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final record = vehicle.recordsByMonth[month];
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        children: [
          _ClickableValue(
            value: record == null ? '—' : _liters(record.liters),
            width: width / 2,
            height: height,
            onTap: () => _open(context),
          ),
          _ClickableValue(
            value: record == null ? '—' : _money(record.amountCents),
            width: width / 2,
            height: height,
            onTap: () => _open(context),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    context.push(
      '/vehicles/${vehicle.vehicle.id}?tab=fuel&year=$year&month=$month',
    );
  }
}

class _PairValues extends StatelessWidget {
  const _PairValues({
    required this.first,
    required this.second,
    required this.width,
    required this.height,
  });

  final String first;
  final String second;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Row(
      children: [
        _TableCell(text: first, width: width / 2, height: height, header: true),
        _TableCell(
          text: second,
          width: width / 2,
          height: height,
          header: true,
        ),
      ],
    ),
  );
}

class _ClickableValue extends StatelessWidget {
  const _ClickableValue({
    required this.value,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String value;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: InkWell(
      onTap: onTap,
      child: _TableCell(text: value, width: width, height: height),
    ),
  );
}

class _TableCell extends StatelessWidget {
  const _TableCell({
    required this.text,
    required this.height,
    this.width,
    this.secondary,
    this.header = false,
  });

  final String text;
  final String? secondary;
  final double height;
  final double? width;
  final bool header;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: header
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (secondary != null)
            Text(secondary!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

String _liters(double value) => value.toStringAsFixed(2);

String _money(int cents) => '${(cents / 100).toStringAsFixed(2)} 元';
