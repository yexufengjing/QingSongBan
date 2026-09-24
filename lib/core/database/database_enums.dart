/// Long-lived employee status. Leave and attendance states are separate
/// concepts and must not be added here.
enum EmployeeStatus { active, paused, terminated }

/// Status of one half-day attendance slot.
enum AttendanceHalfStatus {
  unregistered,
  present,
  leave,
  absent,
  rest,
  stopped,
  notEmployed,
  terminated,
}

/// Business category of a leave record.
enum LeaveType { personal, sick, other, custom }

/// Boundary half-day used to represent a leave date range.
enum LeaveHalfPeriod { morning, afternoon }

/// Lifecycle of a generated monthly attendance summary.
enum MonthlySummaryStatus { notGenerated, pendingReview, confirmed, locked }

/// Lifecycle of a generated temporary-worker payroll batch.
enum PayrollStatus { draft, pendingReview, confirmed, locked }

/// Supported vehicle types in the vehicle management module.
enum VehicleType { sweeper, waterTruck }

/// Current lifecycle state of a vehicle.
enum VehicleStatus { normal, pendingRepair, repairing, stopped, scrapped }

/// Status shared by current vehicle condition items.
enum VehicleConditionStatus {
  normal,
  minorAbnormal,
  needsAttention,
  pendingRepair,
  repairing,
  unavailable,
}

/// Stable business identity for the six tire positions.
enum TirePosition {
  leftFront,
  rightFront,
  leftRearOuter,
  leftRearInner,
  rightRearOuter,
  rightRearInner,
}

enum TireAssetStatus { inUse, spare, removed, scrapped }

enum TireCondition { newTire, usedTire, retreaded }

enum TireWearLevel { good, light, medium, severe, replaceRecommended }

enum TireInstallReason {
  newReplacement,
  rotation,
  relocation,
  reinstalledAfterRepair,
  temporaryRepair,
  other,
}

enum TireRepairType { patch, vulcanization, coldPatch, valve, other }

enum TireRepairSeverity { minor, ordinary, serious }

enum VehicleRepairStatus {
  reported,
  pendingRepair,
  repairing,
  completed,
  cancelled,
}

enum RepairTicketStatus { notIssued, issued, notRequired }

enum RepairCostType { labor, part, material, outsourcing, other }

enum MaintenanceIntervalUnit { days, months, years }

enum MaintenanceDueStatus { noRecord, normal, dueSoon, due, overdue }

enum LifecycleStatus { inUse, spare, removed, scrapped }

enum VehicleManualExpenseType {
  inspection,
  outsourcing,
  cleaning,
  painting,
  other,
}

enum VehicleAttachmentCategory {
  vehiclePhoto,
  repair,
  maintenance,
  certificate,
  other,
}
