import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '_browser_notifier_stub.dart'
    if (dart.library.html) '_browser_notifier_web.dart';

/// Local notifications service for ISLA.
///
/// Channels:
///   • `tasks`    — scheduled reminders for task due dates
///   • `pomodoro` — immediate notification when a focus session ends
///   • `streak`   — daily reminder to keep your study streak
///
/// Notification IDs:
///   • Task reminder       : hash of taskId
///   • Pomodoro end        : 9001
///   • Daily streak nudge  : 9002
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int pomodoroEndId = 9001;
  static const int dailyStreakId = 9002;

  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;

    // On web, ask the browser for permission to use the Notification API.
    // This is the only thing that actually pops a system notification on web.
    if (kIsWeb) {
      if (BrowserNotifier.isSupported &&
          BrowserNotifier.permission == 'default') {
        await BrowserNotifier.requestPermission();
      }
      _initialised = true;
      return;
    }

    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(settings);

    // Android 13+ runtime permission
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();
    } catch (_) {
      // Older Android versions don't have this — ignore.
    }

    _initialised = true;
  }

  // ── Task reminders ─────────────────────────────────────────────────────────

  /// Schedule a reminder for an upcoming task. Lead time, message tone and
  /// notification importance all scale with [priority]:
  ///
  ///   • High   — 24h before, "Important task reminder…", high importance
  ///   • Medium — 12h before, "Task reminder…",         normal importance
  ///   • Low    —  6h before, "Heads up…",              low importance
  ///
  /// If the task is already overdue at schedule time, we instead fire an
  /// immediate "Overdue task" notification so the user is aware.
  /// Passing [hoursBefore] overrides the default for the chosen priority.
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String subject,
    required DateTime dueDate,
    String priority = 'Medium',
    int? hoursBefore,
  }) async {
    if (kIsWeb || !_initialised) return;

    final id = _idFor(taskId);
    await _plugin.cancel(id); // replace any older schedule

    final p = priority.toLowerCase();
    final defaultLead = p == 'high'
        ? 24
        : p == 'low'
            ? 6
            : 12;
    final lead = hoursBefore ?? defaultLead;

    final now = DateTime.now();
    final remindAt = dueDate.subtract(Duration(hours: lead));
    final isOverdue = dueDate.isBefore(now);

    String notifTitle;
    String notifBody;
    Importance importance;
    Priority androidPriority;

    if (isOverdue) {
      notifTitle = 'Overdue task: $title';
      notifBody =
          'This task has passed its deadline. Please review it in ISLA.';
      importance = Importance.max;
      androidPriority = Priority.max;
    } else if (p == 'high') {
      notifTitle = 'Important task reminder: $title';
      notifBody = subject.isEmpty
          ? 'Your high-priority task is due soon.'
          : '$subject · high-priority task due soon.';
      importance = Importance.max;
      androidPriority = Priority.max;
    } else if (p == 'low') {
      notifTitle = 'Heads up: $title';
      notifBody = subject.isEmpty
          ? 'A low-priority task is coming up.'
          : '$subject · low-priority task coming up.';
      importance = Importance.low;
      androidPriority = Priority.low;
    } else {
      notifTitle = 'Task reminder: $title';
      notifBody = subject.isEmpty
          ? 'This task is due soon — open ISLA to start.'
          : '$subject · due soon, open ISLA to start.';
      importance = Importance.defaultImportance;
      androidPriority = Priority.defaultPriority;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'tasks',
        'Task reminders',
        channelDescription: 'Notifies you before a task is due.',
        importance: importance,
        priority: androidPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    // Overdue → fire immediately rather than scheduling in the past.
    if (isOverdue || remindAt.isBefore(now)) {
      await _plugin.show(id, notifTitle, notifBody, details,
          payload: 'task:$taskId');
      return;
    }

    final scheduled = tz.TZDateTime.from(remindAt, tz.local);
    await _plugin.zonedSchedule(
      id,
      notifTitle,
      notifBody,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task:$taskId',
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (kIsWeb || !_initialised) return;
    await _plugin.cancel(_idFor(taskId));
  }

  // ── Pomodoro end ───────────────────────────────────────────────────────────

  Future<void> showPomodoroComplete({String? subject}) async {
    if (!_initialised) return;

    // Web: use the browser Notification API directly.
    if (kIsWeb) {
      _webNotify(
        'Focus session complete',
        subject == null || subject.isEmpty
            ? 'Take a short break, then start the next cycle.'
            : '$subject done — take a short break.',
      );
      return;
    }

    await _plugin.show(
      pomodoroEndId,
      'Focus session complete',
      subject == null || subject.isEmpty
          ? 'Take a short break, then start the next cycle.'
          : '$subject done — take a short break.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pomodoro',
          'Pomodoro alerts',
          channelDescription: 'Notifies you when a focus session ends.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ── Daily streak reminder ──────────────────────────────────────────────────

  /// Schedule a recurring daily notification at 20:00 reminding the user
  /// to study so they don't break their streak.
  Future<void> scheduleDailyStreakReminder({int hour = 20, int minute = 0}) async {
    if (kIsWeb || !_initialised) return;

    final now = tz.TZDateTime.now(tz.local);
    var firstFire = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (!firstFire.isAfter(now)) {
      firstFire = firstFire.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      dailyStreakId,
      'Keep your streak alive',
      'Run one focus session today to hold your study streak.',
      firstFire,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak',
          'Streak reminder',
          channelDescription: 'Daily reminder to keep your study streak.',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily at HH:MM
    );
  }

  /// One-shot check called from MainNavigation when the app is opened.
  ///
  /// If yesterday matched the user's study-day plan but no focus session was
  /// recorded for that day, fire an immediate "you missed yesterday" reminder.
  /// Silently no-ops if Firestore / auth aren't ready, on web (browser
  /// notifications are best-effort), or if the user is on track.
  ///
  /// [studyDays] uses 1=Mon … 7=Sun (matches DateTime.weekday).
  /// [yesterdayHadSession] should be true if the user has at least one
  /// completed session timestamped on yesterday's date.
  Future<void> checkMissedStudyDay({
    required List<int> studyDays,
    required bool yesterdayHadSession,
  }) async {
    if (!_initialised || studyDays.isEmpty) return;

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final wasPlanned = studyDays.contains(yesterday.weekday);
    if (!wasPlanned || yesterdayHadSession) return;

    // Web: use the browser Notification API.
    if (kIsWeb) {
      _webNotify(
        'You missed yesterday\'s study session',
        'No focus session was logged for yesterday. Don\'t lose momentum — start a quick one today.',
      );
      return;
    }

    await _plugin.show(
      9003,
      'You missed yesterday\'s study session',
      'No focus session was logged for yesterday. Don\'t lose momentum — start a quick one today.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak',
          'Streak reminder',
          channelDescription:
              'Daily reminder to keep your study streak.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelDailyStreakReminder() async {
    if (kIsWeb || !_initialised) return;
    await _plugin.cancel(dailyStreakId);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Stable positive 31-bit int derived from a string id (notification id limit).
  static int _idFor(String key) =>
      (key.hashCode & 0x7FFFFFFF).clamp(1, 0x7FFFFFFF);

  /// Fire a browser notification (web only). Silently ignored if the user
  /// hasn't granted permission.
  void _webNotify(String title, String body) {
    BrowserNotifier.show(title, body);
  }
}
