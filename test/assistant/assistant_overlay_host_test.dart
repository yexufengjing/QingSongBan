import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/assistant/application/assistant_providers.dart';
import 'package:qingsongban/features/assistant/application/assistant_overlay_state.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/home/presentation/home_page.dart';

Future<void> _pumpApp(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const QingSongBanApp(),
    ),
  );
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 5}) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<int> _insertVehicle(
  AppDatabase database, {
  required String name,
  required String vehicleNo,
}) => database
    .into(database.vehicles)
    .insert(
      VehiclesCompanion.insert(
        name: name,
        vehicleNo: vehicleNo,
        vehicleType: const Value(VehicleType.sweeper),
      ),
    );

Future<void> _disposeApp(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.runAsync(database.close);
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(appRouter.dispose);

  testWidgets(
    'global overlay covers shell and standalone routes, yields to branch modal, and drags cumulatively',
    (tester) async {
      appRouter.go('/home');
      tester.view.physicalSize = const Size(960, 1920);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final database = AppDatabase.forTesting();
      try {
        await _pumpApp(tester, database);

        await tester.tap(find.byKey(const Key('home-assistant-entry')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('assistant-floating-page')),
          findsOneWidget,
        );

        final homeContext = tester.element(find.byType(HomePage));
        showDialog<void>(
          context: homeContext,
          useRootNavigator: false,
          builder: (context) => AlertDialog(
            title: const Text('业务弹窗'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('业务弹窗'), findsOneWidget);
        expect(find.byKey(const Key('assistant-floating-page')), findsNothing);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('assistant-floating-page')),
          findsOneWidget,
        );

        appRouter.go('/vehicles');
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, '/vehicles');
        expect(
          find.byKey(const Key('assistant-floating-page')),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('更多'));
        await tester.pumpAndSettle();
        expect(find.text('AI 设置'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('AI 设置'), findsNothing);
        expect(
          find.byKey(const Key('assistant-floating-page')),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('assistant-floating-page')), findsNothing);
        expect(
          find.byKey(const Key('assistant-floating-bubble')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('assistant-floating-bubble')));
        await tester.pumpAndSettle();

        tester.view.viewInsets = const FakeViewPadding(bottom: 250);
        await tester.tap(find.byKey(const Key('assistant-composer-input')));
        await tester.pumpAndSettle();
        const draft = '浮窗与全屏共享草稿';
        await tester.enterText(
          find.byKey(const Key('assistant-composer-input')),
          draft,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('转为全屏'));
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, '/assistant');
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('assistant-composer-input')),
              )
              .controller!
              .text,
          draft,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, '/vehicles');
        expect(
          find.byKey(const Key('assistant-floating-page')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('assistant-composer-input')),
              )
              .controller!
              .text,
          draft,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, '/vehicles');
        expect(find.byKey(const Key('assistant-floating-page')), findsNothing);
        expect(
          find.byKey(const Key('assistant-floating-bubble')),
          findsOneWidget,
        );

        final scope = ProviderScope.containerOf(
          tester.element(find.byKey(const Key('assistant-floating-bubble'))),
          listen: false,
        );
        final before = scope
            .read(assistantOverlayStateProvider)
            .normalizedPosition;
        await tester.drag(
          find.byKey(const Key('assistant-floating-bubble')),
          const Offset(-70, 90),
        );
        await tester.pumpAndSettle();
        final afterFirstDrag = scope
            .read(assistantOverlayStateProvider)
            .normalizedPosition;
        expect(afterFirstDrag, isNot(before));
        await tester.drag(
          find.byKey(const Key('assistant-floating-bubble')),
          const Offset(-35, 20),
        );
        await tester.pumpAndSettle();
        expect(
          scope.read(assistantOverlayStateProvider).normalizedPosition,
          isNot(afterFirstDrag),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeApp(tester, database);
      }
    },
  );

  testWidgets(
    'vehicle context follows selected expense year and survives assistant submit setup',
    (tester) async {
      appRouter.go('/home');
      tester.view.physicalSize = const Size(960, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final database = AppDatabase.forTesting();
      try {
        final vehicleId = await _insertVehicle(
          database,
          name: '年份回归车辆',
          vehicleNo: 'TEST-YEAR-001',
        );
        await _pumpApp(tester, database);

        appRouter.go('/vehicles/$vehicleId?tab=expense&expenseYear=2000');
        await _pumpFrames(tester, count: 8);
        final yearDropdown = tester.widget<DropdownButton<int>>(
          find.byType(DropdownButton<int>),
        );
        expect(yearDropdown.value, 2000);
        expect(yearDropdown.items!.any((item) => item.value == 2000), isTrue);

        await tester.tap(find.byType(DropdownButton<int>));
        await _pumpFrames(tester, count: 3);
        await tester.tap(find.text('2025 年').last);
        await _pumpFrames(tester, count: 3);
        await tester.tap(find.byTooltip('问助手这辆车'));
        await _pumpFrames(tester, count: 3);

        final scope = ProviderScope.containerOf(
          tester.element(find.byKey(const Key('assistant-floating-page'))),
          listen: false,
        );
        expect(
          scope.read(assistantOverlayStateProvider).nextPageContext?.vehicleId,
          vehicleId,
        );
        expect(
          scope.read(assistantOverlayStateProvider).nextPageContext?.year,
          2025,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeApp(tester, database);
      }
    },
  );

  testWidgets('backgrounding the app cancels the assistant task', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    final controller = _LifecycleProbeNotifier();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            assistantControllerProvider.overrideWith(() => controller),
          ],
          child: const QingSongBanApp(),
        ),
      );
      await _pumpFrames(tester, count: 8);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(controller.cancelCalls, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await _disposeApp(tester, database);
    }
  });

  testWidgets(
    'reused floating page submits the new vehicle context without changing an in-flight context',
    (tester) async {
      appRouter.go('/home');
      final database = AppDatabase.forTesting();
      final controller = _ContextProbeNotifier();
      try {
        final firstVehicleId = await _insertVehicle(
          database,
          name: '上下文A车',
          vehicleNo: 'TEST-CONTEXT-A',
        );
        final secondVehicleId = await _insertVehicle(
          database,
          name: '上下文B车',
          vehicleNo: 'TEST-CONTEXT-B',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              assistantControllerProvider.overrideWith(() => controller),
            ],
            child: const QingSongBanApp(),
          ),
        );
        await _pumpFrames(tester, count: 8);

        appRouter.go('/vehicles/$firstVehicleId');
        await _pumpFrames(tester, count: 8);
        await tester.tap(find.byTooltip('问助手这辆车'));
        await _pumpFrames(tester);
        await tester.enterText(
          find.byKey(const Key('assistant-composer-input')),
          '查这辆车',
        );
        await tester.tap(find.byTooltip('发送'));
        await tester.pump();
        expect(controller.submittedContexts, hasLength(1));
        expect(controller.submittedContexts.single?.vehicleId, firstVehicleId);

        appRouter.go('/vehicles/$secondVehicleId');
        await _pumpFrames(tester, count: 8);
        expect(appRouter.state.uri.path, '/vehicles/$secondVehicleId');
        final overlay = ProviderScope.containerOf(
          tester.element(find.byKey(const Key('assistant-floating-page'))),
          listen: false,
        ).read(assistantOverlayStateProvider);
        overlay.show(
          pageContext: AssistantPageContext(
            module: 'vehicles',
            page: 'vehicle-detail',
            vehicleId: secondVehicleId,
            year: 2025,
          ),
        );
        await _pumpFrames(tester);
        await tester.enterText(
          find.byKey(const Key('assistant-composer-input')),
          '查新页面这辆车',
        );
        await tester.tap(find.byTooltip('发送'));
        await tester.pump();

        expect(controller.submittedContexts, hasLength(2));
        expect(controller.submittedContexts[0]?.vehicleId, firstVehicleId);
        expect(controller.submittedContexts[1]?.vehicleId, secondVehicleId);

        await tester.tap(find.byTooltip('转为全屏'));
        await _pumpFrames(tester, count: 8);
        expect(appRouter.state.uri.path, '/assistant');
        expect(controller.latestPageContext?.vehicleId, secondVehicleId);
        await tester.binding.handlePopRoute();
        await _pumpFrames(tester, count: 8);

        overlay.setNextPageContext(null);
        await _pumpFrames(tester);
        await tester.tap(find.byTooltip('转为全屏'));
        await _pumpFrames(tester, count: 8);
        expect(appRouter.state.uri.path, '/assistant');
        expect(controller.latestPageContext, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        controller.releaseFirstSubmit();
        await _disposeApp(tester, database);
      }
    },
  );
}

class _LifecycleProbeNotifier extends AssistantSessionNotifier {
  var cancelCalls = 0;

  @override
  AssistantState build() => const AssistantState();

  @override
  void cancelCurrentTask() => cancelCalls++;

  @override
  void updatePageContext(AssistantPageContext? context) {}
}

class _ContextProbeNotifier extends AssistantSessionNotifier {
  final _firstSubmitGate = Completer<void>();
  final submittedContexts = <AssistantPageContext?>[];
  AssistantPageContext? _pageContext;
  AssistantPageContext? get latestPageContext => _pageContext;

  @override
  AssistantState build() => const AssistantState();

  @override
  void updatePageContext(AssistantPageContext? context) {
    _pageContext = context;
  }

  @override
  Future<void> submit(String utterance) async {
    submittedContexts.add(_pageContext);
    if (submittedContexts.length == 1) await _firstSubmitGate.future;
  }

  void releaseFirstSubmit() {
    if (!_firstSubmitGate.isCompleted) _firstSubmitGate.complete();
  }
}
