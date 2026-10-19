import '../domain/assistant_models.dart';

/// The only projection sent when asking DeepSeek to explain a summary.
///
/// The domain value intentionally has only four fields. This serializer keeps
/// that allowlist explicit at the network boundary.
Map<String, Object> projectAttendanceSummary(
  AttendanceOutboundSummary summary,
) => {
  'yearMonth': summary.yearMonth,
  'attendanceDays': summary.attendanceDays,
  'leaveAndRestDays': summary.leaveAndRestDays,
  'overtimeMinutes': summary.overtimeMinutes,
};

Map<String, Object> projectVehicleAnnualRepairSummary(
  VehicleAnnualRepairOutboundSummary summary,
) => {
  'year': summary.year,
  'completedRepairCount': summary.completedRepairCount,
  'actualAmountCents': summary.actualAmountCents,
  'currency': summary.currency,
};

Map<String, Object> projectVehicleRanking(
  VehicleRankingOutboundProjection ranking,
) {
  final cursor = ranking.nextCursor;
  return {
    'year': ranking.year,
    'rows': [
      for (final row in ranking.rows)
        {
          'alias': row.alias,
          'rank': row.rank,
          'completedRepairCount': row.completedRepairCount,
          'actualAmountCents': row.actualAmountCents,
        },
    ],
    'totalVehicleCount': ranking.totalVehicleCount,
    'returnedCount': ranking.returnedCount,
    'hasMore': ranking.hasMore,
    'nextCursor': ?cursor,
  };
}
