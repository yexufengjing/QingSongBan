import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_page.dart';
import '../../features/attendance/presentation/attendance_group_detail_page.dart';
import '../../features/attendance/presentation/attendance_group_form_page.dart';
import '../../features/attendance/presentation/attendance_group_list_page.dart';
import '../../features/attendance/presentation/daily_attendance_page.dart';
import '../../features/attendance/presentation/monthly_roster_page.dart';
import '../../features/attendance/presentation/monthly_attendance_table_page.dart';
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
import '../../features/settings/presentation/settings_page.dart';
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
                  builder: (context, state) => const PersonnelListPage(),
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
                  builder: (context, state) =>
                      const MonthlyAttendanceTablePage(),
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
                  builder: (context, state) => const ExcelPage(),
                ),
                GoRoute(
                  path: 'reminders',
                  name: 'reminders',
                  builder: (context, state) => const ReminderPage(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      name: 'reminder-new',
                      builder: (context, state) => const ReminderFormPage(),
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
  ],
);
