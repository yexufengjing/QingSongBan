/// DeepSeek Flash pricing and peak-hour rules published in the official docs.
///
/// Peak hours are evaluated in UTC. The official public-holiday calendar is
/// currently embedded only for 2026; a weekday peak window in any other year
/// stays unknown until an official calendar is added.
enum DeepSeekPricingPeriod { peak, offPeak, unknown }

class DeepSeekPricingSnapshot {
  const DeepSeekPricingSnapshot({
    required this.period,
    required this.utcTime,
    required this.beijingTime,
    required this.reason,
  });

  final DeepSeekPricingPeriod period;
  final DateTime utcTime;
  final DateTime beijingTime;
  final String reason;

  static const pricePageUrl =
      'https://api-docs.deepseek.com/quick_start/pricing/';
  static const priceVerifiedOn = '2026-10-23';
  static const holidayCalendarVerifiedOn = '2026-10-23';

  double? get cacheHitInputUsdPerMillion => switch (period) {
    DeepSeekPricingPeriod.peak => 0.006,
    DeepSeekPricingPeriod.offPeak => 0.003,
    DeepSeekPricingPeriod.unknown => null,
  };

  double? get cacheMissInputUsdPerMillion => switch (period) {
    DeepSeekPricingPeriod.peak => 0.30,
    DeepSeekPricingPeriod.offPeak => 0.15,
    DeepSeekPricingPeriod.unknown => null,
  };

  double? get outputUsdPerMillion => switch (period) {
    DeepSeekPricingPeriod.peak => 1.20,
    DeepSeekPricingPeriod.offPeak => 0.60,
    DeepSeekPricingPeriod.unknown => null,
  };

  String get periodLabel => switch (period) {
    DeepSeekPricingPeriod.peak => '峰时',
    DeepSeekPricingPeriod.offPeak => '谷时',
    DeepSeekPricingPeriod.unknown => '时段未知',
  };
}

/// Holiday source: https://www.gov.cn/zhengce/content/202511/content_7047090.htm
class DeepSeekPricing {
  DeepSeekPricing._();

  static const officialModel = 'deepseek-flash';

  /// Calculates the current price locally. [now] may have any timezone; its
  /// instant is normalized to UTC before the official peak windows are checked.
  static DeepSeekPricingSnapshot evaluate({
    required String baseUrl,
    required String model,
    required DateTime now,
  }) {
    final utc = now.toUtc();
    final beijing = utc.add(const Duration(hours: 8));
    if (!_isOfficialBaseUrl(baseUrl)) {
      return _unknown(utc, beijing, '当前 API 地址不是 DeepSeek 官方地址，无法核验价格。');
    }
    if (model.trim() != officialModel) {
      return _unknown(utc, beijing, '当前模型不是 deepseek-flash，官方 Flash 价格不适用。');
    }

    // Saturday and Sunday remain off-peak even when the government schedule
    // marks them as make-up workdays.
    if (utc.weekday == DateTime.saturday || utc.weekday == DateTime.sunday) {
      return DeepSeekPricingSnapshot(
        period: DeepSeekPricingPeriod.offPeak,
        utcTime: utc,
        beijingTime: beijing,
        reason: '周末全天为谷时（调休上班日仍按周末计）。',
      );
    }

    final hour = utc.hour;
    final isPotentialPeak = (hour >= 1 && hour < 4) || (hour >= 6 && hour < 10);
    if (!isPotentialPeak) {
      return DeepSeekPricingSnapshot(
        period: DeepSeekPricingPeriod.offPeak,
        utcTime: utc,
        beijingTime: beijing,
        reason: '当前 UTC 时间不在工作日峰时窗口内。',
      );
    }

    if (beijing.year != 2026) {
      return _unknown(utc, beijing, '该年份没有已核验的中国公众假期日历，工作日峰时状态未知。');
    }
    if (_is2026PublicHoliday(beijing.month, beijing.day)) {
      return DeepSeekPricingSnapshot(
        period: DeepSeekPricingPeriod.offPeak,
        utcTime: utc,
        beijingTime: beijing,
        reason: '命中国务院办公厅公布的 2026 年公众假期，全天为谷时。',
      );
    }

    return DeepSeekPricingSnapshot(
      period: DeepSeekPricingPeriod.peak,
      utcTime: utc,
      beijingTime: beijing,
      reason: '工作日 UTC 峰时窗口：01:00–04:00、06:00–10:00。',
    );
  }

  static bool _isOfficialBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == 'api.deepseek.com' &&
        (uri.port == 443) &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  static bool _is2026PublicHoliday(int month, int day) {
    const ranges = <(int, int, int, int)>[
      (1, 1, 1, 3),
      (2, 15, 2, 23),
      (4, 4, 4, 6),
      (5, 1, 5, 5),
      (6, 19, 6, 21),
      (9, 25, 9, 27),
      (10, 1, 10, 7),
    ];
    final date = month * 100 + day;
    return ranges.any(
      (range) =>
          date >= range.$1 * 100 + range.$2 &&
          date <= range.$3 * 100 + range.$4,
    );
  }

  static DeepSeekPricingSnapshot _unknown(
    DateTime utc,
    DateTime beijing,
    String reason,
  ) => DeepSeekPricingSnapshot(
    period: DeepSeekPricingPeriod.unknown,
    utcTime: utc,
    beijingTime: beijing,
    reason: reason,
  );
}
