import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
    await _configureLocalTimeZone();

    // Must be a monochrome drawable — Android only uses the icon's alpha for
    // the status bar, so the full-colour launcher icon shows as a white blob.
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_isla');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(settings);

    _initialised = true;

    // Android 13+ runtime permissions.
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        // POST_NOTIFICATIONS — without this, nothing is ever shown.
        final granted = await androidImpl.requestNotificationsPermission();
        _notificationsEnabled =
            granted ?? await androidImpl.areNotificationsEnabled() ?? false;

        // Exact alarms: USE_EXACT_ALARM auto-grants this on most devices, so we
        // CHECK rather than blindly request (requesting can bounce the user to
        // a settings screen). Only request if the check says it's off.
        _exactAlarmsAllowed =
            await androidImpl.canScheduleExactNotifications() ?? false;
        if (!_exactAlarmsAllowed) {
          await androidImpl.requestExactAlarmsPermission();
          _exactAlarmsAllowed =
              await androidImpl.canScheduleExactNotifications() ?? false;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('NOTIF init ── permission setup failed: $e');
    }

    if (kDebugMode) {
      debugPrint('NOTIF init ── tz=${tz.local.name} '
          'notificationsEnabled=$_notificationsEnabled '
          'exactAlarms=$_exactAlarmsAllowed');
    }
  }

  /// Ask the platform for the device's real IANA timezone name (e.g.
  /// "Asia/Kuala_Lumpur") and set [tz.local] accordingly.
  ///
  /// The old offset-match fallback is kept as a last resort, but it is
  /// unreliable: multiple zones share the same UTC offset, so the first match
  /// in iteration order (often Africa/Abidjan for UTC+0) was being chosen
  /// instead of the actual device zone.
  Future<void> _configureLocalTimeZone() async {
    // Primary: ask the OS for the canonical IANA name.
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      final loc = tz.getLocation(tzName);
      tz.setLocalLocation(loc);
      if (kDebugMode) {
        debugPrint('NOTIF tz ── device reported: $tzName → tz.local=${tz.local.name}');
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NOTIF tz ── FlutterTimezone failed ($e); trying offset fallback');
      }
    }

    // Fallback: match by current UTC offset (less reliable but better than UTC).
    try {
      final offset = DateTime.now().timeZoneOffset;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.now(loc).timeZoneOffset == offset) {
          tz.setLocalLocation(loc);
          if (kDebugMode) {
            debugPrint('NOTIF tz ── offset fallback: ${loc.name} (offset=$offset)');
          }
          return;
        }
      }
    } catch (_) {}

    if (kDebugMode) {
      debugPrint('NOTIF tz ── all methods failed; tz.local remains ${tz.local.name}');
    }
  }

  /// Whether the user has granted the "Alarms & reminders" (exact alarm)
  /// permission. When false we fall back to inexact scheduling so the
  /// notification still fires (just possibly a few minutes late).
  bool _exactAlarmsAllowed = false;

  /// Whether POST_NOTIFICATIONS is granted (Android 13+). When false, NOTHING
  /// is shown — scheduled or immediate — which is the usual cause of a
  /// "notification never arrived" report.
  bool _notificationsEnabled = false;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get exactAlarmsAllowed => _exactAlarmsAllowed;
  bool get isInitialised => _initialised;
  String get timeZoneName => kIsWeb ? 'web' : tz.local.name;

  /// Re-reads the live permission state from the OS (call before scheduling or
  /// from a settings screen). Updates the cached getters and returns them.
  Future<({bool notifications, bool exactAlarms})> refreshPermissions() async {
    if (kIsWeb || !_initialised) {
      return (notifications: false, exactAlarms: false);
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      _notificationsEnabled = await android.areNotificationsEnabled() ?? false;
      _exactAlarmsAllowed =
          await android.canScheduleExactNotifications() ?? false;
    }
    return (notifications: _notificationsEnabled, exactAlarms: _exactAlarmsAllowed);
  }

  /// Requests the notification permission (Android 13+). Returns true if granted.
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb || !_initialised) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ??
        await android?.areNotificationsEnabled() ??
        false;
    _notificationsEnabled = granted;
    return granted;
  }

  // Always TRY exact (USE_EXACT_ALARM makes it auto-granted on reminder apps);
  // _safeZonedSchedule falls back to inexact only if the OS rejects it.
  AndroidScheduleMode get _scheduleMode =>
      AndroidScheduleMode.exactAllowWhileIdle;

  /// Schedule [zonedSchedule] with exact mode, falling back to inexact if the
  /// OS rejects the exact alarm (permission revoked at runtime).
  /// Returns true if a zonedSchedule call completed (exact or inexact fallback).
  Future<bool> _safeZonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime when,
    NotificationDetails details, {
    required String payload,
    DateTimeComponents? matchComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id, title, body, when, details,
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents: matchComponents,
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NOTIF ── exact schedule rejected ($e); retrying inexact');
      }
      // Exact alarm denied at runtime — retry with inexact so it still fires.
      try {
        await _plugin.zonedSchedule(
          id, title, body, when, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
          matchDateTimeComponents: matchComponents,
        );
        return true;
      } catch (e2) {
        if (kDebugMode) debugPrint('NOTIF ── inexact schedule also failed: $e2');
        return false;
      }
    }
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
    if (!_initialised) return;

    // Web: fire an immediate browser notification (no scheduling API available).
    if (kIsWeb) {
      final p = priority.toLowerCase();
      final notifTitle = p == 'high'
          ? 'Important task reminder: $title'
          : p == 'low'
              ? 'Heads up: $title'
              : 'Task reminder: $title';
      final notifBody = subject.isEmpty
          ? 'Task due soon — open ISLA to check your schedule.'
          : '$subject · due soon, open ISLA to start.';
      _webNotify(notifTitle, notifBody);
      return;
    }

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

    if (isOverdue) {
      notifTitle = 'Overdue task: $title';
      notifBody = 'This task has passed its deadline. Please review it in ISLA.';
    } else if (p == 'high') {
      notifTitle = 'Important task reminder: $title';
      notifBody = subject.isEmpty
          ? 'Your high-priority task is due soon.'
          : '$subject · high-priority task due soon.';
    } else if (p == 'low') {
      notifTitle = 'Heads up: $title';
      notifBody = subject.isEmpty
          ? 'A low-priority task is coming up.'
          : '$subject · low-priority task coming up.';
    } else {
      notifTitle = 'Task reminder: $title';
      notifBody = subject.isEmpty
          ? 'This task is due soon — open ISLA to start.'
          : '$subject · due soon, open ISLA to start.';
    }

    // Each priority gets its own channel with a distinct sound.
    final NotificationDetails details;
    if (isOverdue || p == 'high') {
      details = NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks_reminder_high',
          'Important task reminders',
          channelDescription: 'Alarm-level reminder for high-priority tasks.',
          importance: Importance.max,
          priority: Priority.max,
          sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentSound: true, presentBanner: true, presentAlert: true,
        ),
      );
    } else if (p == 'low') {
      details = const NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks_reminder_low',
          'Low-priority task reminders',
          channelDescription: 'Silent nudge for low-priority tasks.',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: false),
      );
    } else {
      details = const NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks_reminder_medium',
          'Task reminders',
          channelDescription: 'Default notification for upcoming tasks.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      );
    }

    // Overdue → fire immediately rather than scheduling in the past.
    if (isOverdue || remindAt.isBefore(now)) {
      await _plugin.show(id, notifTitle, notifBody, details,
          payload: 'task:$taskId');
      return;
    }

    final scheduled = tz.TZDateTime.from(remindAt, tz.local);
    await _safeZonedSchedule(
      id,
      notifTitle,
      notifBody,
      scheduled,
      details,
      payload: 'task:$taskId',
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (kIsWeb || !_initialised) return; // nothing to cancel on web
    await _plugin.cancel(_idFor(taskId));
  }

  /// Schedule an alarm that fires at the exact due time.
  /// Sound and vibration intensity scale with [priority]:
  ///   High   → max importance, full vibration (loudest system sound)
  ///   Medium → high importance, normal vibration
  ///   Low    → min importance, no sound / no vibration (silent badge)
  Future<void> scheduleDueTimeAlarm({
    required String taskId,
    required String title,
    required String subject,
    required DateTime dueDate,
    String priority = 'Medium',
  }) async {
    if (!_initialised) return;

    if (kIsWeb) {
      // Web has no scheduler — fire immediately only if already due.
      if (!dueDate.isAfter(DateTime.now())) {
        final p = priority.toLowerCase();
        final notifTitle = p == 'high'
            ? 'Task due now (High priority): $title'
            : 'Task due now: $title';
        final notifBody = subject.isEmpty
            ? 'This task is now due — open ISLA to complete it.'
            : '$subject — task now due.';
        _webNotify(notifTitle, notifBody);
      }
      return;
    }

    final id = _dueIdFor(taskId);
    await _plugin.cancel(id); // replace existing alarm

    final notifTitle = '⚠️ Overdue: $title';
    final notifBody = subject.isEmpty
        ? 'This task is now overdue — open ISLA to mark it complete.'
        : '$subject · this task is now overdue.';

    final details = _overdueDetails(priority);

    // Make sure we have a fresh read of permissions before deciding/logging.
    await refreshPermissions();

    final now = DateTime.now();
    final secondsUntil = dueDate.difference(now).inSeconds;

    // 1) Already past → don't schedule in the past; the due moment has gone.
    if (secondsUntil <= 0) {
      _logSchedule(
        kind: 'DUE-ALARM',
        taskId: taskId,
        title: title,
        due: dueDate,
        id: id,
        zonedScheduleCalled: false,
        note: 'due time is in the PAST → not scheduled (fired immediate notice)',
      );
      await _plugin.show(id, notifTitle, notifBody, details,
          payload: 'task:$taskId');
      return;
    }

    // 2) Too close (<30s) → exact alarms this short are unreliable on Android,
    //    so just fire immediately.
    if (secondsUntil < 30) {
      _logSchedule(
        kind: 'DUE-ALARM',
        taskId: taskId,
        title: title,
        due: dueDate,
        id: id,
        zonedScheduleCalled: false,
        note: 'due in ${secondsUntil}s (<30s) → shown immediately',
      );
      await _plugin.show(id, notifTitle, notifBody, details,
          payload: 'task:$taskId');
      return;
    }

    // 3) Normal case → schedule an exact alarm at the due instant.
    final scheduled = tz.TZDateTime.from(dueDate, tz.local);
    final ok = await _safeZonedSchedule(
      id,
      notifTitle,
      notifBody,
      scheduled,
      details,
      payload: 'task:$taskId',
    );
    _logSchedule(
      kind: 'DUE-ALARM',
      taskId: taskId,
      title: title,
      due: dueDate,
      id: id,
      scheduledAt: scheduled,
      zonedScheduleCalled: ok,
      note: _notificationsEnabled
          ? null
          : 'WARNING: notifications permission OFF — alarm will be suppressed',
    );
  }

  Future<void> cancelDueTimeAlarm(String taskId) async {
    if (kIsWeb || !_initialised) return;
    await _plugin.cancel(_dueIdFor(taskId));
  }

  /// Fires an immediate "now overdue" notification — called by the in-app due
  /// timer so it works even when [scheduleDueTimeAlarm] is delayed by the OS.
  /// Sound scales with [priority]: high = alarm, medium = default, low = buzz only.
  Future<void> showImmediateOverdue({
    required String taskId,
    required String title,
    required String subject,
    String priority = 'Medium',
  }) async {
    if (!_initialised) return;
    if (kIsWeb) {
      _webNotify(
        '⚠️ Overdue: $title',
        subject.isEmpty ? 'This task is now overdue.' : '$subject · now overdue.',
      );
      return;
    }
    final body = subject.isEmpty
        ? 'This task is now overdue — open ISLA to complete it.'
        : '$subject · this task is now overdue.';
    await _plugin.show(
      _dueIdFor(taskId),
      '⚠️ Overdue: $title',
      body,
      _overdueDetails(priority),
      payload: 'task:$taskId',
    );
  }

  /// Returns [NotificationDetails] scaled to [priority]:
  ///   high   → alarm stream, long vibration, max volume
  ///   medium → default notification sound + vibration
  ///   low    → single short buzz, no sound
  NotificationDetails _overdueDetails(String priority) {
    final p = priority.toLowerCase();
    if (p == 'high') {
      return NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks_overdue_high',
          'Overdue alerts (High priority)',
          channelDescription: 'Alarm-level alert for high-priority overdue tasks.',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
          playSound: true,
          sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        iOS: const DarwinNotificationDetails(
          presentSound: true,
          presentBanner: true,
          presentAlert: true,
        ),
      );
    } else if (p == 'low') {
      return NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks_overdue_low',
          'Overdue alerts (Low priority)',
          channelDescription: 'Quiet nudge for low-priority overdue tasks.',
          importance: Importance.low,
          priority: Priority.low,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 120]),
          playSound: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentSound: false,
          presentBanner: true,
          presentAlert: false,
        ),
      );
    } else {
      // Medium — default notification sound + single vibration
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks_overdue',
          'Overdue task alerts',
          channelDescription: 'Fires when a task passes its due time.',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentBanner: true,
          presentAlert: true,
        ),
      );
    }
  }

  // ── Diagnostics ─────────────────────────────────────────────────────────────

  /// Fires an immediate notification AND schedules one 15 seconds later, so the
  /// user can confirm on-device that both instant and scheduled alarms work.
  /// Returns a short status string for UI feedback.
  Future<String> sendTestNotification() async {
    if (!_initialised) await init();

    if (kIsWeb) {
      _webNotify('ISLA test ✅', 'Notifications are working on web.');
      return 'Sent a browser notification.';
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'tasks_due',
        'Task due alerts',
        channelDescription: 'Notification when a task reaches its due time.',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(presentBanner: true, presentSound: true),
    );

    await refreshPermissions();

    await _plugin.show(9100, 'ISLA test ✅',
        'Instant notification works! A scheduled one will arrive in 60s.',
        details);

    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 60));
    final ok = await _safeZonedSchedule(
      9101,
      'Scheduled alarm ⏰',
      'This fired 60 seconds after you tapped Test — scheduling works!',
      when,
      details,
      payload: 'test',
    );

    if (kDebugMode) {
      debugPrint('NOTIF TEST ── notifEnabled=$_notificationsEnabled '
          'exactAlarms=$_exactAlarmsAllowed tz=${tz.local.name} '
          'scheduledAt=$when zonedScheduleOK=$ok');
    }

    if (!_notificationsEnabled) {
      return 'Notifications are DISABLED for ISLA. Enable them in system '
          'settings, then test again.';
    }
    return _exactAlarmsAllowed
        ? 'Sent now + scheduled in 60s (exact alarms ON).'
        : 'Sent now + scheduled in ~60s (exact alarms OFF — may be delayed).';
  }

  // ── Session in-progress alerts ─────────────────────────────────────────────

  static const int sessionStartId  = 9010;
  static const int sessionHalfId   = 9011;

  Future<void> showSessionStart({String? subject}) async {
    if (!_initialised) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pomodoro_start', 'Session start',
        channelDescription: 'Fires when you begin a focus session.',
        importance: Importance.high, priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    final body = subject == null || subject.isEmpty
        ? 'Your focus session has started. Stay focused!'
        : '$subject · focus session started. You\'ve got this!';
    if (kIsWeb) { _webNotify('Focus session started', body); return; }
    await _plugin.show(sessionStartId, 'Focus session started', body, details);
  }

  Future<void> showHalfwayReminder({
    required int minutesLeft,
    String? subject,
  }) async {
    if (!_initialised) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pomodoro_half', 'Halfway reminder',
        channelDescription: 'Fires at the halfway point of a focus session.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    final body = subject == null || subject.isEmpty
        ? 'Halfway there — $minutesLeft minutes left. Keep going!'
        : '$subject · halfway there. $minutesLeft min left!';
    if (kIsWeb) { _webNotify('Halfway through session', body); return; }
    await _plugin.show(sessionHalfId, 'Halfway there!', body, details);
  }

  // ── Morning / Evening study reminders ──────────────────────────────────────

  static const int morningReminderId = 9020;
  static const int eveningReminderId = 9021;

  Future<void> scheduleMorningReminder({int hour = 8, int minute = 0}) async {
    if (kIsWeb || !_initialised) return;
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
    await _safeZonedSchedule(
      morningReminderId,
      'Good morning! Time to study 📚',
      'Start your study session now to hit your daily goal.',
      first,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_reminder', 'Morning study reminder',
          channelDescription: 'Daily morning nudge to start studying.',
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'morning',
      matchComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelMorningReminder() async {
    if (kIsWeb || !_initialised) return;
    await _plugin.cancel(morningReminderId);
  }

  Future<void> scheduleEveningReminder({int hour = 20, int minute = 0}) async {
    if (kIsWeb || !_initialised) return;
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
    await _safeZonedSchedule(
      eveningReminderId,
      'Evening study session 🌙',
      'Wind down your day with a focused study session.',
      first,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_reminder', 'Evening study reminder',
          channelDescription: 'Daily evening nudge to study.',
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'evening',
      matchComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelEveningReminder() async {
    if (kIsWeb || !_initialised) return;
    await _plugin.cancel(eveningReminderId);
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

    await _safeZonedSchedule(
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
      payload: 'streak',
      matchComponents: DateTimeComponents.time, // repeat daily at HH:MM
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

  /// Verbose, debug-only dump of everything that affects whether a scheduled
  /// notification will actually fire. Printed right after a task is scheduled.
  void _logSchedule({
    required String kind,
    required String taskId,
    required String title,
    required DateTime due,
    required int id,
    tz.TZDateTime? scheduledAt,
    required bool zonedScheduleCalled,
    String? note,
  }) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    debugPrint('NOTIF $kind ───────────────────────────────');
    debugPrint('  1. title           : $title');
    debugPrint('  2. taskId          : $taskId');
    debugPrint('  3. due (selected)  : $due');
    debugPrint('  4. now             : $now');
    debugPrint('  5. timezone        : ${kIsWeb ? "web" : tz.local.name}');
    debugPrint('  6. notifPermission : $_notificationsEnabled');
    debugPrint('  7. exactAlarmPerm  : $_exactAlarmsAllowed');
    debugPrint('  8. notificationId  : $id');
    debugPrint('  -. secondsUntilDue : ${due.difference(now).inSeconds}');
    debugPrint('  9. scheduledAt     : ${scheduledAt ?? "(immediate / not scheduled)"}');
    debugPrint(' 10. zonedSchedule OK: $zonedScheduleCalled'
        '${note != null ? "   [$note]" : ""}');
  }

  /// Stable positive 31-bit int derived from a string id (notification id limit).
  static int _idFor(String key) =>
      (key.hashCode & 0x7FFFFFFF).clamp(1, 0x7FFFFFFF);

  /// Separate ID namespace for the at-due-time alarm (avoids colliding with the
  /// advance reminder scheduled by [scheduleTaskReminder]).
  static int _dueIdFor(String taskId) =>
      ('due:$taskId'.hashCode & 0x7FFFFFFF).clamp(1, 0x7FFFFFFF);

  /// Fire a browser notification (web only). Silently ignored if the user
  /// hasn't granted permission.
  void _webNotify(String title, String body) {
    BrowserNotifier.show(title, body);
  }
}
