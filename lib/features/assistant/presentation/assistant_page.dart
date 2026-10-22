import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../attendance/presentation/monthly_attendance_table_page.dart';
import '../application/assistant_overlay_state.dart';
import '../application/assistant_providers.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_quick_query.dart';
import 'assistant_quick_queries.dart';
import 'assistant_chat_view.dart';
import '../application/assistant_chat.dart';
import 'assistant_result_content.dart';
import 'deepseek_pricing_badge.dart';

final assistantFreeChatModeProvider = StateProvider<bool?>((ref) => null);

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({
    super.key,
    this.pageContext,
    this.floating = false,
    this.onOpenFullScreen,
  });

  final AssistantPageContext? pageContext;
  final bool floating;
  final ValueChanged<AssistantPageContext?>? onOpenFullScreen;

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final _messageKeys = <int, GlobalKey>{};
  final _candidateKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _input.text = ref.read(assistantOverlayStateProvider).draft;
    ref
        .read(assistantControllerProvider.notifier)
        .updatePageContext(widget.pageContext);
  }

  @override
  void didUpdateWidget(covariant AssistantPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageContext != widget.pageContext) {
      ref
          .read(assistantControllerProvider.notifier)
          .updatePageContext(widget.pageContext);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final overlay = ref.read(assistantOverlayStateProvider);
    overlay.setDraft('');
    final notifier = ref.read(assistantControllerProvider.notifier);
    if (widget.floating) {
      notifier.updatePageContext(overlay.nextPageContext);
    }
    await notifier.submit(text);
    _scrollToLatestMessage();
  }

  void _scrollToLatestMessage() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (var attempt = 0; attempt < 4; attempt++) {
        if (!mounted || !_scrollController.hasClients) return;
        final position = _scrollController.position;
        final target = position.maxScrollExtent;
        if (position.pixels >= target - 1) break;
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
        WidgetsBinding.instance.scheduleFrame();
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) return;
      final messages = ref.read(assistantControllerProvider).messages;
      if (messages.isEmpty) return;
      final latestContext =
          (messages.last.candidates.isNotEmpty
              ? _candidateKeys[messages.last.id]?.currentContext
              : null) ??
          _messageKeys[messages.last.id]?.currentContext;
      if (latestContext != null && latestContext.mounted) {
        await Scrollable.ensureVisible(
          latestContext,
          alignment: 0,
          duration: const Duration(milliseconds: 180),
        );
      }
    });
  }

  Future<void> _runQuickQuery(AssistantQuickQuery query) async {
    await ref.read(assistantControllerProvider.notifier).runQuickQuery(query);
    _scrollToLatestMessage();
  }

  void _openQuickQueries() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AssistantQuickQueries(
          pageContext: widget.floating
              ? ref.read(assistantOverlayStateProvider).nextPageContext
              : widget.pageContext,
          onRun: (query) {
            Navigator.pop(sheetContext);
            _runQuickQuery(query);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantControllerProvider);
    final notifier = ref.read(assistantControllerProvider.notifier);
    final chatSettings = ref.watch(assistantChatSettingsProvider).valueOrNull;
    final freeChat =
        ref.watch(assistantFreeChatModeProvider) ??
        chatSettings?.defaultFreeChat ??
        false;
    return Scaffold(
      // The floating host has already subtracted the keyboard inset.
      resizeToAvoidBottomInset: !widget.floating,
      appBar: AppBar(
        toolbarHeight: widget.floating ? 48 : null,
        leading: widget.floating
            ? IconButton(
                tooltip: '收起助手',
                onPressed: () =>
                    ref.read(assistantOverlayStateProvider).collapse(),
                icon: const Icon(Icons.keyboard_arrow_down),
              )
            : null,
        title: const Text('智能助手', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.floating)
            IconButton(
              tooltip: '转为全屏',
              onPressed: () => widget.onOpenFullScreen?.call(
                ref.read(assistantOverlayStateProvider).nextPageContext,
              ),
              icon: const Icon(Icons.open_in_full),
            ),
          if (widget.floating)
            IconButton(
              tooltip: '隐藏助手',
              onPressed: () => ref.read(assistantOverlayStateProvider).hide(),
              icon: const Icon(Icons.close),
            ),
          if (!freeChat || chatSettings != null)
            DeepSeekPricingBadge(
              baseUrl: freeChat
                  ? chatSettings!.baseUrl
                  : 'https://api.deepseek.com',
              model: freeChat ? chatSettings!.model : 'deepseek-flash',
            ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) async {
              if (value == 'settings') {
                context.push('/assistant/settings');
                return;
              }
              if (value == 'clear') {
                if (freeChat) {
                  try {
                    await ref.read(assistantChatProvider.notifier).newSession();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('新对话保存失败，请重试。')),
                      );
                    }
                  }
                } else {
                  notifier.clearSession();
                }
                return;
              }
              final overlay = ref.read(assistantOverlayStateProvider);
              if (value == 'move-left') {
                overlay.setPosition(Offset(0, overlay.normalizedPosition.dy));
              }
              if (value == 'move-right') {
                overlay.setPosition(Offset(1, overlay.normalizedPosition.dy));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings', child: Text('AI 设置')),
              PopupMenuItem(
                value: 'clear',
                child: Text(freeChat ? '新建自由对话' : '清空当前对话'),
              ),
              if (widget.floating) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'move-left', child: Text('悬浮入口靠左')),
                const PopupMenuItem(value: 'move-right', child: Text('悬浮入口靠右')),
              ],
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.business_center_outlined),
                      label: Text('业务查询'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.chat_bubble_outline),
                      label: Text('自由对话'),
                    ),
                  ],
                  selected: {freeChat},
                  onSelectionChanged: (selection) {
                    notifier.cancelCurrentTask();
                    ref.read(assistantChatProvider.notifier).stop();
                    ref.read(assistantFreeChatModeProvider.notifier).state =
                        selection.single;
                  },
                ),
              ),
            ),
          Expanded(
            child: freeChat
                ? const AssistantChatView()
                : SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: state.messages.isEmpty
                              ? _AssistantWelcome(
                                  pageContext: widget.floating
                                      ? ref
                                            .read(assistantOverlayStateProvider)
                                            .nextPageContext
                                      : widget.pageContext,
                                  onRun: _runQuickQuery,
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    20,
                                  ),
                                  itemCount: state.messages.length,
                                  itemBuilder: (context, index) =>
                                      _AssistantMessageView(
                                        key: _messageKeys.putIfAbsent(
                                          state.messages[index].id,
                                          () => GlobalKey(),
                                        ),
                                        message: state.messages[index],
                                        candidateAnchorKey: _candidateKeys
                                            .putIfAbsent(
                                              state.messages[index].id,
                                              () => GlobalKey(),
                                            ),
                                        onSelectCandidate:
                                            (candidateRef) async {
                                              await notifier.selectCandidate(
                                                candidateRef,
                                              );
                                              _scrollToLatestMessage();
                                            },
                                        onLoadMoreRanking:
                                            notifier.loadNextVehicleRankingPage,
                                        onOpenRankedVehicle:
                                            notifier.openRankedVehicle,
                                        onSelectMonth: (yearMonth) async {
                                          await notifier
                                              .selectClarificationMonth(
                                                yearMonth,
                                              );
                                          _scrollToLatestMessage();
                                        },
                                        onRefresh: notifier.refreshResult,
                                        onExplain: notifier.explainAnswer,
                                        onFollowUp:
                                            (yearMonth, operation) async {
                                              await notifier.runFollowUp(
                                                state.messages[index].id,
                                                yearMonth: yearMonth,
                                                operation: operation,
                                              );
                                              _scrollToLatestMessage();
                                            },
                                        isBusy: state.isBusy,
                                      ),
                                ),
                        ),
                        if (state.isBusy)
                          _BusyIndicator(
                            phase: state.phase,
                            progress: state.agentProgress,
                            onStop: notifier.cancelCurrentTask,
                          ),
                        if (state.messages.isNotEmpty &&
                            MediaQuery.viewInsetsOf(context).bottom == 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: state.isBusy
                                  ? null
                                  : _openQuickQueries,
                              icon: const Icon(Icons.bolt_outlined),
                              label: const Text('快捷查询与收藏'),
                            ),
                          ),
                        _Composer(
                          controller: _input,
                          isBusy: state.isBusy,
                          onChanged: (value) => ref
                              .read(assistantOverlayStateProvider)
                              .setDraft(value),
                          onSubmit: _submit,
                          onStop: notifier.cancelCurrentTask,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AssistantWelcome extends ConsumerWidget {
  const _AssistantWelcome({required this.onRun, this.pageContext});
  final ValueChanged<AssistantQuickQuery> onRun;
  final AssistantPageContext? pageContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 36, 22, 24),
    children: [
      Text('今天想查什么？', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        '选择快捷查询，或在下方输入业务问题。业务记录由本地查询和计算。',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.body),
      ),
      const SizedBox(height: 22),
      AssistantQuickQueries(pageContext: pageContext, onRun: onRun),
      const SizedBox(height: 14),
      if (ref.watch(assistantKeyConfiguredProvider).valueOrNull != true)
        Card(
          color: AppColors.lightOrange,
          child: ListTile(
            leading: const Icon(Icons.key_outlined, color: AppColors.warning),
            title: const Text('输入自然语言问题需配置 DeepSeek'),
            subtitle: const Text(
              '快捷查询可直接使用。输入的问题文本会发送给 DeepSeek，本地业务明细不会自动附加。',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/assistant/settings'),
          ),
        ),
    ],
  );
}

