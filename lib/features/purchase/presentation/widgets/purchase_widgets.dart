import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/purchase_status.dart';

/// Keeps the reference palette and control shapes local to purchase routes.
class PurchasePageTheme extends StatelessWidget {
  const PurchasePageTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final titleStyle =
        base.appBarTheme.titleTextStyle ??
        base.textTheme.titleLarge ??
        const TextStyle();
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Theme(
      data: base.copyWith(
        appBarTheme: base.appBarTheme.copyWith(
          centerTitle: true,
          titleTextStyle: titleStyle.copyWith(
            color: const Color(0xFF102A50),
            fontWeight: FontWeight.w700,
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          shape: rounded,
          side: const BorderSide(color: Color(0xFFE0EAF5)),
          backgroundColor: const Color(0xFFF1F6FC),
          selectedColor: const Color(0xFFE5F8F0),
          labelStyle:
              (base.chipTheme.labelStyle ??
                      base.textTheme.labelLarge ??
                      const TextStyle())
                  .copyWith(color: const Color(0xFF425D7F)),
          secondaryLabelStyle:
              (base.chipTheme.secondaryLabelStyle ??
                      base.textTheme.labelLarge ??
                      const TextStyle())
                  .copyWith(
                    color: const Color(0xFF00A86B),
                    fontWeight: FontWeight.w700,
                  ),
          showCheckmark: false,
        ),
        segmentedButtonTheme: base.segmentedButtonTheme.copyWith(
          style:
              base.segmentedButtonTheme.style?.copyWith(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFF00A86B)
                      : const Color(0xFFF0F5FB),
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : const Color(0xFF425D7F),
                ),
                shape: WidgetStatePropertyAll(rounded),
                side: WidgetStatePropertyAll(
                  const BorderSide(color: Color(0xFFDCE7F3)),
                ),
              ) ??
              ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFF00A86B)
                      : const Color(0xFFF0F5FB),
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : const Color(0xFF425D7F),
                ),
                shape: WidgetStatePropertyAll(rounded),
                side: WidgetStatePropertyAll(
                  const BorderSide(color: Color(0xFFDCE7F3)),
                ),
              ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style:
              base.filledButtonTheme.style?.copyWith(
                shape: WidgetStatePropertyAll(rounded),
              ) ??
              ButtonStyle(shape: WidgetStatePropertyAll(rounded)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style:
              base.outlinedButtonTheme.style?.copyWith(
                shape: WidgetStatePropertyAll(rounded),
                foregroundColor: const WidgetStatePropertyAll(
                  Color(0xFF425D7F),
                ),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: Color(0xFFB7C7DA)),
                ),
              ) ??
              ButtonStyle(
                shape: WidgetStatePropertyAll(rounded),
                foregroundColor: const WidgetStatePropertyAll(
                  Color(0xFF425D7F),
                ),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: Color(0xFFB7C7DA)),
                ),
              ),
        ),
        floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
          backgroundColor: const Color(0xFF00A86B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: rounded,
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD9E4F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00A86B), width: 1.5),
          ),
        ),
      ),
      child: child,
    );
  }
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
      borderRadius: BorderRadius.circular(18),
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
    elevation: 1,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
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
  const PurchaseMaterialIcon({this.size = 76, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.lightBlue,
      borderRadius: BorderRadius.circular(14),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 118;
      return Material(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: EdgeInsets.all(compact ? 7 : 12),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: color, size: 18),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: color, size: 23),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              value,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
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
    },
  );
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
