import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Shared white-and-mint building blocks for the inventory screens.
class InventorySection extends StatelessWidget {
  const InventorySection({
    required this.title,
    required this.child,
    this.icon = Icons.inventory_2_outlined,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEAF2EF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080B5B43),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class InventoryMetricCard extends StatelessWidget {
  const InventoryMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.onTap,
    this.compact = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 112 : 94),
        padding: EdgeInsets.all(compact ? 10 : 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAF2EF)),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(icon, color: color, size: 19),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              )
            : Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(icon, color: color, size: 22),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class InventoryQuickAction extends StatelessWidget {
  const InventoryQuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF4F8FA),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      key: Key('inventory-shortcut-$title'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 7),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    ),
  );
}

class InventorySummaryPanel extends StatelessWidget {
  const InventorySummaryPanel({
    required this.title,
    required this.icon,
    required this.metrics,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> metrics;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCEFE8)),
      ),
      child: constraints.maxWidth < 520
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(child: _SummaryMetric(metric: metrics[index])),
                    ],
                  ],
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.description_outlined),
                      label: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            )
          : Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final metric in metrics)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: _SummaryMetric(metric: metric),
                    ),
                  ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.description_outlined),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
    ),
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.metric});
  final (String, String) metric;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        metric.$1,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 2),
      Text(
        metric.$2,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class InventoryMonthPicker extends StatelessWidget {
  const InventoryMonthPicker({
    required this.month,
    required this.onChanged,
    super.key,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () async {
      final selected = await showDatePicker(
        context: context,
        initialDate: month,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        helpText: '选择统计月份',
        initialEntryMode: DatePickerEntryMode.calendarOnly,
      );
      if (selected != null) onChanged(DateTime(selected.year, selected.month));
    },
    icon: const Icon(Icons.calendar_month_outlined, size: 18),
    label: Text('${month.year}年${month.month}月'),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      backgroundColor: AppColors.lightGreen,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      shape: const StadiumBorder(),
    ),
  );
}

class InventoryEmptyState extends StatelessWidget {
  const InventoryEmptyState({
    required this.title,
    this.message = '当前没有记录',
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
    child: Column(
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          size: 40,
          color: AppColors.helper,
        ),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

class InventoryLoadingState extends StatelessWidget {
  const InventoryLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

class InventoryErrorState extends StatelessWidget {
  const InventoryErrorState({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => InventoryEmptyState(
    title: '加载失败',
    message: '库存数据暂时无法读取，请重试。',
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('重试'),
    ),
  );
}

class InventoryStatusChip extends StatelessWidget {
  const InventoryStatusChip({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: color, fontWeight: FontWeight.w700),
    ),
  );
}