class _BusyIndicator extends StatelessWidget {
  const _BusyIndicator({
    required this.phase,
    required this.progress,
    required this.onStop,
  });

  final AssistantTurnPhase phase;
  final String? progress;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            progress?.trim().isNotEmpty == true
                ? progress!.trim()
                : _phaseText(phase),
          ),
        ),
        TextButton(onPressed: onStop, child: const Text('停止')),
      ],
    ),
  );
}

String _phaseText(AssistantTurnPhase phase) => switch (phase) {
  AssistantTurnPhase.parsing => '正在理解问题…',
  AssistantTurnPhase.resolving => '正在确认人员…',
  AssistantTurnPhase.reading => '正在读取本地结果…',
  AssistantTurnPhase.explaining => '正在整理汇总说明…',
  AssistantTurnPhase.idle => '',
};

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isBusy,
    required this.onChanged,
    required this.onSubmit,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isBusy;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 4,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 +
            MediaQuery.viewInsetsOf(context).bottom.clamp(0.0, 20.0).toDouble(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('assistant-composer-input'),
              controller: controller,
              onChanged: onChanged,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => isBusy ? null : onSubmit(),
              decoration: const InputDecoration(
                hintText: '直接说你的需求…',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: isBusy ? '停止' : '发送',
            onPressed: isBusy ? onStop : onSubmit,
            icon: Icon(isBusy ? Icons.stop : Icons.send_rounded),
          ),
        ],
      ),
    ),
  );
}

class _AssistantMessageView extends StatelessWidget {
  const _AssistantMessageView({
    super.key,
    required this.message,
    required this.onSelectCandidate,
    this.candidateAnchorKey,
    required this.onLoadMoreRanking,
    required this.onOpenRankedVehicle,
    required this.onSelectMonth,
    required this.onRefresh,
    required this.onExplain,
    required this.onFollowUp,
    required this.isBusy,
  });

