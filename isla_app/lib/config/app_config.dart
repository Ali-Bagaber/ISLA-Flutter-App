import 'secrets.dart';

class AppConfig {
  // ── Groq (primary) ───────────────────────────────────────
  static String get groqApiKey => Secrets.groqApiKey;
  // llama-3.3-70b-versatile: 12K tokens/min, 100K/day (free).
  static const String groqModel = 'llama-3.3-70b-versatile';
  static bool get hasGroqKey => groqApiKey.trim().isNotEmpty;

  // ── Cerebras (fallback 1) ────────────────────────────────
  static String get cerebrasApiKey => Secrets.cerebrasApiKey;
  static const String cerebrasModel = 'llama-3.3-70b';
  static bool get hasCerebrasKey => cerebrasApiKey.trim().isNotEmpty;

  // ── SambaNova (fallback 2) ───────────────────────────────
  static String get sambanovaApiKey => Secrets.sambanovaApiKey;
  static const String sambanovaModel = 'Meta-Llama-3.3-70B-Instruct';
  static bool get hasSambanovaKey => sambanovaApiKey.trim().isNotEmpty;

  // ── Unsplash (study-aid images) ────────────────────────
  static String get unsplashAccessKey => Secrets.unsplashAccessKey;
  static bool get hasUnsplashKey => unsplashAccessKey.trim().isNotEmpty;
}
