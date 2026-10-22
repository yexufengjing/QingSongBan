import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/domain/deepseek_pricing.dart';

void main() {
  const baseUrl = 'https://api.deepseek.com';
  const model = 'deepseek-flash';

  DeepSeekPricingSnapshot at(String instant) => DeepSeekPricing.evaluate(
    baseUrl: baseUrl,
    model: model,
    now: DateTime.parse(instant),
  );

  test('classifies both UTC peak windows with half-open boundaries', () {
    expect(at('2026-10-22T01:00:00Z').period, DeepSeekPricingPeriod.peak);
    expect(at('2026-10-22T03:59:59Z').period, DeepSeekPricingPeriod.peak);
    expect(at('2026-10-22T04:00:00Z').period, DeepSeekPricingPeriod.offPeak);
    expect(at('2026-10-22T06:00:00Z').period, DeepSeekPricingPeriod.peak);
    expect(at('2026-10-22T09:59:59Z').period, DeepSeekPricingPeriod.peak);
    expect(at('2026-10-22T10:00:00Z').period, DeepSeekPricingPeriod.offPeak);
  });

  test(
    'uses official 2026 holidays and leaves other years unknown at peak',
    () {
      expect(at('2026-10-05T01:30:00Z').period, DeepSeekPricingPeriod.offPeak);
      expect(at('2026-06-19T06:30:00Z').period, DeepSeekPricingPeriod.offPeak);
      expect(at('2027-10-04T01:30:00Z').period, DeepSeekPricingPeriod.unknown);
      expect(at('2027-10-04T04:30:00Z').period, DeepSeekPricingPeriod.offPeak);
    },
  );

  test('weekends remain off-peak on official make-up workdays', () {
    expect(at('2026-10-10T01:30:00Z').period, DeepSeekPricingPeriod.offPeak);
    expect(at('2026-02-14T06:30:00Z').period, DeepSeekPricingPeriod.offPeak);
  });

  test('normalizes non-UTC DateTime instants and reports Beijing time', () {
    final snapshot = at('2026-10-22T09:00:00+08:00');
    expect(snapshot.period, DeepSeekPricingPeriod.peak);
    expect(snapshot.utcTime, DateTime.utc(2026, 10, 22, 1));
    expect(snapshot.beijingTime, DateTime.utc(2026, 10, 22, 9));
  });

  test('does not apply official Flash pricing to other hosts or models', () {
    expect(
      DeepSeekPricing.evaluate(
        baseUrl: 'https://proxy.example.com',
        model: model,
        now: DateTime.utc(2026, 10, 22, 1),
      ).period,
      DeepSeekPricingPeriod.unknown,
    );
    expect(
      DeepSeekPricing.evaluate(
        baseUrl: baseUrl,
        model: 'deepseek-v4-pro',
        now: DateTime.utc(2026, 10, 22, 1),
      ).period,
      DeepSeekPricingPeriod.unknown,
    );
  });

  test('exposes distinct peak and off-peak token prices', () {
    final peak = at('2026-10-22T01:00:00Z');
    final offPeak = at('2026-10-22T04:00:00Z');
    expect(peak.cacheHitInputUsdPerMillion, 0.006);
    expect(peak.cacheMissInputUsdPerMillion, 0.30);
    expect(peak.outputUsdPerMillion, 1.20);
    expect(offPeak.cacheHitInputUsdPerMillion, 0.003);
    expect(offPeak.cacheMissInputUsdPerMillion, 0.15);
    expect(offPeak.outputUsdPerMillion, 0.60);
  });
}
