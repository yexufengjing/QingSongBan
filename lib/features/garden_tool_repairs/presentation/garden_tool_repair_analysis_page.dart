import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/garden_tool_repair_providers.dart';
import '../domain/repair_analytics_models.dart';
import '../domain/repair_formatters.dart';

class GardenToolRepairAnalysisPage extends ConsumerStatefulWidget {
  const GardenToolRepairAnalysisPage({
    required this.initialYear,
    required this.initialMonth,
    super.key,
  });

  final int initialYear;
  final int initialMonth;

  @override
  ConsumerState<GardenToolRepairAnalysisPage> createState() =>
      _GardenToolRepairAnalysisPageState();
}

class _GardenToolRepairAnalysisPageState
    extends ConsumerState<GardenToolRepairAnalysisPage> {
  late int _year;
  late int _month;
  _AnalysisCycle _cycle = _AnalysisCycle.month;
  int? _unitId;
  bool _showTopTen = false;
  bool _showAllFrequency = false;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(gardenToolRepairUnitsProvider(false));
    final start = _cycle == _AnalysisCycle.year
        ? DateTime(_year)
        : DateTime(_year, _month);
    final end = _cycle == _AnalysisCycle.year
        ? DateTime(_year + 1)
        : DateTime(_year, _month + 1);
    final filter = (start: start, endExclusive: end, unitId: _unitId);
    final groupsAsync = ref.watch(gardenToolRepairPeriodProvider(filter));
    return Scaffold(
      appBar: AppBar(title: const Text('数据分析')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildFilters(unitsAsync),
            const SizedBox(height: 12),
            groupsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _AnalysisError(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(gardenToolRepairPeriodProvider(filter)),
              ),
              data: (groups) {
                final report = ref
                    .read(gardenToolRepairAnalysisServiceProvider)
                    .summarize(
                      groups,
                      year: _year,
                      month: _cycle == _AnalysisCycle.month ? _month : null,
                    );
                if (report.itemCount == 0) return const _AnalysisEmpty();
                return _buildReport(report);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(
    AsyncValue<List<GardenToolRepairUnit>> unitsAsync,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 128,
            child: DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: const InputDecoration(labelText: '年份'),
              items: [
                for (var year = DateTime.now().year; year >= 2000; year--)
                  DropdownMenuItem(value: year, child: Text('$year年')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _year = value);
              },
            ),
          ),
          SizedBox(
            width: 116,
            child: DropdownButtonFormField<_AnalysisCycle>(
              initialValue: _cycle,
              decoration: const InputDecoration(labelText: '周期'),
              items: const [
                DropdownMenuItem(value: _AnalysisCycle.year, child: Text('年度')),
                DropdownMenuItem(
                  value: _AnalysisCycle.month,
                  child: Text('月度'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _cycle = value);
              },
            ),
          ),
          if (_cycle == _AnalysisCycle.month)
            SizedBox(
              width: 105,
              child: DropdownButtonFormField<int>(
                initialValue: _month,
                decoration: const InputDecoration(labelText: '月份'),
                items: [
                  for (var month = 1; month <= 12; month++)
                    DropdownMenuItem(value: month, child: Text('$month月')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _month = value);
                },
              ),
            ),
          SizedBox(
            width: 150,
            child: unitsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => const Text('维修单位加载失败'),
              data: (units) => DropdownButtonFormField<int?>(
                initialValue: _unitId,
                decoration: const InputDecoration(labelText: '维修单位'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('全部单位'),
                  ),
                  for (final unit in units)
                    DropdownMenuItem<int?>(
                      value: unit.id,
                      child: Text(unit.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _unitId = value),
              ),
            ),
          ),
          if (_unitId != null)
            TextButton.icon(
              onPressed: () => setState(() => _unitId = null),
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('清除单位筛选'),
            ),
        ],
      ),
    ),
  );

  Widget _buildReport(GardenToolRepairAnalytics report) {
    final periodLabel = _cycle == _AnalysisCycle.year ? '年度' : '本月';
    final maxAmount = report.projectAmounts.isEmpty
        ? 0
        : report.projectAmounts.first.totalCents;
    final visibleProjects = report.projectAmounts
        .take(_showTopTen ? 10 : 5)
        .toList();
    final visibleCounts = report.projectCounts
        .take(_showAllFrequency ? report.projectCounts.length : 10)
        .toList();
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.85,
          children: [
            _MetricCard(
              label: '$periodLabel维修金额',
              value: formatRepairMoney(report.totalCents),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
            ),
            _MetricCard(
              label: '项目总数',
              value: '${report.itemCount}',
              icon: Icons.receipt_long_outlined,
              color: AppColors.techBlue,
            ),
            _MetricCard(
              label: _cycle == _AnalysisCycle.year ? '月均金额' : '本月金额',
              value: formatRepairMoney(report.averageMonthCents),
              icon: Icons.bar_chart,
              color: const Color(0xFFEF8B27),
            ),
            _MetricCard(
              label: '维修人数',
              value: '${report.repairerCount}',
              icon: Icons.people_alt_outlined,
              color: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MonthlyTrendCard(
          title: '月度维修费用趋势',
          amounts: report.monthlyTotalsCents,
          onTapMonth: _openMonth,
        ),
        const SizedBox(height: 12),
        _UnitShareCard(
          totalCents: report.totalCents,
          units: report.unitAmounts,
          selectedUnitId: _unitId,
          onSelect: (id) => setState(() => _unitId = id),
        ),
        const SizedBox(height: 12),
        _ProjectAmountCard(
          entries: visibleProjects,
          maximum: maxAmount,
          canExpand: report.projectAmounts.length > 5,
          expanded: _showTopTen,
          onToggle: () => setState(() => _showTopTen = !_showTopTen),
        ),
        const SizedBox(height: 12),
        _ProjectCountCard(
          entries: visibleCounts,
          canExpand: report.projectCounts.length > 10,
          expanded: _showAllFrequency,
          onToggle: () =>
              setState(() => _showAllFrequency = !_showAllFrequency),
        ),
        const SizedBox(height: 12),
        _RepairerTable(entries: report.repairers),
      ],
    );
  }

  void _openMonth(int month) {
    context.push('/garden-tool-repairs?year=$_year&month=$month');
  }
}

