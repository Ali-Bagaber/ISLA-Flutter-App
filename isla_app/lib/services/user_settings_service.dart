import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Per-user app settings. Stored at user_settings/{userId}.
///
/// Three groups:
///   • notifications — task / pomodoro / streak toggles + streak hour
///   • focus         — default work / break / cycles for the timer
///   • studyPlan     — onboarding answers + which days the user studies
class UserSettingsService {
  static FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  static String? get _userId => AuthService.currentUser?.uid;

  /// Defaults used when nothing has been saved yet.
  /// `studyDays` uses 1=Monday … 7=Sunday (matches DateTime.weekday).
  static const Map<String, dynamic> defaults = {
    'notifications': {
      'taskReminders': true,
      'pomodoroAlerts': true,
      'streakReminder': true,
      'streakHour': 20, // 8 PM
    },
    'focus': {
      'workMinutes': 25,
      'breakMinutes': 5,
      'cycles': 4,
    },
    'studyPlan': {
      'onboardingComplete': false,
      'goal': 'aceExams',
      'focusSubject': 'Operating Systems',
      'deadlineMillis': null,
      'sessionMinutes': 25,
      'studyDays': [1, 2, 3, 4, 5, 6, 7], // every day by default
    },
  };

  /// Realtime stream of the current user's settings doc, with defaults merged.
  static Stream<Map<String, dynamic>> watchSettings() {
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) return Stream.value(_withDefaults(null));
    return db
        .collection('user_settings')
        .doc(uid)
        .snapshots()
        .map((snap) => _withDefaults(snap.data()));
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) return _withDefaults(null);
    final snap = await db.collection('user_settings').doc(uid).get();
    return _withDefaults(snap.exists ? snap.data() : null);
  }

  static Future<void> saveNotifications({
    bool? taskReminders,
    bool? pomodoroAlerts,
    bool? streakReminder,
    int? streakHour,
  }) async {
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) return;
    await db.collection('user_settings').doc(uid).set({
      'userId': uid,
      'notifications': {
        if (taskReminders != null) 'taskReminders': taskReminders,
        if (pomodoroAlerts != null) 'pomodoroAlerts': pomodoroAlerts,
        if (streakReminder != null) 'streakReminder': streakReminder,
        if (streakHour != null) 'streakHour': streakHour,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveFocus({
    int? workMinutes,
    int? breakMinutes,
    int? cycles,
  }) async {
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) return;
    await db.collection('user_settings').doc(uid).set({
      'userId': uid,
      'focus': {
        if (workMinutes != null) 'workMinutes': workMinutes,
        if (breakMinutes != null) 'breakMinutes': breakMinutes,
        if (cycles != null) 'cycles': cycles,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Persist the onboarding answers / editable study plan.
  /// Passing [onboardingComplete: true] marks the user as past first-run so
  /// AuthGate sends them straight to MainNavigation next time.
  static Future<void> saveStudyPlan({
    bool? onboardingComplete,
    String? goal,
    String? focusSubject,
    DateTime? deadline,
    int? sessionMinutes,
    List<int>? studyDays,
  }) async {
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) return;
    // On web, force the network connection before writing to avoid the
    // Firestore internal-assertion errors that occur on a fresh session.
    if (kIsWeb) await db.enableNetwork();
    await db.collection('user_settings').doc(uid).set({
      'userId': uid,
      'studyPlan': {
        if (onboardingComplete != null)
          'onboardingComplete': onboardingComplete,
        if (goal != null) 'goal': goal,
        if (focusSubject != null) 'focusSubject': focusSubject,
        if (deadline != null) 'deadlineMillis': deadline.millisecondsSinceEpoch,
        if (sessionMinutes != null) 'sessionMinutes': sessionMinutes,
        if (studyDays != null) 'studyDays': studyDays,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static const List<String> defaultSubjects = [
    'Mathematics', 'Physics', 'Chemistry', 'Biology',
    'Computer Science', 'Data Structures', 'Operating Systems',
    'Database Systems', 'Software Engineering', 'English',
    'Economics', 'Other',
  ];

  static Stream<List<String>> watchSubjects() {
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) return Stream.value(defaultSubjects);
    return db.collection('user_settings').doc(uid).snapshots().map((snap) {
      final raw = snap.data()?['subjects'];
      if (raw is List && raw.isNotEmpty) return List<String>.from(raw);
      return defaultSubjects;
    });
  }

  static Future<List<String>> loadSubjects() async {
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) return defaultSubjects;
    final snap = await db.collection('user_settings').doc(uid).get();
    final raw = snap.data()?['subjects'];
    if (raw is List && raw.isNotEmpty) return List<String>.from(raw);
    return defaultSubjects;
  }

  static Future<void> saveSubjects(List<String> subjects) async {
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) return;
    await db.collection('user_settings').doc(uid).set({
      'userId': uid,
      'subjects': subjects,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Map<String, dynamic> _withDefaults(Map<String, dynamic>? data) {
    final n = Map<String, dynamic>.from(defaults['notifications'] as Map);
    final f = Map<String, dynamic>.from(defaults['focus'] as Map);
    final s = Map<String, dynamic>.from(defaults['studyPlan'] as Map);
    if (data != null) {
      final dn = data['notifications'];
      if (dn is Map) n.addAll(dn.cast<String, dynamic>());
      final df = data['focus'];
      if (df is Map) f.addAll(df.cast<String, dynamic>());
      final ds = data['studyPlan'];
      if (ds is Map) s.addAll(ds.cast<String, dynamic>());
    }
    return {'notifications': n, 'focus': f, 'studyPlan': s};
  }
}
