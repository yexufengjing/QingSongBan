import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/database/database_provider.dart';
import 'fuel_anomaly_service.dart';
import '../data/lifecycle_repository.dart';
import '../data/maintenance_repository.dart';
import '../data/repair_repository.dart';
import '../data/tire_repository.dart';
import '../data/fuel_repository.dart';
import '../data/vehicle_expense_repository.dart';
import '../data/vehicle_attachment_repository.dart';
import '../data/vehicle_attachment_service.dart';
import '../domain/fuel_year_summary_options.dart';
import 'fuel_year_summary_service.dart';
import '../domain/fuel_options.dart';
import '../domain/expense_options.dart';
import '../data/vehicle_condition_repository.dart';
import '../data/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository(ref.watch(appDatabaseProvider));
});

final vehicleSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final vehicleTypeFilterProvider = StateProvider.autoDispose<VehicleType?>(
  (ref) => null,
);

final vehicleStatusFilterProvider = StateProvider.autoDispose<VehicleStatus?>(
  (ref) => null,
);

final vehicleShowDeletedProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

final vehicleListProvider = StreamProvider.autoDispose<List<Vehicle>>((ref) {
  return ref
      .watch(vehicleRepositoryProvider)
      .watchVehicles(
        search: ref.watch(vehicleSearchQueryProvider),
        type: ref.watch(vehicleTypeFilterProvider),
        status: ref.watch(vehicleStatusFilterProvider),
        includeDeleted: ref.watch(vehicleShowDeletedProvider),
      );
});

final allVehiclesProvider = StreamProvider.autoDispose<List<Vehicle>>((ref) {
  return ref.watch(vehicleRepositoryProvider).watchVehicles();
});

final vehicleProvider = FutureProvider.autoDispose.family<Vehicle?, int>(
  (ref, id) => ref.watch(vehicleRepositoryProvider).findById(id),
);

final vehicleConditionRepositoryProvider = Provider<VehicleConditionRepository>(
  (ref) {
    return VehicleConditionRepository(ref.watch(appDatabaseProvider));
  },
);

final vehicleConditionItemsProvider = StreamProvider.autoDispose
    .family<List<VehicleConditionItem>, int>((ref, vehicleId) {
      return ref
          .watch(vehicleConditionRepositoryProvider)
          .watchCurrentItems(vehicleId);
    });

final tireRepositoryProvider = Provider<TireRepository>((ref) {
  return TireRepository(ref.watch(appDatabaseProvider));
});

final vehicleTireAssetsProvider = FutureProvider.autoDispose<List<Tire>>((ref) {
  return ref.watch(tireRepositoryProvider).listAssets();
});

final vehicleTireInstallationsProvider = StreamProvider.autoDispose
    .family<List<TireInstallation>, int>((ref, vehicleId) {
      return ref
          .watch(tireRepositoryProvider)
          .watchCurrentInstallations(vehicleId);
    });

final repairRepositoryProvider = Provider<RepairRepository>((ref) {
  return RepairRepository(ref.watch(appDatabaseProvider));
});

final vehicleRepairOrdersProvider = StreamProvider.autoDispose
    .family<List<RepairOrder>, int>((ref, vehicleId) {
      return ref
          .watch(repairRepositoryProvider)
          .watchOrders(vehicleId: vehicleId);
    });

final allRepairOrdersProvider = StreamProvider.autoDispose<List<RepairOrder>>(
  (ref) => ref.watch(repairRepositoryProvider).watchAllOrders(),
);

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository(ref.watch(appDatabaseProvider));
});

final vehicleMaintenanceItemsProvider = StreamProvider.autoDispose
    .family<List<VehicleMaintenanceItem>, int>((ref, vehicleId) {
      return ref.watch(maintenanceRepositoryProvider).watchItems(vehicleId);
    });

final lifecycleRepositoryProvider = Provider<LifecycleRepository>((ref) {
  return LifecycleRepository(ref.watch(appDatabaseProvider));
});

final vehicleLifecycleRecordsProvider = StreamProvider.autoDispose
    .family<List<ComponentLifecycleRecord>, int>((ref, vehicleId) {
      return ref.watch(lifecycleRepositoryProvider).watchCurrent(vehicleId);
    });

final fuelRepositoryProvider = Provider<FuelRepository>((ref) {
  return FuelRepository(ref.watch(appDatabaseProvider));
});

final vehicleExpenseRepositoryProvider = Provider<VehicleExpenseRepository>((
  ref,
) {
  return VehicleExpenseRepository(ref.watch(appDatabaseProvider));
});

final vehicleAttachmentRepositoryProvider =
    Provider<VehicleAttachmentRepository>((ref) {
      return VehicleAttachmentRepository(ref.watch(appDatabaseProvider));
    });

final vehicleAttachmentServiceProvider = Provider<VehicleAttachmentService>((
  ref,
) {
  return VehicleAttachmentService(
    ref.watch(vehicleAttachmentRepositoryProvider),
  );
});

final vehicleAttachmentsProvider = StreamProvider.autoDispose
    .family<List<VehicleAttachment>, (int, bool)>((ref, key) {
      return ref
          .watch(vehicleAttachmentRepositoryProvider)
          .watchForVehicle(key.$1, includeDeleted: key.$2);
    });

final vehicleFuelProvider = FutureProvider.autoDispose
    .family<List<FuelMonthlyRecord>, (int, int)>((ref, key) {
      return ref.watch(fuelRepositoryProvider).listByVehicle(key.$1, key.$2);
    });

final vehicleCurrentFuelAnomalyProvider = FutureProvider.autoDispose
    .family<FuelAnomaly?, int>((ref, vehicleId) {
      final now = DateTime.now();
      return FuelAnomalyService(ref.watch(fuelRepositoryProvider))
          .analyze(vehicleId: vehicleId, year: now.year, month: now.month);
    });

final vehicleFuelSummaryProvider = FutureProvider.autoDispose
    .family<FuelAnnualSummary, (int, int)>((ref, key) {
      return ref.watch(fuelRepositoryProvider).annualSummary(key.$1, key.$2);
    });

final fuelYearSummaryServiceProvider = Provider<FuelYearSummaryService>((ref) {
  return FuelYearSummaryService(ref.watch(appDatabaseProvider));
});

final fuelYearSummaryProvider = FutureProvider.autoDispose
    .family<FuelYearSummary, int>((ref, year) {
      return ref.watch(fuelYearSummaryServiceProvider).build(year);
    });

final vehicleExpenseItemsProvider = FutureProvider.autoDispose
    .family<List<VehicleExpenseItem>, int>((ref, vehicleId) {
      return ref
          .watch(vehicleExpenseRepositoryProvider)
          .list(vehicleId, year: DateTime.now().year);
    });
