import 'secrets.dart';

class AppConfig {
  // ── Gemini ────────────────────────────────────────────────
  static String get geminiApiKey => Secrets.geminiApiKey;
  static const String geminiModel = 'gemini-2.0-flash-lite';
  static bool get hasGeminiKey =>
      geminiApiKey.trim().isNotEmpty &&
      geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';

  // ── Groq (first fallback) ─────────────────────────────────
  static String get groqApiKey => Secrets.groqApiKey;
  static const String groqModel = 'llama-3.3-70b-versatile';
  static bool get hasGroqKey =>
      groqApiKey.trim().isNotEmpty;

  // ── OpenRouter (second fallback) ──────────────────────────
  static String get openRouterApiKey => Secrets.openRouterApiKey;
  static const String openRouterModel = 'meta-llama/llama-4-scout:free';
  static bool get hasOpenRouterKey =>
      openRouterApiKey.trim().isNotEmpty;
}
