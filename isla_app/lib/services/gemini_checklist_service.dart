import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class GeminiChecklistService {
  final Dio _dio;

  GeminiChecklistService({Dio? dio}) : _dio = dio ?? Dio();

  /// Try Groq → Cerebras → SambaNova in order
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

    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: 3 * attempt));
      }

      // 1. Groq
      if (AppConfig.hasGroqKey) {
        try {
          return await _callOpenAiCompatible(
            endpoint: 'https://api.groq.com/openai/v1/chat/completions',
            model: AppConfig.groqModel,
            apiKey: AppConfig.groqApiKey,
            prompt: prompt,
            requestedItems: requestedItems,
          );
        } catch (e) {
          print('[ISLA AI] Groq checklist failed (pass ${attempt + 1}): $e');
        }
      }

      // 2. Cerebras
      if (AppConfig.hasCerebrasKey) {
        try {
          return await _callOpenAiCompatible(
            endpoint: 'https://api.cerebras.ai/v1/chat/completions',
            model: AppConfig.cerebrasModel,
            apiKey: AppConfig.cerebrasApiKey,
            prompt: prompt,
            requestedItems: requestedItems,
          );
        } catch (e) {
          print('[ISLA AI] Cerebras checklist failed (pass ${attempt + 1}): $e');
        }
      }

      // 3. SambaNova
      if (AppConfig.hasSambanovaKey) {
        try {
          return await _callOpenAiCompatible(
            endpoint: 'https://api.sambanova.ai/v1/chat/completions',
            model: AppConfig.sambanovaModel,
            apiKey: AppConfig.sambanovaApiKey,
            prompt: prompt,
            requestedItems: requestedItems,
          );
        } catch (e) {
          print('[ISLA AI] SambaNova checklist failed (pass ${attempt + 1}): $e');
        }
      }
    }

    throw StateError(
      'All AI providers (Groq, Cerebras, SambaNova) are unavailable or quota-limited.',
    );
  }

  // ── OpenAI-compatible call (Groq / Cerebras / SambaNova) ─────────────────────

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
