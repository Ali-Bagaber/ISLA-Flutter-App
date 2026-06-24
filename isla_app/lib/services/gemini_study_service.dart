import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// AI service for generating summaries, flashcards, and quiz questions.
/// Saves content to: summaries, flashcards, quiz_aids collections.
class GeminiStudyService {
  final Dio _dio;

  GeminiStudyService({Dio? dio}) : _dio = dio ?? Dio();

  /// Display name of the AI provider that answered the most recent request.
  /// Read this right after a generate* call to label the result accurately.
  String lastProvider = 'Groq AI';

  static FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  static String? get _userId => AuthService.currentUser?.uid;

  static DateTime _safeCreatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }

  // ── Core request helper — Groq → Cerebras → SambaNova ──────────────────────
  // All three are OpenAI-compatible, all running Llama 3.3 70B on free tiers.
  // Three independent providers = if one 429s, the next picks up instantly.

  Future<String> _ask(
    String prompt, {
    void Function()? onRetrying,
    int maxTokens = 1024,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        onRetrying?.call();
        await Future.delayed(Duration(seconds: 3 * attempt));
      }

      // 1. Groq 
      if (AppConfig.hasGroqKey) {
        try {
          final result = await _callOpenAiCompatible(
            endpoint: 'https://api.groq.com/openai/v1/chat/completions',
            model: AppConfig.groqModel,
            apiKey: AppConfig.groqApiKey,
            prompt: prompt,
            maxTokens: maxTokens,
          );
          lastProvider = 'Groq AI';
          return result;
        } catch (e) {
          print('[ISLA AI] Groq failed (pass ${attempt + 1}): $e');
        }
      }

      // 2. Cerebras .
      if (AppConfig.hasCerebrasKey) {
        try {
          final result = await _callOpenAiCompatible(
            endpoint: 'https://api.cerebras.ai/v1/chat/completions',
            model: AppConfig.cerebrasModel,
            apiKey: AppConfig.cerebrasApiKey,
            prompt: prompt,
            maxTokens: maxTokens,
          );
          lastProvider = 'Cerebras AI';
          return result;
        } catch (e) {
          print('[ISLA AI] Cerebras failed (pass ${attempt + 1}): $e');
        }
      }

      // 3. SambaNova.
      if (AppConfig.hasSambanovaKey) {
        try {
          final result = await _callOpenAiCompatible(
            endpoint: 'https://api.sambanova.ai/v1/chat/completions',
            model: AppConfig.sambanovaModel,
            apiKey: AppConfig.sambanovaApiKey,
            prompt: prompt,
            maxTokens: maxTokens,
          );
          lastProvider = 'SambaNova AI';
          return result;
        } catch (e) {
          print('[ISLA AI] SambaNova failed (pass ${attempt + 1}): $e');
        }
      }
    }

    throw StateError(
      'All AI providers (Groq, Cerebras, SambaNova) are unavailable or quota-limited.',
    );
  }

  Future<String> _callOpenAiCompatible({
    required String endpoint,
    required String model,
    required String apiKey,
    required String prompt,
    int maxTokens = 1024,
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
        'max_tokens': maxTokens,
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
  String _trimForPrompt(String text, {int maxChars = 16000}) {
    final t = text.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars)}\n\n[...content truncated...]';
  }

  // ── Summary length scaling ─────────────────────────────────────────────────

  /// Infer page/slide count from extracted text when not stored explicitly.
  static int _inferPageCount(String text) {
    final markers = RegExp(r'^Slide \d+:', multiLine: true).allMatches(text).length;
    if (markers > 0) return markers;
    final chars = text.trim().length;
    if (chars == 0) return 0;
    return (chars / 1500).ceil().clamp(1, 100);
  }

  /// Returns {bullets, paragraphs, words, tokens} scaled to document length.
  static ({int bullets, int paragraphs, int words, int tokens}) _summaryConfig(int pages) {
    if (pages <= 0)  return (bullets: 5,  paragraphs: 2, words: 280,  tokens: 1024);
    if (pages <= 5)  return (bullets: 5,  paragraphs: 2, words: 320,  tokens: 1024);
    if (pages <= 15) return (bullets: 8,  paragraphs: 3, words: 480,  tokens: 1600);
    if (pages <= 30) return (bullets: 10, paragraphs: 4, words: 650,  tokens: 2200);
    if (pages <= 50) return (bullets: 12, paragraphs: 5, words: 850,  tokens: 2800);
    return             (bullets: 15, paragraphs: 6, words: 1100, tokens: 3500);
  }

  // ── Summary ────────────────────────────────────────────────────────────────

  /// Summary output style.
  ///   - bullets   : numbered list, count scales with document length.
  ///   - paragraph : detailed paragraphs, count scales with document length.
  Future<String> generateSummary({
    required String title,      
    required String subject,
    String documentText = '',
    String mode = 'bullets',
    int pageCount = 0,
    void Function()? onRetrying,
  }) async {
    final hasText = documentText.trim().isNotEmpty;
    final wantParagraph = mode.toLowerCase() == 'paragraph';

    final pages = pageCount > 0 ? pageCount : _inferPageCount(documentText);
    final cfg = _summaryConfig(pages);

    final String prompt;
    if (wantParagraph) {
      prompt = hasText
          ? 'Summarize the following study material in clear paragraphs for a university student. '
              'Write ${cfg.paragraphs} detailed paragraphs covering the main ideas, important '
              'explanations and key concepts. Use simple academic language. Do not use bullet '
              'points or headings. Aim for approximately ${cfg.words} words.\n\n'
              'Document title: "$title"\nSubject: $subject\n\n'
              'Content:\n${_trimForPrompt(documentText)}'
          : 'Write a clear ${cfg.paragraphs}-paragraph summary of "$title" ($subject) for a '
              'university student, covering the main ideas, important explanations and key concepts '
              'in simple academic language. Do not use bullet points. Aim for ~${cfg.words} words.';
    } else {
      prompt = hasText
          ? 'Summarize the following document for a university student. Give ${cfg.bullets} key points as a numbered list. Each point: 1-2 sentences. Plain text only, start with "1.".\n\nDocument title: "$title"\nSubject: $subject\n\nContent:\n${_trimForPrompt(documentText)}'
          : 'Summarize the document "$title" ($subject) for a university student. Give ${cfg.bullets} key points as a numbered list. Each point: 1-2 sentences. Plain text only, start with "1."';
    }
    return await _ask(prompt, onRetrying: onRetrying, maxTokens: cfg.tokens);
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
            'Return ONLY a JSON array. Each item must have "question", "answer", and "imageKeyword" keys. '
            '"imageKeyword" is a short 2-4 word English search phrase describing the visual topic of that specific card '
            '(e.g. "cell division microscope", "newton gravity apple", "python code editor"). '
            'Answers: 1-2 sentences. No markdown.'
        : 'Create $count flashcards for "$title" ($subject). Return ONLY a JSON array. Each item must have "question", "answer", and "imageKeyword" keys. '
            '"imageKeyword" is a short 2-4 word English search phrase describing the visual topic of that specific card '
            '(e.g. "cell division microscope", "newton gravity apple", "python code editor"). '
            'Answers: 1-2 sentences. No markdown.';
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
                'imageKeyword': (item['imageKeyword'] ?? '').toString(),
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
            'Return ONLY a JSON array. Each item: "question" (string), "options" (4 strings), "correct" (0-3 index), '
            '"imageKeyword" (a short 2-4 word English search phrase describing the visual topic of that question, '
            'e.g. "solar system planets", "human heart anatomy"). No markdown.'
        : 'Create $count MCQ questions for "$title" ($subject). Return ONLY a JSON array. Each item: "question" (string), "options" (4 strings), "correct" (0-3 index), '
            '"imageKeyword" (a short 2-4 word English search phrase describing the visual topic of that question, '
            'e.g. "solar system planets", "human heart anatomy"). No markdown.';
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
                'imageKeyword': (item['imageKeyword'] ?? '').toString(),
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

    Stream<List<Map<String, dynamic>>> snap(String col) => db
        .collection(col)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

    // Combine three streams by merging their latest values
    return _combineThree(
      snap('summaries'),
      snap('flashcards'),
      snap('quiz_aids'),
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

  /// Delete a focus session and roll back its contribution to analytics totals.
  /// Removes the doc from both `sessions` and `study_sessions`, then decrements
  /// the user's total study minutes and session count (clamped at 0).
  static Future<void> deleteSession(String sessionId) async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null || sessionId.isEmpty) return;

    // Read the session's minutes first so we can subtract them from analytics.
    var minutes = 0;
    try {
      final snap = await db.collection('sessions').doc(sessionId).get();
      minutes = (snap.data()?['focusMinutes'] as num? ?? 0).toInt();
    } catch (_) {}

    await db.collection('sessions').doc(sessionId).delete();
    try {
      await db.collection('study_sessions').doc(sessionId).delete();
    } catch (_) {}

    // Roll back the running totals (never below zero).
    try {
      final ref = db.collection('analytics').doc(userId);
      final snap = await ref.get();
      final data = snap.data() ?? <String, dynamic>{};
      final totalMinutes =
          ((data['totalStudyTime'] as num? ?? 0).toInt() - minutes)
              .clamp(0, 1 << 31);
      final sessionCount =
          ((data['sessionCount'] as num? ?? 0).toInt() - 1).clamp(0, 1 << 31);
      await ref.set({
        'totalStudyTime': totalMinutes,
        'sessionCount': sessionCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
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

  /// One-time read of the user's sessions to work out the streak. Call this
  /// BEFORE saving a new session: [studiedToday] tells you whether today
  /// already had a session, so a new one will *increase* the streak when false.
  /// Returns the streak as it will be once today is counted, plus the last-7-day
  /// activity (oldest → newest, index 6 == today).
  static Future<({bool studiedToday, int newStreak, List<bool> last7})>
      getStreakInfo() async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) {
      return (studiedToday: false, newStreak: 1, last7: List.filled(7, false));
    }
    final studyDays = <DateTime>{};
    try {
      final snap = await db
          .collection('sessions')
          .where('userId', isEqualTo: userId)
          .get();
      for (final d in snap.docs) {
        final raw = d.data()['timestamp'];
        DateTime? ts;
        if (raw is Timestamp) ts = raw.toDate();
        if (ts != null) studyDays.add(DateTime(ts.year, ts.month, ts.day));
      }
    } catch (_) {}

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final studiedToday = studyDays.contains(today);

    // Count the streak as if today is included.
    studyDays.add(today);
    var streak = 0;
    var cursor = today;
    while (studyDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final last7 = List<bool>.generate(
        7, (i) => studyDays.contains(today.subtract(Duration(days: 6 - i))));

    return (studiedToday: studiedToday, newStreak: streak, last7: last7);
  }

  static Future<void> saveSession({
    required int focusMinutes,
    required int cycles,
    int plannedCycles = 0,
    String? subject,
    int? checklistDone,
    int? checklistTotal,
    int verifiedCorrect = 0,
    int verifiedTotal = 0,
    bool quizAvailable = true,
  }) async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return;

    final done = checklistDone ?? 0;
    final total = checklistTotal ?? 0;

    // Session score (0–100). Transparent formula:
    //   Base                                10
    //   Cycles completed (vs PLAN)          0–40
    //   Checklist completion %              0–20
    //   Verification correctness %          0–30 (auto-granted if no quiz)
    // Cycles are scored against the user's plan — finishing every planned cycle
    // earns full marks. Skipping a real Quick Check yields 0 for verification.
    final cycleRatio = plannedCycles > 0
        ? (cycles / plannedCycles).clamp(0.0, 1.0)
        : (cycles > 0 ? (min(cycles, 4) / 4) : 0.0);
    final cycleScore = (cycleRatio * 40).round();
    final checklistRatio = total > 0
        ? (done / total).clamp(0.0, 1.0)
        : 0.0;
    final checklistScore = (checklistRatio * 20).round();
    final int verifyScore;
    if (!quizAvailable) {
      verifyScore = 30;
    } else {
      final verifyRatio = verifiedTotal > 0
          ? (verifiedCorrect / verifiedTotal).clamp(0.0, 1.0)
          : 0.0;
      verifyScore = (verifyRatio * 30).round();
    }
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
