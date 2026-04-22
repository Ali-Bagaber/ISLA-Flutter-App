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

  // ── Core request helper ────────────────────────────────────────────────────

  Future<String> _ask(String prompt,
      {int retryCount = 0, void Function()? onRetrying}) async {
    if (!AppConfig.hasGeminiKey) {
      throw StateError('Gemini API key is not configured in secrets.dart');
    }
    Map<String, dynamic>? responseData;
    try {
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
          'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 512},
        },
        options: Options(
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      responseData = response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429 && retryCount < 3) {
        // Rate limited — notify UI, wait then retry silently (up to 3 times)
        onRetrying?.call();
        // Wait longer each retry: 5s, 10s, 20s
        final waitSeconds = [5, 10, 20][retryCount];
        await Future.delayed(Duration(seconds: waitSeconds));
        return _ask(prompt, retryCount: retryCount + 1, onRetrying: onRetrying);
      }
      throw StateError(_friendlyApiError(e));
    }

    final candidates = responseData?['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final parts = candidates.first['content']?['parts'];
      if (parts is List && parts.isNotEmpty) {
        final text = parts.first['text'];
        if (text is String) return text;
      }
    }
    throw StateError('Empty response from Gemini API');
  }

  String _friendlyApiError(DioException e) {
    final statusCode = e.response?.statusCode;
    final apiError = _extractApiError(e.response?.data);

    if (statusCode == 429) {
      return 'AI is temporarily busy. Please tap Try Again in a few seconds.';
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

  // ── Summary ────────────────────────────────────────────────────────────────

  Future<String> generateSummary({
    required String title,
    required String subject,
    void Function()? onRetrying,
  }) async {
    final prompt =
        'Summarize the document "$title" ($subject) for a university student. Give 5 key points as a numbered list. Each point: 1-2 sentences. Plain text only, start with "1."';
    try {
      return await _ask(prompt, onRetrying: onRetrying);
    } catch (_) {
      return '1. $title is a key topic in $subject that covers foundational concepts and principles.\n'
          '2. Understanding this subject requires familiarity with core definitions, frameworks, and methodologies.\n'
          '3. The main themes include theoretical foundations, practical applications, and real-world case studies.\n'
          '4. Key skills developed include analytical thinking, problem-solving, and applying knowledge to new scenarios.\n'
          '5. Reviewing this document will help consolidate understanding and prepare for assessments in $subject.';
    }
  }

  // ── Flashcards ─────────────────────────────────────────────────────────────

  /// Generate a single flashcard (card number [index]+1 of [total]).
  Future<Map<String, String>> generateSingleFlashcard({
    required String title,
    required String subject,
    required int index,
    required int total,
  }) async {
    final prompt =
        'Create flashcard ${index + 1} of $total for "$title" ($subject). '
        'Return ONLY a JSON object with "question" and "answer" keys. '
        'Answer: 1-2 sentences. No markdown. Example: {"question":"...","answer":"..."}';
    final _fallbacks = [
      {
        'question': 'What is the main topic of "$title"?',
        'answer': 'It covers key concepts and principles in $subject.'
      },
      {
        'question': 'What subject does "$title" belong to?',
        'answer': 'It belongs to $subject.'
      },
      {
        'question': 'Why is $subject important?',
        'answer':
            '$subject provides foundational knowledge and practical skills.'
      },
      {
        'question': 'What are the core themes in $subject?',
        'answer': 'Theory, application, analysis, and problem-solving.'
      },
      {
        'question': 'How should you study "$title"?',
        'answer':
            'Read actively, take notes, and test yourself on key concepts.'
      },
      {
        'question': 'What skills does $subject develop?',
        'answer':
            'Critical thinking, analytical reasoning, and applied knowledge.'
      },
      {
        'question': 'How does "$title" relate to real-world use?',
        'answer': 'It applies concepts to practical scenarios in $subject.'
      },
      {
        'question': 'What is the best way to review $subject material?',
        'answer':
            'Summarise key points, use flashcards, and practice with past questions.'
      },
    ];
    try {
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
    } catch (_) {}
    return _fallbacks[index % _fallbacks.length];
  }

  Future<List<Map<String, String>>> generateFlashcards({
    required String title,
    required String subject,
    int count = 8,
    void Function()? onRetrying,
  }) async {
    final prompt =
        'Create $count flashcards for "$title" ($subject). Return ONLY a JSON array with "question" and "answer" keys. Answers: 1-2 sentences. No markdown.';
    try {
      final raw = await _ask(prompt, onRetrying: onRetrying);
      return _parseFlashcards(raw);
    } catch (_) {
      return [
        {
          'question': 'What is the main topic of "$title"?',
          'answer': 'It covers key concepts and principles in $subject.'
        },
        {
          'question': 'What subject does "$title" belong to?',
          'answer': 'It belongs to $subject.'
        },
        {
          'question': 'Why is $subject important?',
          'answer':
              '$subject provides foundational knowledge and practical skills.'
        },
        {
          'question': 'What are the core themes in $subject?',
          'answer': 'Theory, application, analysis, and problem-solving.'
        },
        {
          'question': 'How should you study "$title"?',
          'answer':
              'Read actively, take notes, and test yourself on key concepts.'
        },
        {
          'question': 'What skills does $subject develop?',
          'answer':
              'Critical thinking, analytical reasoning, and applied knowledge.'
        },
        {
          'question': 'How does "$title" relate to real-world use?',
          'answer': 'It applies concepts to practical scenarios in $subject.'
        },
        {
          'question': 'What is the best way to review $subject material?',
          'answer':
              'Summarise key points, use flashcards, and practice with past questions.'
        },
      ].take(count).toList();
    }
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
    void Function()? onRetrying,
  }) async {
    final prompt =
        'Create $count MCQ questions for "$title" ($subject). Return ONLY a JSON array. Each item: "question" (string), "options" (4 strings), "correct" (0-3 index). No markdown.';
    try {
      final raw = await _ask(prompt, onRetrying: onRetrying);
      return _parseQuiz(raw);
    } catch (_) {
      return [
        {
          'question': 'What is the primary focus of "$title"?',
          'options': [
            'Core concepts of $subject',
            'Historical events',
            'Mathematical formulas',
            'Programming languages'
          ],
          'correct': 0
        },
        {
          'question': 'Which skill does studying $subject develop?',
          'options': [
            'Memorisation only',
            'Critical thinking and analysis',
            'Physical coordination',
            'Language translation'
          ],
          'correct': 1
        },
        {
          'question': 'What is the best approach to understanding $subject?',
          'options': [
            'Skip the theory',
            'Read once quickly',
            'Study concepts with examples',
            'Focus only on definitions'
          ],
          'correct': 2
        },
        {
          'question': 'How is $subject applied in practice?',
          'options': [
            'It has no real-world use',
            'Only in research labs',
            'Through problem-solving and case studies',
            'Only in exams'
          ],
          'correct': 2
        },
        {
          'question': 'What should you do when reviewing "$title"?',
          'options': [
            'Ignore key terms',
            'Take structured notes and test yourself',
            'Read passively',
            'Skip difficult sections'
          ],
          'correct': 1
        },
      ].take(count).toList();
    }
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
  }) async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return;

    final done = checklistDone ?? 0;
    final total = checklistTotal ?? 0;
    final ratio = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.6;
    final focusScore =
        (62 + (ratio * 24).round() + (min(cycles, 4) * 3)).clamp(55, 99);
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
      'focusScore': focusScore,
      'completed': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update analytics (non-blocking)
    _updateAnalytics(db, userId, addStudyMinutes: focusMinutes, addSessions: 1);
  }
}
