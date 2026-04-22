import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class GeminiChecklistService {
  final Dio _dio;

  GeminiChecklistService({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<String>> generateChecklist({
    required String goal,
    required String sourceText,
    String sessionSubject = '',
    int requestedItems = 3,
    List<String> existingItems = const [],
  }) async {
    if (!AppConfig.hasGeminiKey) {
      throw StateError('GEMINI_API_KEY is missing.');
    }

    const endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent';

    final normalizedSubject = sessionSubject.trim();
    final normalizedGoal = goal.trim();
    final normalizedSource = sourceText.trim();
    final safeCount = requestedItems.clamp(1, 6);
    final requestId = DateTime.now().millisecondsSinceEpoch;
    final existingBlock = existingItems.isEmpty
        ? '- none'
        : existingItems.map((item) => '- ${item.trim()}').join('\n');

    final prompt = '''
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

    Map<String, dynamic>? responseData;
    try {
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
      responseData = response.data;
    } on DioException catch (e) {
      throw StateError(_friendlyApiError(e));
    }

    final text = _extractResponseText(responseData);
    final parsed =
        _parseChecklist(text).where((item) => item.isNotEmpty).toList();
    if (parsed.length <= safeCount) return parsed;
    return parsed.take(safeCount).toList();
  }

  String _friendlyApiError(DioException e) {
    final statusCode = e.response?.statusCode;
    final apiError = _extractApiError(e.response?.data);

    if (statusCode == 429) {
      return 'Gemini quota/rate limit reached (HTTP 429). Wait and retry, or increase quota/billing for your API key project.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'Gemini API key is invalid or blocked by restrictions.';
    }
    if (statusCode == 404) {
      return 'Gemini model not found. Update model in app config.';
    }
    if (apiError != null && apiError.isNotEmpty) {
      return apiError;
    }

    return 'Network error while contacting Gemini API.';
  }

  String? _extractApiError(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final error = responseData['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String) {
          return message;
        }
      }
    }
    return null;
  }

  String _extractResponseText(Map<String, dynamic>? data) {
    final candidates = data?['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final content = candidates.first['content'];
      final parts = content['parts'];
      if (parts is List && parts.isNotEmpty) {
        final text = parts.first['text'];
        if (text is String) {
          return text;
        }
      }
    }
    throw StateError('Gemini response has no text.');
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
