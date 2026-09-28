import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/garden_tool_repair_attachment_service.dart';
import '../data/garden_tool_repair_repository.dart';
import '../domain/repair_models.dart';
import 'garden_tool_repair_analysis_service.dart';

final gardenToolRepairRepositoryProvider = Provider<GardenToolRepairRepository>(
  (ref) {
    return GardenToolRepairRepository(ref.watch(appDatabaseProvider));
  },
);

final gardenToolRepairAnalysisServiceProvider =
    Provider<GardenToolRepairAnalysisService>((ref) {
      return const GardenToolRepairAnalysisService();
    });

final gardenToolRepairAttachmentServiceProvider =
    Provider<GardenToolRepairAttachmentService>((ref) {
      return GardenToolRepairAttachmentService(
        ref.watch(gardenToolRepairRepositoryProvider),
      );
    });

final gardenToolRepairUnitsProvider =
    StreamProvider.family<List<GardenToolRepairUnit>, bool>((
      ref,
      includeInactive,
    ) {
      return ref
          .watch(gardenToolRepairRepositoryProvider)
          .watchUnits(includeInactive: includeInactive);
    });

final gardenToolRepairPersonsProvider =
    StreamProvider.family<List<GardenToolRepairPerson>, int>((ref, unitId) {
      return ref.watch(gardenToolRepairRepositoryProvider).watchPersons(unitId);
    });

final gardenToolRepairAttachmentsProvider =
    StreamProvider.family<List<GardenToolRepairAttachment>, int>((
      ref,
      groupId,
    ) {
      return ref
          .watch(gardenToolRepairRepositoryProvider)
          .watchAttachments(groupId);
    });

final gardenToolRepairMonthProvider =
    StreamProvider.family<List<GardenToolRepairLedgerGroup>, DateTime>((
      ref,
      month,
    ) {
      return ref.watch(gardenToolRepairRepositoryProvider).watchMonth(month);
    });

typedef GardenToolRepairPeriodFilter = ({
  DateTime start,
  DateTime endExclusive,
  int? unitId,
});

final gardenToolRepairPeriodProvider =
    StreamProvider.family<
      List<GardenToolRepairLedgerGroup>,
      GardenToolRepairPeriodFilter
    >((ref, filter) {
      return ref
          .watch(gardenToolRepairRepositoryProvider)
          .watchPeriod(
            start: filter.start,
            endExclusive: filter.endExclusive,
            unitId: filter.unitId,
          );
    });

final gardenToolRepairAnalyticsProvider = Provider((ref) {
  return ref.watch(gardenToolRepairAnalysisServiceProvider);
});

final gardenToolRepairLedgerSummaryProvider =
    Provider.family<
      GardenToolRepairMonthSummary,
      List<GardenToolRepairLedgerGroup>
    >((ref, groups) {
      return GardenToolRepairMonthSummary.fromGroups(groups);
    });

final gardenToolRepairPriceSummaryProvider =
    Provider.family<
      GardenToolRepairPriceSummary,
      List<GardenToolRepairPricePoint>
    >((ref, points) {
      if (points.isEmpty) {
        return const GardenToolRepairPriceSummary(
          points: [],
          averagePriceCents: null,
          minimumPriceCents: null,
          maximumPriceCents: null,
        );
      }
      final prices = points.map((point) => point.unitPriceCents).toList();
      return GardenToolRepairPriceSummary(
        points: points,
        averagePriceCents: (prices.reduce((a, b) => a + b) / prices.length)
            .round(),
        minimumPriceCents: prices.reduce((a, b) => a < b ? a : b),
        maximumPriceCents: prices.reduce((a, b) => a > b ? a : b),
      );
    });

final gardenToolRepairPriceItemOptionsProvider = FutureProvider((ref) {
  return ref.watch(gardenToolRepairRepositoryProvider).loadPriceItemOptions();
});

typedef GardenToolRepairPriceFilter = ({
  String projectName,
  String specModel,
  String countUnit,
  DateTime start,
  DateTime endExclusive,
  int? unitId,
});

final gardenToolRepairPricePointsProvider =
    FutureProvider.family<
      List<GardenToolRepairPricePoint>,
      GardenToolRepairPriceFilter
    >((ref, filter) {
      return ref
          .watch(gardenToolRepairRepositoryProvider)
          .loadPricePoints(
            projectName: filter.projectName,
            specModel: filter.specModel,
            countUnit: filter.countUnit,
            start: filter.start,
            endExclusive: filter.endExclusive,
            unitId: filter.unitId,
          );
    });
