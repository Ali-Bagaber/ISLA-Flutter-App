import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_service.dart';

/// Handles saving/loading multi-semester GPA records per user in Firestore.
/// Collection: gpa_records / {userId}
///
/// Document shape:
/// {
///   userId, cgpa, totalCredits, updatedAt,
///   semesters: [
///     { id, name, courses: [ {id, name, credits, grade}, ... ] }
///   ]
/// }
class GpaService {
  static FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  static String? get _userId => AuthService.currentUser?.uid;

  /// 4.0-scale grade points
  static const Map<String, double> gradePoints = {
    'A+': 4.00,
    'A': 4.00,
    'A-': 3.67,
    'B+': 3.33,
    'B': 3.00,
    'B-': 2.67,
    'C+': 2.33,
    'C': 2.00,
    'C-': 1.67,
    'D+': 1.33,
    'D': 1.00,
    'F': 0.00,
  };

  static const List<String> grades = [
    'A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'F'
  ];

  /// Compute GPA for a single semester (list of courses).
  static double computeGpa(List<Map<String, dynamic>> courses) {
    double pts = 0;
    int creds = 0;
    for (final c in courses) {
      final g = (c['grade'] ?? '').toString().trim().toUpperCase();
      final cr = (c['credits'] as num? ?? 0).toInt();
      final p = gradePoints[g];
      if (p != null && cr > 0) {
        pts += p * cr;
        creds += cr;
      }
    }
    return creds == 0 ? 0.0 : double.parse((pts / creds).toStringAsFixed(2));
  }

  /// Compute CGPA across all semesters (weighted by credits).
  static double computeCgpa(List<Map<String, dynamic>> semesters) {
    double pts = 0;
    int creds = 0;
    for (final sem in semesters) {
      final courses = (sem['courses'] as List? ?? []).cast<Map<String, dynamic>>();
      for (final c in courses) {
        final g = (c['grade'] ?? '').toString().trim().toUpperCase();
        final cr = (c['credits'] as num? ?? 0).toInt();
        final p = gradePoints[g];
        if (p != null && cr > 0) {
          pts += p * cr;
          creds += cr;
        }
      }
    }
    return creds == 0 ? 0.0 : double.parse((pts / creds).toStringAsFixed(2));
  }

  static int computeTotalCredits(List<Map<String, dynamic>> semesters) {
    int total = 0;
    for (final sem in semesters) {
      final courses = (sem['courses'] as List? ?? []).cast<Map<String, dynamic>>();
      for (final c in courses) {
        total += (c['credits'] as num? ?? 0).toInt();
      }
    }
    return total;
  }

  /// Stream the current user's GPA record (multi-semester). Emits null if not set.
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

  /// Save semester list + computed CGPA to Firestore.
  /// [semesters] must each contain `id`, `name`, and `courses` (each course
  /// with `id`, `name`, `credits`, `grade`).
  static Future<void> saveSemesters(
      List<Map<String, dynamic>> semesters) async {
    final db = _db;
    final userId = _userId;
    if (db == null || userId == null) return;

    final cgpa = computeCgpa(semesters);
    final totalCredits = computeTotalCredits(semesters);

    await db.collection('gpa_records').doc(userId).set({
      'userId': userId,
      'semesters': semesters
          .map((s) => {
                'id': s['id'],
                'name': s['name'],
                'courses': ((s['courses'] as List?) ?? [])
                    .cast<Map<String, dynamic>>()
                    .map((c) => {
                          'id': c['id'],
                          'name': (c['name'] ?? '').toString(),
                          'credits': (c['credits'] as num? ?? 3).toInt(),
                          'grade': (c['grade'] ?? 'B').toString(),
                        })
                    .toList(),
              })
          .toList(),
      'cgpa': cgpa,
      'totalCredits': totalCredits,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Mirror to analytics doc so the Analytics page can show current CGPA.
    await db.collection('analytics').doc(userId).set({
      'userId': userId,
      'currentCGPA': cgpa,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
