// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show Notification;

/// Web implementation of the browser Notification API wrapper.
class BrowserNotifier {
  static bool get isSupported => true;

  static String get permission {
    try {
      return html.Notification.permission ?? 'default';
    } catch (_) {
      return 'denied';
    }
  }

  static Future<String> requestPermission() async {
    try {
      return await html.Notification.requestPermission();
    } catch (_) {
      return 'denied';
    }
  }

  static void show(String title, String body) {
    try {
      if (permission == 'granted') {
        html.Notification(title, body: body);
      }
    } catch (_) {
      // Browser doesn't expose Notification API — fall through silently.
    }
  }
}