  final AssistantMessage message;
  final GlobalKey? candidateAnchorKey;
  final ValueChanged<String> onSelectCandidate;
  final Future<void> Function(String resultRef, String cursor)
  onLoadMoreRanking;
  final Future<void> Function(String resultRef, int vehicleId)
  onOpenRankedVehicle;
  final ValueChanged<String> onSelectMonth;
  final ValueChanged<String> onRefresh;
  final ValueChanged<String> onExplain;
  final void Function(String? yearMonth, String? operation) onFollowUp;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final answer = message.answer;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .9,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: message.isUser ? AppColors.primary : AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: message.isUser
                ? BorderSide.none
                : const BorderSide(color: AppColors.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (answer?.businessResult == null &&
                    (answer == null ||
                        answer.vehicleExpenseAnalysis != null ||
                        answer.vehicleSummary != null ||
                        answer.vehicleRanking != null))
                  Text(
                    answer?.vehicleExpenseAnalysis?.summaryText.isNotEmpty ==
                            true
                        ? answer!.vehicleExpenseAnalysis!.summaryText
                        : message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : AppColors.ink,
                    ),
                  ),
                if (answer?.vehicleExpenseAnalysis != null)
                  _VehicleExpenseAnalysisActions(
                    analysis: answer!.vehicleExpenseAnalysis!,
                    onRefresh: onRefresh,
                    resultRef: message.resultRef,
                  )
                else if (answer?.vehicleSummary != null)
                  _VehicleSummaryActions(message: message, onRefresh: onRefresh)
                else if (answer?.vehicleRanking != null)
                  _VehicleRankingActions(
                    message: message,
                    onLoadMore: onLoadMoreRanking,
                    onOpenVehicle: onOpenRankedVehicle,
                    onRefresh: onRefresh,
                  )
                else if (answer?.businessResult != null)
                  _BusinessResultActions(
                    result: answer!.businessResult!,
                    explanation: answer.explanation,
                    isBusy: isBusy,
                    messageId: message.id.toString(),
                    onRefresh: onRefresh,
                    onExplain: onExplain,
                  )
                else if (answer != null) ...[
                  _AttendanceResultSummary(answer: answer),
                  _AnswerActions(
                    message: message,
                    onRefresh: onRefresh,
                    onExplain: onExplain,
                  ),
                ],
                if (answer != null &&
                    (answer.error == null ||
                        answer.error == AssistantErrorCode.notInRoster))
                  _QuickFollowUps(
                    message: message,
                    onFollowUp: onFollowUp,
                    isBusy: isBusy,
                  ),
                if (message.candidates.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _CandidateChoices(
                    key: candidateAnchorKey,
                    candidates: message.candidates,
                    onSelected: onSelectCandidate,
                  ),
                ],
                if (message.vehicleCandidates.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _VehicleCandidateChoices(
                    candidates: message.vehicleCandidates,
                    onSelected: onSelectCandidate,
                  ),
                ],
                if (message.text == '查哪个月？') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => onSelectMonth(_currentYearMonth()),
                        child: const Text('本月'),
                      ),
                      OutlinedButton(
                        onPressed: () => onSelectMonth(_previousYearMonth()),
                        child: const Text('上月'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceResultSummary extends StatelessWidget {
  const _AttendanceResultSummary({required this.answer});
  final AssistantAnswer answer;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AssistantResultHeading(
        title: '考勤查询 · ${answer.yearMonth}',
        scope: answer.employeeLabel,
        status: answer.error == null ? '按月考勤表统计' : '需要核对考勤来源',
        warning: answer.error != null,
      ),
      const SizedBox(height: 16),
      if (answer.error != null)
        Text(answer.text, style: const TextStyle(height: 1.5))
      else
        AssistantResultMetrics(
          metrics: [
            if (answer.attendanceDays != null)
              AssistantResultMetric(
                label: '出勤',
                value: _daysValue(answer.attendanceDays!),
                unit: '天',
              ),
            if (answer.leaveAndRestDays != null)
              AssistantResultMetric(
                label: '请假与休息',
                value: _daysValue(answer.leaveAndRestDays!),
                unit: '天',
              ),
            if (answer.overtimeMinutes != null)
              AssistantResultMetric(
                label: '加班',
                value: '${answer.overtimeMinutes}',
                unit: '分钟',
              ),
          ],
        ),
    ],
  );
}

String _daysValue(double days) =>
    days == days.roundToDouble() ? days.toInt().toString() : days.toString();

class _QuickFollowUps extends StatelessWidget {
  const _QuickFollowUps({
    required this.message,
    required this.onFollowUp,
    required this.isBusy,
  });
  final AssistantMessage message;
  final void Function(String? yearMonth, String? operation) onFollowUp;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final business = message.businessQuery;
    final month = message.localQuery?.yearMonth ?? business?.yearMonth;
    final monthly =
        message.localQuery != null ||
        (business != null &&
            const {
              AssistantBusinessType.payroll,
              AssistantBusinessType.distribution,
              AssistantBusinessType.vehicleMaintenance,
            }.contains(business.domain));
    final date = month == null ? null : DateTime.tryParse('$month-01');
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (monthly && date != null) ...[
          ActionChip(
            label: const Text('查前一个月'),
            onPressed: isBusy
                ? null
                : () => onFollowUp(
                    assistantMonth(DateTime(date.year, date.month - 1)),
                    null,
                  ),
          ),
          if (month != assistantMonth(DateTime.now()))
            ActionChip(
              label: const Text('查本月'),
              onPressed: isBusy
                  ? null
                  : () => onFollowUp(assistantMonth(DateTime.now()), null),
            ),
        ],
        if (business?.domain == AssistantBusinessType.distribution) ...[
          ActionChip(
            label: const Text('只看未领取'),
            onPressed: isBusy ? null : () => onFollowUp(null, 'notReceived'),
          ),
          ActionChip(
            label: const Text('只看已领取'),
            onPressed: isBusy ? null : () => onFollowUp(null, 'received'),
          ),
          if (business?.operation != 'summary')
            ActionChip(
              label: const Text('全部领取状态'),
              onPressed: isBusy ? null : () => onFollowUp(null, 'summary'),
            ),
        ],
        if (business?.domain == AssistantBusinessType.purchase) ...[
          ActionChip(
            label: const Text('只看部分到货'),
            onPressed: isBusy ? null : () => onFollowUp(null, 'partial'),
          ),
          ActionChip(
            label: const Text('查看待到货'),
            onPressed: isBusy ? null : () => onFollowUp(null, 'pending'),
          ),
        ],
      ],
    );
  }
}

