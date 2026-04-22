import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_service.dart';

/// Handles saving and loading GPA data per user in Firestore.
/// Collection: gpa_records / {userId}
class GpaService {
  static FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  static String? get _userId => AuthService.currentUser?.uid;

  /// Stream the current user's GPA record. Emits null when no data saved yet.
  static Stream<Map<String, dynamic>?> watchGpaRecord() {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return Stream.value(null);

    return db
        .collection('gpa_records')
        .doc(userId)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }

  /// Load the current user's GPA record once. Returns null if not set yet.
  static Future<Map<String, dynamic>?> loadGpaRecord() async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return null;

    final snap = await db.collection('gpa_records').doc(userId).get();
    return snap.exists ? snap.data() : null;
  }

  /// Save courses list + computed GPA to Firestore.
  static Future<void> saveGpaRecord({
    required List<Map<String, dynamic>> courses,
    required double gpa,
  }) async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return;

    final totalCredits =
        courses.fold<int>(0, (sum, c) => sum + (c['credit'] as int? ?? 0));

    await db.collection('gpa_records').doc(userId).set({
      'userId': userId,
      'gpa': double.parse(gpa.toStringAsFixed(2)),
      'totalCredits': totalCredits,
      'courseCount': courses.length,
      'courses': courses
          .map(
            (c) => {
              'name': (c['name'] ?? '').toString(),
              'credit': c['credit'] as int? ?? 3,
              'grade': (c['grade'] ?? 'B').toString(),
            },
          )
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Save each course to the courses collection
    final batch = db.batch();
    for (final c in courses) {
      final courseId =
          '${userId}_${(c['name'] ?? '').toString().replaceAll(' ', '_')}';
      batch.set(
          db.collection('courses').doc(courseId),
          {
            'courseId': courseId,
            'userId': userId,
            'name': (c['name'] ?? '').toString(),
            'credits': c['credit'] as int? ?? 3,
            'grade': (c['grade'] ?? 'B').toString(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();

    // Also update the analytics doc for this user — include userId so Firestore rules pass.
    await db.collection('analytics').doc(userId).set({
      'userId': userId,
      'currentGPA': double.parse(gpa.toStringAsFixed(2)),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
