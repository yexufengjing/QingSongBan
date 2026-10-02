import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database_enums.dart';
import '../../core/utils/date_utils.dart';
import '../../features/attendance/presentation/attendance_page.dart';
import '../../features/attendance/presentation/attendance_group_detail_page.dart';
import '../../features/attendance/presentation/attendance_group_form_page.dart';
import '../../features/attendance/presentation/attendance_group_list_page.dart';
import '../../features/attendance/presentation/daily_attendance_page.dart';
import '../../features/attendance/presentation/monthly_roster_page.dart';
import '../../features/attendance/presentation/monthly_attendance_table_page.dart';
import '../../features/attachments/presentation/employee_attachments_page.dart';
import '../../features/leave/presentation/leave_form_page.dart';
import '../../features/leave/presentation/leave_page.dart';
import '../../features/overtime/presentation/overtime_form_page.dart';
import '../../features/overtime/presentation/overtime_page.dart';
import '../../features/termination/presentation/termination_form_page.dart';
import '../../features/termination/presentation/termination_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/insurance/presentation/insurance_change_form_page.dart';
import '../../features/insurance/presentation/insurance_page.dart';
import '../../features/insurance/presentation/insurance_profile_form_page.dart';
import '../../features/excel/presentation/excel_page.dart';
import '../../features/reminders/presentation/reminder_form_page.dart';
import '../../features/reminders/presentation/reminder_page.dart';
import '../../features/backup/presentation/backup_page.dart';
import '../../features/operation_logs/presentation/operation_log_page.dart';
import '../../features/personnel/presentation/personnel_page.dart';
import '../../features/personnel/presentation/personnel_detail_page.dart';
import '../../features/personnel/presentation/personnel_form_page.dart';
import '../../features/personnel/presentation/personnel_list_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/payroll/presentation/payroll_detail_page.dart';
import '../../features/payroll/presentation/payroll_editor_page.dart';
import '../../features/payroll/presentation/payroll_export_page.dart';
import '../../features/payroll/presentation/payroll_history_page.dart';
import '../../features/payroll/presentation/payroll_home_page.dart';
import '../../features/payroll/presentation/employee_payroll_page.dart';
import '../../features/payroll/presentation/wage_job_settings_page.dart';
import '../../features/item_distribution/presentation/item_distribution_page.dart';
import '../../features/inventory/inventory_routes.dart';
import '../../features/purchase/presentation/purchase_create_page.dart';
import '../../features/purchase/presentation/purchase_detail_page.dart';
import '../../features/purchase/presentation/purchase_home_page.dart';
import '../../features/purchase/presentation/purchase_history_page.dart';
import '../../features/purchase/presentation/purchase_item_history_page.dart';
import '../../features/purchase/presentation/purchase_item_prefill.dart';
import '../../features/purchase/presentation/purchase_pending_apply_page.dart';
import '../../features/purchase/presentation/purchase_pending_receive_page.dart';
import '../../features/purchase/presentation/purchase_stock_in_page.dart';
import '../../features/purchase/presentation/purchase_tracking_page.dart';
import '../../features/purchase/domain/purchase_status.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/vehicles/application/vehicle_providers.dart';
import '../../features/vehicles/presentation/vehicle_detail_page.dart';
import '../../features/vehicles/presentation/vehicle_archive_page.dart';
import '../../features/vehicles/presentation/vehicle_reminder_page.dart';
import '../../features/vehicles/presentation/vehicle_fuel_summary_page.dart';
import '../../features/vehicles/presentation/vehicle_attachments_page.dart';
import '../../features/vehicles/presentation/vehicle_form_page.dart';
import '../../features/vehicles/presentation/vehicle_page.dart';
import '../../features/vehicles/presentation/vehicle_repair_detail_page.dart';
import '../../features/vehicles/presentation/vehicle_repair_form_page.dart';
import '../../features/vehicles/presentation/vehicle_repair_list_page.dart';
import '../../features/garden_tool_repairs/domain/repair_models.dart';
import '../../features/garden_tool_repairs/presentation/garden_tool_repair_attachments_page.dart';
import '../../features/garden_tool_repairs/presentation/garden_tool_repair_analysis_page.dart';
import '../../features/garden_tool_repairs/presentation/garden_tool_repair_form_page.dart';
import '../../features/garden_tool_repairs/presentation/garden_tool_repair_page.dart';
import '../../features/garden_tool_repairs/presentation/garden_tool_repair_price_page.dart';
import '../../features/garden_tool_repairs/presentation/garden_tool_repair_units_page.dart';
import 'app_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/personnel',
              name: 'personnel',
              builder: (context, state) => const PersonnelPage(),
              routes: [
                GoRoute(
                  path: 'list',
                  name: 'personnel-list',
                  builder: (context, state) => PersonnelListPage(
                    initialStatus: _employeeStatusFromQuery(
                      state.uri.queryParameters['status'],
                    ),
                    initialHireMonth: _validHireMonth(
                      state.uri.queryParameters['hireMonth'],
                    ),
                  ),
                ),
                GoRoute(
                  path: 'new',
                  name: 'personnel-new',
                  builder: (context, state) => const PersonnelFormPage(),
                ),
                GoRoute(
                  path: ':employeeId',
                  name: 'personnel-detail',
                  builder: (context, state) {
                    final employeeId = int.tryParse(
                      state.pathParameters['employeeId'] ?? '',
                    );
                    if (employeeId == null) {
                      return const Scaffold(
                        body: Center(child: Text('无效的人员编号')),
                      );
                    }
                    return PersonnelDetailPage(employeeId: employeeId);
                  },
                  routes: [
                    GoRoute(
                      path: 'attachments',
                      name: 'personnel-attachments',
                      builder: (context, state) {
                        final employeeId = int.tryParse(
                          state.pathParameters['employeeId'] ?? '',
                        );
                        if (employeeId == null) {
                          return const Scaffold(
                            body: Center(child: Text('无效的人员编号')),
                          );
                        }
                        return EmployeeAttachmentsPage(employeeId: employeeId);
                      },
                    ),
                    GoRoute(
                      path: 'payroll',
                      name: 'employee-payroll',
                      builder: (context, state) {
                        final employeeId = int.tryParse(
                          state.pathParameters['employeeId'] ?? '',
                        );
                        if (employeeId == null) {
                          return const Scaffold(
                            body: Center(child: Text('无效的人员编号')),
                          );
                        }
                        return EmployeePayrollPage(employeeId: employeeId);
                      },
                    ),
                    GoRoute(
                      path: 'edit',
                      name: 'personnel-edit',
                      builder: (context, state) {
                        final employeeId = int.tryParse(
                          state.pathParameters['employeeId'] ?? '',
                        );
                        if (employeeId == null) {
                          return const Scaffold(
                            body: Center(child: Text('无效的人员编号')),
                          );
                        }
                        return PersonnelFormPage(employeeId: employeeId);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/attendance',
              name: 'attendance',
              builder: (context, state) => const AttendancePage(),
              routes: [
                GoRoute(
                  path: 'daily',
                  name: 'daily-attendance',
                  builder: (context, state) => const DailyAttendancePage(),
                ),
                GoRoute(
                  path: 'monthly-table',
                  name: 'monthly-attendance-table',
                  builder: (context, state) {
                    final value = state.uri.queryParameters['month'];
                    DateTime? initialMonth;
                    if (value != null) {
                      try {
                        initialMonth = AppDateUtils.parseYearMonth(value);
                      } on FormatException {
                        initialMonth = null;
                      }
                    }
                    return MonthlyAttendanceTablePage(
                      initialMonth: initialMonth,
                    );
                  },
                ),
                GoRoute(
                  path: 'monthly-roster',
                  name: 'monthly-roster',
                  builder: (context, state) => const MonthlyRosterPage(),
                ),
                GoRoute(
                  path: 'leave',
                  name: 'leave',
                  builder: (context, state) => const LeavePage(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      name: 'leave-new',
                      builder: (context, state) => const LeaveFormPage(),
                    ),
                    GoRoute(
                      path: ':leaveId/edit',
                      name: 'leave-edit',
                      builder: (context, state) {
                        final leaveId = int.tryParse(
                          state.pathParameters['leaveId'] ?? '',
                        );
                        if (leaveId == null) {
                          return const Scaffold(
                            body: Center(child: Text('无效的请假记录编号')),
                          );
                        }
                        return LeaveFormPage(leaveId: leaveId);
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'overtime',
                  name: 'overtime',
                  builder: (context, state) => const OvertimePage(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      name: 'overtime-new',
                      builder: (context, state) => const OvertimeFormPage(),
                    ),
                    GoRoute(
                      path: ':overtimeId/edit',
                      name: 'overtime-edit',
                      builder: (context, state) {
                        final overtimeId = int.tryParse(
                          state.pathParameters['overtimeId'] ?? '',
                        );
                        if (overtimeId == null) {
                          return const Scaffold(
                            body: Center(child: Text('无效的加班记录编号')),
                          );
                        }
                        return OvertimeFormPage(overtimeId: overtimeId);
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'termination',
                  name: 'termination',
                  builder: (context, state) => const TerminationPage(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      name: 'termination-new',
                      builder: (context, state) => const TerminationFormPage(),
                    ),
                    GoRoute(
                      path: ':terminationId/edit',
                      name: 'termination-edit',
                      builder: (context, state) {
                        final terminationId = int.tryParse(
                          state.pathParameters['terminationId'] ?? '',
                        );
                        if (terminationId == null) {
                          return const Scaffold(
                            body: Center(child: Text('无效的离职记录编号')),
                          );
                        }
                        return TerminationFormPage(
                          terminationId: terminationId,
                        );
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'groups',
                  name: 'attendance-groups',
                  builder: (context, state) => const AttendanceGroupListPage(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      name: 'attendance-group-new',
                      builder: (context, state) =>
                          const AttendanceGroupFormPage(),
                    ),
                    GoRoute(
                      path: ':groupId',
                      name: 'attendance-group-detail',
                      builder: (context, state) {
                        final groupId = int.tryParse(
                          state.pathParameters['groupId'] ?? '',
                        );
                        if (groupId == null) {
                          return const Scaffold(
                            body: Center(child: Text('无效的考勤组编号')),
                          );
                        }
                        return AttendanceGroupDetailPage(groupId: groupId);
                      },
                      routes: [
                        GoRoute(
                          path: 'edit',
                          name: 'attendance-group-edit',
                          builder: (context, state) {
                            final groupId = int.tryParse(
                              state.pathParameters['groupId'] ?? '',
                            );
                            if (groupId == null) {
                              return const Scaffold(
                                body: Center(child: Text('无效的考勤组编号')),
                              );
                            }
                            return AttendanceGroupFormPage(groupId: groupId);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              name: 'reports',
              builder: (context, state) => const ReportsPage(),
              routes: [
                GoRoute(
                  path: 'payroll',
                  name: 'payroll',
                  builder: (context, state) => const PayrollHomePage(),
                  routes: [
                    GoRoute(
                      path: 'edit/:batchId',
                      name: 'payroll-edit',
                      builder: (context, state) {
                        final batchId = int.tryParse(
                          state.pathParameters['batchId'] ?? '',
                        );
                        if (batchId == null) {
                          return const Scaffold(
                            body: Center(child: Text('无效的工资批次编号')),
                          );
                        }
                        return PayrollEditorPage(batchId: batchId);
                      },
                    ),
                    GoRoute(
                      path: 'item/:itemId',
                      name: 'payroll-item-detail',
                      builder: (context, state) {
                        final itemId = int.tryParse(
                          state.pathParameters['itemId'] ?? '',
                        );
                        if (itemId == null) {
                          return const Scaffold(
                            body: Center(child: Text('无效的工资明细编号')),
                          );
                        }
                        return PayrollDetailPage(itemId: itemId);
                      },
                    ),
                    GoRoute(
                      path: 'history',
                      name: 'payroll-history',
                      builder: (context, state) => const PayrollHistoryPage(),
                    ),
                    GoRoute(
                      path: 'settings',
                      name: 'payroll-settings',
                      builder: (context, state) => const WageJobSettingsPage(),
                    ),
                    GoRoute(
                      path: 'export/:batchId',
                      name: 'payroll-export',
                      builder: (context, state) {
                        final batchId = int.tryParse(
                          state.pathParameters['batchId'] ?? '',
                        );
                        if (batchId == null) {
                          return const Scaffold(
                            body: Center(child: Text('无效的工资批次编号')),
                          );
                        }
                        return PayrollExportPage(batchId: batchId);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsPage(),
              routes: [
                GoRoute(
                  path: 'insurance',
                  name: 'insurance',
                  builder: (context, state) => const InsurancePage(),
                  routes: [
                    GoRoute(
                      path: 'profile',
                      name: 'insurance-profile',
                      builder: (context, state) => InsuranceProfileFormPage(
                        employeeId: int.tryParse(
                          state.uri.queryParameters['employeeId'] ?? '',
                        ),
                      ),
                    ),
                    GoRoute(
                      path: 'change',
                      name: 'insurance-change',
                      builder: (context, state) =>
                          const InsuranceChangeFormPage(),
                      routes: [
                        GoRoute(
                          path: ':changeId/edit',
                          name: 'insurance-change-edit',
                          builder: (context, state) {
                            final changeId = int.tryParse(
                              state.pathParameters['changeId'] ?? '',
                            );
                            if (changeId == null) {
                              return const Scaffold(
                                body: Center(child: Text('无效的保险变更编号')),
                              );
                            }
                            return InsuranceChangeFormPage(changeId: changeId);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: 'excel',
                  name: 'excel',
                  builder: (context, state) {
                    final parts = state.uri.queryParameters['month']?.split(
                      '-',
                    );
                    final year = parts != null && parts.length == 2
                        ? int.tryParse(parts[0])
                        : null;
                    final month = parts != null && parts.length == 2
                        ? int.tryParse(parts[1])
                        : null;
                    return ExcelPage(
                      initialMonth:
                          year != null &&
                              month != null &&
                              month >= 1 &&
                              month <= 12
                          ? DateTime(year, month)
                          : null,
                    );
                  },
                ),
                GoRoute(
                  path: 'reminders',
                  name: 'reminders',
                  builder: (context, state) => const ReminderPage(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      name: 'reminder-new',
                      builder: (context, state) => ReminderFormPage(
                        initialTitle: state.uri.queryParameters['title'],
                        initialRemark: state.uri.queryParameters['remark'],
                        sourceEntityType:
                            state.uri.queryParameters['sourceType'],
                        sourceEntityId: int.tryParse(
                          state.uri.queryParameters['sourceId'] ?? '',
                        ),
                      ),
                    ),
                    GoRoute(
                      path: ':id/edit',
                      name: 'reminder-edit',
                      builder: (context, state) => ReminderFormPage(
                        reminderId: int.tryParse(
                          state.pathParameters['id'] ?? '',
                        ),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'backup',
                  name: 'backup',
                  builder: (context, state) => const BackupPage(),
                ),
                GoRoute(
                  path: 'operation-logs',
                  name: 'operation-logs',
                  builder: (context, state) => const OperationLogPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    ...inventoryRoutes(),
    GoRoute(
      path: '/purchase',
      name: 'purchase-home',
      builder: (context, state) => const PurchaseHomePage(),
      routes: [
        GoRoute(
          path: 'create',
          name: 'purchase-create',
          builder: (context, state) => PurchaseCreatePage(
            requestId: int.tryParse(state.uri.queryParameters['editId'] ?? ''),
            initialItem: state.extra is PurchaseItemPrefill
                ? state.extra! as PurchaseItemPrefill
                : null,
          ),
        ),
        GoRoute(
          path: 'pending-apply',
          name: 'purchase-pending-apply',
          builder: (context, state) => const PurchasePendingApplyPage(),
        ),
        GoRoute(
          path: 'tracking',
          name: 'purchase-tracking',
          builder: (context, state) => PurchaseTrackingPage(
            showAll: state.uri.queryParameters['all'] == '1',
            initialStatus: state.uri.queryParameters['status'] == null
                ? null
                : PurchaseStatus.parse(state.uri.queryParameters['status']!),
          ),
        ),
        GoRoute(
          path: 'pending-receive',
          name: 'purchase-pending-receive',
          builder: (context, state) => const PurchasePendingReceivePage(),
        ),
        GoRoute(
          path: 'history',
          name: 'purchase-history',
          builder: (context, state) => PurchaseHistoryPage(
            initialPreset: state.uri.queryParameters['preset'],
          ),
        ),
        GoRoute(
          path: 'detail/:requestId',
          name: 'purchase-detail',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['requestId'] ?? '');
            return id == null
                ? const Scaffold(body: Center(child: Text('无效的采购记录编号')))
                : PurchaseDetailPage(requestId: id);
          },
        ),
        GoRoute(
          path: 'stock-in/:requestId',
          name: 'purchase-stock-in',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['requestId'] ?? '');
            return id == null
                ? const Scaffold(body: Center(child: Text('无效的采购记录编号')))
                : PurchaseStockInPage(requestId: id);
          },
        ),
        GoRoute(
          path: 'item-history/:materialId',
          name: 'purchase-item-history',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['materialId'] ?? '');
            return id == null
                ? const Scaffold(body: Center(child: Text('无效的库存物资编号')))
                : PurchaseItemHistoryPage(inventoryMaterialId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/items',
      name: 'item-distribution',
      builder: (context, state) => const ItemDistributionPage(),
    ),
    GoRoute(
      path: '/garden-tool-repairs',
      name: 'garden-tool-repairs',
      builder: (context, state) {
        final query = state.uri.queryParameters;
        final year = int.tryParse(query['year'] ?? '');
        final month = int.tryParse(query['month'] ?? '');
        return GardenToolRepairPage(
          initialYear: year != null && year >= 2000 && year <= 2100
              ? year
              : null,
          initialMonth: month != null && month >= 1 && month <= 12
              ? month
              : null,
        );
      },
    ),
    GoRoute(
      path: '/garden-tool-repairs/units',
      name: 'garden-tool-repair-units',
      builder: (context, state) => const GardenToolRepairUnitsPage(),
    ),
    GoRoute(
      path: '/garden-tool-repairs/analysis',
      name: 'garden-tool-repair-analysis',
      builder: (context, state) {
        final now = DateTime.now();
        final query = state.uri.queryParameters;
        final requestedYear = int.tryParse(query['year'] ?? '') ?? now.year;
        final requestedMonth = int.tryParse(query['month'] ?? '') ?? now.month;
        return GardenToolRepairAnalysisPage(
          initialYear: requestedYear >= 2000 && requestedYear <= 2100
              ? requestedYear
              : now.year,
          initialMonth: requestedMonth >= 1 && requestedMonth <= 12
              ? requestedMonth
              : now.month,
        );
      },
    ),
    GoRoute(
      path: '/garden-tool-repairs/prices',
      name: 'garden-tool-repair-prices',
      builder: (context, state) => const GardenToolRepairPricePage(),
    ),
    GoRoute(
      path: '/garden-tool-repairs/new',
      name: 'garden-tool-repair-new',
      builder: (context, state) {
        final query = state.uri.queryParameters;
        final now = DateTime.now();
        final year = int.tryParse(query['year'] ?? '') ?? now.year;
        final month = int.tryParse(query['month'] ?? '') ?? now.month;
        final validMonth = month >= 1 && month <= 12 ? month : now.month;
        final draft = state.extra is GardenToolRepairGroupDraft
            ? state.extra! as GardenToolRepairGroupDraft
            : null;
        return GardenToolRepairFormPage(
          initialMonth: DateTime(year, validMonth),
          initialDraft: draft,
        );
      },
    ),
    GoRoute(
      path: '/garden-tool-repairs/groups/:groupId/edit',
      name: 'garden-tool-repair-edit',
      builder: (context, state) {
        final groupId = int.tryParse(state.pathParameters['groupId'] ?? '');
        if (groupId == null) {
          return const Scaffold(body: Center(child: Text('无效的维修记录编号')));
        }
        return GardenToolRepairFormPage(
          initialMonth: DateTime.now(),
          groupId: groupId,
        );
      },
    ),
    GoRoute(
      path: '/garden-tool-repairs/groups/:groupId/attachments',
      name: 'garden-tool-repair-attachments',
      builder: (context, state) {
        final groupId = int.tryParse(state.pathParameters['groupId'] ?? '');
        if (groupId == null) {
          return const Scaffold(body: Center(child: Text('无效的维修记录编号')));
        }
        return GardenToolRepairAttachmentsPage(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/vehicles/repairs',
      name: 'vehicle-repairs',
      builder: (context, state) => const VehicleRepairListPage(),
    ),
    GoRoute(
      path: '/vehicles/repairs/:repairOrderId',
      name: 'vehicle-repair-detail',
      builder: (context, state) {
        final repairOrderId = int.tryParse(
          state.pathParameters['repairOrderId'] ?? '',
        );
        if (repairOrderId == null) {
          return const Scaffold(body: Center(child: Text('无效的维修单编号')));
        }
        return VehicleRepairDetailPage(repairOrderId: repairOrderId);
      },
    ),
    GoRoute(
      path: '/vehicles/repairs/:repairOrderId/edit',
      name: 'vehicle-repair-edit',
      builder: (context, state) {
        final repairOrderId = int.tryParse(
          state.pathParameters['repairOrderId'] ?? '',
        );
        if (repairOrderId == null) {
          return const Scaffold(body: Center(child: Text('无效的维修单编号')));
        }
        return _VehicleRepairEditRoute(repairOrderId: repairOrderId);
      },
    ),
    GoRoute(
      path: '/vehicles',
      name: 'vehicles',
      builder: (context, state) => const VehiclePage(),
      routes: [
        GoRoute(
          path: 'archive',
          name: 'vehicle-archive',
          builder: (context, state) => const VehicleArchivePage(),
        ),
        GoRoute(
          path: 'reminders',
          name: 'vehicle-reminders',
          builder: (context, state) => const VehicleReminderPage(),
        ),
        GoRoute(
          path: 'fuel-summary',
          name: 'vehicle-fuel-summary',
          builder: (context, state) => const VehicleFuelSummaryPage(),
        ),
        GoRoute(
          path: 'new',
          name: 'vehicle-new',
          builder: (context, state) => const VehicleFormPage(),
        ),
        GoRoute(
          path: ':vehicleId',
          name: 'vehicle-detail',
          builder: (context, state) {
            final vehicleId = int.tryParse(
              state.pathParameters['vehicleId'] ?? '',
            );
            if (vehicleId == null) {
              return const Scaffold(body: Center(child: Text('无效的车辆编号')));
            }
            final query = state.uri.queryParameters;
            final fuelYear = int.tryParse(query['year'] ?? '');
            final fuelMonth = int.tryParse(query['month'] ?? '');
            return VehicleDetailPage(
              vehicleId: vehicleId,
              initialTab: query['tab'],
              initialFuelYear: fuelYear,
              initialFuelMonth:
                  fuelMonth != null && fuelMonth >= 1 && fuelMonth <= 12
                  ? fuelMonth
                  : null,
            );
          },
          routes: [
            GoRoute(
              path: 'edit',
              name: 'vehicle-edit',
              builder: (context, state) {
                final vehicleId = int.tryParse(
                  state.pathParameters['vehicleId'] ?? '',
                );
                if (vehicleId == null) {
                  return const Scaffold(body: Center(child: Text('无效的车辆编号')));
                }
                return VehicleFormPage(vehicleId: vehicleId);
              },
            ),
            GoRoute(
              path: 'repair/new',
              name: 'vehicle-repair-new',
              builder: (context, state) {
                final vehicleId = int.tryParse(
                  state.pathParameters['vehicleId'] ?? '',
                );
                if (vehicleId == null) {
                  return const Scaffold(body: Center(child: Text('无效的车辆编号')));
                }
                return VehicleRepairFormPage(vehicleId: vehicleId);
              },
            ),
            GoRoute(
              path: 'attachments',
              name: 'vehicle-attachments',
              builder: (context, state) {
                final vehicleId = int.tryParse(
                  state.pathParameters['vehicleId'] ?? '',
                );
                if (vehicleId == null) {
                  return const Scaffold(body: Center(child: Text('无效的车辆编号')));
                }
                return VehicleAttachmentsPage(
                  vehicleId: vehicleId,
                  repairOrderId: int.tryParse(
                    state.uri.queryParameters['repairOrderId'] ?? '',
                  ),
                );
              },
            ),
          ],
        ),
      ],
    ),
  ],
);

class _VehicleRepairEditRoute extends ConsumerStatefulWidget {
  const _VehicleRepairEditRoute({required this.repairOrderId});

  final int repairOrderId;

  @override
  ConsumerState<_VehicleRepairEditRoute> createState() =>
      _VehicleRepairEditRouteState();
}

class _VehicleRepairEditRouteState
    extends ConsumerState<_VehicleRepairEditRoute> {
  late final Future<int?> _vehicleIdFuture;

  @override
  void initState() {
    super.initState();
    _vehicleIdFuture = ref
        .read(repairRepositoryProvider)
        .findById(widget.repairOrderId)
        .then((order) => order?.vehicleId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<int?>(
    future: _vehicleIdFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final vehicleId = snapshot.data;
      if (vehicleId == null) {
        return const Scaffold(body: Center(child: Text('维修单不存在或已删除')));
      }
      return VehicleRepairFormPage(
        vehicleId: vehicleId,
        repairOrderId: widget.repairOrderId,
      );
    },
  );
}

EmployeeStatus? _employeeStatusFromQuery(String? value) {
  return switch (value) {
    'active' => EmployeeStatus.active,
    'paused' => EmployeeStatus.paused,
    'terminated' => EmployeeStatus.terminated,
    _ => null,
  };
}

String? _validHireMonth(String? value) {
  if (value == null) return null;
  try {
    AppDateUtils.parseYearMonth(value);
    return value;
  } on FormatException {
    return null;
  }
}