class _BusinessResultActions extends StatelessWidget {
  const _BusinessResultActions({
    required this.result,
    required this.messageId,
    required this.onRefresh,
    required this.onExplain,
    required this.isBusy,
    this.explanation,
  });
  final AssistantBusinessReadResult result;
  final String messageId;
  final ValueChanged<String> onRefresh;
  final ValueChanged<String> onExplain;
  final bool isBusy;
  final String? explanation;

  @override
  Widget build(BuildContext context) => AssistantBusinessResultContent(
    result: result,
    explanation: explanation,
    ruleLabel: _businessRuleLabel(result.sourceRule),
    onOpenSource: (path) => _openBusinessSource(context, path),
    onRefresh: isBusy ? null : () => onRefresh(messageId),
    onExplain: isBusy || result.error != null
        ? null
        : () => onExplain(messageId),
  );
}

Future<void> _openBusinessSource(BuildContext context, String path) async {
  final overlay = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(assistantOverlayStateProvider);
  final restoreFloatingAssistant =
      overlay.mode == AssistantOverlayMode.expanded;
  if (restoreFloatingAssistant) overlay.hide();
  try {
    await context.push<void>(path);
  } finally {
    if (restoreFloatingAssistant) overlay.expand();
  }
}

class _AnswerActions extends StatelessWidget {
  const _AnswerActions({
    required this.message,
    required this.onRefresh,
    required this.onExplain,
  });

  final AssistantMessage message;
  final ValueChanged<String> onRefresh;
  final ValueChanged<String> onExplain;

  @override
  Widget build(BuildContext context) {
    final answer = message.answer!;
    final id = message.id.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (answer.explanation != null) ...[
          const SizedBox(height: 8),
          Text(
            answer.explanation!,
            style: const TextStyle(color: AppColors.body),
          ),
        ],
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: const Text('口径与来源', style: TextStyle(fontSize: 14)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${answer.businessResult == null ? '按月考勤表规则统计。年份来源：${_sourceLabel(answer.yearMonthSource)}。' : '业务域：${answer.businessResult!.title}。'}'
                  '完整性：${_completenessLabel(answer.completeness)}。'
                  '${answer.groupLabels.isEmpty ? '' : '\n考勤组：${answer.groupLabels.join('、')}'}'
                  '${answer.sourceRule == null ? '' : '\n口径：${answer.businessResult == null ? answer.sourceRule : _businessRuleLabel(answer.sourceRule!)}'}'
                  '${answer.businessResult == null && answer.sourcePage != null ? '\n来源页面：${answer.sourcePage}' : ''}'
                  '\n查询时间：${_timestamp(answer.queriedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        if (answer.localDetails != null)
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('查看本地明细', style: TextStyle(fontSize: 14)),
              children: [
                for (final day in answer.localDetails!.attendanceDaysByDate)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${day.date.month}/${day.date.day}  上午${day.morningStatus} · 下午${day.afternoonStatus}',
                    ),
                  ),
                for (final overtime in answer.localDetails!.overtime)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${overtime.date.month}/${overtime.date.day}  加班 ${_duration(overtime.durationMinutes)}',
                    ),
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 4,
          children: [
            TextButton.icon(
              onPressed: () => onRefresh(id),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新本地结果'),
            ),
            TextButton.icon(
              onPressed:
                  answer.businessResult == null && answer.attendanceDays == null
                  ? null
                  : () => onExplain(id),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('解释这组结果'),
            ),
            if (answer.businessResult != null)
              TextButton.icon(
                onPressed: answer.sourcePage == null
                    ? null
                    : () => _openBusinessSource(context, answer.sourcePage!),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('打开业务来源'),
              ),
            if (answer.businessResult == null && answer.attendanceDays != null)
              TextButton.icon(
                onPressed: () async {
                  final navigator = GoRouter.of(context)
                      .routerDelegate
                      .navigatorKey
                      .currentState;
                  if (navigator == null) return;
                  final overlay = ProviderScope.containerOf(
                    context,
                    listen: false,
                  ).read(assistantOverlayStateProvider);
                  final restoreFloatingAssistant =
                      overlay.mode == AssistantOverlayMode.expanded;
                  if (restoreFloatingAssistant) overlay.hide();
                  try {
                    await navigator.push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => MonthlyAttendanceTablePage(
                          initialMonth: AppDateUtils.parseYearMonth(
                            answer.yearMonth,
                          ),
                          initialGroupId: answer.groupIds.isEmpty
                              ? null
                              : answer.groupIds.first,
                        ),
                      ),
                    );
                  } finally {
                    if (restoreFloatingAssistant) overlay.expand();
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('打开月考勤表'),
              ),
          ],
        ),
      ],
    );
  }
}

