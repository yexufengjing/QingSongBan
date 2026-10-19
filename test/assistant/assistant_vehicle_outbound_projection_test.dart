import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/data/assistant_outbound_projection.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';

void main() {
  test('vehicle annual summary projection contains only approved metrics', () {
    final projected = projectVehicleAnnualRepairSummary(
      const VehicleAnnualRepairOutboundSummary(
        year: 2026,
        completedRepairCount: 2,
        actualAmountCents: 12000,
      ),
    );

    expect(projected.keys.toSet(), {
      'year',
      'completedRepairCount',
      'actualAmountCents',
      'currency',
    });
    expect(projected, {
      'year': 2026,
      'completedRepairCount': 2,
      'actualAmountCents': 12000,
      'currency': 'CNY',
    });
  });

  test(
    'vehicle ranking projection uses aliases and excludes local identities',
    () {
      final projected = projectVehicleRanking(
        const VehicleRankingOutboundProjection(
          year: 2026,
          rows: [
            VehicleRankingOutboundRow(
              alias: 'V001',
              rank: 1,
              completedRepairCount: 2,
              actualAmountCents: 12000,
            ),
          ],
          totalVehicleCount: 8,
          returnedCount: 1,
          hasMore: true,
          nextCursor: 'local-cursor',
        ),
      );
      final row = (projected['rows'] as List).single as Map<String, Object>;

      expect(row.keys.toSet(), {
        'alias',
        'rank',
        'completedRepairCount',
        'actualAmountCents',
      });
      expect(row.containsKey('vehicleId'), isFalse);
      expect(row.containsKey('vehicleNumber'), isFalse);
      expect(projected['nextCursor'], 'local-cursor');
    },
  );
}
