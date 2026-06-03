import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'user_settings_service.dart';

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
    int estimatedMinutes = 45,
    bool setReminder = true,
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
      'estimatedMinutes': estimatedMinutes,
      'reminderAt': Timestamp.fromDate(
        dueDate.subtract(const Duration(hours: 6)),
      ),
      'setReminder': setReminder,
      'completed': false,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Advance reminder 6h before due time (only if enabled).
    if (setReminder) {
      await NotificationService.instance.scheduleTaskReminder(
        taskId: ref.id,
        title: title,
        subject: subject,
        dueDate: dueDate,
        priority: priority,
        hoursBefore: 6,
      );
    }
    // At-due-time alarm — sound/vibration intensity scales with priority.
    await NotificationService.instance.scheduleDueTimeAlarm(
      taskId: ref.id,
      title: title,
      subject: subject,
      dueDate: dueDate,
      priority: priority,
    );

    return ref.id;
  }

  /// Toggle task completed/incomplete
  static Future<void> toggleTask(String id, bool completed) async {
    if (_userId == null) return;
    // Read whether XP is currently held for this task so we can mirror the
    // completion state: award once on complete, take it back on un-complete.
    final snap = await _col?.doc(id).get();
    final data = snap?.data() as Map<String, dynamic>?;
    final wasAwarded = data?['xpAwarded'] as bool? ?? false;

    await _col?.doc(id).update({
      'completed': completed,
      'status': completed ? 'completed' : 'inProgress',
      'completedAt': completed ? FieldValue.serverTimestamp() : null,
      'xpAwarded': completed, // XP held == task currently complete
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (completed) {
      await NotificationService.instance.cancelTaskReminder(id);
      await NotificationService.instance.cancelDueTimeAlarm(id);
      if (!wasAwarded) UserSettingsService.addXp(10).ignore(); // +10 once
    } else {
      // Un-completed → it isn't finished, so take the reward back.
      if (wasAwarded) UserSettingsService.addXp(-10).ignore(); // −10
    }
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
    int? estimatedMinutes,
    bool setReminder = true,
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
      if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
      'setReminder': setReminder,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Re-schedule advance reminder 6h before (only if enabled).
    if (setReminder) {
      await NotificationService.instance.scheduleTaskReminder(
        taskId: id,
        title: title,
        subject: subject,
        dueDate: dueDate,
        priority: priority,
        hoursBefore: 6,
      );
    } else {
      await NotificationService.instance.cancelTaskReminder(id);
    }
    // Re-schedule at-due-time alarm.
    await NotificationService.instance.scheduleDueTimeAlarm(
      taskId: id,
      title: title,
      subject: subject,
      dueDate: dueDate,
      priority: priority,
    );
  }

  /// Delete a task
  static Future<void> deleteTask(String id) async {
    if (_userId == null) return;
    await NotificationService.instance.cancelTaskReminder(id);
    await NotificationService.instance.cancelDueTimeAlarm(id);
    await _col?.doc(id).delete();
  }
}
