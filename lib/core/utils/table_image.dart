import 'dart:typed_data';

class TableImage {
  const TableImage(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;
}
