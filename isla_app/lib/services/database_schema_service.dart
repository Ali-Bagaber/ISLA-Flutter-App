import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_service.dart';

/// One-time schema bootstrap/migration to enrich Firestore data model.
class DatabaseSchemaService {
  static const int _targetSchemaVersion = 2;

  static FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  static String? get _userId => AuthService.currentUser?.uid;

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _toText(dynamic value, {String fallback = ''}) {
    final text = (value ?? fallback).toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static Timestamp? _toTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return null;
  }

  static int _computeFocusScore({
    required int checklistDone,
    required int checklistTotal,
    required int cycles,
    required int focusMinutes,
  }) {
    final ratio = checklistTotal > 0
        ? (checklistDone / checklistTotal).clamp(0.0, 1.0)
        : 0.6;

    final score = 62 +
        (ratio * 24).round() +
        (min(cycles, 4) * 3) +
        (focusMinutes >= 120
            ? 4
            : focusMinutes >= 60
                ? 2
                : 0);

    return score.clamp(55, 99).toInt();
  }

  static int _parseSizeBytes(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final text = _toText(raw);
    if (text.isEmpty) return 0;

    final match =
        RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(B|KB|MB|GB)', caseSensitive: false)
            .firstMatch(text);
    if (match == null) {
      return int.tryParse(text) ?? 0;
    }

    final value = double.tryParse(match.group(1) ?? '') ?? 0;
    final unit = (match.group(2) ?? 'B').toUpperCase();
    final multiplier = switch (unit) {
      'GB' => 1024 * 1024 * 1024,
      'MB' => 1024 * 1024,
      'KB' => 1024,
      _ => 1,
    };
    return (value * multiplier).round();
  }

  static Future<bool> _hasRequiredSeedData(
    FirebaseFirestore db,
    String userId,
  ) async {
    final usersSnap = await db.collection('users').doc(userId).get();
    final goalSnap =
        await db.collection('study_goals').doc('${userId}_default_goal').get();
    final templateSnap = await db
        .collection('checklist_templates')
        .doc('${userId}_default')
        .get();

    return usersSnap.exists && goalSnap.exists && templateSnap.exists;
  }

  static Future<void> ensureEnhancedSchema({bool force = false}) async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return;

    final settingsRef = db.collection('user_settings').doc(userId);
    final settingsSnap = await settingsRef.get();
    final currentSchemaVersion =
        _toInt(settingsSnap.data()?['schemaVersion'], fallback: 0);

    if (!force && currentSchemaVersion >= _targetSchemaVersion) {
      final hasSeedData = await _hasRequiredSeedData(db, userId);
      if (hasSeedData) {
        return;
      }
    }

    await _seedCoreDocuments(db, userId);
    await _migrateTasks(db, userId);
    await _migrateDocuments(db, userId);
    await _migrateSessions(db, userId);
    await _migrateStudyMaterials(db, userId);
    await _migrateQuizzes(db, userId);

