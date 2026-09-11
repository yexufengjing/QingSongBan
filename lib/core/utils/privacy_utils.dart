abstract final class PrivacyUtils {
  static String maskIdCard(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '未填写';
    }
    if (text.length <= 8) {
      return '${text.substring(0, 1)}${'*' * (text.length - 2)}'
          '${text.substring(text.length - 1)}';
    }
    return '${text.substring(0, 4)}${'*' * (text.length - 8)}'
        '${text.substring(text.length - 4)}';
  }

  static String maskPhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '未填写';
    }
    if (text.length <= 7) {
      return '${text.substring(0, 2)}****';
    }
    return '${text.substring(0, 3)}****${text.substring(text.length - 4)}';
  }
}
