import 'package:flutter/services.dart';

abstract final class AppRestart {
  static const _channel = MethodChannel('qingsongban/app_lifecycle');

  static Future<void> restart() => _channel.invokeMethod<void>('restartApp');
}
