import 'package:flutter/material.dart';

enum AppTab { home, personnel, attendance, reports, settings }

extension AppTabDetails on AppTab {
  String get label => switch (this) {
    AppTab.home => '首页',
    AppTab.personnel => '人员',
    AppTab.attendance => '考勤',
    AppTab.reports => '汇总',
    AppTab.settings => '我的',
  };

  IconData get icon => switch (this) {
    AppTab.home => Icons.home_outlined,
    AppTab.personnel => Icons.groups_outlined,
    AppTab.attendance => Icons.calendar_month_outlined,
    AppTab.reports => Icons.bar_chart_outlined,
    AppTab.settings => Icons.person_outline,
  };

  IconData get selectedIcon => switch (this) {
    AppTab.home => Icons.home,
    AppTab.personnel => Icons.groups,
    AppTab.attendance => Icons.calendar_month,
    AppTab.reports => Icons.bar_chart,
    AppTab.settings => Icons.person,
  };
}
