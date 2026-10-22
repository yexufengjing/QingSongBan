import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../personnel/application/personnel_providers.dart';
import '../../vehicles/application/vehicle_providers.dart';
import '../application/assistant_favorites.dart';
import '../application/assistant_providers.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_quick_query.dart';

const _names = {
  AssistantQuickQueryKind.attendance: '考勤查询',
  AssistantQuickQueryKind.payroll: '工资与依据',
  AssistantQuickQueryKind.inventoryLowStock: '低库存物资',
  AssistantQuickQueryKind.purchasePending: '待到货采购',
  AssistantQuickQueryKind.distribution: '福利领取',
  AssistantQuickQueryKind.vehicleRepair: '车辆维修',
};

String assistantMonth(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

/// Shared by the welcome screen and the composer, so shortcuts stay reachable.
class AssistantQuickQueries extends ConsumerWidget {
  const AssistantQuickQueries({
    super.key,
    this.pageContext,
    required this.onRun,
  });

  final AssistantPageContext? pageContext;
  final ValueChanged<AssistantQuickQuery> onRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(assistantControllerProvider).isBusy;
    final favorites = ref.watch(assistantQueryFavoritesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('快捷查询', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('选好条件即可查询，无需输入，也无需 API Key。'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in AssistantQuickQueryKind.values)
              ActionChip(
                label: Text(_names[kind]!),
                onPressed: busy ? null : () => _configure(context, kind),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('我的收藏', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        favorites.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton.icon(
            onPressed: () => ref.invalidate(assistantQueryFavoritesProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('收藏加载失败，点击重试'),
          ),
          data: (items) => items.isEmpty
              ? const Text('在查询条件中点击“收藏查询”，下次可一键重查。')
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.star_outline),
                        title: Text(item.name),
                        subtitle: Text(item.query.title),
                        onTap: busy ? null : () => onRun(item.query),
                        trailing: IconButton(
                          tooltip: '移除收藏 ${item.name}',
                          onPressed: () async {
                            try {
                              await ref
                                  .read(
                                    assistantQueryFavoritesProvider.notifier,
                                  )
                                  .remove(item.id);
                            } catch (_) {
                              if (context.mounted) {
                                _showMessage(context, '移除收藏失败，请重试。');
                              }
                            }
                          },
                          icon: const Icon(Icons.star, color: Colors.amber),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _configure(
    BuildContext context,
    AssistantQuickQueryKind kind,
  ) async {
    final query = await showModalBottomSheet<AssistantQuickQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QuickQueryForm(kind: kind, pageContext: pageContext),
    );
    if (query != null && context.mounted) onRun(query);
  }
}

class _QuickQueryForm extends ConsumerStatefulWidget {
  const _QuickQueryForm({required this.kind, this.pageContext});
  final AssistantQuickQueryKind kind;
  final AssistantPageContext? pageContext;
  @override
  ConsumerState<_QuickQueryForm> createState() => _QuickQueryFormState();
}

class _QuickQueryFormState extends ConsumerState<_QuickQueryForm> {
  late DateTime _month;
  int? _employeeId;
  int? _vehicleId;
  bool _saving = false;
  bool _saved = false;
  String? _error;
  bool get _needsEmployee =>
      widget.kind == AssistantQuickQueryKind.attendance ||
      widget.kind == AssistantQuickQueryKind.payroll;
  bool get _needsVehicle =>
      widget.kind == AssistantQuickQueryKind.vehicleRepair;
  bool get _needsMonth =>
      widget.kind != AssistantQuickQueryKind.inventoryLowStock &&
      widget.kind != AssistantQuickQueryKind.purchasePending;

  @override
  void initState() {
    super.initState();
    final page = widget.pageContext;
    _month = DateTime.tryParse('${page?.yearMonth}-01') ?? DateTime.now();
    _employeeId = page?.employeeId;
    _vehicleId = page?.vehicleId;
  }

  @override
  Widget build(BuildContext context) {
    final employees = _needsEmployee ? ref.watch(allPersonnelProvider) : null;
    final vehicles = _needsVehicle ? ref.watch(allVehiclesProvider) : null;
    final people = employees?.valueOrNull ?? [];
    final cars = vehicles?.valueOrNull ?? [];
    final person = people.where((e) => e.id == _employeeId).firstOrNull;
    final car = cars.where((v) => v.id == _vehicleId).firstOrNull;
    final valid =
        (!_needsEmployee || person != null) && (!_needsVehicle || car != null);
    final query = AssistantQuickQuery(
      kind: widget.kind,
      yearMonth: _needsMonth ? assistantMonth(_month) : null,
      employeeId: _needsEmployee ? person?.id : null,
      vehicleId: _needsVehicle ? car?.id : null,
    );
    final subject = person == null
        ? (car == null
              ? ''
              : '${car.name}（${car.licensePlate ?? car.vehicleNo}）')
        : '${person.name}（${person.employeeNo}）';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _names[widget.kind]!,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('业务数据在本地查询，结果可查看来源。'),
            if (_needsEmployee) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_search_outlined),
                label: Text(
                  person == null
                      ? '选择人员'
                      : '${person.name} · ${person.employeeNo}',
                ),
                onPressed:
                    employees?.hasError == true || employees?.isLoading == true
                    ? null
                    : () async {
                        final id = await _selectEntity(context, '选择人员', [
                          for (final e in people)
                            (id: e.id, label: '${e.name} · ${e.employeeNo}'),
                        ]);
                        if (id != null && mounted) {
                          setState(() {
                            _employeeId = id;
                            _saved = false;
                          });
                        }
                      },
              ),
              if (employees?.isLoading == true) const LinearProgressIndicator(),
              if (employees?.hasError == true)
                TextButton(
                  onPressed: () => ref.invalidate(allPersonnelProvider),
                  child: const Text('人员加载失败，点击重试'),
                ),
              if (employees?.hasValue == true && people.isEmpty)
                const Text('暂无人员，请先在人员管理中添加。'),
            ],
            if (_needsVehicle) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.directions_car_outlined),
                label: Text(
                  car == null
                      ? '选择车辆'
                      : '${car.name} · ${car.licensePlate ?? car.vehicleNo}',
                ),
                onPressed:
                    vehicles?.hasError == true || vehicles?.isLoading == true
                    ? null
                    : () async {
                        final id = await _selectEntity(context, '选择车辆', [
                          for (final v in cars)
                            (
                              id: v.id,
                              label:
                                  '${v.name} · ${v.licensePlate ?? v.vehicleNo}',
                            ),
                        ]);
                        if (id != null && mounted) {
                          setState(() {
                            _vehicleId = id;
                            _saved = false;
                          });
                        }
                      },
              ),
              if (vehicles?.isLoading == true) const LinearProgressIndicator(),
              if (vehicles?.hasError == true)
                TextButton(
                  onPressed: () => ref.invalidate(allVehiclesProvider),
                  child: const Text('车辆加载失败，点击重试'),
                ),
              if (vehicles?.hasValue == true && cars.isEmpty)
                const Text('暂无车辆，请先在车辆管理中添加。'),
            ],
            if (_needsMonth) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: '前一个月',
                    onPressed: () =>
                        _setMonth(DateTime(_month.year, _month.month - 1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          useRootNavigator: false,
                          initialDate: DateTime(_month.year, _month.month),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100, 12, 31),
                          helpText: '选择查询月份（日期仅用于定位月份）',
                        );
                        if (date != null && mounted) _setMonth(date);
                      },
                      child: Text('${assistantMonth(_month)} 月'),
                    ),
                  ),
                  IconButton(
                    tooltip: '后一个月',
                    onPressed: () =>
                        _setMonth(DateTime(_month.year, _month.month + 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('本月'),
                    onPressed: () => _setMonth(DateTime.now()),
                  ),
                  ActionChip(
                    label: const Text('上月'),
                    onPressed: () {
                      final now = DateTime.now();
                      _setMonth(DateTime(now.year, now.month - 1));
                    },
                  ),
                ],
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: valid && !_saving
                  ? () => Navigator.pop(context, query)
                  : null,
              icon: const Icon(Icons.search),
              label: const Text('查询本地数据'),
            ),
            OutlinedButton.icon(
              onPressed: valid && !_saving && !_saved
                  ? () => _save(
                      query,
                      '${_names[widget.kind]}${subject.isEmpty ? '' : ' · $subject'}${_needsMonth ? ' · ${assistantMonth(_month)}' : ''}',
                    )
                  : null,
              icon: Icon(_saved ? Icons.star : Icons.star_outline),
              label: Text(
                _saving
                    ? '正在保存…'
                    : _saved
                    ? '已收藏此查询'
                    : '收藏查询',
              ),
            ),
            if (_needsMonth)
              const Text('收藏保留所选月份；查询其他月份可重新选择。', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _setMonth(DateTime month) => setState(() {
    _month = month;
    _saved = false;
    _error = null;
  });

  Future<void> _save(AssistantQuickQuery query, String name) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(assistantQueryFavoritesProvider.notifier).add(name, query);
      if (mounted) setState(() => _saved = true);
    } on StateError {
      if (mounted) setState(() => _error = '此查询已收藏，可在“我的收藏”中使用。');
    } catch (_) {
      if (mounted) setState(() => _error = '收藏保存失败，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

Future<int?> _selectEntity(
  BuildContext context,
  String title,
  List<({int id, String label})> items,
) => showDialog<int>(
  context: context,
  useRootNavigator: false,
  builder: (_) => _EntityPicker(title: title, items: items),
);

class _EntityPicker extends StatefulWidget {
  const _EntityPicker({required this.title, required this.items});
  final String title;
  final List<({int id, String label})> items;
  @override
  State<_EntityPicker> createState() => _EntityPickerState();
}

class _EntityPickerState extends State<_EntityPicker> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where((e) => e.label.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        height: MediaQuery.sizeOf(context).height * .45,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '搜索姓名、工号或车辆',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('没有匹配的记录'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(items[index].label),
                        onTap: () => Navigator.pop(context, items[index].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

void _showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
