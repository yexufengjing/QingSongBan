import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/database/app_database.dart';

class InventoryFormFooter extends StatelessWidget {
  const InventoryFormFooter({
    required this.label,
    required this.icon,
    required this.onSave,
    this.saving = false,
    this.buttonKey,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onSave;
  final bool saving;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: FilledButton.icon(
          key: buttonKey,
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(saving ? '正在保存…' : label),
        ),
      ),
    ),
  );
}

Future<bool?> showInventoryConfirmation({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '取消',
  IconData? icon,
}) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    icon: icon == null
        ? null
        : Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: AppColors.lightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
    title: Text(title, textAlign: TextAlign.center),
    content: Text(message, textAlign: TextAlign.center),
    actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
    actions: [
      Row(
        children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lightBlue,
                foregroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(cancelLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ),
        ],
      ),
    ],
  ),
);

class InventoryMaterialPickerField extends StatelessWidget {
  const InventoryMaterialPickerField({
    required this.materials,
    required this.selectedId,
    required this.onChanged,
    super.key,
  });

  final List<InventoryMaterial> materials;
  final int? selectedId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = materials
        .where((item) => item.id == selectedId)
        .firstOrNull;
    return InkWell(
      key: const Key('inventory-material-picker'),
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final viewInsets = MediaQuery.viewInsetsOf(context);
        final viewPadding = MediaQuery.viewPaddingOf(context);
        final material = await showModalBottomSheet<InventoryMaterial>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _InventoryMaterialPickerSheet(
            materials: materials,
            safeBottomInset: viewInsets.bottom > 0 ? 0 : viewPadding.bottom,
          ),
        );
        if (material != null && context.mounted) onChanged(material.id);
      },
      child: Semantics(
        button: true,
        label: '物资，${selected?.materialName ?? '请选择'}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('物资', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: selected?.materialName ?? '选择物资',
                      child: Text(selected?.materialName ?? '选择物资'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.search, color: AppColors.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryMaterialPickerSheet extends StatefulWidget {
  const _InventoryMaterialPickerSheet({
    required this.materials,
    required this.safeBottomInset,
  });

  final List<InventoryMaterial> materials;
  final double safeBottomInset;

  @override
  State<_InventoryMaterialPickerSheet> createState() =>
      _InventoryMaterialPickerSheetState();
}

class _InventoryMaterialPickerSheetState
    extends State<_InventoryMaterialPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materials = widget.materials;
    final query = _query.trim().toLowerCase();
    final filtered = materials.where((material) {
      if (query.isEmpty) return true;
      return material.materialName.toLowerCase().contains(query) ||
          (material.modelSpec ?? '').toLowerCase().contains(query) ||
          material.materialCode.toLowerCase().contains(query);
    }).toList();
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bottomInset = viewInsets.bottom;
    final maxBottomInset = bottomInset > 0
        ? bottomInset
        : widget.safeBottomInset;
    final availableHeight = (MediaQuery.sizeOf(context).height - maxBottomInset)
        .clamp(0.0, double.infinity)
        .toDouble();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: availableHeight * .82),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择库存物资',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: TextField(
                  key: const Key('inventory-material-search'),
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜索物资名称、规格或编码',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              if (materials.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + (bottomInset == 0 ? widget.safeBottomInset : 0),
                  ),
                  child: const Text('暂无可选物资'),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + (bottomInset == 0 ? widget.safeBottomInset : 0),
                  ),
                  child: const Text('没有匹配的物资'),
                )
              else
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: bottomInset == 0 ? widget.safeBottomInset : 0,
                    ),
                    child: ListView.separated(
                      key: const Key('inventory-material-results'),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final material = filtered[index];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            key: Key(
                              'inventory-material-option-${material.id}',
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(material.materialName),
                            subtitle: Text(
                              '${material.modelSpec ?? '未填规格'} · 库存 ${material.currentStock} ${material.unitName}',
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.primary,
                            ),
                            onTap: () => Navigator.pop(context, material),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
