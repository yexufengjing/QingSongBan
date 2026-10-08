import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// The white sections and small colored icons shared by the reference pages.
class DesignSection extends StatelessWidget {
  const DesignSection({
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    ),
  );
}

class DesignIcon extends StatelessWidget {
  const DesignIcon(
    this.icon, {
    this.color = AppColors.primary,
    this.size = 32,
    super.key,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, color: color, size: size <= 28 ? 18 : 24),
  );
}

/// Wrap lets content grow at large text sizes instead of clipping fixed cells.
class DesignGrid extends StatelessWidget {
  const DesignGrid({
    required this.children,
    this.columns = 4,
    this.spacing = 8,
    this.minimumCellWidth = 0,
    super.key,
  });
  final List<Widget> children;
  final int columns;
  final double spacing;
  final double minimumCellWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var count =
          constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 18
          ? columns.clamp(1, 2)
          : columns;
      while (count > 1 &&
          (constraints.maxWidth - spacing * (count - 1)) / count <
              minimumCellWidth) {
        count = count > 2 ? 2 : 1;
      }
      final width = (constraints.maxWidth - spacing * (count - 1)) / count;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
