import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Gemini AI service for generating summaries, flashcards, and quiz questions.
/// Saves content to: summaries, flashcards, quiz_aids collections.
class GeminiStudyService {
  final Dio _dio;

  GeminiStudyService({Dio? dio}) : _dio = dio ?? Dio();

  static FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  static String? get _userId => AuthService.currentUser?.uid;

  final String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent';

  static DateTime _safeCreatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }

  // ── Core request helper — Gemini → Groq → OpenRouter ───────────────────────

  Future<String> _ask(String prompt, {void Function()? onRetrying}) async {
    // ── 1. Gemini ────────────────────────────────────────────────────────────
    if (AppConfig.hasGeminiKey) {
      try {
        return await _callGemini(prompt);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        // Auth errors → key is broken, don't try further providers
        if (code == 401 || code == 403) {
          throw StateError('Gemini API key invalid or restricted.');
        }
        // 429, network, or anything else → notify UI and try Groq
        onRetrying?.call();
      } on StateError {
        onRetrying?.call();
      }
    }

    // ── 2. Groq ──────────────────────────────────────────────────────────────
    if (AppConfig.hasGroqKey) {
      try {
        return await _callOpenAiCompatible(
          endpoint: 'https://api.groq.com/openai/v1/chat/completions',
          model: AppConfig.groqModel,
          apiKey: AppConfig.groqApiKey,
          prompt: prompt,
        );
      } catch (_) {
        // Fall through to OpenRouter
      }
    }

    // ── 3. OpenRouter ────────────────────────────────────────────────────────
    if (AppConfig.hasOpenRouterKey) {
      try {
        return await _callOpenAiCompatible(
          endpoint: 'https://openrouter.ai/api/v1/chat/completions',
          model: AppConfig.openRouterModel,
          apiKey: AppConfig.openRouterApiKey,
          prompt: prompt,
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

  Future<String> _callGemini(String prompt) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
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
        'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 1024},
      },
      options: Options(
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    final candidates = response.data?['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final parts = candidates.first['content']?['parts'];
      if (parts is List && parts.isNotEmpty) {
        final text = parts.first['text'];
        if (text is String) return text;
      }
    }
    throw StateError('Empty response from Gemini API');
  }

  Future<String> _callOpenAiCompatible({
    required String endpoint,
    required String model,
    required String apiKey,
    required String prompt,
    Map<String, String> extraHeaders = const {},
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      endpoint,
      data: {
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.4,
        'max_tokens': 1024,
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

    final choices = response.data?['choices'];
    if (choices is List && choices.isNotEmpty) {
      final message = choices.first['message'];
      if (message is Map) {
        final content = message['content'];
        if (content is String) return content;
      }
    }
    throw StateError('Empty response from AI provider.');
  }

  /// Trim long document content to keep request payload reasonable.
  String _trimForPrompt(String text, {int maxChars = 12000}) {
    final t = text.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars)}\n\n[...content truncated...]';
  }

  // ── Summary ────────────────────────────────────────────────────────────────

  /// Summary output style.
  ///   - bullets   : 5-point numbered list (default; quick scanning).
  ///   - paragraph : 2–3 detailed paragraphs explaining the material.
  ///
  /// Both styles are kept short enough to stay well under token limits.
  Future<String> generateSummary({
    required String title,
    required String subject,
    String documentText = '',
    String mode = 'bullets',
    void Function()? onRetrying,
  }) async {
    final hasText = documentText.trim().isNotEmpty;
    final wantParagraph = mode.toLowerCase() == 'paragraph';

    final String prompt;
    if (wantParagraph) {
      prompt = hasText
          ? 'Summarize the following study material in clear paragraphs for a university student. '
              'Write 2 to 3 detailed but concise paragraphs covering the main ideas, important '
              'explanations and key concepts. Use simple academic language. Do not use bullet '
              'points or headings. Keep the whole answer under ~280 words.\n\n'
              'Document title: "$title"\nSubject: $subject\n\n'
              'Content:\n${_trimForPrompt(documentText)}'
          : 'Write a clear 2–3 paragraph summary of "$title" ($subject) for a university student, '
              'covering the main ideas, important explanations and key concepts in simple academic '
              'language. Do not use bullet points. Keep the whole answer under ~280 words.';
    } else {
      prompt = hasText
          ? 'Summarize the following document for a university student. Give 5 key points as a numbered list. Each point: 1-2 sentences. Plain text only, start with "1.".\n\nDocument title: "$title"\nSubject: $subject\n\nContent:\n${_trimForPrompt(documentText)}'
          : 'Summarize the document "$title" ($subject) for a university student. Give 5 key points as a numbered list. Each point: 1-2 sentences. Plain text only, start with "1."';
    }
    return await _ask(prompt, onRetrying: onRetrying);
  }

  // ── Flashcards ─────────────────────────────────────────────────────────────

  /// Generate a single flashcard (card number [index]+1 of [total]).
  Future<Map<String, String>> generateSingleFlashcard({
    required String title,
    required String subject,
    required int index,
    required int total,
    String documentText = '',
  }) async {
    final hasText = documentText.trim().isNotEmpty;
    final prompt = hasText
        ? 'Create flashcard ${index + 1} of $total based on the following document.\n\n'
            'Title: "$title"\nSubject: $subject\n\n'
            'Content:\n${_trimForPrompt(documentText)}\n\n'
            'Return ONLY a JSON object with "question" and "answer" keys. '
            'Answer: 1-2 sentences. No markdown. Example: {"question":"...","answer":"..."}'
        : 'Create flashcard ${index + 1} of $total for "$title" ($subject). '
            'Return ONLY a JSON object with "question" and "answer" keys. '
            'Answer: 1-2 sentences. No markdown. Example: {"question":"...","answer":"..."}';
    final raw = await _ask(prompt);
    var cleaned =
        raw.trim().replaceAll('```json', '').replaceAll('```', '').trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start != -1 && end != -1) cleaned = cleaned.substring(start, end + 1);
    final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
    final q = (decoded['question'] ?? '').toString();
    final a = (decoded['answer'] ?? '').toString();
    if (q.isNotEmpty && a.isNotEmpty) return {'question': q, 'answer': a};
    throw StateError('Invalid flashcard response from AI.');
  }

  Future<List<Map<String, String>>> generateFlashcards({
    required String title,
    required String subject,
    int count = 8,
    String documentText = '',
    void Function()? onRetrying,
  }) async {
    final hasText = documentText.trim().isNotEmpty;
    final prompt = hasText
        ? 'Create $count flashcards based on the following document.\n\n'
            'Title: "$title"\nSubject: $subject\n\n'
            'Content:\n${_trimForPrompt(documentText)}\n\n'
            'Return ONLY a JSON array with "question" and "answer" keys. Answers: 1-2 sentences. No markdown.'
        : 'Create $count flashcards for "$title" ($subject). Return ONLY a JSON array with "question" and "answer" keys. Answers: 1-2 sentences. No markdown.';
    final raw = await _ask(prompt, onRetrying: onRetrying);
    return _parseFlashcards(raw);
  }

  List<Map<String, String>> _parseFlashcards(String raw) {
    var cleaned = raw.trim();
    // Strip markdown code fences if present
    cleaned = cleaned.replaceAll('```json', '').replaceAll('```', '').trim();

    // Extract JSON array
    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start != -1 && end != -1) {
      cleaned = cleaned.substring(start, end + 1);
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is List) {
        return decoded
            .map<Map<String, String>>((item) {
              return {
                'question': (item['question'] ?? '').toString(),
                'answer': (item['answer'] ?? '').toString(),
              };
            })
            .where((m) => m['question']!.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Quiz ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> generateQuiz({
    required String title,
    required String subject,
    int count = 5,
    String documentText = '',
    void Function()? onRetrying,
  }) async {
    final hasText = documentText.trim().isNotEmpty;
    final prompt = hasText
        ? 'Create $count MCQ questions based on the following document.\n\n'
            'Title: "$title"\nSubject: $subject\n\n'
            'Content:\n${_trimForPrompt(documentText)}\n\n'
            'Return ONLY a JSON array. Each item: "question" (string), "options" (4 strings), "correct" (0-3 index). No markdown.'
        : 'Create $count MCQ questions for "$title" ($subject). Return ONLY a JSON array. Each item: "question" (string), "options" (4 strings), "correct" (0-3 index). No markdown.';
    final raw = await _ask(prompt, onRetrying: onRetrying);
    return _parseQuiz(raw);
  }

  List<Map<String, dynamic>> _parseQuiz(String raw) {
    var cleaned = raw.trim();
    cleaned = cleaned.replaceAll('```json', '').replaceAll('```', '').trim();

    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start != -1 && end != -1) {
      cleaned = cleaned.substring(start, end + 1);
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is List) {
        return decoded
            .map<Map<String, dynamic>>((item) {
              return {
                'question': (item['question'] ?? '').toString(),
                'options': (item['options'] as List?)
                        ?.map((o) => o.toString())
                        .toList() ??
                    [],
                'correct': (item['correct'] as int?) ?? 0,
              };
            })
            .where((m) => m['question'].toString().isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Firestore Persistence ──────────────────────────────────────────────────

  /// Update the user's analytics document (incremental)
  static Future<void> _updateAnalytics(
    FirebaseFirestore db,
    String userId, {
    int addStudyMinutes = 0,
    int addSessions = 0,
    int? quizScore, // percentage 0-100
  }) async {
    final ref = db.collection('analytics').doc(userId);
    final snap = await ref.get();
    final existing = snap.exists ? snap.data()! : <String, dynamic>{};

    final totalMinutes =
        (existing['totalStudyTime'] as num? ?? 0).toInt() + addStudyMinutes;
    final sessionCount =
        (existing['sessionCount'] as num? ?? 0).toInt() + addSessions;

    // Compute running quiz average
    int quizAvg = (existing['quizAvg'] as num? ?? 0).toInt();
    int quizCount = (existing['quizCount'] as num? ?? 0).toInt();
    if (quizScore != null) {
      quizCount += 1;
      quizAvg = ((quizAvg * (quizCount - 1) + quizScore) / quizCount).round();
    }

    await ref.set({
      'analyticsId': userId,
      'userId': userId,
      'totalStudyTime': totalMinutes,
      'sessionCount': sessionCount,
      'quizAvg': quizAvg,
      'quizCount': quizCount,
      'currentGPA': existing['currentGPA'] ?? 0.0,
      'currentCGPA': existing['currentCGPA'] ?? 0.0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Save summary to Firestore — summaries collection
  static Future<String?> saveSummary({
    required String title,
    required String subject,
    required String content,
    String documentId = '',
  }) async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return null;

    final ref = db.collection('summaries').doc();
    final id = ref.id;
    await ref.set({
      'summaryId': id,
      'documentId': documentId,
      'userId': userId,
      'type': 'Summary',
      'title': title,
      'subject': subject,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// Save flashcards to Firestore — flashcards collection
  static Future<String?> saveFlashcards({
    required String title,
    required String subject,
    required List<Map<String, String>> cards,
    String documentId = '',
  }) async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return null;

    final ref = db.collection('flashcards').doc();
    final id = ref.id;
    final encoded = jsonEncode(cards);
    await ref.set({
      'flashcardId': id,
      'documentId': documentId,
      'userId': userId,
      'type': 'Flashcards',
      'title': title,
      'subject': subject,
      'content': encoded,
      'cardCount': cards.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// Save quiz questions + result to Firestore + update analytics
  static Future<String?> saveQuizWithResult({
    required String title,
    required String subject,
    required List<Map<String, dynamic>> questions,
    required int score,
    required int total,
    String documentId = '',
  }) async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return null;

    final safeTotal = max(1, total);
    final correctAnswers = score.clamp(0, safeTotal);
    final scorePercentage = ((correctAnswers / safeTotal) * 100).round();
    final encoded = jsonEncode(questions);

    final ref = db.collection('quiz_aids').doc();
    final id = ref.id;
    await ref.set({
      'quizAidId': id,
      'documentId': documentId,
      'userId': userId,
      'type': 'Quiz',
      'title': title,
      'subject': subject,
      'content': encoded,
      'score': scorePercentage,
      'totalQuestions': safeTotal,
      'correctAnswers': correctAnswers,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Update analytics (non-blocking)
    _updateAnalytics(db, userId, quizScore: scorePercentage);
    return id;
  }

  /// Legacy — kept for compatibility
  static Future<void> saveQuizResult({
    required String docTitle,
    required String subject,
    required int score,
    required int total,
  }) async {
    await saveQuizWithResult(
      title: docTitle,
      subject: subject,
      questions: [],
      score: score,
      total: total,
    );
  }

  /// Stream for Study Library — merges summaries + flashcards + quiz_aids
  static Stream<List<Map<String, dynamic>>> watchStudyMaterials() {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return Stream.value([]);

    Stream<List<Map<String, dynamic>>> _snap(String col) => db
        .collection(col)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

    // Combine three streams by merging their latest values
    return _combineThree(
      _snap('summaries'),
      _snap('flashcards'),
      _snap('quiz_aids'),
    );
  }

  static Stream<List<Map<String, dynamic>>> _combineThree(
    Stream<List<Map<String, dynamic>>> a,
    Stream<List<Map<String, dynamic>>> b,
    Stream<List<Map<String, dynamic>>> c,
  ) async* {
    List<Map<String, dynamic>> latestA = [];
    List<Map<String, dynamic>> latestB = [];
    List<Map<String, dynamic>> latestC = [];
    bool gotA = false, gotB = false, gotC = false;

    final controller = StreamController<List<Map<String, dynamic>>>();

    void emit() {
      if (!gotA || !gotB || !gotC) return;
      final merged = [...latestA, ...latestB, ...latestC];
      merged.sort((x, y) => _safeCreatedAt(y['createdAt'])
          .compareTo(_safeCreatedAt(x['createdAt'])));
      if (!controller.isClosed) controller.add(merged);
    }

    final subs = [
      a.listen((v) {
        latestA = v;
        gotA = true;
        emit();
      }),
      b.listen((v) {
        latestB = v;
        gotB = true;
        emit();
      }),
      c.listen((v) {
        latestC = v;
        gotC = true;
        emit();
      }),
    ];

    yield* controller.stream;
    for (final s in subs) {
      await s.cancel();
    }
    await controller.close();
  }

  /// Stream for quiz attempts/results
  static Stream<List<Map<String, dynamic>>> watchQuizResults() {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return Stream.value([]);
    return db
        .collection('quiz_results')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
            (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Stream for saved Pomodoro sessions
  static Stream<List<Map<String, dynamic>>> watchSessions() {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return Stream.value([]);
    return db
        .collection('sessions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
            (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  static Future<void> saveSession({
    required int focusMinutes,
    required int cycles,
    String? subject,
    int? checklistDone,
    int? checklistTotal,
    int verifiedCorrect = 0,
    int verifiedTotal = 0,
  }) async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return;

    final done = checklistDone ?? 0;
    final total = checklistTotal ?? 0;

    // Session score (0–100). Transparent formula:
    //   Base                                10
    //   Cycles completed (×10, cap at 4)    0–40
    //   Checklist completion %              0–20
    //   Verification correctness %          0–30
    // Skipping the Quick Check yields 0 for the verification slice — so users
    // who actually demonstrate retention earn a meaningfully higher score.
    final cycleScore = (min(cycles, 4) * 10);
    final checklistRatio = total > 0
        ? (done / total).clamp(0.0, 1.0)
        : 0.0;
    final checklistScore = (checklistRatio * 20).round();
    final verifyRatio = verifiedTotal > 0
        ? (verifiedCorrect / verifiedTotal).clamp(0.0, 1.0)
        : 0.0;
    final verifyScore = (verifyRatio * 30).round();
    final focusScore =
        (10 + cycleScore + checklistScore + verifyScore).clamp(0, 100);

    final safeSubject = (subject == null || subject.trim().isEmpty)
        ? 'Other Tasks'
        : subject.trim();

    final ref = db.collection('sessions').doc();
    await ref.set({
      'sessionId': ref.id,
      'focusMinutes': focusMinutes,
      'cycles': cycles,
      'subject': safeSubject,
      'checklistDone': done,
      'checklistTotal': total,
      'verifiedCorrect': verifiedCorrect,
      'verifiedTotal': verifiedTotal,
      'duration': focusMinutes,
      'actualMinutes': focusMinutes,
      'plannedMinutes': focusMinutes,
      'sessionMode': 'focus',
      'focusScore': focusScore,
      'completed': true,
      'userId': userId,
      'date': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await db.collection('study_sessions').doc(ref.id).set({
      'sessionId': ref.id,
      'userId': userId,
      'subject': safeSubject,
      'documentId': '',
      'sessionMode': 'focus',
      'plannedMinutes': focusMinutes,
      'actualMinutes': focusMinutes,
      'breakMinutes': 0,
      'interruptionsCount': 0,
      'checklistDone': done,
      'checklistTotal': total,
      'verifiedCorrect': verifiedCorrect,
      'verifiedTotal': verifiedTotal,
      'focusScore': focusScore,
      'completed': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update analytics (non-blocking)
    _updateAnalytics(db, userId, addStudyMinutes: focusMinutes, addSessions: 1);
  }
}
