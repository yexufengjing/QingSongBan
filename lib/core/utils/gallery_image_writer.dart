import 'package:flutter/services.dart';

class GalleryImageWriter {
  static const _channel = MethodChannel('qingsongban/file_exports');

  static Future<String> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uri = await _channel.invokeMethod<String>('saveImageToGallery', {
      'bytes': bytes,
      'fileName': fileName,
    });
    if (uri == null || uri.isEmpty) {
      throw StateError('相册未返回保存结果');
    }
    return uri;
  }
}
