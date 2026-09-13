class AttachmentOptions {
  const AttachmentOptions._();

  static const int maxFileSize = 20 * 1024 * 1024;

  static const categories = <String>[
    'idFront',
    'idBack',
    'bankCard',
    'insurance',
    'termination',
    'other',
  ];

  static const allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
  ];

  static String categoryLabel(String value) => switch (value) {
    'idFront' => '身份证正面',
    'idBack' => '身份证反面',
    'bankCard' => '银行卡',
    'insurance' => '保险材料',
    'termination' => '离职材料',
    _ => '其他证明',
  };

  static bool isSensitive(String value) =>
      value == 'idFront' || value == 'idBack' || value == 'bankCard';

  static bool isImage(String extension) =>
      const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension.toLowerCase());
}

class PendingAttachment {
  const PendingAttachment({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;
  final int size;
}
