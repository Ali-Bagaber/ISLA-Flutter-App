import 'secrets.dart';

class AppConfig {
  static String get geminiApiKey => Secrets.geminiApiKey;
  static const String geminiModel = 'gemini-2.0-flash-lite';
  static bool get hasGeminiKey =>
      geminiApiKey.trim().isNotEmpty &&
      geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';
}
