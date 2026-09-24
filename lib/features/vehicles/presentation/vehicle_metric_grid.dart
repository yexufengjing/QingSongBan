import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

class VehicleMetricData {
  const VehicleMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

/// Compact, non-scrolling metric rows used by the vehicle detail pages.
class VehicleMetricGrid extends StatelessWidget {
  const VehicleMetricGrid({required this.items, super.key});

  final List<VehicleMetricData> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 340 ? 4 : 2;
      return Column(
        children: [
          for (var start = 0; start < items.length; start += columns) ...[
            if (start > 0) const SizedBox(height: 7),
            Row(
              children: [
                for (
                  var index = start;
                  index < items.length && index < start + columns;
                  index++
                ) ...[
                  if (index > start) const SizedBox(width: 7),
                  Expanded(child: _MetricTile(item: items[index])),
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
    height: 92,
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
    decoration: BoxDecoration(
      color: item.color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(item.icon, color: item.color, size: 20),
        const SizedBox(height: 3),
        SizedBox(
          height: 23,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.value,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.body, fontSize: 11),
        ),
      ],
    ),
  );
}
