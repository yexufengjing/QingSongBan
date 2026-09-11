import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_page.dart';
import '../../features/attendance/presentation/attendance_group_detail_page.dart';
import '../../features/attendance/presentation/attendance_group_form_page.dart';
import '../../features/attendance/presentation/attendance_group_list_page.dart';
import '../../features/home/presentation/home_page.dart';
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
            ),
          ],
        ),
      ],
    ),
  ],
);
