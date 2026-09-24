import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_enums.dart';

/// Keeps vehicle pages visually consistent with the product's five-tab shell.
/// The vehicle module is opened as a business sub-flow from 首页, so 首页 stays
/// selected while the user is inside the module.
class VehicleNavigationBar extends StatelessWidget {
  const VehicleNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    final destinations = [
      (Icons.home_outlined, Icons.home, '首页', '/home'),
      (Icons.groups_outlined, Icons.groups, '人员', '/personnel'),
      (
        Icons.calendar_month_outlined,
        Icons.calendar_month,
        '考勤',
        '/attendance',
      ),
      (Icons.bar_chart_outlined, Icons.bar_chart, '汇总', '/reports'),
      (Icons.person_outline, Icons.person, '我的', '/settings'),
    ];
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        indicatorColor: AppColors.lightBlue,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.techBlue
                : AppColors.body,
            size: 23,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.techBlue
                : AppColors.body,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) => context.go(destinations[index].$4),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.$1),
              selectedIcon: Icon(destination.$2),
              label: destination.$3,
            ),
        ],
      ),
    );
  }
}

Color vehicleStatusColor(VehicleStatus status) => switch (status) {
  VehicleStatus.normal => AppColors.primary,
  VehicleStatus.pendingRepair => Colors.orange,
  VehicleStatus.repairing => AppColors.techBlue,
  VehicleStatus.stopped || VehicleStatus.scrapped => AppColors.body,
};
