/// Non-web stub for browser Notification API. All methods no-op.
class BrowserNotifier {
  /// Returns true if the platform supports browser notifications. Always
  /// false off the web.
  static bool get isSupported => false;

  /// Returns the current permission state ("granted" / "denied" / "default").
  static String get permission => 'denied';

  /// Asks the user for permission. No-op off the web.
  static Future<String> requestPermission() async => 'denied';

  /// Shows a system notification. No-op off the web.
  static void show(String title, String body) {}
}
