import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/vehicle_providers.dart';
import '../domain/condition_options.dart';
import '../domain/tire_options.dart';

enum VehicleViewAngle { frontLeft, frontRight, rearRight, rearLeft }

/// One inspectable point on a particular atlas quadrant.
class VehicleVisualNodeSpec {
  const VehicleVisualNodeSpec.condition({
    required this.label,
    required this.x,
    required this.y,
    required this.componentType,
    required this.componentKey,
  }) : tirePosition = null;

  const VehicleVisualNodeSpec.tire({
    required this.label,
    required this.x,
    required this.y,
    required this.tirePosition,
  }) : componentType = null,
       componentKey = null;

  final String label;
  final double x;
  final double y;
  final String? componentType;
  final String? componentKey;
  final TirePosition? tirePosition;

  bool get isTire => tirePosition != null;
}

/// Atlas quadrants by driver-side orientation: TL=frontRight, TR=frontLeft,
/// BL=rearRight and BR=rearLeft.
Rect vehicleAtlasQuadrantForAngle(
  VehicleViewAngle angle, {
  double atlasWidth = 1,
  double atlasHeight = 1,
}) {
  final halfWidth = atlasWidth / 2;
  final halfHeight = atlasHeight / 2;
  final origin = switch (angle) {
    VehicleViewAngle.frontLeft => Offset(halfWidth, 0),
    VehicleViewAngle.frontRight => Offset.zero,
    VehicleViewAngle.rearRight => Offset(0, halfHeight),
    VehicleViewAngle.rearLeft => Offset(halfWidth, halfHeight),
  };
  return Rect.fromLTWH(origin.dx, origin.dy, halfWidth, halfHeight);
}

/// Trims transparent margins inside a quadrant so the truck fills the preview
/// while preserving the source aspect ratio.
Rect vehicleAtlasContentRectForAngle(
  VehicleViewAngle angle, {
  double atlasWidth = 1,
  double atlasHeight = 1,
}) {
  final quadrant = vehicleAtlasQuadrantForAngle(
    angle,
    atlasWidth: atlasWidth,
    atlasHeight: atlasHeight,
  );
  final topInset = quadrant.height * 0.10;
  return Rect.fromLTWH(
    quadrant.left,
    quadrant.top + topInset,
    quadrant.width,
    quadrant.height * 0.80,
  );
}

Alignment vehicleAtlasAlignmentForAngle(VehicleViewAngle angle) =>
    switch (angle) {
      VehicleViewAngle.frontLeft => Alignment.topRight,
      VehicleViewAngle.frontRight => Alignment.topLeft,
      VehicleViewAngle.rearRight => Alignment.bottomLeft,
      VehicleViewAngle.rearLeft => Alignment.bottomRight,
    };

String vehicleAtlasAssetPath(VehicleType type) => switch (type) {
  VehicleType.sweeper => 'assets/vehicles/sweeper-angles.png',
  VehicleType.waterTruck => 'assets/vehicles/water-angles.png',
};