    await settingsRef.set(
      {
        'schemaVersion': _targetSchemaVersion,
        'migrationState': 'completed',
        'lastMigrationAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> _seedCoreDocuments(
    FirebaseFirestore db,
    String userId,
  ) async {
    final now = FieldValue.serverTimestamp();
    final email = AuthService.currentUser?.email ?? '';

    final profileData =
        (await db.collection('profiles').doc(userId).get()).data() ?? {};
    final usersRef = db.collection('users').doc(userId);
    final usersSnap = await usersRef.get();

    final batch = db.batch();

    final userPayload = <String, dynamic>{
      'userId': userId,
      'email': email,
      'name': _toText(profileData['name']),
      'studentId': _toText(profileData['studentId']),
      'faculty': _toText(profileData['faculty']),
      'program': _toText(profileData['program']),
      'year': _toInt(profileData['year']),
      'semester': _toInt(profileData['semester']),
      'accountStatus': 'active',
      'updatedAt': now,
      'lastLoginAt': now,
    };

    if (!usersSnap.exists) {
      userPayload['createdAt'] = now;
    }
    batch.set(usersRef, userPayload, SetOptions(merge: true));

    batch.set(
      db.collection('user_settings').doc(userId),
      {
        'settingId': userId,
        'userId': userId,
        'themeMode': 'system',
        'language': 'en',
        'reminderEnabled': true,
        'dailyGoalMinutes': 120,
        'weekStartDay': 1,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    final today = DateTime.now();
    final startDay = DateTime(today.year, today.month, today.day);
    final endDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final analyticsId = '${userId}_${today.toIso8601String().split('T').first}';

    batch.set(
      db.collection('analytics').doc(analyticsId),
      {
        'analyticsId': analyticsId,
        'userId': userId,
        'periodType': 'daily',
        'periodStart': Timestamp.fromDate(startDay),
        'periodEnd': Timestamp.fromDate(endDay),
        'totalStudyTime': 0,
        'sessionsCount': 0,
        'documentsCount': 0,
        'completedTasksCount': 0,
        'completionRate': 0.0,
        'averageFocusScore': 0.0,
        'strongestSubject': '',
        'weakestSubject': '',
        'currentGPA': 0.0,
        'currentCGPA': 0.0,
        'generatedAt': now,
      },
      SetOptions(merge: true),
    );

    batch.set(
      db.collection('study_goals').doc('${userId}_default_goal'),
      {
        'goalId': '${userId}_default_goal',
        'userId': userId,
        'title': 'Daily Focus Goal',
        'description': 'Study at least 120 minutes every day.',
        'targetType': 'minutes',
        'targetValue': 120,
        'progressValue': 0,
        'status': 'active',
        'startDate': Timestamp.fromDate(startDay),
        'endDate': Timestamp.fromDate(startDay.add(const Duration(days: 30))),
        'createdAt': now,
      },
      SetOptions(merge: true),
    );

    batch.set(
      db.collection('checklist_templates').doc('${userId}_default'),
      {
        'templateId': '${userId}_default',
        'userId': userId,
        'subject': 'General',
        'title': 'Default Focus Checklist',
        'isDefault': true,
        'createdAt': now,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    batch.set(
      db.collection('notifications').doc('${userId}_welcome'),
      {
        'notificationId': '${userId}_welcome',
        'userId': userId,
        'channel': 'inApp',
        'title': 'Schema Updated',
        'body': 'Enhanced database schema has been initialized.',
        'type': 'milestone',
        'relatedEntityType': 'system',
        'relatedEntityId': 'schema_v$_targetSchemaVersion',
        'isRead': false,
        'sentAt': now,
      },
      SetOptions(merge: true),
    );

    batch.set(
      db.collection('gpa_records').doc(userId),
      {
        'userId': userId,
        'gpa': 0.0,
        'totalCredits': 0,
        'courseCount': 0,
        'courses': <Map<String, dynamic>>[],
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    batch.set(
      db
          .collection('activity_logs')
          .doc('${userId}_schema_v$_targetSchemaVersion'),
      {
        'logId': '${userId}_schema_v$_targetSchemaVersion',
        'userId': userId,
        'action': 'schema_migration',
        'entityType': 'system',
        'entityId': 'v$_targetSchemaVersion',
        'metadata': {
          'schemaVersion': _targetSchemaVersion,
          'source': 'app_bootstrap',
        },
        'createdAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  static Future<void> _migrateTasks(FirebaseFirestore db, String userId) async {
    final snap =
        await db.collection('tasks').where('userId', isEqualTo: userId).get();
    if (snap.docs.isEmpty) return;

    var batch = db.batch();
    var ops = 0;

    Future<void> queueUpdate(
      DocumentReference ref,
      Map<String, dynamic> data,
    ) async {
      batch.set(ref, data, SetOptions(merge: true));
      ops += 1;
      if (ops >= 400) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final type = _toText(data['type'],
          fallback: _toText(data['taskType'], fallback: 'Task'));
      final completed = data['completed'] == true;

      final updates = <String, dynamic>{};
      if (_toText(data['taskId']).isEmpty) updates['taskId'] = doc.id;
      if (_toText(data['taskType']).isEmpty) updates['taskType'] = type;
      if (_toText(data['type']).isEmpty) updates['type'] = type;
      if (_toText(data['status']).isEmpty) {
        updates['status'] = completed ? 'completed' : 'notStarted';
      }
      if (data['estimatedMinutes'] == null) updates['estimatedMinutes'] = 60;
      if (data['updatedAt'] == null) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
      }
      if (data['createdAt'] == null) {
        updates['createdAt'] = FieldValue.serverTimestamp();
      }

      if (updates.isNotEmpty) {
        await queueUpdate(doc.reference, updates);
      }
    }

    if (ops > 0) {
      await batch.commit();
    }
  }

  static Future<void> _migrateDocuments(
    FirebaseFirestore db,
    String userId,
  ) async {
    final snap = await db
        .collection('documents')
        .where('userId', isEqualTo: userId)
        .get();
    if (snap.docs.isEmpty) return;

    var batch = db.batch();
    var ops = 0;

    Future<void> queueUpdate(
      DocumentReference ref,
      Map<String, dynamic> data,
    ) async {
      batch.set(ref, data, SetOptions(merge: true));
      ops += 1;
      if (ops >= 400) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final fileType = _toText(data['fileType'],
          fallback: _toText(data['type'], fallback: 'PDF'));
      final createdAt = _toTimestamp(data['createdAt']);
      final uploadDate = _toTimestamp(data['uploadDate']) ?? createdAt;

      final updates = <String, dynamic>{};
      if (_toText(data['documentId']).isEmpty) updates['documentId'] = doc.id;
      if (_toText(data['type']).isEmpty) updates['type'] = fileType;
      if (_toText(data['fileType']).isEmpty) updates['fileType'] = fileType;
      if (data['fileSizeBytes'] == null) {
        updates['fileSizeBytes'] = _parseSizeBytes(data['size']);
      }
      if (uploadDate != null && data['uploadDate'] == null) {
        updates['uploadDate'] = uploadDate;
      }
      if (_toText(data['processingStatus']).isEmpty) {
        updates['processingStatus'] = 'ready';
      }
      if (data['isArchived'] == null) updates['isArchived'] = false;
      if (data['updatedAt'] == null) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
      }

      if (updates.isNotEmpty) {
        await queueUpdate(doc.reference, updates);
      }
    }

    if (ops > 0) {
      await batch.commit();
    }
  }

  static Future<void> _migrateSessions(
      FirebaseFirestore db, String userId) async {
    final snap = await db
        .collection('sessions')
        .where('userId', isEqualTo: userId)
        .get();
    if (snap.docs.isEmpty) return;

    var batch = db.batch();
    var ops = 0;

    Future<void> queueUpdate(
      DocumentReference ref,
      Map<String, dynamic> data,
    ) async {
      batch.set(ref, data, SetOptions(merge: true));
      ops += 1;
      if (ops >= 350) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final timestamp = _toTimestamp(data['timestamp']) ??
          _toTimestamp(data['date']) ??
          _toTimestamp(data['startTime']);

      final focusMinutes =
          _toInt(data['focusMinutes'], fallback: _toInt(data['duration']));
      final done = _toInt(data['checklistDone']);
      final total = _toInt(data['checklistTotal']);
      final cycles = _toInt(data['cycles']);
      final score = _computeFocusScore(
        checklistDone: done,
        checklistTotal: total,
        cycles: cycles,
        focusMinutes: focusMinutes,
      );
      final startTime = _toTimestamp(data['startTime']) ?? timestamp;
      final endTime = _toTimestamp(data['endTime']) ??
          (startTime == null
              ? null
              : Timestamp.fromDate(
                  startTime
                      .toDate()
                      .add(Duration(minutes: max(1, focusMinutes))),
                ));

      final sourceUpdates = <String, dynamic>{};
      if (_toText(data['sessionId']).isEmpty)
        sourceUpdates['sessionId'] = doc.id;
      if (timestamp != null && data['date'] == null)
        sourceUpdates['date'] = timestamp;
      if (data['duration'] == null) sourceUpdates['duration'] = focusMinutes;
      if (data['actualMinutes'] == null)
        sourceUpdates['actualMinutes'] = focusMinutes;
      if (data['plannedMinutes'] == null)
        sourceUpdates['plannedMinutes'] = focusMinutes;
      if (_toText(data['sessionMode']).isEmpty)
        sourceUpdates['sessionMode'] = 'focus';
      if (data['focusScore'] == null) sourceUpdates['focusScore'] = score;
      if (startTime != null && data['startTime'] == null) {
        sourceUpdates['startTime'] = startTime;
      }
      if (endTime != null && data['endTime'] == null) {
        sourceUpdates['endTime'] = endTime;
      }
      if (data['createdAt'] == null) {
        sourceUpdates['createdAt'] = timestamp ?? FieldValue.serverTimestamp();
      }

      if (sourceUpdates.isNotEmpty) {
        await queueUpdate(doc.reference, sourceUpdates);
      }

      final mirror = <String, dynamic>{
        'sessionId': doc.id,
        'userId': userId,
        'subject': _toText(data['subject'], fallback: 'Other Tasks'),
        'documentId': _toText(data['documentId']),
        'sessionMode': _toText(data['sessionMode'], fallback: 'focus'),
        'plannedMinutes':
            _toInt(data['plannedMinutes'], fallback: focusMinutes),
        'actualMinutes': _toInt(data['actualMinutes'], fallback: focusMinutes),
        'breakMinutes': _toInt(data['breakMinutes']),
        'interruptionsCount': _toInt(data['interruptionsCount']),
        'checklistDone': done,
        'checklistTotal': total,
        'focusScore': _toInt(data['focusScore'], fallback: score),
        'completed': data['completed'] == false ? false : true,
        'createdAt':
            data['createdAt'] ?? timestamp ?? FieldValue.serverTimestamp(),
      };
      if (startTime != null) mirror['startTime'] = startTime;
      if (endTime != null) mirror['endTime'] = endTime;

      await queueUpdate(db.collection('study_sessions').doc(doc.id), mirror);
    }

    if (ops > 0) {
      await batch.commit();
    }
  }

  static Future<void> _migrateStudyMaterials(
    FirebaseFirestore db,
    String userId,
  ) async {
    final snap = await db
        .collection('study_materials')
        .where('userId', isEqualTo: userId)
        .get();
    if (snap.docs.isEmpty) return;

    var batch = db.batch();
    var ops = 0;

    Future<void> queueUpdate(
      DocumentReference ref,
      Map<String, dynamic> data,
    ) async {
      batch.set(ref, data, SetOptions(merge: true));
      ops += 1;
      if (ops >= 350) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final generatedDate = _toTimestamp(data['generatedDate']) ??
          _toTimestamp(data['createdAt']) ??
          FieldValue.serverTimestamp();
      final type = _toText(data['type'], fallback: 'Summary');

      final sourceUpdates = <String, dynamic>{};
      if (_toText(data['studyAidId']).isEmpty)
        sourceUpdates['studyAidId'] = doc.id;
      if (data['generatedDate'] == null) {
        sourceUpdates['generatedDate'] = generatedDate;
      }
      if (_toText(data['generationModel']).isEmpty) {
        sourceUpdates['generationModel'] = 'gemini';
      }
      if (data['sourceVersion'] == null) sourceUpdates['sourceVersion'] = 1;
      if (_toText(data['difficultyLevel']).isEmpty) {
        sourceUpdates['difficultyLevel'] = 'medium';
      }
      if (data['qualityScore'] == null) sourceUpdates['qualityScore'] = 0.8;
      if (data['isFavorited'] == null) sourceUpdates['isFavorited'] = false;
      if (_toText(data['status']).isEmpty) sourceUpdates['status'] = 'active';

      if (sourceUpdates.isNotEmpty) {
        await queueUpdate(doc.reference, sourceUpdates);
      }

      await queueUpdate(
        db.collection('study_aids').doc(doc.id),
        {
          'studyAidId': doc.id,
          'documentId': _toText(data['documentId']),
          'userId': userId,
          'title': _toText(data['title']),
          'subject': _toText(data['subject']),
          'type': type,
          'content': data['content'] ?? '',
          'generatedDate': generatedDate,
          'generationModel':
              _toText(data['generationModel'], fallback: 'gemini'),
          'sourceVersion': _toInt(data['sourceVersion'], fallback: 1),
          'difficultyLevel':
              _toText(data['difficultyLevel'], fallback: 'medium'),
          'qualityScore': _toDouble(data['qualityScore'], fallback: 0.8),
          'isFavorited': data['isFavorited'] == true,
          'status': _toText(data['status'], fallback: 'active'),
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
        },
      );
    }

    if (ops > 0) {
      await batch.commit();
    }
  }

  static Future<void> _migrateQuizzes(
      FirebaseFirestore db, String userId) async {
    final snap =
        await db.collection('quizzes').where('userId', isEqualTo: userId).get();
    if (snap.docs.isEmpty) return;

    var batch = db.batch();
    var ops = 0;

    Future<void> queueUpdate(
      DocumentReference ref,
      Map<String, dynamic> data,
    ) async {
      batch.set(ref, data, SetOptions(merge: true));
      ops += 1;
      if (ops >= 350) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final total = max(
          1,
          _toInt(data['total'],
              fallback: _toInt(data['totalQuestions'], fallback: 1)));
      final rawScore = _toInt(data['score']);
      final correct = _toInt(
        data['correctAnswers'],
        fallback:
            rawScore > total ? ((rawScore / 100) * total).round() : rawScore,
      );
      final boundedCorrect = correct.clamp(0, total);
      final wrong = max(0, total - boundedCorrect);
      final percentage = ((boundedCorrect / total) * 100).round();
      final attemptDate = _toTimestamp(data['attemptDate']) ??
          _toTimestamp(data['timestamp']) ??
          FieldValue.serverTimestamp();

      final sourceUpdates = <String, dynamic>{
        'resultId': doc.id,
      };
      if (data['totalQuestions'] == null)
        sourceUpdates['totalQuestions'] = total;
      if (data['correctAnswers'] == null)
        sourceUpdates['correctAnswers'] = boundedCorrect;
      if (data['wrongAnswers'] == null) sourceUpdates['wrongAnswers'] = wrong;
      if (data['unansweredCount'] == null) sourceUpdates['unansweredCount'] = 0;
      if (data['scorePercentage'] == null)
        sourceUpdates['scorePercentage'] = percentage;
      if (data['attemptDate'] == null)
        sourceUpdates['attemptDate'] = attemptDate;
      if (data['timeSpentSeconds'] == null)
        sourceUpdates['timeSpentSeconds'] =
            _toInt(data['timeSpent'], fallback: total * 45);
      if (data['attemptNo'] == null) sourceUpdates['attemptNo'] = 1;

      await queueUpdate(doc.reference, sourceUpdates);

      await queueUpdate(
        db.collection('quiz_results').doc(doc.id),
        {
          'resultId': doc.id,
          'studyAidId': _toText(data['studyAidId']),
          'userId': userId,
          'score': percentage,
          'rawScore': boundedCorrect,
          'totalQuestions': total,
          'correctAnswers': boundedCorrect,
          'wrongAnswers': wrong,
          'unansweredCount': 0,
          'attemptDate': attemptDate,
          'timeSpentSeconds':
              _toInt(data['timeSpentSeconds'], fallback: total * 45),
          'attemptNo': _toInt(data['attemptNo'], fallback: 1),
          'feedbackSummary': _toText(data['feedbackSummary']),
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
        },
      );
    }

    if (ops > 0) {
      await batch.commit();
    }
  }
}