String _businessRuleLabel(String sourceRule) => switch (sourceRule) {
  'payroll_items_sum_and_attendance_snapshot_v1' => '工资明细实发金额及出勤快照，并按工资校验规则核对。',
  'inventory_current_stock_vs_min_v1' => '当前库存与物资预警下限比较。',
  'purchase_status_items_received_v1' => '采购申请状态及每项申请、已入库数量。',
  'welfare_distribution_entries_status_month_v1' => '按福利月份和领取状态汇总。',
  'garden_repair_amount_sum_by_month_v1' => '按月份累加维修登记金额。',
  'garden_repair_price_by_project_spec_unit_v1' => '同项目、规格与计价单位的登记单价比较。',
  'vehicle_repair_order_status_v1' => '维修单进度、日期和实际费用。',
  'vehicle_linked_enabled_open_reminders_due_date_v1' => '车辆关联的启用且未完成提醒。',
  'employee_profile_local_v1' => '本地有效人员档案。',
  _ => '根据本地业务记录查询。',
};

class _VehicleSummaryActions extends StatelessWidget {
  const _VehicleSummaryActions({
    required this.message,
    required this.onRefresh,
  });

  final AssistantMessage message;
  final ValueChanged<String> onRefresh;

  @override
  Widget build(BuildContext context) {
    final result = message.answer!.vehicleSummary!;
    final vehicle = result.vehicle;
    final succeeded = result.status == VehicleAnnualRepairReadStatus.success;
    final empty = result.status == VehicleAnnualRepairReadStatus.empty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        if (!succeeded && !empty)
          Text(
            result.status == VehicleAnnualRepairReadStatus.unavailable
                ? '车辆已失效，无法读取维修结果。'
                : '本地维修费用读取失败，请重试。',
          ),
        if (result.details.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: const Text('查看本地维修明细'),
            children: [
              for (final detail in result.details)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _openAssistantSource(
                      context,
                      '/vehicles/repairs/${detail.repairOrderId}',
                    ),
                    child: Text(
                      '${_date(detail.reportDate)} · 完成 ${detail.completedAt == null ? '—' : _date(detail.completedAt!)} · ${_money(detail.actualAmountCents)}',
                    ),
                  ),
                ),
            ],
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('口径与来源'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '查询时间：${_timestamp(result.queriedAt)}\n'
                '来源：车辆维修单。金额采用维修单实际金额，按报修日期 ${result.year} 年筛选。\n'
                '统计范围：未删除车辆的已完成维修单。\n'
                '车辆费用分析还会汇总油耗、保养等费用。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        Wrap(
          children: [
            TextButton.icon(
              onPressed: () => onRefresh(message.id.toString()),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新本地结果'),
            ),
            if (succeeded || empty)
              TextButton.icon(
                onPressed: () => _openAssistantSource(
                  context,
                  '/vehicles/${vehicle.vehicleId}?tab=expense&expenseYear=${result.year}',
                ),
                icon: const Icon(Icons.directions_car_outlined, size: 18),
                label: const Text('车辆费用分析'),
              ),
            TextButton.icon(
              onPressed: () => _openAssistantSource(
                context,
                '/vehicles/${vehicle.vehicleId}?tab=repair',
              ),
              icon: const Icon(Icons.build_outlined, size: 18),
              label: const Text('车辆维修记录'),
            ),
          ],
        ),
      ],
    );
  }
}

class _VehicleExpenseAnalysisActions extends StatelessWidget {
  const _VehicleExpenseAnalysisActions({
    required this.analysis,
    required this.onRefresh,
    required this.resultRef,
  });

  final VehicleExpenseAnalysisAnswer analysis;
  final ValueChanged<String> onRefresh;
  final String? resultRef;

