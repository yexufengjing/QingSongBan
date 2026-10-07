import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/garden_tool_repair_providers.dart';
import '../domain/repair_formatters.dart';
import '../domain/repair_models.dart';
import 'garden_tool_repair_design.dart';

class GardenToolRepairPricePage extends ConsumerStatefulWidget {
  const GardenToolRepairPricePage({super.key});

  @override
  ConsumerState<GardenToolRepairPricePage> createState() =>
      _GardenToolRepairPricePageState();
}

class _GardenToolRepairPricePageState
    extends ConsumerState<GardenToolRepairPricePage> {
  String? _projectName;
  String? _specModel;
  String? _countUnit;
  int? _unitId;
  int _months = 12;

  @override
  Widget build(BuildContext context) {
    final optionsAsync = ref.watch(gardenToolRepairPriceItemOptionsProvider);
    final unitsAsync = ref.watch(gardenToolRepairUnitsProvider(true));
    return Theme(
      data: gardenToolRepairTheme(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('价格比对')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              optionsAsync.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('历史项目加载失败：$error'),
                  ),
                ),
                data: (options) => _buildWithOptions(options, unitsAsync),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWithOptions(
    List<GardenToolRepairPriceItemOption> options,
    AsyncValue<List<GardenToolRepairUnit>> unitsAsync,
  ) {
    if (options.isEmpty) return const _NoPriceData();
    final projectNames = options
        .map((option) => option.projectName)
        .toSet()
        .toList();
    final project = projectNames.contains(_projectName)
        ? _projectName!
        : projectNames.first;
    final specs = options
        .where((option) => option.projectName == project)
        .toList();
    final specNames = specs.map((option) => option.specModel).toSet().toList();
    final spec = specNames.contains(_specModel) ? _specModel! : specNames.first;
    final units = specs
        .where((option) => option.specModel == spec)
        .map((option) => option.countUnit)
        .toSet()
        .toList();
    final countUnit = units.contains(_countUnit) ? _countUnit! : units.first;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - _months + 1);
    final endExclusive = DateTime(now.year, now.month + 1);
    final filter = (
      projectName: project,
      specModel: spec,
      countUnit: countUnit,
      start: start,
      endExclusive: endExclusive,
      unitId: _unitId,
    );
    final pointsAsync = ref.watch(gardenToolRepairPricePointsProvider(filter));
    return Column(
      children: [
        _buildFilters(
          projectNames: projectNames,
          specNames: specNames,
          units: units,
          project: project,
          spec: spec,
          countUnit: countUnit,
          unitsAsync: unitsAsync,
        ),
        const SizedBox(height: 10),
        pointsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('价格记录加载失败：$error'),
            ),
          ),
          data: (points) => points.isEmpty
              ? const _NoPriceData(message: '当前项目在所选时间范围内暂无价格记录')
              : _buildPriceReport(points),
        ),
      ],
    );
  }

  Widget _buildFilters({
    required List<String> projectNames,
    required List<String> specNames,
    required List<String> units,
    required String project,
    required String spec,
    required String countUnit,
    required AsyncValue<List<GardenToolRepairUnit>> unitsAsync,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  isDense: true,
                  initialValue: project,
                  decoration: const InputDecoration(
                    labelText: '项目名称',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    for (final name in projectNames)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) => setState(() {
                    _projectName = value;
                    _specModel = null;
                    _countUnit = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  isDense: true,
                  initialValue: spec,
                  decoration: const InputDecoration(
                    labelText: '规格型号',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    for (final value in specNames)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.isEmpty ? '无规格' : value),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _specModel = value;
                    _countUnit = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  isDense: true,
                  initialValue: countUnit,
                  decoration: const InputDecoration(
                    labelText: '计数单位',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    for (final value in units)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) => setState(() => _countUnit = value),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  isDense: true,
                  initialValue: _months,
                  decoration: const InputDecoration(
                    labelText: '时间范围',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 6, child: Text('近6个月')),
                    DropdownMenuItem(value: 12, child: Text('近12个月')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _months = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _UnitChoiceChip(
                  label: '全部单位',
                  selected: _unitId == null,
                  onSelected: () => setState(() => _unitId = null),
                ),
                ...unitsAsync.valueOrNull?.map(
                      (unit) => _UnitChoiceChip(
                        label: unit.name,
                        selected: _unitId == unit.id,
                        onSelected: () => setState(() => _unitId = unit.id),
                      ),
                    ) ??
                    const <Widget>[],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildPriceReport(List<GardenToolRepairPricePoint> points) {
    final summary = ref.watch(gardenToolRepairPriceSummaryProvider(points));
    final change = summary.changePercent;
    final changeCents = summary.changeCents;
    final changeColor = changeCents == null
        ? AppColors.body
        : changeCents > 0
        ? AppColors.danger
        : AppColors.primary;
    final changeAmount = changeCents == null
        ? null
        : '${changeCents >= 0 ? '+' : ''}${formatRepairMoney(changeCents)}';
    final changeLabel = changeCents == null
        ? '暂无对比'
        : '$changeAmount · '
              '${change == null ? '暂无涨跌幅' : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%'}';
    final chronological = points.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _PriceMetric(
                label: '当前价格',
                value: formatRepairMoney(summary.currentPriceCents!),
                color: AppColors.primary,
                icon: Icons.sell_outlined,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _PriceMetric(
                label: '上次价格',
                value: summary.previousPriceCents == null
                    ? '暂无对比'
                    : formatRepairMoney(summary.previousPriceCents!),
                color: AppColors.techBlue,
                icon: Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _PriceMetric(
                label: '涨跌幅',
                value: changeLabel,
                color: changeColor,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _PriceMetric(
                label: '平均价格',
                value: formatRepairMoney(summary.averagePriceCents!),
                color: const Color(0xFFEF8B27),
                icon: Icons.bar_chart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '历史价格趋势',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const Text('单位：元', style: TextStyle(color: AppColors.body)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: _PriceTrendChart(
                    points: chronological,
                    onTapPoint: (point) => _showPoint(point),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('历史记录', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('日期')),
                      DataColumn(label: Text('维修单位')),
                      DataColumn(label: Text('维修人')),
                      DataColumn(label: Text('单价'), numeric: true),
                    ],
                    rows: [
                      for (final point in points)
                        DataRow(
                          onSelectChanged: (_) => _showPoint(point),
                          cells: [
                            DataCell(Text(_dateLabel(point.repairDate))),
                            DataCell(Text(point.unitName)),
                            DataCell(Text(point.repairerName)),
                            DataCell(
                              Text(formatRepairMoney(point.unitPriceCents)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PriceMetric(
                label: '最低价',
                value: formatRepairMoney(summary.minimumPriceCents!),
                color: AppColors.primary,
                icon: Icons.south,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PriceMetric(
                label: '最高价',
                value: formatRepairMoney(summary.maximumPriceCents!),
                color: AppColors.danger,
                icon: Icons.north,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PriceMetric(
                label: '记录数',
                value: '${points.length}条',
                color: AppColors.techBlue,
                icon: Icons.list_alt,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showPoint(GardenToolRepairPricePoint point) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(formatRepairMoney(point.unitPriceCents)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('日期：${_dateLabel(point.repairDate)}'),
            Text('维修单位：${point.unitName}'),
            Text('维修人：${point.repairerName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _PriceMetric extends StatelessWidget {
  const _PriceMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 10),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

class _UnitChoiceChip extends StatelessWidget {
  const _UnitChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    visualDensity: VisualDensity.compact,
    labelStyle: TextStyle(
      fontSize: 11,
      color: selected ? AppColors.primary : AppColors.body,
    ),
    side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
  );
}

class _PriceTrendChart extends StatelessWidget {
  const _PriceTrendChart({required this.points, required this.onTapPoint});

  final List<GardenToolRepairPricePoint> points;
  final ValueChanged<GardenToolRepairPricePoint> onTapPoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      onTapUp: (details) {
        if (points.isEmpty) return;
        const left = 40.0;
        final width = constraints.maxWidth - left - 8;
        final index =
            ((details.localPosition.dx - left) / width * points.length)
                .round()
                .clamp(0, points.length - 1);
        onTapPoint(points[index]);
      },
      child: CustomPaint(
        painter: _PriceTrendPainter(points),
        size: Size(constraints.maxWidth, constraints.maxHeight),
      ),
    ),
  );
}

class _PriceTrendPainter extends CustomPainter {
  const _PriceTrendPainter(this.points);

  final List<GardenToolRepairPricePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const left = 40.0;
    const top = 18.0;
    const bottom = 28.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - 8,
      size.height - bottom,
    );
    final prices = points.map((point) => point.unitPriceCents).toList();
    final minimum = prices.reduce(math.min);
    final maximum = prices.reduce(math.max);
    final range = math.max(1, maximum - minimum);
    final gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    final labels = TextPainter(textDirection: TextDirection.ltr);
    for (var line = 0; line <= 3; line++) {
      final y = chart.bottom - chart.height * line / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = minimum + range * line / 3;
      labels
        ..text = TextSpan(
          text: (value / 100).toStringAsFixed(2),
          style: const TextStyle(fontSize: 9, color: AppColors.body),
        )
        ..layout();
      labels.paint(canvas, Offset(0, y - labels.height / 2));
    }
    final pointsToDraw = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (points.length - 1);
      final y =
          chart.bottom -
          chart.height * (points[index].unitPriceCents - minimum) / range;
      pointsToDraw.add(Offset(x, y));
      if (index == 0 || index == points.length - 1 || points.length <= 6) {
        final label = TextPainter(
          text: TextSpan(
            text: _dateLabel(points[index].repairDate),
            style: const TextStyle(fontSize: 9, color: AppColors.body),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x - label.width / 2, chart.bottom + 4));
      }
    }
    final line = Path()..moveTo(pointsToDraw.first.dx, pointsToDraw.first.dy);
    for (final point in pointsToDraw.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (final point in pointsToDraw) {
      canvas.drawCircle(point, 4, Paint()..color = AppColors.primary);
    }
    for (var index = 0; index < pointsToDraw.length; index++) {
      final label = TextPainter(
        text: TextSpan(
          text: (points[index].unitPriceCents / 100).toStringAsFixed(2),
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: chart.width / points.length + 6);
      label.paint(
        canvas,
        Offset(
          pointsToDraw[index].dx - label.width / 2,
          math.max(top, pointsToDraw[index].dy - label.height - 5),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_PriceTrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _NoPriceData extends StatelessWidget {
  const _NoPriceData({this.message = '暂无历史价格项目'});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 20),
      child: Column(
        children: [
          const Icon(
            Icons.price_check_outlined,
            size: 58,
            color: AppColors.helper,
          ),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}

String _dateLabel(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
