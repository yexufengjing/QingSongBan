import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class InventoryFormFooter extends StatelessWidget {
  const InventoryFormFooter({
    required this.label,
    required this.icon,
    required this.onSave,
    this.subtitle,
    this.saving = false,
    this.buttonKey,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onSave;
  final String? subtitle;
  final bool saving;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              key: buttonKey,
              onPressed: saving ? null : onSave,
              child: subtitle == null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(icon),
                        const SizedBox(width: 8),
                        Text(saving ? '正在保存…' : label),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (saving) ...[
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(saving ? '正在保存…' : label),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
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

/// Shared blue-and-white sections for the inventory reference pages.
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
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
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
    this.valueMaxLines = 1,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool compact;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF6FAFE),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 108 : 94),
        padding: EdgeInsets.all(compact ? 10 : 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
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
                      width: 28,
                      height: 28,
                      child: Icon(icon, color: color, size: 19),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: AppColors.body),
                  ),
                  const SizedBox(height: 2),
                  valueMaxLines > 1
                      ? Tooltip(
                          message: value,
                          child: Text(
                            value,
                            maxLines: valueMaxLines,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        )
                      : Text(
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
              )
            : Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(icon, color: color, size: 24),
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
    color: color.withValues(alpha: .05),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      key: Key('inventory-shortcut-$title'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 7),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
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
      backgroundColor: AppColors.lightBlue,
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
      borderRadius: BorderRadius.circular(12),
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