  @override
  Widget build(BuildContext context) {
    final keyEvidence = analysis.evidence
        .where(_hasDefaultExpenseEvidence)
        .take(3)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (analysis.stopped)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                '已停止查询；以下依据只包含停止前已查到的事实。',
                style: TextStyle(color: AppColors.body),
              ),
            )
          else if (analysis.failure != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '分析未完整完成（${_assistantFailureLabel(analysis.failure!)}）；以下为已取得的依据。',
                style: const TextStyle(color: AppColors.body),
              ),
            ),
          Text(
            '${analysis.vehicleLabel}费用分析',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final period in analysis.periods)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${_vehicleExpenseGranularityLabel(period.granularity)}'
                '：${_vehicleExpensePeriodLabel(period)} · '
                '${_vehicleExpenseCoverageLabel(period.coverage)}',
              ),
            ),
          for (final note
              in analysis.periods
                  .expand((period) => period.coverageNotes)
                  .where(_isEssentialExpenseCoverageNote)
                  .take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '登记提示：$note',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.body),
              ),
            ),
          if (keyEvidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('关键依据', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final evidence in keyEvidence)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(_vehicleExpenseKeyEvidenceText(evidence)),
              ),
          ],
          for (final comparison in analysis.peerComparisons.take(2))
            _VehicleExpensePeerSummary(comparison: comparison),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: const Text('查看分析依据', style: TextStyle(fontSize: 14)),
            children: [
              for (final period in analysis.periods) ...[
                _VehicleExpensePeriodView(period: period),
                if (period != analysis.periods.last) const Divider(height: 12),
              ],
              if (analysis.evidence.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('费用变化依据', style: Theme.of(context).textTheme.titleSmall),
                for (final evidence in analysis.evidence)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_vehicleExpenseEvidenceText(evidence)),
                  ),
              ],
              for (final comparison in analysis.peerComparisons)
                _VehicleExpensePeerDetails(comparison: comparison),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '维修按已完成维修单的实际金额和报修日期统计；保养按执行日期，'
                  '手工费用按费用日期。油费按月登记，不折算成日级金额。',
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            children: [
              if (resultRef != null)
                TextButton.icon(
                  onPressed: () => onRefresh(resultRef!),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('刷新本地结果'),
                ),
              TextButton.icon(
                onPressed: () => _openAssistantSource(
                  context,
                  '/vehicles/${analysis.vehicleId}?tab=expense&expenseYear='
                  '${_vehicleExpenseApplicableYear(analysis)}',
                ),
                icon: const Icon(Icons.directions_car_outlined, size: 18),
                label: const Text('打开车辆费用页面'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

bool _isEssentialExpenseCoverageNote(String note) =>
    note.contains('油费') ||
    note.contains('没有油费登记') ||
    note.contains('没有记录不代表零支出') ||
    note.contains('不按零费用纳入') ||
    note.contains('无记录不按零费用');

String _assistantFailureLabel(AssistantErrorCode code) => switch (code) {
  AssistantErrorCode.timeout => '请求超时',
  AssistantErrorCode.cancelled => '查询已取消',
  AssistantErrorCode.providerUnavailable ||
  AssistantErrorCode.network => '服务暂不可用',
  AssistantErrorCode.invalidProviderResponse => '分析服务返回内容无效',
  _ => '读取或分析遇到问题',
};

class _VehicleExpensePeriodView extends StatelessWidget {
  const _VehicleExpensePeriodView({required this.period});

  final VehicleExpensePeriodResult period;

  @override
  Widget build(BuildContext context) {
    final range = _vehicleExpensePeriodLabel(period);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_vehicleExpenseGranularityLabel(period.granularity)}：$range · '
            '${_vehicleExpenseCoverageLabel(period.coverage)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final category in period.categories)
            Text(
              '${_vehicleExpenseCategoryLabel(category.category)}'
              '：${_money(category.amountCents)} · ${category.recordCount} 笔'
              '${category.coverage == period.coverage ? '' : ' · ${_vehicleExpenseCoverageLabel(category.coverage)}'}',
            ),
          if (period.workload != null)
            Text(_vehicleExpenseWorkloadText(period.workload!)),
          for (final fuelMonth in period.fuelMonths)
            Text(
              '${fuelMonth.year}年${fuelMonth.month}月油费：'
              '${_money(fuelMonth.amountCents)} · ${fuelMonth.liters.toStringAsFixed(1)} 升'
              '${fuelMonth.mileage == null ? '' : ' · ${fuelMonth.mileage!.toStringAsFixed(0)} 公里'}'
              ' · ${_vehicleExpenseCoverageLabel(fuelMonth.coverage)}',
            ),
          for (final note in period.coverageNotes)
            Text(note, style: const TextStyle(color: AppColors.body)),
        ],
      ),
    );
  }
}

class _VehicleExpensePeerSummary extends StatelessWidget {
  const _VehicleExpensePeerSummary({required this.comparison});

  final VehicleExpensePeerResult comparison;

  @override
  Widget build(BuildContext context) {
    final scope = _vehicleExpenseCategoryLabel(comparison.category);
    final amount = comparison.peerAmountCents == null
        ? '暂无可比金额'
        : '同类登记均值 ${_money(comparison.peerAmountCents!)}';
    final metricUnit = comparison.metricUnit;
    final targetCost = comparison.targetUnitCost;
    final peerCost = comparison.peerUnitCost;
    final unitLine = metricUnit == null || targetCost == null
        ? '暂缺可共同使用的同期工作量指标，无法比较单位费用。'
        : peerCost == null
        ? '本车 ${_unitCost(targetCost)} ${_vehicleExpenseMetricLabel(metricUnit)}；'
              '同类车辆缺少可比工作量。'
        : '本车 ${_unitCost(targetCost)} ${_vehicleExpenseMetricLabel(metricUnit)}；'
              '同类均值 ${_unitCost(peerCost)} ${_vehicleExpenseMetricLabel(metricUnit)}'
              '${_unitCostDifference(targetCost, peerCost)}';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('同类参照（$scope）', style: Theme.of(context).textTheme.titleSmall),
          Text('$amount · ${comparison.comparableVehicleCount} 辆有同期登记车辆'),
          Text(unitLine),
        ],
      ),
    );
  }
}

class _VehicleExpensePeerDetails extends StatelessWidget {
  const _VehicleExpensePeerDetails({required this.comparison});

  final VehicleExpensePeerResult comparison;

  @override
  Widget build(BuildContext context) {
    final metric = comparison.metricUnit;
    final targetCost = comparison.targetUnitCost;
    final peerCost = comparison.peerUnitCost;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_vehicleExpenseCategoryLabel(comparison.category)}同类参照'),
          Text(
            '本车登记金额：${comparison.targetAmountCents == null ? '暂无' : _money(comparison.targetAmountCents!)}；'
            '同类登记均值：${comparison.peerAmountCents == null ? '暂无' : _money(comparison.peerAmountCents!)}；'
            '纳入 ${comparison.comparableVehicleCount} 辆有同期登记车辆。',
          ),
          if (metric != null)
            Text(
              '按${_vehicleExpenseMetricLabel(metric)}比较：'
              '本车${targetCost == null ? '暂无' : _unitCost(targetCost)}，'
              '同类均值${peerCost == null ? '暂无' : _unitCost(peerCost)}。',
            ),
          if (comparison.note?.isNotEmpty == true)
            Text(
              comparison.note!,
              style: const TextStyle(color: AppColors.body),
            ),
        ],
      ),
    );
  }
}

