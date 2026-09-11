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

/// Lifecycle of a generated monthly attendance summary.
enum MonthlySummaryStatus { notGenerated, pendingReview, confirmed, locked }
