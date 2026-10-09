import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../domain/purchase_status.dart';

/// Purchase routes share the app reference theme, including modal controls.
class PurchasePageTheme extends StatelessWidget {
  const PurchasePageTheme({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

/// Owns resources created specifically for a modal route. The route future
/// completes as soon as pop starts, so disposal belongs to the sheet subtree
/// after its reverse transition has actually finished.
class PurchaseSheetResources extends StatefulWidget {
  const PurchaseSheetResources({
    required this.resources,
    required this.child,
    super.key,
  });

  final List<ChangeNotifier> resources;
  final Widget child;

  @override
  State<PurchaseSheetResources> createState() => _PurchaseSheetResourcesState();
}

class _PurchaseSheetResourcesState extends State<PurchaseSheetResources> {
  @override
  void dispose() {
    for (final resource in widget.resources) {
      resource.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PurchasePageTheme(child: widget.child);
}

class PurchaseStatusChip extends StatelessWidget {
  const PurchaseStatusChip({required this.status, super.key});

  final PurchaseStatus status;

  Color get _color => switch (status) {
    PurchaseStatus.pendingApply => const Color(0xFF00A86B),
    PurchaseStatus.applied => AppColors.techBlue,
    PurchaseStatus.purchasing => const Color(0xFF10B7A3),
    PurchaseStatus.pendingReceive => const Color(0xFFFF8A1F),
    PurchaseStatus.stocked => AppColors.primary,
    PurchaseStatus.cancelled => AppColors.danger,
  };

  Color get _background => switch (status) {
    PurchaseStatus.pendingApply => const Color(0xFFE5F8F0),
    PurchaseStatus.applied => AppColors.lightBlue,
    PurchaseStatus.purchasing => const Color(0xFFE3F8F3),
    PurchaseStatus.pendingReceive => AppColors.lightOrange,
    PurchaseStatus.stocked => AppColors.lightGreen,
    PurchaseStatus.cancelled => AppColors.lightDanger,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: _background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      status.label,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: _color, fontWeight: FontWeight.w700),
    ),
  );
}

class PurchasePanel extends StatelessWidget {
  const PurchasePanel({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFEAF0F7)),
    ),
    child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
  );
}

class PurchaseSectionHeading extends StatelessWidget {
  const PurchaseSectionHeading(
    this.title, {
    this.trailing,
    this.icon,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 9),
      if (icon != null) ...[
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 6),
      ],
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      ?trailing,
    ],
  );
}

class PurchaseMaterialIcon extends StatelessWidget {
  const PurchaseMaterialIcon({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.lightBlue,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(
      Icons.inventory_2_outlined,
      size: size * .48,
      color: AppColors.techBlue,
    ),
  );
}

class PurchaseEmptyState extends StatelessWidget {
  const PurchaseEmptyState({
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.helper),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action case final button?) ...[
            const SizedBox(height: 18),
            button,
          ],
        ],
      ),
    ),
  );
}

class PurchaseLoadingState extends StatelessWidget {
  const PurchaseLoadingState({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class PurchaseErrorState extends StatelessWidget {
  const PurchaseErrorState({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => PurchaseEmptyState(
    title: '加载失败',
    message: '请检查本地数据后重试。',
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('重新加载'),
    ),
  );
}

class PurchaseMetricTile extends StatelessWidget {
  const PurchaseMetricTile({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: .04),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  DesignIcon(icon!, color: color, size: 20),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PurchaseLabeledField extends StatelessWidget {
  const PurchaseLabeledField({
    required this.label,
    required this.child,
    this.inline = false,
    this.labelWidth = 132,
    super.key,
  });

  final String label;
  final Widget child;
  final bool inline;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
    );
    if (inline) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(14) > 17;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: labelWidget,
                ),
                child,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: labelWidth, child: labelWidget),
              const SizedBox(width: 10),
              Expanded(child: child),
            ],
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: labelWidget),
        child,
      ],
    );
  }
}

String purchaseDateLabel(DateTime? date) {
  if (date == null) return '未填写';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String purchaseShortDateLabel(DateTime? date) {
  if (date == null) return '未填写';
  return '${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
}

String purchaseQuantityLabel(double quantity) =>
    quantity == quantity.roundToDouble()
    ? quantity.toInt().toString()
    : quantity.toString();

Future<DateTime?> pickPurchaseDate(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initialDate ?? now,
    firstDate: DateTime(2000),
    lastDate: DateTime(now.year + 20),
    builder: (context, child) => PurchasePageTheme(child: child!),
  );
}