String _vehicleExpenseEvidenceText(VehicleExpenseEvidence evidence) {
  final parts = <String>[_vehicleExpenseEvidenceLabel(evidence.label)];
  if (evidence.amountCents != null) {
    parts.add(_money(evidence.amountCents!));
  }
  if (evidence.recordCount != null) {
    parts.add('${evidence.recordCount} 笔');
  }
  if (evidence.previousAmountCents != null) {
    parts.add('前期 ${_money(evidence.previousAmountCents!)}');
  }
  if (evidence.deltaCents != null) {
    final delta = evidence.deltaCents!;
    parts.add('${delta >= 0 ? '增加' : '减少'} ${_money(delta.abs())}');
  }
  if (evidence.contributionPercent != null) {
    parts.add('贡献净增长 ${evidence.contributionPercent!.toStringAsFixed(1)}%');
  }
  if (evidence.contributionBasis != null &&
      evidence.contributionBasis!.isNotEmpty) {
    parts.add(evidence.contributionBasis!);
  }
  return parts.join(' · ');
}

String _vehicleExpenseKeyEvidenceText(VehicleExpenseEvidence evidence) {
  final parts = <String>[_vehicleExpenseEvidenceLabel(evidence.label)];
  if (evidence.amountCents != null) {
    parts.add(_money(evidence.amountCents!));
  }
  if (evidence.recordCount != null) {
    parts.add('${evidence.recordCount} 笔');
  }
  if (evidence.previousAmountCents != null) {
    parts.add('前期 ${_money(evidence.previousAmountCents!)}');
  }
  if (evidence.deltaCents != null) {
    final delta = evidence.deltaCents!;
    parts.add('${delta >= 0 ? '增加' : '减少'} ${_money(delta.abs())}');
  }
  if (evidence.contributionPercent != null) {
    parts.add('贡献净增长 ${evidence.contributionPercent!.toStringAsFixed(1)}%');
  }
  return parts.join(' · ');
}

bool _hasDefaultExpenseEvidence(VehicleExpenseEvidence evidence) =>
    (evidence.recordCount ?? 0) > 0 ||
    (evidence.amountCents ?? 0) != 0 ||
    (evidence.previousAmountCents ?? 0) != 0 ||
    (evidence.deltaCents ?? 0) != 0;

String _vehicleExpenseEvidenceLabel(String label) =>
    switch (label.trim().toLowerCase()) {
      'all' => '全部费用',
      'repair' => '维修',
      'maintenance' => '保养',
      'fuel' => '油费',
      'manual' => '其他手工费用',
      _ => label,
    };

String _vehicleExpenseMetricLabel(VehicleExpenseWorkloadMetric metric) =>
    switch (metric) {
      VehicleExpenseWorkloadMetric.mileage => '元/公里',
      VehicleExpenseWorkloadMetric.workHours => '元/工时',
      VehicleExpenseWorkloadMetric.workDays => '元/工作日',
    };

String _unitCost(double cents) => '¥${(cents / 100).toStringAsFixed(2)}';

String _unitCostDifference(double target, double peer) {
  if (peer <= 0) return '';
  final percentage = (target - peer) * 100 / peer;
  if (percentage.abs() < .05) return '（与同类接近）';
  return '（比同类${percentage > 0 ? '高' : '低'}${percentage.abs().toStringAsFixed(1)}%）';
}

int _vehicleExpenseApplicableYear(VehicleExpenseAnalysisAnswer analysis) =>
    analysis.periods.firstOrNull?.startInclusive.year ?? DateTime.now().year;

String _vehicleExpensePeriodLabel(VehicleExpensePeriodResult period) {
  if (period.granularity == VehicleExpenseGranularity.monthly &&
      period.startInclusive.day == 1 &&
      period.endExclusive.day == 1 &&
      period.startInclusive.year == period.endExclusive.year &&
      period.endExclusive.month == period.startInclusive.month + 1) {
    return '${period.startInclusive.year}年${period.startInclusive.month}月';
  }
  final lastDay = period.endExclusive.subtract(const Duration(days: 1));
  return '${_date(period.startInclusive)} 至 ${_date(lastDay)}';
}

String _vehicleExpenseCoverageLabel(VehicleExpenseCoverage coverage) =>
    switch (coverage) {
      VehicleExpenseCoverage.complete => '覆盖完整',
      VehicleExpenseCoverage.partial => '部分登记',
      VehicleExpenseCoverage.unknown => '覆盖情况未知',
    };

String _vehicleExpenseGranularityLabel(VehicleExpenseGranularity granularity) =>
    switch (granularity) {
      VehicleExpenseGranularity.daily => '按日统计',
      VehicleExpenseGranularity.monthly => '月度记录',
    };

String _vehicleExpenseCategoryLabel(VehicleExpenseCategoryScope category) =>
    switch (category) {
      VehicleExpenseCategoryScope.all => '全部费用',
      VehicleExpenseCategoryScope.repair => '维修',
      VehicleExpenseCategoryScope.maintenance => '保养',
      VehicleExpenseCategoryScope.fuel => '油费',
      VehicleExpenseCategoryScope.manual => '其他手工费用',
    };

String _vehicleExpenseWorkloadText(VehicleExpenseWorkload workload) {
  final values = <String>[];
  if (workload.mileage != null) {
    values.add('${workload.mileage!.toStringAsFixed(0)} 公里');
  }
  if (workload.workDays != null) values.add('${workload.workDays} 个工作日');
  if (workload.workHours != null) {
    values.add('${workload.workHours!.toStringAsFixed(1)} 小时');
  }
  if (values.isEmpty) return '可用工作量：里程、工作日和工时均未登记';
  return '可用工作量：${values.join(' · ')} · '
      '${_vehicleExpenseCoverageLabel(workload.coverage)}';
}

class _VehicleRankingActions extends StatelessWidget {
  const _VehicleRankingActions({
    required this.message,
    required this.onLoadMore,
    required this.onOpenVehicle,
    required this.onRefresh,
  });