const vehicleVisualNodesByAngle =
    <VehicleViewAngle, List<VehicleVisualNodeSpec>>{
      VehicleViewAngle.frontLeft: [
        VehicleVisualNodeSpec.condition(
          label: '车身',
          x: 0.30,
          y: 0.49,
          componentType: 'exterior',
          componentKey: 'exteriorMain',
        ),
        VehicleVisualNodeSpec.condition(
          label: '发动机',
          x: 0.12,
          y: 0.56,
          componentType: 'engine',
          componentKey: 'engineMain',
        ),
        VehicleVisualNodeSpec.condition(
          label: '车灯',
          x: 0.09,
          y: 0.66,
          componentType: 'light',
          componentKey: 'lighting',
        ),
        VehicleVisualNodeSpec.condition(
          label: '清扫',
          x: 0.66,
          y: 0.77,
          componentType: 'sweeper',
          componentKey: 'sweeperMain',
        ),
        VehicleVisualNodeSpec.condition(
          label: '水路',
          x: 0.57,
          y: 0.48,
          componentType: 'water',
          componentKey: 'waterMain',
        ),
        VehicleVisualNodeSpec.tire(
          label: '左前轮',
          x: 0.48,
          y: 0.80,
          tirePosition: TirePosition.leftFront,
        ),
        VehicleVisualNodeSpec.tire(
          label: '左后轮',
          x: 0.82,
          y: 0.73,
          tirePosition: TirePosition.leftRearOuter,
        ),
      ],
      VehicleViewAngle.frontRight: [
        VehicleVisualNodeSpec.condition(
          label: '车身',
          x: 0.70,
          y: 0.49,
          componentType: 'exterior',
          componentKey: 'exteriorMain',
        ),
        VehicleVisualNodeSpec.condition(
          label: '发动机',
          x: 0.88,
          y: 0.56,
          componentType: 'engine',
          componentKey: 'engineMain',
        ),
        VehicleVisualNodeSpec.condition(
          label: '车灯',
          x: 0.91,
          y: 0.66,
          componentType: 'light',
          componentKey: 'lighting',
        ),
        VehicleVisualNodeSpec.condition(
          label: '清扫',
          x: 0.34,
          y: 0.77,
          componentType: 'sweeper',
          componentKey: 'sweeperMain',
        ),
        VehicleVisualNodeSpec.condition(
          label: '水路',
          x: 0.43,
          y: 0.48,
          componentType: 'water',
          componentKey: 'waterMain',
        ),
        VehicleVisualNodeSpec.tire(
          label: '右前轮',
          x: 0.52,
          y: 0.80,
          tirePosition: TirePosition.rightFront,
        ),
        VehicleVisualNodeSpec.tire(
          label: '右后轮',
          x: 0.14,
          y: 0.73,
          tirePosition: TirePosition.rightRearOuter,
        ),
      ],
      VehicleViewAngle.rearRight: [
        VehicleVisualNodeSpec.condition(
          label: '车身',
          x: 0.66,
          y: 0.49,
          componentType: 'exterior',
          componentKey: 'exteriorMain',
        ),
        VehicleVisualNodeSpec.condition(
          label: '车灯',
          x: 0.09,
          y: 0.67,
          componentType: 'light',
          componentKey: 'lighting',
        ),
        VehicleVisualNodeSpec.condition(
          label: '清扫',
          x: 0.36,
          y: 0.77,
          componentType: 'sweeper',
          componentKey: 'sweeperMain',
        ),
        VehicleVisualNodeSpec.condition(
          label: '水路',
          x: 0.47,
          y: 0.47,
          componentType: 'water',
          componentKey: 'waterMain',
        ),
        VehicleVisualNodeSpec.tire(
          label: '右后轮',
          x: 0.57,
          y: 0.73,
          tirePosition: TirePosition.rightRearOuter,
        ),
        VehicleVisualNodeSpec.tire(
          label: '右前轮',
          x: 0.89,
          y: 0.73,
          tirePosition: TirePosition.rightFront,
        ),
      ],
      VehicleViewAngle.rearLeft: [
        VehicleVisualNodeSpec.condition(
          label: '车身',
          x: 0.34,
          y: 0.49,
          componentType: 'exterior',
          componentKey: 'exteriorMain',
        ),
        VehicleVisualNodeSpec.condition(
          label: '车灯',
          x: 0.91,
          y: 0.67,
          componentType: 'light',
          componentKey: 'lighting',
        ),
        VehicleVisualNodeSpec.condition(
          label: '清扫',
          x: 0.64,
          y: 0.77,
          componentType: 'sweeper',
          componentKey: 'sweeperMain',
        ),
        VehicleVisualNodeSpec.condition(
          label: '水路',
          x: 0.53,
          y: 0.47,
          componentType: 'water',
          componentKey: 'waterMain',
        ),
        VehicleVisualNodeSpec.tire(
          label: '左后轮',
          x: 0.43,
          y: 0.73,
          tirePosition: TirePosition.leftRearOuter,
        ),
        VehicleVisualNodeSpec.tire(
          label: '左前轮',
          x: 0.16,
          y: 0.73,
          tirePosition: TirePosition.leftFront,
        ),
      ],
    };

List<VehicleVisualNodeSpec> vehicleVisualNodesFor(
  VehicleViewAngle angle,
  VehicleType type,
) => [
  for (final node in vehicleVisualNodesByAngle[angle]!)
    if (node.componentType == null ||
        (type == VehicleType.sweeper && node.componentType != 'water') ||
        (type == VehicleType.waterTruck && node.componentType != 'sweeper'))
      node,
];

VehicleConditionItem? findVehicleConditionNode(
  Iterable<VehicleConditionItem> items,
  String componentType,
  String componentKey,
) {
  for (final item in items) {
    if (item.componentType == componentType &&
        item.componentKey == componentKey) {
      return item;
    }
  }
  return null;
}

