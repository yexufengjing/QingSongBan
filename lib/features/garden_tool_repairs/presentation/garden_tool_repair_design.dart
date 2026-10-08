import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

ThemeData gardenToolRepairTheme(
  BuildContext context,
) => Theme.of(context).copyWith(
  textTheme: Theme.of(context).textTheme.copyWith(
    headlineLarge: Theme.of(context).textTheme.headlineLarge
        ?.copyWith(fontSize: 24),
    headlineMedium: Theme.of(context).textTheme.headlineMedium
        ?.copyWith(fontSize: 20),
    titleLarge: Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontSize: 18, height: 1.3),
    bodyLarge: Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontSize: 16, height: 1.4),
    bodyMedium: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontSize: 14, height: 1.4),
    bodySmall: Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontSize: 12, height: 1.4),
  ),
  appBarTheme: Theme.of(context).appBarTheme.copyWith(
    titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle
        ?.copyWith(fontSize: 20),
    toolbarHeight: 56,
  ),
  inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      visualDensity: VisualDensity.standard,
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      visualDensity: VisualDensity.standard,
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      visualDensity: VisualDensity.standard,
      padding: const EdgeInsets.symmetric(horizontal: 10),
    ),
  ),
  dataTableTheme: DataTableThemeData(
    headingRowHeight: 44,
    dataRowMinHeight: 44,
    dataRowMaxHeight: 64,
    horizontalMargin: 10,
    columnSpacing: 12,
    headingTextStyle: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: AppColors.body, fontWeight: FontWeight.w600),
    dataTextStyle: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppColors.ink),
  ),
  cardTheme: const CardThemeData(
    color: AppColors.card,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shadowColor: Color(0x17112746),
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  ),
);