  final AssistantMessage message;
  final Future<void> Function(String resultRef, String cursor) onLoadMore;
  final Future<void> Function(String resultRef, int vehicleId) onOpenVehicle;
  final ValueChanged<String> onRefresh;

  @override
  Widget build(BuildContext context) {
    final page = message.answer!.vehicleRanking!;
    final hasError = page.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${page.year} 年车辆维修费用排名',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                if (hasError)
                  const Text('本地车辆排名读取失败，请重试。')
                else if (!page.hasRepairRecords)
                  Text(
                    '没有可比较的已完成维修记录。'
                    '已检查 ${page.returnedCount}/${page.totalVehicleCount} 辆。',
                  )
                else if (page.rows.isEmpty)
                  const Text('暂无可显示的排名车辆。')
                else ...[
                  Text(
                    '共 ${page.totalVehicleCount} 辆 · 已显示 ${page.returnedCount} 辆',
                  ),
                  const SizedBox(height: 8),
                  for (final row in page.rows)
                    Material(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            onOpenVehicle(page.resultRef, row.vehicleId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 38,
                                child: Text(
                                  '${row.rank} 名',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.vehicleLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text('已完成 ${row.completedRepairCount} 次'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(_money(row.actualAmountCents)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (page.hasMore && page.nextCursor != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () =>
                            onLoadMore(page.resultRef, page.nextCursor!),
                        child: Text(
                          '加载更多（${page.returnedCount}/${page.totalVehicleCount}）',
                        ),
                      ),
                    ),
                  Wrap(
                    children: [
                      for (final row in page.rows.take(3))
                        TextButton.icon(
                          onPressed: () => _openAssistantSource(
                            context,
                            '/vehicles/${row.vehicleId}?tab=expense&expenseYear=${page.year}',
                          ),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text('查看${row.vehicleLabel}'),
                        ),
                    ],
                  ),
                ],
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('口径与来源'),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '查询时间：${_timestamp(page.queriedAt)}\n'
                        '按已完成维修单实际金额统计完整车辆集合，停用车辆也参与排名；同金额并列。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _openAssistantSource(context, '/vehicles'),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('打开车辆列表'),
                    ),
                  ],
                ),
                if (!hasError)
                  TextButton.icon(
                    onPressed: () => onRefresh(message.id.toString()),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('刷新本地结果'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleCandidateChoices extends StatelessWidget {
  const _VehicleCandidateChoices({
    required this.candidates,
    required this.onSelected,
  });

  final List<VehicleCandidate> candidates;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final candidate in candidates)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: OutlinedButton.icon(
            onPressed: () => onSelected(candidate.candidateRef),
            icon: const Icon(Icons.directions_car_outlined),
            label: Text(
              candidate.vehicleNumber.isEmpty
                  ? candidate.label
                  : '${candidate.label} · ${candidate.vehicleNumber}',
              textAlign: TextAlign.left,
            ),
          ),
        ),
    ],
  );
}

Future<void> _openAssistantSource(BuildContext context, String location) async {
  final router = GoRouter.of(context);
  final overlay = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(assistantOverlayStateProvider);
  final restoreFloatingAssistant =
      overlay.mode == AssistantOverlayMode.expanded;
  if (restoreFloatingAssistant) overlay.hide();
  try {
    await router.push<void>(location);
  } finally {
    if (restoreFloatingAssistant) overlay.expand();
  }
}

String _money(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _duration(int minutes) => '${minutes ~/ 60} 小时 ${minutes % 60} 分钟';

String _sourceLabel(AssistantFieldSource source) => switch (source) {
  AssistantFieldSource.input => '本次输入',
  AssistantFieldSource.turn => '本轮对话',
  AssistantFieldSource.page => '当前页面',
  AssistantFieldSource.currentYear => '设备当前年份',
  AssistantFieldSource.none => '未确定',
};

String _completenessLabel(AttendanceCompleteness completeness) =>
    switch (completeness) {
      AttendanceCompleteness.notEvaluated => '未评估',
      AttendanceCompleteness.partial => '部分登记',
      AttendanceCompleteness.complete => '完整',
    };

String _timestamp(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _currentYearMonth() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
}

String _previousYearMonth() {
  final now = DateTime.now();
  final previous = DateTime(now.year, now.month - 1);
  return '${previous.year.toString().padLeft(4, '0')}-${previous.month.toString().padLeft(2, '0')}';
}

class _CandidateChoices extends StatefulWidget {
  const _CandidateChoices({
    super.key,
    required this.candidates,
    required this.onSelected,
  });

  final List<EmployeeCandidate> candidates;
  final ValueChanged<String> onSelected;

  @override
  State<_CandidateChoices> createState() => _CandidateChoicesState();
}

class _CandidateChoicesState extends State<_CandidateChoices> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final candidates = query.isEmpty
        ? widget.candidates
        : widget.candidates
              .where(
                (candidate) => [
                  candidate.label,
                  candidate.employeeNumber ?? '',
                  candidate.groupLabel ?? '',
                ].join(' ').toLowerCase().contains(query),
              )
              .toList();
    return Column(
      children: [
        if (widget.candidates.length > 5)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '在本地候选中搜索',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final candidate = candidates[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => widget.onSelected(candidate.candidateRef),
                    child: Text(
                      [
                        candidate.label,
                        if (candidate.employeeNumber?.isNotEmpty == true)
                          '编号 ${candidate.employeeNumber}',
                        if (candidate.groupLabel?.isNotEmpty == true)
                          candidate.groupLabel!,
                      ].join(' · '),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (candidates.isEmpty) const Text('没有匹配的候选人员。'),
      ],
    );
  }
}
