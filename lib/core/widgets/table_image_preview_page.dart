import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../utils/gallery_image_writer.dart';
import '../utils/table_image.dart';

class TableImagePreviewPage extends StatefulWidget {
  const TableImagePreviewPage({
    super.key,
    required this.title,
    required this.heading,
    required this.description,
    required this.fileNamePrefix,
    required this.semanticLabel,
    required this.previewKey,
    required this.saveKey,
    required this.generate,
  });

  final String title;
  final String heading;
  final String description;
  final String fileNamePrefix;
  final String semanticLabel;
  final Key previewKey;
  final Key saveKey;
  final Future<TableImage> Function() generate;

  @override
  State<TableImagePreviewPage> createState() => _TableImagePreviewPageState();
}

class _TableImagePreviewPageState extends State<TableImagePreviewPage> {
  TableImage? _image;
  String? _error;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() => _error = null);
    try {
      final image = await widget.generate();
      if (mounted) setState(() => _image = image);
    } catch (_) {
      if (mounted) setState(() => _error = '图片生成失败，请重试');
    }
  }

  Future<void> _save() async {
    final image = _image;
    if (image == null || _saving || _saved) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final prefix = widget.fileNamePrefix.replaceAll(
        RegExp(r'[\\/:*?"<>|\x00-\x1F]'),
        '_',
      );
      await GalleryImageWriter.save(
        bytes: image.bytes,
        fileName:
            '${prefix}_'
            '${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存到相册「轻松办」')));
    } on MissingPluginException {
      if (mounted) setState(() => _error = '当前平台暂不支持保存到相册');
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? '保存失败，请重试');
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.heading,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: image == null
                  ? Center(
                      child: _error == null
                          ? const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LinearProgressIndicator(),
                                SizedBox(height: 16),
                                Text('正在生成完整图片…'),
                              ],
                            )
                          : TextButton.icon(
                              onPressed: _generate,
                              icon: const Icon(Icons.refresh_outlined),
                              label: const Text('重新生成'),
                            ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRect(
                        child: InteractiveViewer(
                          key: widget.previewKey,
                          minScale: 1,
                          maxScale: 12,
                          child: Center(
                            child: Image.memory(
                              image.bytes,
                              fit: BoxFit.contain,
                              semanticLabel: widget.semanticLabel,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    _saved ? '已保存到相册「轻松办」' : '双指放大查看，拖动核对表格',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: widget.saveKey,
                    onPressed: image == null || _saving || _saved
                        ? null
                        : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: Icon(
                      _saved ? Icons.check_outlined : Icons.save_alt_outlined,
                    ),
                    label: Text(
                      _saving
                          ? '正在保存…'
                          : _saved
                          ? '已保存'
                          : '保存到相册',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