const vehicleUnknownNodeColor = Color(0xff96a2ad);

Color vehicleConditionNodeColor(VehicleConditionItem? item) =>
    switch (item?.status) {
      null => vehicleUnknownNodeColor,
      VehicleConditionStatus.normal => AppColors.primary,
      VehicleConditionStatus.minorAbnormal ||
      VehicleConditionStatus.needsAttention => Colors.orange,
      VehicleConditionStatus.pendingRepair ||
      VehicleConditionStatus.repairing => AppColors.danger,
      VehicleConditionStatus.unavailable => AppColors.body,
    };

Color vehicleTireNodeColor(TireInstallation? installation, Tire? tire) {
  if (installation == null || tire == null) return vehicleUnknownNodeColor;
  if (tire.status == TireAssetStatus.scrapped) return AppColors.danger;
  if (tire.status != TireAssetStatus.inUse) return vehicleUnknownNodeColor;
  return switch (tire.wearLevel) {
    TireWearLevel.good => AppColors.primary,
    TireWearLevel.light || TireWearLevel.medium => Colors.orange,
    TireWearLevel.severe ||
    TireWearLevel.replaceRecommended => AppColors.danger,
  };
}

class VehicleVisualView extends ConsumerStatefulWidget {
  const VehicleVisualView({
    required this.vehicle,
    this.conditions = const [],
    super.key,
  });

  final Vehicle vehicle;
  final List<VehicleConditionItem> conditions;

  @override
  ConsumerState<VehicleVisualView> createState() => _VehicleVisualViewState();
}

