import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/inventory_providers.dart';
import '../../application/inventory_excel_service.dart';

class InventoryExportButton extends ConsumerStatefulWidget {
  const InventoryExportButton({super.key});

  @override
  ConsumerState<InventoryExportButton> createState() =>
      _InventoryExportButtonState();
}

class _InventoryExportButtonState extends ConsumerState<InventoryExportButton> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await ref.read(inventoryExcelServiceProvider).exportToFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('库存工作簿已导出：${file.path}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is InventoryExportEmptyException
                  ? '暂无可导出的库存业务数据'
                  : '库存工作簿导出失败：$error',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: _exporting ? '正在导出库存工作簿' : '导出库存工作簿',
    child: TextButton(
      key: const Key('inventory-export'),
      onPressed: _exporting ? null : _export,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _exporting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined),
          Text(
            _exporting ? '导出中' : '导出',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );
}
