import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/home/presentation/home_page.dart';
import 'package:qingsongban/features/reports/presentation/reports_page.dart';
import 'package:qingsongban/features/inventory/presentation/inventory_issue_form_page.dart';
import 'package:qingsongban/features/purchase/presentation/purchase_home_page.dart';
import 'package:qingsongban/features/purchase/presentation/widgets/purchase_widgets.dart';

Future<void> mount(
  WidgetTester tester,
  AppDatabase db,
  Widget page,
  double scale,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: page,
          bottomNavigationBar: const SizedBox(height: 80),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (size, scale) in [
    (const Size(427, 933), 1.0),
    (const Size(390, 844), 1.3),
    (const Size(320, 700), 1.3),
  ]) {
    testWidgets('home date left and separate right buttons $size/$scale', (
      tester,
    ) async {
      final db = AppDatabase.forTesting();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await mount(tester, db, const HomePage(), scale);
      final date = find.byKey(const Key('home-date'));
      final overview = find.byKey(const Key('home-overview-button'));
      final processing = find.byKey(const Key('home-processing-button'));
      final dateRect = tester.getRect(date);
      final overviewRect = tester.getRect(overview);
      final processingRect = tester.getRect(processing);
      final logoRect = tester.getRect(find.byType(Image).first);
      final taglineRect = tester.getRect(find.byKey(const Key('home-tagline')));
      expect(taglineRect.center.dy, closeTo(logoRect.center.dy, 0.1));
      expect(taglineRect.left, greaterThan(logoRect.right));
      expect(taglineRect.right, closeTo(size.width - 16, 0.1));
      expect(
        tester.getTopLeft(find.text('查看汇总')).dy,
        lessThan(tester.getTopLeft(find.text('人员与考勤：当前与今日')).dy),
      );
      expect(dateRect.left, 16);
      expect(dateRect.right, lessThan(overviewRect.left));
      expect(processingRect.right, size.width - 16);
      expect(overviewRect.center.dy, processingRect.center.dy);
      expect(overviewRect.left - dateRect.right, greaterThanOrEqualTo(8));
      expect(processingRect.left - overviewRect.right, greaterThanOrEqualTo(8));
      expect(overviewRect.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await tester.tap(processing);
      await tester.pumpAndSettle();
      expect(find.text('常用入口'), findsOneWidget);
      expect(find.text('待办提醒'), findsNothing);
      final common = find.text('常用入口');
      final business = find.text('业务模块');
      final registration = find.text('登记与查询');
      expect(
        tester.getTopLeft(find.text('待办事项')).dy,
        lessThan(tester.getTopLeft(common).dy),
      );
      final entryCard = tester.widget<Card>(
        find.ancestor(of: common, matching: find.byType(Card)),
      );
      for (final heading in [business, registration]) {
        expect(
          tester.widget<Card>(
            find.ancestor(of: heading, matching: find.byType(Card)),
          ),
          same(entryCard),
        );
      }
      for (final label in [
        '每日考勤',
        '车辆管理',
        '库存出库',
        '采购管理',
        '人员管理',
        '考勤管理',
        '车辆档案',
        '库存管理',
        '物品领取',
        '采购跟踪',
        '器械维修',
        '工资管理',
        '新增人员',
        '请假登记',
        '加班登记',
        '离职登记',
        '保险变更',
        '新建提醒',
        '年度油耗',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.ensureVisible(find.byKey(const Key('home-pending-toggle')));
      await tester.tap(find.byKey(const Key('home-pending-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('待办提醒'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-pending-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('待办提醒'), findsNothing);
      await tester.ensureVisible(overview);
      await tester.tap(overview);
      await tester.pumpAndSettle();
      expect(find.text('关键指标'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.close());
    });

    testWidgets(
      'purchase metrics centered and empty panel folds $size/$scale',
      (tester) async {
        final db = AppDatabase.forTesting();
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await mount(tester, db, const PurchaseHomePage(), scale);
        for (final label in ['待申报', '已申报', '采购中', '待领取']) {
          final tile = find.ancestor(
            of: find.text(label).first,
            matching: find.byType(PurchaseMetricTile),
          );
          final tileRect = tester.getRect(tile);
          final value = find.descendant(of: tile, matching: find.text('0'));
          expect(
            tester.getRect(value).center.dx,
            closeTo(tileRect.center.dx, 0.1),
          );
        }
        final toggle = find.byKey(const Key('purchase-action-required-toggle'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('暂无需要处理的采购记录。'), findsOneWidget);
        expect(find.byTooltip('折叠'), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('暂无需要处理的采购记录。'), findsNothing);
        expect(find.byTooltip('展开'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.runAsync(() => db.close());
      },
    );

    testWidgets('issue empty state centered $size/$scale', (tester) async {
      final db = AppDatabase.forTesting();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, db, const InventoryIssueFormPage(), scale);
      for (final label in ['先新增物资档案', '出库单需要关联已有物资。']) {
        expect(
          tester.getRect(find.text(label)).center.dx,
          closeTo(size.width / 2, 0.1),
        );
      }
      expect(
        tester.getRect(find.widgetWithText(FilledButton, '新增物资')).center.dx,
        closeTo(size.width / 2, 0.1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.close());
    });

    testWidgets('summary empty generate button fits $size/$scale', (
      tester,
    ) async {
      final db = AppDatabase.forTesting();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await mount(tester, db, const ReportsPage(), scale);
      expect(find.text('本月尚未生成汇总'), findsOneWidget);
      final generate = find.byKey(const Key('summary-generate-empty-button'));
      await tester.ensureVisible(generate);
      await tester.pumpAndSettle();
      expect(generate.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(find.text('月度汇总已生成，状态为待检查'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.close());
    });
  }
}
