import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

class VehicleMetricData {
  const VehicleMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.unit,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? unit;
}

/// Compact, non-scrolling metric rows used by the vehicle detail pages.
class VehicleMetricGrid extends StatelessWidget {
  const VehicleMetricGrid({required this.items, super.key});

  final List<VehicleMetricData> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
      final columns = constraints.maxWidth >= 320 && !largeText ? 4 : 2;
      return Column(
        children: [
          for (var start = 0; start < items.length; start += columns) ...[
            if (start > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = start; index < start + columns; index++) ...[
                  if (index > start) const SizedBox(width: 8),
                  Expanded(
                    child: index < items.length
                        ? _MetricTile(item: items[index])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      );
    },
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item});
  final VehicleMetricData item;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: item.unit != null ? 94 : 76),
    padding: EdgeInsets.symmetric(
      horizontal: item.unit != null ? 4 : 8,
      vertical: 12,
    ),
    decoration: BoxDecoration(
      color: item.color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: item.unit != null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (item.unit != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Icon(item.icon, color: item.color, size: 16),
                const SizedBox(width: 4),
                Text(
                  item.label,
                  style: const TextStyle(color: AppColors.body, fontSize: 11),
                ),
              ],
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: item.color, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: AppColors.body,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: item.unit != null
              ? Alignment.center
              : Alignment.centerLeft,
          child: Text(
            item.value,
            softWrap: false,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: item.unit != null
                  ? 22
                  : (item.value.contains('¥') || item.value.contains('元')
                        ? 16
                        : 20),
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (item.unit != null) ...[
          const SizedBox(height: 6),
          Text(
            item.unit!,
            style: const TextStyle(color: AppColors.body, fontSize: 13),
          ),
        ],
      ],
    ),
  );
}
