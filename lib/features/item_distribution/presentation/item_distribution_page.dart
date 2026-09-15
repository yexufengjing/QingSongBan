import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../application/item_distribution_providers.dart';
import '../data/item_distribution_repository.dart';
import '../domain/item_distribution_models.dart';

class ItemDistributionPage extends ConsumerStatefulWidget {
  const ItemDistributionPage({super.key});

  @override
  ConsumerState<ItemDistributionPage> createState() =>
      _ItemDistributionPageState();
}

class _ItemDistributionPageState extends ConsumerState<ItemDistributionPage> {
  late DateTime _month;
  String _tab = DistributionCategory.welfare.name;
  bool _standardsExpanded = false;
  final Set<String> _expandedRoles = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month - 1, 1);
  }

  String get _monthKey =>
      '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  DistributionCategory get _category => DistributionCategory.values.firstWhere(
    (item) => item.name == _tab,
    orElse: () => DistributionCategory.welfare,
  );

  String get _actualMonth {
    final next = DateTime(_month.year, _month.month + 1, 1);
    return '${next.year}年${next.month.toString().padLeft(2, '0')}月';
  }

  void _refresh() {
    ref.invalidate(categoryDistributionGroupsProvider('$_monthKey|$_tab'));
    ref.invalidate(distributionGroupsProvider(_monthKey));
    ref.invalidate(distributionSummaryProvider(_monthKey));
    ref.invalidate(temporaryWelfareCandidatesProvider(_monthKey));
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(
      categoryDistributionGroupsProvider('$_monthKey|$_tab'),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('物品领取'),
        actions: [
          IconButton(
            tooltip: '更多操作',
            onPressed: _showMoreMenu,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          _topTabs(),
          Expanded(
            child: _category == DistributionCategory.welfare
                ? _welfareBody(groupsAsync)
                : _manualBody(groupsAsync),
          ),
        ],
      ),
      floatingActionButton: _category == DistributionCategory.welfare
          ? null
          : FloatingActionButton.extended(
              onPressed: _showManualDistribution,
              icon: const Icon(Icons.add),
              label: Text(
                _category == DistributionCategory.tool ? '新增工具领用' : '新增办公用品',
              ),
            ),
    );
  }

  Widget _topTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'welfare',
              label: Text('福利劳保'),
              icon: Icon(Icons.card_giftcard_outlined),
            ),
            ButtonSegment(
              value: 'office',
              label: Text('办公用品'),
              icon: Icon(Icons.inventory_2_outlined),
            ),
            ButtonSegment(
              value: 'tool',
              label: Text('工具'),
              icon: Icon(Icons.build_outlined),
            ),
          ],
          selected: {_tab},
          onSelectionChanged: (value) => setState(() {
            _tab = value.first;
            _expandedRoles.clear();
          }),
        ),
      ),
    );
  }

  Widget _welfareBody(
    AsyncValue<List<DistributionRecipientGroup>> groupsAsync,
  ) {
    final summaryAsync = ref.watch(distributionSummaryProvider(_monthKey));
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
        children: [
          _monthHeader(showWelfareIssueInfo: true),
          const SizedBox(height: 10),
          _standardsPanel(),
          const SizedBox(height: 16),
          groupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _errorState('福利清单加载失败：$error'),
            data: (groups) {
              if (groups.isEmpty) return _welfareEmptyState();
              final formal = groups
                  .where(
                    (group) =>
                        group.recipientType == 'employee' &&
                        group.employmentType == '正式工',
                  )
                  .toList();
              final temporary = groups
                  .where(
                    (group) =>
                        group.recipientType == 'employee' &&
                        group.employmentType == '临时工',
                  )
                  .toList();
              final sweepers = groups
                  .where((group) => group.recipientType == 'sweeper')
                  .toList();
              final publicGroups = groups
                  .where((group) => group.recipientType == 'public')
                  .toList();
              return Column(
                children: [
                  _employeeSection('正式职工福利发放表', formal, '正式工'),
                  const SizedBox(height: 18),
                  _employeeSection(
                    '临时工福利发放表',
                    temporary,
                    '临时工',
                    showModify: true,
                  ),
                  const SizedBox(height: 18),
                  _sweeperSection(sweepers),
                  const SizedBox(height: 18),
                  _publicSection(publicGroups),
                  const SizedBox(height: 18),
                  summaryAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: _monthlySummary,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _monthHeader({required bool showWelfareIssueInfo}) {
    final monthLabel = showWelfareIssueInfo ? '福利归属月份' : '记录月份';
    final monthTitle = showWelfareIssueInfo
        ? '福利'
        : (_category == DistributionCategory.tool ? '工具' : '办公用品');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: showWelfareIssueInfo ? '上一个福利月' : '上一记录月',
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickMonth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          monthLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_month.year}年${_month.month.toString().padLeft(2, '0')}月$monthTitle',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: showWelfareIssueInfo ? '下一个福利月' : '下一记录月',
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1, 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                showWelfareIssueInfo
                    ? '福利归属：${_month.year}年${_month.month.toString().padLeft(2, '0')}月 · 实际发放：$_actualMonth'
                    : '记录月份：${_month.year}年${_month.month.toString().padLeft(2, '0')}月',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _standardsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _standardsExpanded = !_standardsExpanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rule_outlined, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '本月发放标准',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    _standardsExpanded ? '收起' : '展开',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    _standardsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
              if (!_standardsExpanded) ...[
                const SizedBox(height: 6),
                const Text(
                  '正式工 洗1 / 手1 / 毛1；临时工 洗1 / 手1 / 毛1；扫路车 洗1 / 车；公用 洗1',
                ),
              ] else ...[
                const SizedBox(height: 12),
                _ruleLine('正式工', '洗衣膏 1袋/人 · 线手套 1副/人 · 1月、7月毛巾 1条/人'),
                _ruleLine('临时工', '洗衣膏 1袋/人 · 单数月线手套 1副/人 · 1月、7月毛巾 1条/人'),
                _ruleLine('扫路车', '洗衣膏 1袋/车 · 不发手套、毛巾'),
                _ruleLine('公用', '洗衣膏 1袋 · 不发手套、毛巾'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleLine(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(detail)),
        ],
      ),
    );
  }

  Widget _employeeSection(
    String title,
    List<DistributionRecipientGroup> groups,
    String employmentType, {
    bool showModify = false,
  }) {
    final byRole = <String, List<DistributionRecipientGroup>>{};
    for (final group in groups) {
      byRole.putIfAbsent(group.welfarePosition ?? '其他', () => []).add(group);
    }
    final roles = byRole.keys.toList()..sort();
    return _sectionFrame(
      title: title,
      trailing: showModify
          ? TextButton.icon(
              onPressed: _showTemporaryRoster,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('修改名单'),
            )
          : null,
      child: groups.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('尚未生成名单，请先从上方生成福利清单。'),
            )
          : Column(
              children: [
                _tableHeader(),
                for (final role in roles)
                  _roleRow(role, byRole[role]!, employmentType),
                _totalRow(groups, '合计'),
              ],
            ),
    );
  }

  Widget _sectionFrame({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: const Row(
        children: [
          Expanded(flex: 4, child: Text('福利岗位')),
          Expanded(child: Center(child: Text('人数'))),
          Expanded(child: Center(child: Text('洗'))),
          Expanded(child: Center(child: Text('毛'))),
          Expanded(child: Center(child: Text('手'))),
        ],
      ),
    );
  }

  Widget _roleRow(
    String role,
    List<DistributionRecipientGroup> groups,
    String employmentType,
  ) {
    final expanded = _expandedRoles.contains('$employmentType:$role');
    final rowKey = '$employmentType:$role';
    return Column(
      children: [
        InkWell(
          onTap: () => setState(
            () => expanded
                ? _expandedRoles.remove(rowKey)
                : _expandedRoles.add(rowKey),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    role,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${groups.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                _quantityCell(groups, '洗衣膏', 'washing_paste', '袋'),
                _quantityCell(groups, '毛巾', 'towel', '条'),
                _quantityCell(groups, '线手套', 'gloves', '副'),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppColors.helper,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            width: double.infinity,
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final group in groups) _nameChip(group)],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _quantityCell(
    List<DistributionRecipientGroup> groups,
    String label,
    String code,
    String unit,
  ) {
    final entries = groups
        .expand((group) => group.entries)
        .where((entry) => entry.itemCode == code)
        .toList();
    final quantity = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.quantity,
    );
    return Expanded(
      child: InkWell(
        onTap: () => _showQuantityDetails(groups, label, unit, quantity),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: Text(
              _formatQuantity(quantity),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalRow(List<DistributionRecipientGroup> groups, String title) {
    double total(String code) => groups
        .expand((group) => group.entries)
        .where((entry) => entry.itemCode == code)
        .fold(0, (sum, entry) => sum + entry.quantity);
    return Container(
      color: AppColors.lightGreen,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${groups.length}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _formatQuantity(total('washing_paste')),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _formatQuantity(total('towel')),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _formatQuantity(total('gloves')),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameChip(DistributionRecipientGroup group) {
    final received = group.allReceived;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: ActionChip(
        onPressed: () => _showSourceSheet(group),
        backgroundColor: received ? AppColors.lightGreen : AppColors.card,
        side: BorderSide(
          color: received
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.divider,
        ),
        avatar: received
            ? const Icon(Icons.check, size: 17, color: AppColors.primary)
            : null,
        label: Text(
          received ? '${group.recipientName}✓' : group.recipientName,
          style: TextStyle(
            color: received ? AppColors.primary : AppColors.ink,
            fontWeight: received ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _sweeperSection(List<DistributionRecipientGroup> assignments) {
    return FutureBuilder<int>(
      future: ref.read(itemDistributionRepositoryProvider).getSweeperCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 6;
        return _sectionFrame(
          title: '扫路车福利',
          trailing: TextButton.icon(
            onPressed: _showSweeperAssignment,
            icon: const Icon(Icons.group_add_outlined, size: 18),
            label: const Text('分配'),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$count辆 · ${assignments.length}份 · 洗衣膏${count}袋',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      assignments.length > count
                          ? '超出${assignments.length - count}份'
                          : '已分配${assignments.length}人',
                      style: TextStyle(
                        color: assignments.length > count
                            ? AppColors.danger
                            : AppColors.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (assignments.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('点击“分配”选择实际领取的正式员工司机。'),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final group in assignments) _nameChip(group),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _publicSection(List<DistributionRecipientGroup> groups) {
    final group = groups.firstOrNull;
    return _sectionFrame(
      title: '公用福利',
      trailing: TextButton.icon(
        onPressed: _showPublicRecipient,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('修改'),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: group == null
            ? const Align(
                alignment: Alignment.centerLeft,
                child: Text('尚未指定公用福利领取人。'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatQuantity(group.entries.fold<double>(0, (sum, entry) => sum + entry.quantity))}份 · 洗衣膏${_formatQuantity(group.entries.fold<double>(0, (sum, entry) => sum + entry.quantity))}袋',
                  ),
                  const SizedBox(height: 8),
                  _nameChip(group),
                ],
              ),
      ),
    );
  }

  Widget _monthlySummary(DistributionSummary summary) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '本月领取情况',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => _showUnreceived(summary),
                child: const Text('查看未领'),
              ),
            ],
          ),
          Text(
            '人员：已领取${summary.receivedCount} / 未领取${summary.notReceivedCount}',
          ),
          const SizedBox(height: 4),
          Text(
            '福利来源记录：已完成${summary.entryReceivedCount} / 未完成${summary.entryNotReceivedCount}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _manualBody(AsyncValue<List<DistributionRecipientGroup>> groupsAsync) {
    final title = _category == DistributionCategory.tool
        ? '工具领用记录'
        : '办公用品领用记录';
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
        children: [
          _monthHeader(showWelfareIssueInfo: false),
          const SizedBox(height: 16),
          _sectionFrame(
            title: title,
            child: groupsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _errorState('记录加载失败：$error'),
              data: (groups) => groups.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('本月还没有$title，请点击右下角新增。'),
                    )
                  : Column(
                      children: [for (final group in groups) _manualRow(group)],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _manualRow(DistributionRecipientGroup group) {
    return Column(
      children: [
        for (final entry in group.entries) _manualEntryRow(group, entry),
      ],
    );
  }

  Widget _manualEntryRow(
    DistributionRecipientGroup group,
    DistributionEntry entry,
  ) {
    final received = entry.status == DistributionStatus.received;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            onTap: () => _showSourceSheet(group),
            leading: Icon(
              _category == DistributionCategory.tool
                  ? Icons.build_outlined
                  : Icons.inventory_2_outlined,
              color: AppColors.techBlue,
            ),
            title: Text(
              group.recipientName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.itemName} ${_formatQuantity(entry.quantity)}${entry.unit}',
                ),
                Text(
                  '登记时间：${_formatDateTime(entry.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (entry.note != null && entry.note!.isNotEmpty)
                  Text(
                    '备注：${entry.note}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  received ? '已领取✓' : '未领取',
                  style: TextStyle(
                    color: received ? AppColors.primary : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: '删除记录',
                  onPressed: () => _confirmDeleteManualEntry(entry),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _errorState(String text) =>
      Padding(padding: const EdgeInsets.all(24), child: Text(text));

  Widget _welfareEmptyState() {
    return _sectionFrame(
      title: '福利发放表',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 42,
              color: AppColors.helper,
            ),
            const SizedBox(height: 8),
            const Text('本月还没有福利发放表'),
            const SizedBox(height: 4),
            const Text(
              '先确认临时工名单，再生成正式工、临时工和公用福利。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _showTemporaryRoster,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('生成福利发放表'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatQuantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  Future<void> _showMoreMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_category == DistributionCategory.welfare) ...[
              _menuTile('发放设置', Icons.tune_outlined, 'settings'),
              _menuTile('修改临时工名单', Icons.people_outline, 'temporary'),
              _menuTile('扫路车福利分配', Icons.local_shipping_outlined, 'sweeper'),
              _menuTile('公用福利领取人', Icons.person_search_outlined, 'public'),
              _menuTile(
                '查看未领取人员',
                Icons.assignment_late_outlined,
                'unreceived',
              ),
            ] else
              _menuTile('新增记录', Icons.add, 'manual'),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'settings':
        await _showSettings();
      case 'temporary':
        await _showTemporaryRoster();
      case 'sweeper':
        await _showSweeperAssignment();
      case 'public':
        await _showPublicRecipient();
      case 'unreceived':
        await _showUnreceived(null);
      case 'manual':
        await _showManualDistribution();
    }
  }

  Widget _menuTile(String label, IconData icon, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.ink),
      title: Text(label),
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _showSourceSheet(DistributionRecipientGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.recipientName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _sourceSubtitle(group),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Text(
                _category == DistributionCategory.welfare ? '本月福利来源' : '领用明细',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...group.entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${entry.itemName} ${_formatQuantity(entry.quantity)}${entry.unit}',
                  ),
                  subtitle: Text(
                    [
                      entry.status == DistributionStatus.received
                          ? '已领取 ✓${entry.signedAt == null ? '' : ' · 签收：${_formatDateTime(entry.signedAt)}'}'
                          : '未领取',
                      '登记：${_formatDateTime(entry.createdAt)}',
                    ].join('\n'),
                  ),
                  trailing: _category == DistributionCategory.welfare
                      ? null
                      : IconButton(
                          tooltip: '删除记录',
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _confirmDeleteManualEntry(entry);
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                ),
              ),
              const Divider(),
              if (group.allReceived)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _confirmResetStatus(group);
                        },
                        icon: const Icon(Icons.undo),
                        label: const Text('改为未领取'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showReplenishment(group);
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('补领'),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _setSourceStatus(group, DistributionStatus.received);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('标记为已领取'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceSubtitle(DistributionRecipientGroup group) {
    if (group.recipientType == 'sweeper')
      return '扫路车福利 · ${group.welfarePosition ?? '司机'}';
    if (group.recipientType == 'public')
      return '公用福利 · ${group.welfarePosition ?? '实际领取人'}';
    return '${group.employmentType ?? '人员'} · ${group.welfarePosition ?? '其他'}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '未知';
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDeleteManualEntry(DistributionEntry entry) async {
    final label = _category == DistributionCategory.tool ? '工具' : '办公用品';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除$label领用记录？'),
        content: Text(
          '${entry.recipientName} · ${entry.itemName} ${_formatQuantity(entry.quantity)}${entry.unit}\n'
          '登记时间：${_formatDateTime(entry.createdAt)}\n\n'
          '删除后记录将从当前列表隐藏，但操作日志会保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await ref
          .read(itemDistributionRepositoryProvider)
          .deleteManualEntry(entry.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败：$error')));
      return;
    }
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('领用记录已删除')));
  }

  Future<void> _setSourceStatus(
    DistributionRecipientGroup group,
    DistributionStatus status,
  ) async {
    await ref
        .read(itemDistributionRepositoryProvider)
        .setSourceStatus(
          _monthKey,
          group.recipientKey,
          status,
          category: _category,
        );
    _refresh();
  }

  Future<void> _confirmResetStatus(DistributionRecipientGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认修改领取状态？'),
        content: Text(
          '${group.recipientName} 当前为“已领取”。\n修改后将恢复为“未领取”。\n原领取时间会保留在操作日志中。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认改为未领取'),
          ),
        ],
      ),
    );
    if (confirmed == true)
      await _setSourceStatus(group, DistributionStatus.notReceived);
  }

  Future<void> _showQuantityDetails(
    List<DistributionRecipientGroup> groups,
    String itemName,
    String unit,
    double quantity,
  ) async {
    final standard = groups.length.toDouble();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$itemName数量详情',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Text('标准人数：${groups.length}人'),
              const SizedBox(height: 6),
              Text('标准数量：${_formatQuantity(standard)}$unit'),
              const SizedBox(height: 6),
              Text(
                '实际数量：${_formatQuantity(quantity)}$unit',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                '实际数量默认按标准人数生成；特殊调整可在后续数量调整入口中记录原因。',
                style: TextStyle(color: AppColors.body),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTemporaryRoster() async {
    final repo = ref.read(itemDistributionRepositoryProvider);
    final candidates = await ref.read(
      temporaryWelfareCandidatesProvider(_monthKey).future,
    );
    final currentGroups = await ref.read(
      distributionGroupsProvider(_monthKey).future,
    );
    final existing = currentGroups
        .where(
          (group) => group.employmentType == '临时工' && group.employeeId != null,
        )
        .map((group) => group.employeeId!)
        .toSet();
    final selected = <int>{
      ...(existing.isEmpty
          ? candidates
                .where((item) => item.isCurrentlyActive)
                .map((item) => item.id)
          : existing),
    };
    final search = TextEditingController();
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final visible = candidates
              .where(
                (item) =>
                    search.text.trim().isEmpty ||
                    item.name.contains(search.text.trim()) ||
                    item.employeeNo.contains(search.text.trim()),
              )
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.84,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '修改$_monthKey临时工福利名单',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text('推荐来源：对应福利月份的月度考勤名单'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: search,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: '搜索姓名或工号',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '已选择：${selected.length}人',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setSheetState(
                            () => selected.addAll(
                              candidates.map((item) => item.id),
                            ),
                          ),
                          child: const Text('全选'),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(selected.clear),
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final candidate = visible[index];
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selected.contains(candidate.id),
                            onChanged: (value) => setSheetState(
                              () => value == true
                                  ? selected.add(candidate.id)
                                  : selected.remove(candidate.id),
                            ),
                            title: Text(candidate.name),
                            subtitle: Text(
                              '${candidate.employeeNo}${candidate.isCurrentlyActive ? ' · 当前在岗' : ' · 当前已离职'}',
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          Set<int>.from(selected),
                        ),
                        child: Text('保存名单 ${selected.length}人'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    search.dispose();
    if (result == null) return;
    await repo.ensureWelfareBatch(
      month: _monthKey,
      temporaryEmployeeIds: result,
    );
    _refresh();
  }

  Future<void> _showSweeperAssignment() async {
    final repo = ref.read(itemDistributionRepositoryProvider);
    final count = await repo.getSweeperCount();
    final candidates = await repo.listFormalCandidates();
    final existing = await repo.listSweeperAssignments(_monthKey);
    final selected = <int>{
      for (final group in existing)
        if (group.employeeId != null) group.employeeId!,
    };
    String? error;
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.78,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '扫路车福利分配',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('车辆数量：$count · 福利份数：$count · 已选择：${selected.length}人'),
                  const SizedBox(height: 4),
                  const Text('优先推荐：正式工司机；每人对应1份洗衣膏。'),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final candidate in candidates)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selected.contains(candidate.id),
                            onChanged: (value) => setSheetState(() {
                              error = null;
                              value == true
                                  ? selected.add(candidate.id)
                                  : selected.remove(candidate.id);
                            }),
                            title: Text(candidate.name),
                            subtitle: Text(candidate.employeeNo),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selected.length > count
                          ? null
                          : () async {
                              if (selected.length < count) {
                                final keep = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('还有福利未分配'),
                                    content: Text(
                                      '还有${count - selected.length}份福利未分配，仍要保存吗？',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('返回继续分配'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('仍然保存'),
                                      ),
                                    ],
                                  ),
                                );
                                if (keep != true) return;
                              }
                              if (sheetContext.mounted)
                                Navigator.pop(
                                  sheetContext,
                                  Set<int>.from(selected),
                                );
                            },
                      child: Text(
                        selected.length > count
                            ? '已超出${selected.length - count}人'
                            : '保存分配',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    try {
      await repo.saveSweeperAssignments(_monthKey, result);
      _refresh();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showPublicRecipient() async {
    final repo = ref.read(itemDistributionRepositoryProvider);
    final candidates = await repo.listPublicCandidates();
    final groups = await repo.listGroupsForMonth(_monthKey);
    final current = groups
        .where((group) => group.recipientType == 'public')
        .firstOrNull
        ?.employeeId;
    var selected =
        current ??
        candidates.where((item) => item.isCurrentlyActive).firstOrNull?.id;
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('公用福利领取人', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text('默认推荐当前在岗的正式员工，可按实际情况更换。'),
                const SizedBox(height: 8),
                ...candidates.map(
                  (candidate) => RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: candidate.id,
                    groupValue: selected,
                    onChanged: (value) => setSheetState(() => selected = value),
                    title: Text(candidate.name),
                    subtitle: Text(
                      '${candidate.employeeNo}${candidate.isCurrentlyActive ? ' · 当前在岗' : ' · 当前非在岗'}',
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selected == null
                        ? null
                        : () => Navigator.pop(sheetContext, selected),
                    child: const Text('保存领取人'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    await repo.savePublicRecipient(_monthKey, result);
    _refresh();
  }

  Future<void> _showUnreceived(DistributionSummary? summary) async {
    final groups = await ref.read(distributionGroupsProvider(_monthKey).future);
    final notReceived = groups.where((group) => group.hasNotReceived).toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_monthKey 未领取',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (notReceived.isEmpty)
                  const Expanded(child: Center(child: Text('本月福利已全部领取。')))
                else
                  Expanded(
                    child: ListView(
                      children: [
                        for (final group in notReceived)
                          ListTile(
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _showSourceSheet(group);
                            },
                            leading: const Icon(Icons.person_outline),
                            title: Text(group.recipientName),
                            subtitle: Text(_sourceSubtitle(group)),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReplenishment(DistributionRecipientGroup group) async {
    final source = group.entries.first;
    var reason = '补发';
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('补领'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('人员：${group.recipientName}'),
              Text('福利来源：${_sourceSubtitle(group)}'),
              Text(
                '物品：${source.itemName} ${_formatQuantity(source.quantity)}${source.unit}',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: '补领原因'),
                items: const [
                  DropdownMenuItem(value: '破损', child: Text('破损')),
                  DropdownMenuItem(value: '遗失', child: Text('遗失')),
                  DropdownMenuItem(value: '补发', child: Text('补发')),
                  DropdownMenuItem(value: '其他', child: Text('其他')),
                ],
                onChanged: (value) => setState(() => reason = value ?? reason),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认补领'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await ref
          .read(itemDistributionRepositoryProvider)
          .addReplenishment(
            month: _monthKey,
            group: group,
            sourceEntry: source,
            reason: reason,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
          );
      _refresh();
    }
    note.dispose();
  }

  Future<void> _showSettings() async {
    final repo = ref.read(itemDistributionRepositoryProvider);
    final sweeper = TextEditingController(
      text: '${await repo.getSweeperCount()}',
    );
    final public = TextEditingController(
      text: '${await repo.getPublicCount()}',
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('福利发放设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sweeper,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '扫路车数量',
                helperText: '每辆对应1份洗衣膏福利',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: public,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '公用福利份数',
                helperText: '按实际公用份数填写',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await repo.setSweeperCount(int.tryParse(sweeper.text) ?? 6);
              await repo.setPublicCount(int.tryParse(public.text) ?? 1);
              if (context.mounted) Navigator.pop(context);
              _refresh();
            },
            child: const Text('保存设置'),
          ),
        ],
      ),
    );
    sweeper.dispose();
    public.dispose();
  }

  Future<void> _showManualDistribution() async {
    final category = _category;
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ManualDistributionDialog(
        category: category,
        month: _monthKey,
        repository: ref.read(itemDistributionRepositoryProvider),
      ),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _pickMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 2, 12),
      helpText: '选择福利归属月份',
    );
    if (selected != null)
      setState(() => _month = DateTime(selected.year, selected.month, 1));
  }
}

class _ManualDistributionDialog extends StatefulWidget {
  const _ManualDistributionDialog({
    required this.category,
    required this.month,
    required this.repository,
  });

  final DistributionCategory category;
  final String month;
  final ItemDistributionRepository repository;

  @override
  State<_ManualDistributionDialog> createState() =>
      _ManualDistributionDialogState();
}

class _ManualDistributionDialogState extends State<_ManualDistributionDialog> {
  late final TextEditingController _recipient;
  late final TextEditingController _item;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _note;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _recipient = TextEditingController();
    _item = TextEditingController();
    _quantity = TextEditingController(text: '1');
    _unit = TextEditingController(text: '件');
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _recipient.dispose();
    _item.dispose();
    _quantity.dispose();
    _unit.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.category == DistributionCategory.tool
        ? '新增工具领用'
        : '新增办公用品领用';
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _recipient,
              decoration: const InputDecoration(labelText: '领取人/领取对象'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _item,
              decoration: const InputDecoration(labelText: '物品名称'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '数量'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: '单位'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存记录')),
      ],
    );
  }

  Future<void> _save() async {
    final recipient = _recipient.text.trim();
    final item = _item.text.trim();
    if (recipient.isEmpty || item.isEmpty) {
      setState(() => _validationMessage = '请填写领取人和物品名称');
      return;
    }

    final draft = ManualDistributionDraft(
      category: widget.category,
      month: widget.month,
      recipientName: recipient,
      recipientType: 'custom',
      recipientKey: 'custom:$recipient',
      itemName: item,
      quantity: double.tryParse(_quantity.text) ?? 1,
      unit: _unit.text.trim().isEmpty ? '件' : _unit.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (await widget.repository.duplicateCount(draft) > 0) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('重复领取提醒'),
          content: Text(
            '${draft.recipientName} 本月已有“${draft.itemName}”记录，是否仍要继续登记？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回检查'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('仍然登记'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    await widget.repository.addManualDistribution(draft);
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
