import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/assistant_models.dart';

enum AssistantOverlayMode { hidden, collapsed, expanded }

/// Runtime-only presentation state shared by the floating and full-page views.
class AssistantOverlayState extends ChangeNotifier {
  AssistantOverlayMode mode = AssistantOverlayMode.collapsed;
  Offset normalizedPosition = const Offset(.94, .66);
  String draft = '';
  AssistantPageContext? nextPageContext;

  void show({AssistantPageContext? pageContext}) {
    if (pageContext != null) nextPageContext = pageContext;
    mode = AssistantOverlayMode.expanded;
    notifyListeners();
  }

  void hide() {
    mode = AssistantOverlayMode.hidden;
    notifyListeners();
  }

  void collapse() {
    mode = AssistantOverlayMode.collapsed;
    notifyListeners();
  }

  void expand() {
    mode = AssistantOverlayMode.expanded;
    notifyListeners();
  }

  void setDraft(String value) {
    if (draft == value) return;
    draft = value;
    notifyListeners();
  }

  void setNextPageContext(AssistantPageContext? value) {
    nextPageContext = value;
    notifyListeners();
  }

  void setPosition(Offset value) {
    normalizedPosition = Offset(
      value.dx.clamp(0.0, 1.0).toDouble(),
      value.dy.clamp(0.0, 1.0).toDouble(),
    );
    notifyListeners();
  }

  Offset positionIn(Size size, {double bubbleSize = 52}) => Offset(
    (size.width - bubbleSize).clamp(0.0, double.infinity) *
        normalizedPosition.dx,
    (size.height - bubbleSize).clamp(0.0, double.infinity) *
        normalizedPosition.dy,
  );

  void moveBubble(Offset position, Size size, {double bubbleSize = 52}) {
    final maxX = math.max(0.0, size.width - bubbleSize);
    final maxY = math.max(0.0, size.height - bubbleSize);
    setPosition(
      Offset(
        maxX == 0 ? 0 : position.dx / maxX,
        maxY == 0 ? 0 : position.dy / maxY,
      ),
    );
  }
}

final assistantOverlayStateProvider = ChangeNotifierProvider(
  (ref) => AssistantOverlayState(),
);

final assistantBlockingRouteVisible = ValueNotifier<bool>(false);
final Set<Route<dynamic>> _assistantBlockingRoutes = {};

/// Keeps business dialogs and selectors above the app-wide assistant overlay.
class AssistantOverlayModalObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route, true);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _track(route, false);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _track(route, false);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) _track(oldRoute, false);
    if (newRoute != null) _track(newRoute, true);
  }

  void _track(Route<dynamic> route, bool added) {
    if (route is! PopupRoute<dynamic>) return;
    if (added) {
      _assistantBlockingRoutes.add(route);
    } else {
      _assistantBlockingRoutes.remove(route);
    }
    assistantBlockingRouteVisible.value = _assistantBlockingRoutes.isNotEmpty;
  }
}

final assistantOverlayModalObserver = AssistantOverlayModalObserver();
