import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class GeminiChecklistService {
  final Dio _dio;

  GeminiChecklistService({Dio? dio}) : _dio = dio ?? Dio();

  /// Try Gemini → Groq → OpenRouter in order. Throws only if all fail.
  Future<List<String>> generateChecklist({
    required String goal,
    required String sourceText,
    String sessionSubject = '',
    int requestedItems = 3,
    List<String> existingItems = const [],
  }) async {
    final prompt = _buildPrompt(
      goal: goal,
      sourceText: sourceText,
      sessionSubject: sessionSubject,
      requestedItems: requestedItems,
      existingItems: existingItems,
    );

    // ── 1. Gemini ──────────────────────────────────────────────────────────────
    if (AppConfig.hasGeminiKey) {
      try {
        return await _callGemini(prompt, requestedItems);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        // Auth errors → don't try further (key is broken, not quota)
        if (code == 401 || code == 403) {
          throw StateError(_geminiHttpError(e));
        }
        // 429 or network → fall through to next provider
      } on StateError {
        // Parsing failure → fall through
      }
    }

    // ── 2. Groq ────────────────────────────────────────────────────────────────
    if (AppConfig.hasGroqKey) {
      try {
        return await _callOpenAiCompatible(
          endpoint: 'https://api.groq.com/openai/v1/chat/completions',
          model: AppConfig.groqModel,
          apiKey: AppConfig.groqApiKey,
          prompt: prompt,
          requestedItems: requestedItems,
        );
      } catch (_) {
        // Fall through to OpenRouter
      }
    }

    // ── 3. OpenRouter ──────────────────────────────────────────────────────────
    if (AppConfig.hasOpenRouterKey) {
      try {
        return await _callOpenAiCompatible(
          endpoint: 'https://openrouter.ai/api/v1/chat/completions',
          model: AppConfig.openRouterModel,
          apiKey: AppConfig.openRouterApiKey,
          prompt: prompt,
          requestedItems: requestedItems,
          extraHeaders: {'HTTP-Referer': 'https://isla.app'},
        );
      } catch (_) {
        // Fall through
      }
    }

    throw StateError(
      'All AI providers (Gemini, Groq, OpenRouter) are unavailable or quota-limited.',
    );
  }

  // ── Gemini call ──────────────────────────────────────────────────────────────

  Future<List<String>> _callGemini(String prompt, int safeCount) async {
    const endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent';

    final response = await _dio.post<Map<String, dynamic>>(
      endpoint,
      queryParameters: {'key': AppConfig.geminiApiKey},
      data: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 1.0,
          'topP': 0.95,
          'maxOutputTokens': 512,
        },
      },
      options: Options(
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    final text = _extractGeminiText(response.data);
    return _takeParsed(text, safeCount);
  }

  String _extractGeminiText(Map<String, dynamic>? data) {
    final candidates = data?['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final content = candidates.first['content'];
      final parts = content['parts'];
      if (parts is List && parts.isNotEmpty) {
        final text = parts.first['text'];
        if (text is String) return text;
      }
    }
    throw StateError('Gemini response has no text.');
  }

  String _geminiHttpError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 429) return 'Gemini quota/rate limit reached (429).';
    if (code == 401 || code == 403) return 'Gemini API key invalid or restricted.';
    if (code == 404) return 'Gemini model not found.';
    return 'Gemini network error.';
  }

  // ── OpenAI-compatible call (Groq / OpenRouter) ───────────────────────────────

  Future<List<String>> _callOpenAiCompatible({
    required String endpoint,
    required String model,
    required String apiKey,
    required String prompt,
    required int requestedItems,
    Map<String, String> extraHeaders = const {},
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      endpoint,
      data: {
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 1.0,
        'max_tokens': 512,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          ...extraHeaders,
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    final text = _extractOpenAiText(response.data);
    return _takeParsed(text, requestedItems);
  }

  String _extractOpenAiText(Map<String, dynamic>? data) {
    final choices = data?['choices'];
    if (choices is List && choices.isNotEmpty) {
      final message = choices.first['message'];
      if (message is Map) {
        final content = message['content'];
        if (content is String) return content;
      }
    }
    throw StateError('AI response has no text.');
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────

  String _buildPrompt({
    required String goal,
    required String sourceText,
    required String sessionSubject,
    required int requestedItems,
    required List<String> existingItems,
  }) {
    final safeCount = requestedItems.clamp(1, 6);
    final requestId = DateTime.now().millisecondsSinceEpoch;
    final existingBlock = existingItems.isEmpty
        ? '- none'
        : existingItems.map((item) => '- ${item.trim()}').join('\n');
    final normalizedSubject = sessionSubject.trim();
    final normalizedGoal = goal.trim();
    final normalizedSource = sourceText.trim();

    return '''
You are generating study checklist actions for one student session.
Return ONLY a valid JSON array of strings.

Hard rules:
- Return exactly $safeCount items.
- Each item must be specific to the subject/goal/context below.
- Use varied sentence patterns and varied action types.
- Do not output generic filler.
- Do not repeat or paraphrase existing checklist items.
- Keep each item concise (max 95 characters).
- No markdown, no commentary.

Session subject:
${normalizedSubject.isEmpty ? 'Not provided' : normalizedSubject}

Study goal:
${normalizedGoal.isEmpty ? 'Not provided' : normalizedGoal}

Session context:
${normalizedSource.isEmpty ? 'Not provided' : normalizedSource}

Existing checklist items that MUST NOT be repeated:
$existingBlock

Checklist style guidance:
- include practical actions such as subtopic targeting, explanation, recall check,
  mini-problem solving, and end-of-cycle review
- phrasing should sound natural and student-focused, not robotic

Request id: $requestId
''';
  }

  List<String> _takeParsed(String raw, int safeCount) {
    final parsed = _parseChecklist(raw).where((item) => item.isNotEmpty).toList();
    if (parsed.length <= safeCount) return parsed;
    return parsed.take(safeCount).toList();
  }

  List<String> _parseChecklist(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceAll('```json', '').replaceAll('```', '').trim();
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is List) {
        return decoded.map((item) => item.toString().trim()).toList();
      }
    } catch (_) {
      // Fallback to line parsing.
    }

    final lines = cleaned.split('\n');
    return lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^[-*]\s+'), ''))
        .map((line) => line.replaceFirst(RegExp(r'^\d+[.)]\s+'), ''))
        .toList();
  }
}
