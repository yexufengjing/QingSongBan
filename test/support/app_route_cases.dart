/// Production route destinations covered by contract and render audits.
///
/// Dynamic path and query values use named tokens. [AppRouteCase.locationFor]
/// substitutes supplied fixture IDs and uses 999999 for absent records.
class AppRouteCase {
  const AppRouteCase(this.location, this.name, {this.missingRecordRedirect});

  final String location;
  final String name;
  final String? missingRecordRedirect;

  String locationFor([Map<String, int> ids = const {}]) =>
      location.replaceAllMapped(RegExp(r':([A-Za-z][A-Za-z0-9_]*)'), (match) {
        return '${ids[match[1]] ?? 999999}';
      });
}

const appRouteCases = <AppRouteCase>[
  AppRouteCase('/home', 'home'),
  AppRouteCase('/personnel', 'personnel'),
  AppRouteCase(
    '/personnel/list?status=active&hireMonth=2026-10',
    'personnel-list',
  ),
  AppRouteCase('/personnel/new', 'personnel-new'),
  AppRouteCase('/personnel/:employeeId', 'personnel-detail'),
  AppRouteCase('/personnel/:employeeId/attachments', 'personnel-attachments'),
  AppRouteCase('/personnel/:employeeId/payroll', 'employee-payroll'),
  AppRouteCase('/personnel/:employeeId/edit', 'personnel-edit'),
  AppRouteCase('/attendance', 'attendance'),
  AppRouteCase('/attendance/daily', 'daily-attendance'),
  AppRouteCase(
    '/attendance/monthly-table?month=2026-10',
    'monthly-attendance-table',
  ),
  AppRouteCase('/attendance/monthly-roster', 'monthly-roster'),
  AppRouteCase('/attendance/leave', 'leave'),
  AppRouteCase('/attendance/leave/new', 'leave-new'),
  AppRouteCase('/attendance/leave/:leaveId/edit', 'leave-edit'),
  AppRouteCase('/attendance/overtime', 'overtime'),
  AppRouteCase('/attendance/overtime/new', 'overtime-new'),
  AppRouteCase('/attendance/overtime/:overtimeId/edit', 'overtime-edit'),
  AppRouteCase('/attendance/termination', 'termination'),
  AppRouteCase('/attendance/termination/new', 'termination-new'),
  AppRouteCase(
    '/attendance/termination/:terminationId/edit',
    'termination-edit',
  ),
  AppRouteCase('/attendance/groups', 'attendance-groups'),
  AppRouteCase('/attendance/groups/new', 'attendance-group-new'),
  AppRouteCase(
    '/attendance/groups/:attendanceGroupId',
    'attendance-group-detail',
  ),
  AppRouteCase(
    '/attendance/groups/:attendanceGroupId/edit',
    'attendance-group-edit',
  ),
  AppRouteCase('/reports', 'reports'),
  AppRouteCase('/reports/payroll', 'payroll'),
  AppRouteCase('/reports/payroll/edit/:batchId', 'payroll-edit'),
  AppRouteCase('/reports/payroll/item/:itemId', 'payroll-item-detail'),
  AppRouteCase('/reports/payroll/history', 'payroll-history'),
  AppRouteCase('/reports/payroll/settings', 'payroll-settings'),
  AppRouteCase('/reports/payroll/export/:batchId', 'payroll-export'),
  AppRouteCase('/settings', 'settings'),
  AppRouteCase('/settings/insurance', 'insurance'),
  AppRouteCase(
    '/settings/insurance/profile?employeeId=:employeeId',
    'insurance-profile',
  ),
  AppRouteCase('/settings/insurance/change', 'insurance-change'),
  AppRouteCase(
    '/settings/insurance/change/:changeId/edit',
    'insurance-change-edit',
    missingRecordRedirect: 'insurance-change',
  ),
  AppRouteCase('/settings/excel?month=2026-10', 'excel'),
  AppRouteCase('/settings/reminders', 'reminders'),
  AppRouteCase('/settings/reminders/new?title=route-audit', 'reminder-new'),
  AppRouteCase(
    '/settings/reminders/:id/edit',
    'reminder-edit',
    missingRecordRedirect: 'reminders',
  ),
  AppRouteCase('/settings/backup', 'backup'),
  AppRouteCase('/settings/operation-logs', 'operation-logs'),
  AppRouteCase('/inventory', 'inventory-home'),
  AppRouteCase('/inventory/materials', 'inventory-materials'),
  AppRouteCase('/inventory/materials/new', 'inventory-material-new'),
  AppRouteCase('/inventory/materials/:materialId', 'inventory-material-detail'),
  AppRouteCase(
    '/inventory/materials/:materialId/edit',
    'inventory-material-edit',
  ),
  AppRouteCase('/inventory/receipts', 'inventory-receipts'),
  AppRouteCase('/inventory/receipts/new', 'inventory-receipt-new'),
  AppRouteCase('/inventory/receipts/:receiptId', 'inventory-receipt-detail'),
  AppRouteCase('/inventory/issues', 'inventory-issues'),
  AppRouteCase('/inventory/issues/new', 'inventory-issue-new'),
  AppRouteCase('/inventory/issues/:issueId', 'inventory-issue-detail'),
  AppRouteCase('/inventory/stock', 'inventory-stock'),
  AppRouteCase('/inventory/stocktake', 'inventory-stocktakes'),
  AppRouteCase('/inventory/stocktake/new', 'inventory-stocktake-new'),
  AppRouteCase(
    '/inventory/stocktake/:stocktakeId',
    'inventory-stocktake-detail',
  ),
  AppRouteCase('/inventory/warnings', 'inventory-warnings'),
  AppRouteCase('/inventory/replenishment', 'inventory-replenishments'),
  AppRouteCase('/inventory/transactions', 'inventory-transactions'),
  AppRouteCase('/inventory/adjust?materialId=:materialId', 'inventory-adjust'),
  AppRouteCase('/purchase', 'purchase-home'),
  AppRouteCase('/purchase/create?editId=:editRequestId', 'purchase-create'),
  AppRouteCase('/purchase/pending-apply', 'purchase-pending-apply'),
  AppRouteCase('/purchase/tracking?all=1', 'purchase-tracking'),
  AppRouteCase('/purchase/pending-receive', 'purchase-pending-receive'),
  AppRouteCase('/purchase/history?preset=month', 'purchase-history'),
  AppRouteCase('/purchase/detail/:requestId', 'purchase-detail'),
  AppRouteCase('/purchase/stock-in/:requestId', 'purchase-stock-in'),
  AppRouteCase('/purchase/item-history/:materialId', 'purchase-item-history'),
  AppRouteCase('/items', 'item-distribution'),
  AppRouteCase(
    '/garden-tool-repairs?year=2026&month=10',
    'garden-tool-repairs',
  ),
  AppRouteCase('/garden-tool-repairs/units', 'garden-tool-repair-units'),
  AppRouteCase(
    '/garden-tool-repairs/analysis?year=2026&month=10',
    'garden-tool-repair-analysis',
  ),
  AppRouteCase('/garden-tool-repairs/prices', 'garden-tool-repair-prices'),
  AppRouteCase(
    '/garden-tool-repairs/new?year=2026&month=10',
    'garden-tool-repair-new',
  ),
  AppRouteCase(
    '/garden-tool-repairs/groups/:gardenRepairGroupId/edit',
    'garden-tool-repair-edit',
  ),
  AppRouteCase(
    '/garden-tool-repairs/groups/:gardenRepairGroupId/attachments',
    'garden-tool-repair-attachments',
  ),
  AppRouteCase('/vehicles/repairs', 'vehicle-repairs'),
  AppRouteCase('/vehicles/repairs/:repairOrderId', 'vehicle-repair-detail'),
  AppRouteCase('/vehicles/repairs/:repairOrderId/edit', 'vehicle-repair-edit'),
  AppRouteCase('/vehicles', 'vehicles'),
  AppRouteCase('/vehicles/archive', 'vehicle-archive'),
  AppRouteCase('/vehicles/reminders', 'vehicle-reminders'),
  AppRouteCase('/vehicles/fuel-summary', 'vehicle-fuel-summary'),
  AppRouteCase('/vehicles/new', 'vehicle-new'),
  AppRouteCase('/vehicles/:vehicleId', 'vehicle-detail'),
  AppRouteCase('/vehicles/:vehicleId/edit', 'vehicle-edit'),
  AppRouteCase('/vehicles/:vehicleId/repair/new', 'vehicle-repair-new'),
  AppRouteCase(
    '/vehicles/:vehicleId/attachments?repairOrderId=:repairOrderId',
    'vehicle-attachments',
  ),
];
