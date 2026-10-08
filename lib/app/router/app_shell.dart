import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_navigation.dart';
import '../../features/home/presentation/home_page.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tabs = [
      AppTab.home,
      AppTab.attendance,
      AppTab.reports,
      AppTab.settings,
    ];
    const branchIndices = [0, 2, 3, 4];
    final path = GoRouterState.of(context).uri.path;
    final showNavigation = const [
      '/home',
      '/attendance',
      '/reports',
      '/settings',
    ].contains(path);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: showNavigation
          ? NavigationBar(
              selectedIndex: branchIndices
                  .indexOf(navigationShell.currentIndex)
                  .clamp(0, 3),
              onDestinationSelected: (index) {
                if (index == 0) {
                  ref.read(homeProcessingProvider.notifier).state = false;
                }
                navigationShell.goBranch(
                  branchIndices[index],
                  initialLocation:
                      branchIndices[index] == navigationShell.currentIndex,
                );
              },
              destinations: [
                for (final tab in tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                  ),
              ],
            )
          : null,
    );
  }
}