class _VehicleVisualViewState extends ConsumerState<VehicleVisualView> {
  VehicleViewAngle _angle = VehicleViewAngle.frontLeft;
  bool _listView = false;
  double _horizontalDragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final installationAsync = ref.watch(
      vehicleTireInstallationsProvider(widget.vehicle.id),
    );
    final tireAsync = ref.watch(vehicleTireAssetsProvider);
    final installations =
        installationAsync.valueOrNull ?? const <TireInstallation>[];
    final tireById = {
      for (final tire in tireAsync.valueOrNull ?? const <Tire>[]) tire.id: tire,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('部件状态说明', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _LegendDot(color: AppColors.primary, label: '正常'),
                _LegendDot(color: Colors.orange, label: '关注'),
                _LegendDot(color: AppColors.danger, label: '待维修'),
                _LegendDot(color: vehicleUnknownNodeColor, label: '未记录'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ViewModeButton(
                  icon: Icons.directions_car_outlined,
                  label: '车辆视图',
                  selected: !_listView,
                  onTap: () => setState(() => _listView = false),
                ),
                const SizedBox(width: 8),
                _ViewModeButton(
                  icon: Icons.view_list_outlined,
                  label: '部件列表',
                  selected: _listView,
                  onTap: () => setState(() => _listView = true),
                ),
                const Spacer(),
                if (!_listView)
                  IconButton.filledTonal(
                    tooltip: '重置到左前方',
                    onPressed: () =>
                        setState(() => _angle = VehicleViewAngle.frontLeft),
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _listView
                  ? _buildList(tireById, installations)
                  : _buildAtlas(tireById, installations),
            ),
            if (!_listView) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '每次滑动切换一个视角，点击节点查看记录',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '上一个视角',
                    onPressed: () => _stepAngle(forward: false),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    _angleLabel(_angle),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  IconButton(
                    tooltip: '下一个视角',
                    onPressed: () => _stepAngle(forward: true),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _stepAngle({required bool forward}) => setState(() {
    final views = VehicleViewAngle.values;
    final index = views.indexOf(_angle);
    _angle = views[(index + (forward ? 1 : views.length - 1)) % views.length];
  });

  Widget _buildAtlas(
    Map<int, Tire> tireById,
    List<TireInstallation> installations,
  ) => LayoutBuilder(
    key: const ValueKey('vehicle-atlas'),
    builder: (context, constraints) {
      final size = constraints.maxWidth;
      final nodes = vehicleVisualNodesFor(_angle, widget.vehicle.vehicleType);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _horizontalDragDistance = 0,
        onHorizontalDragUpdate: (details) {
          _horizontalDragDistance += details.delta.dx;
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          final distance = _horizontalDragDistance;
          _horizontalDragDistance = 0;
          if (velocity.abs() >= 80) {
            _stepAngle(forward: velocity < 0);
          } else if (distance.abs() >= 36) {
            _stepAngle(forward: distance < 0);
          }
        },
        child: SizedBox(
          width: size,
          height: size * 0.80,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: _VehicleAtlasQuadrant(
                  assetPath: vehicleAtlasAssetPath(widget.vehicle.vehicleType),
                  angle: _angle,
                ),
              ),
              for (final node in nodes)
                _buildNodeMarker(node, size, tireById, installations),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildNodeMarker(
    VehicleVisualNodeSpec node,
    double size,
    Map<int, Tire> tireById,
    List<TireInstallation> installations,
  ) {
    final installation = node.isTire
        ? _installationAt(installations, node.tirePosition!)
        : null;
    final tire = installation == null ? null : tireById[installation.tireId];
    final color = node.isTire
        ? vehicleTireNodeColor(installation, tire)
        : vehicleConditionNodeColor(
            findVehicleConditionNode(
              widget.conditions,
              node.componentType!,
              node.componentKey!,
            ),
          );
    return Positioned(
      left: node.x * size,
      top: ((node.y - 0.10) / 0.80) * size * 0.80,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: _NodeMarker(
          spec: node,
          color: color,
          onTap: () => node.isTire
              ? _showTire(node.tirePosition!, installation, tire)
              : _showCondition(node),
        ),
      ),
    );
  }

  Widget _buildList(
    Map<int, Tire> tireById,
    List<TireInstallation> installations,
  ) => Column(
    key: const ValueKey('vehicle-node-list'),
    children: [
      for (final (label, type, key) in [
        ('车身外观', 'exterior', 'exteriorMain'),
        ('发动机', 'engine', 'engineMain'),
        ('车灯', 'light', 'lighting'),
        if (widget.vehicle.vehicleType == VehicleType.sweeper)
          ('清扫系统', 'sweeper', 'sweeperMain'),
        if (widget.vehicle.vehicleType == VehicleType.waterTruck)
          ('水路与喷头', 'water', 'waterMain'),
      ])
        _ConditionNodeListTile(
          label: label,
          item: findVehicleConditionNode(widget.conditions, type, key),
          onTap: () => _showCondition(
            VehicleVisualNodeSpec.condition(
              label: label,
              x: 0.5,
              y: 0.5,
              componentType: type,
              componentKey: key,
            ),
          ),
        ),
      const Divider(height: 8),
      for (final position in TirePosition.values)
        _TireNodeListTile(
          position: position,
          installation: _installationAt(installations, position),
          tire: tireById[_installationAt(installations, position)?.tireId],
          onTap: () => _showTire(
            position,
            _installationAt(installations, position),
            tireById[_installationAt(installations, position)?.tireId],
          ),
        ),
    ],
  );

  void _showCondition(VehicleVisualNodeSpec node) {
    final item = findVehicleConditionNode(
      widget.conditions,
      node.componentType!,
      node.componentKey!,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.label,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                item == null
                    ? '尚无该部件的检查记录'
                    : '当前状态：${VehicleConditionOptions.statusLabel(item.status)}',
              ),
              if (item?.detail?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(item!.detail!),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('关闭'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.push(
                          '/vehicles/${widget.vehicle.id}/repair/new',
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.techBlue,
                      ),
                      child: const Text('转为报修'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTire(
    TirePosition position,
    TireInstallation? installation,
    Tire? tire,
  ) {
    final color = vehicleTireNodeColor(installation, tire);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TireOptions.positionLabel(position),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              if (installation == null)
                Text('该轮位未安装轮胎', style: TextStyle(color: color))
              else if (tire == null)
                Text(
                  '找不到轮胎档案（编号 ${installation.tireId}）',
                  style: TextStyle(color: color),
                )
              else ...[
                Text('轮胎编号：${tire.tireNo}'),
                Text('磨损情况：${TireOptions.wearLabel(tire.wearLevel)}'),
                Text('轮胎状态：${TireOptions.statusLabel(tire.status)}'),
                Text('安装日期：${_dateLabel(installation.installDate)}'),
                if (installation.note?.isNotEmpty == true)
                  Text('安装备注：${installation.note}'),
                if (tire.remark?.isNotEmpty == true)
                  Text('轮胎备注：${tire.remark}'),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TireInstallation? _installationAt(
    List<TireInstallation> installations,
    TirePosition position,
  ) {
    for (final installation in installations) {
      if (installation.position == position && installation.isActive) {
        return installation;
      }
    }
    return null;
  }
}

class _VehicleAtlasQuadrant extends StatefulWidget {
  const _VehicleAtlasQuadrant({required this.assetPath, required this.angle});

  final String assetPath;
  final VehicleViewAngle angle;

  @override
  State<_VehicleAtlasQuadrant> createState() => _VehicleAtlasQuadrantState();
}

class _VehicleAtlasQuadrantState extends State<_VehicleAtlasQuadrant> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _imageInfo;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _VehicleAtlasQuadrant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) _resolveImage();
  }

  void _resolveImage() {
    final nextStream = AssetImage(widget.assetPath)
        .resolve(createLocalImageConfiguration(context));
    if (identical(nextStream, _stream)) return;
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = ImageStreamListener(
      (info, _) {
        final nextInfo = info.clone();
        final previous = _imageInfo;
        if (mounted) {
          setState(() {
            _imageInfo = nextInfo;
            _error = null;
          });
          previous?.dispose();
        } else {
          nextInfo.dispose();
        }
      },
      onError: (error, _) {
        if (mounted) setState(() => _error = error);
      },
    );
    _stream = nextStream;
    nextStream.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _imageInfo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _AtlasQuadrantPainter(
      image: _imageInfo?.image,
      angle: widget.angle,
      error: _error != null,
    ),
    child: _imageInfo == null
        ? Center(
            child: _error == null
                ? const Icon(
                    Icons.directions_car_filled_outlined,
                    color: AppColors.body,
                    size: 40,
                  )
                : const Text('车辆视图加载失败'),
          )
        : null,
  );
}

class _AtlasQuadrantPainter extends CustomPainter {
  const _AtlasQuadrantPainter({
    required this.image,
    required this.angle,
    required this.error,
  });

  final ui.Image? image;
  final VehicleViewAngle angle;
  final bool error;

  @override
  void paint(Canvas canvas, Size size) {
    final atlas = image;
    if (atlas == null || error || size.isEmpty) return;
    final source = vehicleAtlasContentRectForAngle(
      angle,
      atlasWidth: atlas.width.toDouble(),
      atlasHeight: atlas.height.toDouble(),
    );
    final fitted = applyBoxFit(BoxFit.contain, source.size, size);
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      atlas,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_AtlasQuadrantPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.angle != angle ||
      oldDelegate.error != error;
}

class _NodeMarker extends StatelessWidget {
  const _NodeMarker({
    required this.spec,
    required this.color,
    required this.onTap,
  });

  final VehicleVisualNodeSpec spec;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${spec.label}，${color == vehicleUnknownNodeColor ? '未记录' : '查看状态'}',
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.72)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x220f2746),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                spec.label,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ConditionNodeListTile extends StatelessWidget {
  const _ConditionNodeListTile({
    required this.label,
    required this.item,
    required this.onTap,
  });

  final String label;
  final VehicleConditionItem? item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = vehicleConditionNodeColor(item);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, color: color, size: 14),
      title: Text(label),
      subtitle: Text(
        item?.detail?.isNotEmpty == true ? item!.detail! : '无检查备注',
      ),
      trailing: Text(
        item == null
            ? '未记录'
            : VehicleConditionOptions.statusShortLabel(item!.status),
        style: TextStyle(color: color),
      ),
      onTap: onTap,
    );
  }
}

class _TireNodeListTile extends StatelessWidget {
  const _TireNodeListTile({
    required this.position,
    required this.installation,
    required this.tire,
    required this.onTap,
  });

  final TirePosition position;
  final TireInstallation? installation;
  final Tire? tire;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = vehicleTireNodeColor(installation, tire);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, color: color, size: 14),
      title: Text(TireOptions.positionLabel(position)),
      subtitle: Text(
        installation == null
            ? '未安装轮胎'
            : tire == null
            ? '轮胎档案缺失'
            : '${tire!.tireNo} · ${TireOptions.wearLabel(tire!.wearLevel)}',
      ),
      trailing: Text(
        installation == null ? '无记录' : '查看',
        style: TextStyle(color: color),
      ),
      onTap: onTap,
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.techBlue
            : AppColors.lightBlue.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: selected ? Colors.white : AppColors.body),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

String _angleLabel(VehicleViewAngle angle) => switch (angle) {
  VehicleViewAngle.frontLeft => '车辆左前方',
  VehicleViewAngle.frontRight => '车辆右前方',
  VehicleViewAngle.rearRight => '车辆右后方',
  VehicleViewAngle.rearLeft => '车辆左后方',
};

String _dateLabel(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
