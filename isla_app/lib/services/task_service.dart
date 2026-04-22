import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_service.dart';

class TaskService {
  static FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  static String? get _userId => AuthService.currentUser?.uid;

  static CollectionReference? get _col => _db?.collection('tasks');

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }

  /// Realtime stream of all tasks for current user
  static Stream<List<Map<String, dynamic>>> watchTasks() {
    final col = _col;
    final userId = _userId;
    if (col == null || userId == null) return Stream.value([]);
    return col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final items = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();

      items.sort((a, b) {
        final aDate = _toDateTime(a['dueDate']);
        final bDate = _toDateTime(b['dueDate']);
        return aDate.compareTo(bDate);
      });

      return items;
    });
  }

  /// Add a new task
  static Future<String> addTask({
    required String title,
    required String subject,
    required DateTime dueDate,
    required String type,
    required String priority,
    String description = '',
  }) async {
    final col = _col;
    final userId = _userId;
    if (col == null) {
      throw StateError('Firebase is not configured.');
    }
    if (userId == null) {
      throw StateError('You must sign in before adding tasks.');
    }
    final ref = col.doc();
    await ref.set({
      'taskId': ref.id,
      'title': title,
      'subject': subject,
      'dueDate': Timestamp.fromDate(dueDate),
      'type': type,
      'taskType': type,
      'priority': priority,
      'description': description,
      'status': 'notStarted',
      'estimatedMinutes': 60,
      'reminderAt': Timestamp.fromDate(
        dueDate.subtract(const Duration(hours: 12)),
      ),
      'completed': false,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Toggle task completed/incomplete
  static Future<void> toggleTask(String id, bool completed) async {
    if (_userId == null) return;
    await _col?.doc(id).update({
      'completed': completed,
      'status': completed ? 'completed' : 'inProgress',
      'completedAt': completed ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update an existing task
  static Future<void> updateTask(
    String id, {
    required String title,
    required String subject,
    required DateTime dueDate,
    required String type,
    required String priority,
    String description = '',
  }) async {
    if (_userId == null) return;
    await _col?.doc(id).update({
      'title': title,
      'subject': subject,
      'dueDate': Timestamp.fromDate(dueDate),
      'type': type,
      'taskType': type,
      'priority': priority,
      'description': description,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a task
  static Future<void> deleteTask(String id) async {
    if (_userId == null) return;
    await _col?.doc(id).delete();
  }
}
