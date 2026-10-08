import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders the artwork directly from the approved 002 reference without
/// approximating its buildings, trees, shading, or brand mark.
class HomeOfficeIllustration extends StatelessWidget {
  const HomeOfficeIllustration({super.key});
  @override
  Widget build(BuildContext context) => const _ReferenceSprite(
    source: Rect.fromLTRB(420, 285, 824, 473),
    width: 184,
    height: 86,
  );
}

class HomeReferenceBrand extends StatelessWidget {
  const HomeReferenceBrand({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '轻松办',
    hint: '有序办理，高效管理',
    image: true,
    child: const _ReferenceSprite(
      source: Rect.fromLTRB(29, 84, 359, 166),
      width: 151,
      height: 38,
    ),
  );
}

class _ReferenceSprite extends StatefulWidget {
  const _ReferenceSprite({
    required this.source,
    required this.width,
    required this.height,
  });
  final Rect source;
  final double width, height;
  @override
  State<_ReferenceSprite> createState() => _ReferenceSpriteState();
}

class _ReferenceSpriteState extends State<_ReferenceSprite> {
  ui.Image? _image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await rootBundle.load('assets/ui/home_reference.png');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: _image == null
        ? null
        : CustomPaint(painter: _SpritePainter(_image!, widget.source)),
  );
}

class _SpritePainter extends CustomPainter {
  const _SpritePainter(this.image, this.source);
  final ui.Image image;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    source,
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.high,
  );
  @override
  bool shouldRepaint(_SpritePainter oldDelegate) =>
      image != oldDelegate.image || source != oldDelegate.source;
}
