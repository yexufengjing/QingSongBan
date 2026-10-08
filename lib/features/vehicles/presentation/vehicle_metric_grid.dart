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
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
      var columns = constraints.maxWidth >= 320 && !largeText ? 4 : 2;
      double valueWidth(VehicleMetricData item) {
        final painter = TextPainter(
          text: TextSpan(
            text: item.value,
            style: TextStyle(
              fontSize: item.value.contains('¥') || item.value.contains('元')
                  ? 16
                  : 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        return painter.width;
      }

      while (columns > 1 &&
          items.any(
            (item) =>
                valueWidth(item) >
                (constraints.maxWidth - (columns - 1) * 8) / columns - 16,
          )) {
        columns = columns ~/ 2;
      }
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
    constraints: const BoxConstraints(minHeight: 76),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: item.color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Text(
          item.value,
          softWrap: false,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: item.value.contains('¥') || item.value.contains('元')
                ? 16
                : 20,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
