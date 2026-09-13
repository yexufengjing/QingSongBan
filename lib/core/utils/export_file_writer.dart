import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ExportFileWriter {
  const ExportFileWriter._();

  static const _channel = MethodChannel('qingsongban/file_exports');

  static Future<File> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (Platform.isAndroid) {
      final uri = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
      });
      if (uri != null && uri.isNotEmpty) {
        return File('/storage/emulated/0/Download/$fileName');
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}exports',
    );
    await exportDirectory.create(recursive: true);
    final file = File(
      '${exportDirectory.path}${Platform.pathSeparator}$fileName',
    );
    await file.writeAsBytes(bytes);
    return file;
  }
}
