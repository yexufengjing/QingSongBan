import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/assistant_models.dart';

/// A scan-first reading order shared by local business results.
class AssistantBusinessResultContent extends StatelessWidget {
  const AssistantBusinessResultContent({
    super.key,
    required this.result,
    required this.onOpenSource,
    required this.onRefresh,
    required this.onExplain,
    required this.ruleLabel,
    this.explanation,
  });

  final AssistantBusinessReadResult result;
  final ValueChanged<String> onOpenSource;
  final VoidCallback? onRefresh;
  final VoidCallback? onExplain;
  final String ruleLabel;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final warnings = result.facts.indexed
        .where((row) => row.$2.isWarning)
        .toList();
    final records = result.facts.indexed
        .where((row) => !row.$2.isWarning)
        .toList();
    final warningCount = warnings.fold<int>(
      0,
      (count, row) =>
          count + (row.$2.details.isEmpty ? 1 : row.$2.details.length),
    );
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AssistantResultHeading(
          title: result.title,
          scope: result.scopeLabel,
          status: warningCount > 0 ? '待核对 $warningCount 项' : '本地结果',
          warning: warningCount > 0,
        ),
        if (result.metrics.isNotEmpty) ...[
          const SizedBox(height: 20),
          AssistantResultMetrics(metrics: result.metrics),
        ] else if (result.emptyMessage == null) ...[
          const SizedBox(height: 12),
          Text(result.summary, style: const TextStyle(height: 1.5)),
        ],
        if (result.emptyMessage != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.emptyMessage!,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
        for (final (index, fact) in warnings) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightOrange,
              border: Border(
                left: BorderSide(color: AppColors.warning, width: 3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fact.label,
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final detail
                    in fact.details.isEmpty ? [fact.value] : fact.details)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            detail,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (fact.sourcePage != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: ValueKey(
                        'assistant_business_fact_source_${result.domain.name}_$index',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => onOpenSource(fact.sourcePage!),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text('查看${fact.label}来源'),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (records.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          for (final (index, fact) in records)
            _FactRow(
              fact: fact,
              sourceKey: ValueKey(
                'assistant_business_fact_source_${result.domain.name}_$index',
              ),
              onOpenSource: onOpenSource,
            ),
        ],
        if (explanation != null) ...[
          const SizedBox(height: 12),
          Text(
            '结果说明',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(explanation!, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
        for (final (index, related) in result.relatedReads.indexed) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(
              related.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            children: [
              Text(
                related.summary,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              TextButton.icon(
                key: ValueKey(
                  'assistant_business_related_source_${result.domain.name}_$index',
                ),
                onPressed: () => onOpenSource(related.sourcePage),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('打开${related.title}来源'),
              ),
              for (final (factIndex, fact) in related.facts.indexed)
                _FactRow(
                  fact: fact,
                  sourceKey: ValueKey(
                    'assistant_business_related_fact_source_${result.domain.name}_${index}_$factIndex',
                  ),
                  onOpenSource: onOpenSource,
                ),
            ],
          ),
        ],
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: const Text('口径与来源', style: TextStyle(fontSize: 13)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ruleLabel,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.summary,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  for (final fact in result.facts)
                    if (fact.explanation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${fact.label}：${fact.explanation}',
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ),
                  const SizedBox(height: 8),
                  Text(
                    '查询时间：${_time(result.queriedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!warnings.any((row) => row.$2.sourcePage == result.sourcePage))
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => onOpenSource(result.sourcePage),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(_sourceLabel(result.domain)),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新本地结果'),
            ),
            TextButton.icon(
              onPressed: onExplain,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('解释这组结果'),
            ),
          ],
        ),
      ],
    );
  }
}

class AssistantResultHeading extends StatelessWidget {
  const AssistantResultHeading({
    super.key,
    required this.title,
    this.scope,
    required this.status,
    this.warning = false,
  });
  final String title;
  final String? scope;
  final String status;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
            height: 1.4,
          ),
        ),
        if (scope != null) ...[
          const SizedBox(height: 4),
          Text(
            scope!,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              warning ? Icons.warning_amber_rounded : Icons.storage_outlined,
              size: 14,
              color: warning ? AppColors.warning : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: warning ? AppColors.warning : scheme.onSurfaceVariant,
                  fontWeight: warning ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AssistantResultMetrics extends StatelessWidget {
  const AssistantResultMetrics({super.key, required this.metrics});
  final List<AssistantResultMetric> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
      final halfWidth = (constraints.maxWidth - 16) / 2;
      final valuesFit = metrics.indexed.every((row) {
        final painter = TextPainter(
          text: TextSpan(
            text: row.$2.value,
            style: TextStyle(
              fontSize: row.$1 == 0 ? 30 : 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fits =
            painter.width + (row.$2.unit.isEmpty ? 0 : 28) <= halfWidth;
        painter.dispose();
        return fits;
      });
      final columns = constraints.maxWidth >= 240 && !largeText && valuesFit
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      final scheme = Theme.of(context).colorScheme;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final (index, metric) in metrics.indexed)
            SizedBox(
              key: ValueKey('assistant_metric_${metric.label}'),
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 4,
                    children: [
                      Text(
                        metric.value,
                        style: TextStyle(
                          fontSize: index == 0 ? 30 : 26,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: index == 0 ? scheme.primary : scheme.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (metric.unit.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            metric.unit,
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.fact,
    required this.sourceKey,
    required this.onOpenSource,
  });
  final AssistantBusinessFact fact;
  final Key sourceKey;
  final ValueChanged<String> onOpenSource;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fact.label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                fact.value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (fact.sourcePage != null)
          IconButton(
            key: sourceKey,
            tooltip: '查看${fact.label}来源',
            onPressed: () => onOpenSource(fact.sourcePage!),
            icon: const Icon(Icons.open_in_new, size: 18),
          ),
      ],
    ),
  );
}

String _sourceLabel(AssistantBusinessType domain) => switch (domain) {
  AssistantBusinessType.payroll => '查看工资明细',
  AssistantBusinessType.inventory => '查看库存',
  AssistantBusinessType.purchase => '查看采购单',
  AssistantBusinessType.distribution => '查看领取记录',
  AssistantBusinessType.vehicleMaintenance => '查看维修单',
  AssistantBusinessType.personnel => '查看人员档案',
  AssistantBusinessType.gardenRepair => '查看维修记录',
  AssistantBusinessType.vehicleReminders => '查看车辆提醒',
  _ => '打开业务来源',
};

String _time(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
