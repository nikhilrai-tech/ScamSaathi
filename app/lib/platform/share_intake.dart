import 'package:flutter/services.dart';

/// Text shared to the app from WhatsApp, SMS or a browser (Android). Safe to call on any platform.
class ShareIntake {
  static const _channel = MethodChannel('scamsaathi/share');

  /// Text that started the app, if any.
  Future<String?> initial() async {
    try {
      return await _channel.invokeMethod<String>('takeSharedText');
    } on MissingPluginException {
      return null; // web, tests, other platforms
    } on PlatformException {
      return null;
    }
  }

  /// Text shared while the app is already open.
  void listen(void Function(String text) onText) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) onText(call.arguments as String);
    });
  }
}
