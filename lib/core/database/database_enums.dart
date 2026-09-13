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