enum _AnalysisCycle { year, month }

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard({
    required this.title,
    required this.amounts,
    required this.onTapMonth,
  });

  final String title;
  final List<int> amounts;
  final ValueChanged<int> onTapMonth;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onTapUp: (details) {
                const chartLeft = 42.0;
                const chartRightPadding = 8.0;
                final chartWidth =
                    constraints.maxWidth - chartLeft - chartRightPadding;
                final x = details.localPosition.dx - chartLeft;
                if (x < 0 || x > chartWidth || chartWidth <= 0) return;
                final index = (x / chartWidth * 12).floor().clamp(0, 11);
                onTapMonth(index + 1);
              },
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: CustomPaint(painter: _TrendPainter(amounts)),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('单位：元', style: TextStyle(color: AppColors.body)),
          ),
        ],
      ),
    ),
  );
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.amounts);

  final List<int> amounts;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const top = 14.0;
    const bottom = 28.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - 8,
      size.height - bottom,
    );
    final maxAmount = math.max(1, amounts.fold<int>(0, math.max));
    final gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    final axisText = TextPainter(textDirection: TextDirection.ltr);
    for (var line = 0; line <= 3; line++) {
      final y = chart.bottom - chart.height * line / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = (maxAmount * line / 3 / 100).round();
      axisText
        ..text = TextSpan(
          text: value.toString(),
          style: const TextStyle(fontSize: 10, color: AppColors.body),
        )
        ..layout();
      axisText.paint(canvas, Offset(0, y - axisText.height / 2));
    }
    final points = <Offset>[];
    for (var index = 0; index < 12; index++) {
      final x = chart.left + chart.width * (index + .5) / 12;
      final y = chart.bottom - chart.height * amounts[index] / maxAmount;
      points.add(Offset(x, y));
      final label = TextPainter(
        text: TextSpan(
          text: '${index + 1}月',
          style: const TextStyle(fontSize: 10, color: AppColors.body),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x - label.width / 2, chart.bottom + 5));
    }
    final fill = Path()..moveTo(points.first.dx, chart.bottom);
    fill.lineTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      fill.lineTo(point.dx, point.dy);
    }
    fill
      ..lineTo(points.last.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = AppColors.lightGreen
        ..style = PaintingStyle.fill,
    );
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (final point in points) {
      canvas.drawCircle(
        point,
        3.5,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.amounts != amounts;
}

class _UnitShareCard extends StatelessWidget {
  const _UnitShareCard({
    required this.totalCents,
    required this.units,
    required this.selectedUnitId,
    required this.onSelect,
  });

  final int totalCents;
  final List<GardenToolRepairUnitAmount> units;
  final int? selectedUnitId;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('维修单位费用占比', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CustomPaint(
                  painter: _DonutPainter(
                    units.map((unit) => unit.totalCents).toList(),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(35),
                      child: FittedBox(
                        child: Text(formatRepairMoney(totalCents)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < units.length; index++)
                      InkWell(
                        onTap: () => onSelect(
                          selectedUnitId == units[index].unitId
                              ? null
                              : units[index].unitId,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      _chartColors[index % _chartColors.length],
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(child: Text(units[index].unitName)),
                              Text(
                                '${(units[index].share * 100).toStringAsFixed(1)}%',
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (selectedUnitId != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onSelect(null),
                child: const Text('清除单位筛选'),
              ),
            ),
        ],
      ),
    ),
  );
}

const _chartColors = [
  AppColors.primary,
  AppColors.techBlue,
  Color(0xFFEF8B27),
  Color(0xFF6D4AFF),
  Color(0xFFE05252),
];

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return;
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      canvas.drawArc(
        rect.deflate(8),
        start,
        sweep,
        false,
        Paint()
          ..color = _chartColors[index % _chartColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => oldDelegate.values != values;
}

class _ProjectAmountCard extends StatelessWidget {
  const _ProjectAmountCard({
    required this.entries,
    required this.maximum,
    required this.canExpand,
    required this.expanded,
    required this.onToggle,
  });

  final List<GardenToolRepairProjectAmount> entries;
  final int maximum;
  final bool canExpand;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '维修项目金额排行',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Text('单位：元', style: TextStyle(color: AppColors.body)),
            ],
          ),
          const SizedBox(height: 8),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      entry.projectName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: maximum == 0 ? 0 : entry.totalCents / maximum,
                      minHeight: 14,
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.primary,
                      backgroundColor: AppColors.background,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatRepairMoney(entry.totalCents)),
                ],
              ),
            ),
          if (canExpand)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onToggle,
                child: Text(expanded ? '收起' : '查看更多（TOP10）'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ProjectCountCard extends StatelessWidget {
  const _ProjectCountCard({
    required this.entries,
    required this.canExpand,
    required this.expanded,
    required this.onToggle,
  });

  final List<GardenToolRepairProjectCount> entries;
  final bool canExpand;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('维修项目次数排行', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          for (final entry in entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.projectName),
              trailing: Text('${entry.count}条'),
            ),
          if (canExpand)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onToggle,
                child: Text(expanded ? '收起' : '查看更多'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _RepairerTable extends StatelessWidget {
  const _RepairerTable({required this.entries});

  final List<GardenToolRepairPersonSummary> entries;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('维修人数据统计', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('姓名')),
                DataColumn(label: Text('所属单位')),
                DataColumn(label: Text('项目条数'), numeric: true),
                DataColumn(label: Text('累计金额'), numeric: true),
                DataColumn(label: Text('占比'), numeric: true),
              ],
              rows: [
                for (final entry in entries)
                  DataRow(
                    cells: [
                      DataCell(Text(entry.personName)),
                      DataCell(Text(entry.unitName)),
                      DataCell(Text('${entry.itemCount}')),
                      DataCell(Text(formatRepairMoney(entry.totalCents))),
                      DataCell(
                        Text('${(entry.share * 100).toStringAsFixed(1)}%'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AnalysisEmpty extends StatelessWidget {
  const _AnalysisEmpty();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 20),
      child: Column(
        children: [
          const Icon(
            Icons.insights_outlined,
            size: 58,
            color: AppColors.helper,
          ),
          const SizedBox(height: 12),
          Text('当前条件暂无维修数据', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}

class _AnalysisError extends StatelessWidget {
  const _AnalysisError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
          const SizedBox(height: 8),
          Text('数据分析加载失败：$message'),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}
