import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/deepseek_pricing.dart';

class DeepSeekPricingBadge extends StatefulWidget {
  const DeepSeekPricingBadge({
    super.key,
    required this.baseUrl,
    required this.model,
  });

  final String baseUrl;
  final String model;

  @override
  State<DeepSeekPricingBadge> createState() => _DeepSeekPricingBadgeState();
}

class _DeepSeekPricingBadgeState extends State<DeepSeekPricingBadge>
    with WidgetsBindingObserver {
  Timer? _minuteTimer;
  late DeepSeekPricingSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _scheduleMinuteRefresh();
  }

  @override
  void didUpdateWidget(covariant DeepSeekPricingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseUrl != widget.baseUrl ||
        oldWidget.model != widget.model) {
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _scheduleMinuteRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuteTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    _snapshot = DeepSeekPricing.evaluate(
      baseUrl: widget.baseUrl,
      model: widget.model,
      now: DateTime.now().toUtc(),
    );
    if (mounted) setState(() {});
  }

  void _scheduleMinuteRefresh() {
    _minuteTimer?.cancel();
    final now = DateTime.now();
    final delay = Duration(
      milliseconds:
          Duration.millisecondsPerMinute -
          (now.millisecond + now.second * Duration.millisecondsPerSecond),
    );
    _minuteTimer = Timer(delay, () {
      if (!mounted) return;
      _refresh();
      _minuteTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _refresh(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final known = _snapshot.period != DeepSeekPricingPeriod.unknown;
    final label = known ? _snapshot.periodLabel : '价格未知';
    final compact = !known
        ? '?'
        : _snapshot.period == DeepSeekPricingPeriod.peak
        ? '峰'
        : '谷';
    final tint = _snapshot.period == DeepSeekPricingPeriod.peak
        ? Colors.orange.shade800
        : _snapshot.period == DeepSeekPricingPeriod.offPeak
        ? Colors.green.shade800
        : colors.onSurfaceVariant;
    final tooltip = 'DeepSeek 价格提醒：$label，点击查看价格规则';
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        onTap: _showDetails,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _showDetails,
            onLongPress: _showDetails,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32, minWidth: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      compact,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: tint, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails() => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: false,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _PricingDetails(snapshot: _snapshot),
  );
}

class _PricingDetails extends StatelessWidget {
  const _PricingDetails({required this.snapshot});

  final DeepSeekPricingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final known = snapshot.period != DeepSeekPricingPeriod.unknown;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DeepSeek Flash · 1017', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text('官方 API 峰谷价格 · 美元 / 百万 token'),
            Text('当前时段：${snapshot.periodLabel}'),
            Text('北京时间：${_formatDateTime(snapshot.beijingTime)}'),
            Text('UTC：${_formatDateTime(snapshot.utcTime)}'),
            const SizedBox(height: 8),
            Text(snapshot.reason),
            const SizedBox(height: 8),
            const Text(
              '北京时间：周一至周五 09:00–12:00、14:00–18:00 为峰时；周末和中国公众假期全天为谷时。谷价为峰价的 50%。',
            ),
            if (known) ...[
              const SizedBox(height: 12),
              Text(
                '每百万 token：缓存命中 \$${snapshot.cacheHitInputUsdPerMillion!.toStringAsFixed(3)}',
              ),
              Text(
                '每百万 token：缓存未命中 \$${snapshot.cacheMissInputUsdPerMillion!.toStringAsFixed(2)}',
              ),
              Text(
                '每百万 token：输出 \$${snapshot.outputUsdPerMillion!.toStringAsFixed(2)}',
              ),
            ],
            const SizedBox(height: 12),
            Text('价格页核验日期：${DeepSeekPricingSnapshot.priceVerifiedOn}'),
            Text(
              '2026 节假日安排核验日期：${DeepSeekPricingSnapshot.holidayCalendarVerifiedOn}',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(DeepSeekPricingSnapshot.pricePageUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('打开 DeepSeek 官方价格页'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
