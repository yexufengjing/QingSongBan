import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openPurchaseOaUrl(BuildContext context, String? value) async {
  final uri = value == null ? null : Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    _showOaOpenError(context);
    return false;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) _showOaOpenError(context);
    return opened;
  } catch (_) {
    if (context.mounted) _showOaOpenError(context);
    return false;
  }
}

void _showOaOpenError(BuildContext context) {
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('当前 OA 链接无法打开，请检查链接是否有效。')));
}
