import '../application/assistant_chat.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/assistant_overlay_state.dart';
import '../application/assistant_providers.dart';
import 'assistant_page.dart';

String _activeRouterPath(GoRouter router) {
  if (router.routerDelegate.currentConfiguration.isEmpty) {
    return router.routeInformationProvider.value.uri.path;
  }
  return router.state.uri.path;
}

class AssistantOverlayHost extends ConsumerStatefulWidget {
  const AssistantOverlayHost({
    required this.child,
    required this.router,
    super.key,
  });

  final Widget child;
  final GoRouter router;

  @override
  ConsumerState<AssistantOverlayHost> createState() =>
      _AssistantOverlayHostState();
}

class _AssistantOverlayHostState extends ConsumerState<AssistantOverlayHost>
    with WidgetsBindingObserver {
  final _floatingNavigatorKey = GlobalKey<NavigatorState>();
  Offset? _dragPosition;
  late String _activePath;
  late bool _modalVisible;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _activePath = _activeRouterPath(widget.router);
    _modalVisible = assistantBlockingRouteVisible.value;
    widget.router.routerDelegate.addListener(_scheduleHostRefresh);
    assistantBlockingRouteVisible.addListener(_scheduleHostRefresh);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant AssistantOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_scheduleHostRefresh);
      widget.router.routerDelegate.addListener(_scheduleHostRefresh);
      _scheduleHostRefresh();
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_scheduleHostRefresh);
    assistantBlockingRouteVisible.removeListener(_scheduleHostRefresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleHostRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!mounted) return;
      final path = _activeRouterPath(widget.router);
      final modalVisible = assistantBlockingRouteVisible.value;
      final previousPath = _activePath;
      if (path == previousPath && modalVisible == _modalVisible) return;
      if (path != previousPath) _clearStalePageContext(path);
      setState(() {
        _activePath = path;
        _modalVisible = modalVisible;
      });
    });
  }

  void _clearStalePageContext(String path) {
    if (path == '/assistant' || path.startsWith('/assistant/')) return;
    final pageContext = ref.read(assistantOverlayStateProvider).nextPageContext;
    if (pageContext?.module != 'vehicles' ||
        pageContext?.page != 'vehicle-detail' ||
        path == '/vehicles/${pageContext!.vehicleId}') {
      return;
    }
    ref.read(assistantOverlayStateProvider).setNextPageContext(null);
    ref.read(assistantControllerProvider.notifier).updatePageContext(null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ref.read(assistantControllerProvider.notifier).cancelCurrentTask();
      ref.read(assistantChatProvider.notifier).stop();
    }
  }

  @override
  Future<bool> didPopRoute() async {
    if (assistantBlockingRouteVisible.value) return false;
    final path = _activeRouterPath(widget.router);
    if (path == '/assistant' || path.startsWith('/assistant/')) return false;
    final overlay = ref.read(assistantOverlayStateProvider);
    if (overlay.mode == AssistantOverlayMode.expanded) {
      if (await _floatingNavigatorKey.currentState?.maybePop() == true) {
        return true;
      }
      overlay.collapse();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final path = _activePath;
    final assistantPageVisible =
        path == '/assistant' || path.startsWith('/assistant/');
    final inShell = const [
      '/home',
      '/personnel',
      '/attendance',
      '/reports',
      '/settings',
    ].any((base) => path == base || path.startsWith('$base/'));
    final overlay = ref.watch(assistantOverlayStateProvider);
    final showOverlay =
        !_modalVisible &&
        !assistantPageVisible &&
        overlay.mode != AssistantOverlayMode.hidden;
    final media = MediaQuery.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (showOverlay)
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, safeConstraints) {
                  final reservedBottom = inShell ? 76.0 : 0.0;
                  final size = Size(
                    safeConstraints.maxWidth,
                    (safeConstraints.maxHeight - reservedBottom).clamp(
                      0.0,
                      double.infinity,
                    ),
                  );
                  return _buildOverlay(context, overlay, size, media);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    AssistantOverlayState overlay,
    Size size,
    MediaQueryData media,
  ) {
    if (overlay.mode == AssistantOverlayMode.collapsed) {
      const bubbleSize = 52.0;
      final position = overlay.positionIn(size, bubbleSize: bubbleSize);
      return Stack(
        children: [
          Positioned(
            left: position.dx,
            top: position.dy,
            child: GestureDetector(
              key: const Key('assistant-floating-bubble'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => _dragPosition = position,
              onPanUpdate: (details) {
                final next = (_dragPosition ?? position) + details.delta;
                _dragPosition = next;
                overlay.moveBubble(next, size, bubbleSize: bubbleSize);
              },
              onTap: overlay.expand,
              child: Semantics(
                button: true,
                label: '打开智能助手',
                onTap: overlay.expand,
                child: Material(
                  color: AppColors.primary,
                  elevation: 5,
                  shape: const CircleBorder(),
                  child: const SizedBox(
                    width: bubbleSize,
                    height: bubbleSize,
                    child: Icon(
                      Icons.forum_outlined,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final keyboardInset = media.viewInsets.bottom;
    final usableHeight = size.height - keyboardInset;
    final fullHeight = usableHeight < 420;
    final panelWidth = fullHeight
        ? size.width
        : math.min(size.width - 24, 520.0).clamp(0.0, size.width);
    final panelHeight = fullHeight
        ? usableHeight
        : (usableHeight * .78).clamp(320.0, 620.0);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          ),
        ),
        Positioned(
          right: fullHeight ? 0 : 12,
          bottom: keyboardInset + (fullHeight ? 0 : 12),
          width: panelWidth,
          height: panelHeight,
          child: Material(
            color: AppColors.card,
            elevation: 12,
            clipBehavior: Clip.antiAlias,
            borderRadius: fullHeight
                ? BorderRadius.zero
                : BorderRadius.circular(18),
            child: Navigator(
              key: _floatingNavigatorKey,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => InheritedGoRouter(
                  goRouter: widget.router,
                  child: AssistantPage(
                    key: const Key('assistant-floating-page'),
                    floating: true,
                    pageContext: overlay.nextPageContext,
                    onOpenFullScreen: (pageContext) =>
                        widget.router.push('/assistant', extra: pageContext),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
