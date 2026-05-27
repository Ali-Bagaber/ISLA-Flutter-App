import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/document_service.dart';
import '../../services/gemini_study_service.dart';
import '../../services/nav_controller.dart';
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/hover_lift.dart';
import '../../widgets/isla_logo.dart';
import '../planner/add_task_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _greeting;
  late String _greetingEmoji;
  late Timer _timer;

  StreamSubscription<List<Map<String, dynamic>>>? _tasksSub;
  StreamSubscription<List<Map<String, dynamic>>>? _sessionsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _documentsSub;

  int _completedTasks = 0;
  int _totalTasks = 0;
  int _streak = 0;
  int _totalStudyMinutes = 0;
  List<Map<String, dynamic>> _upcomingTasks = const [];

  /// Tasks scheduled for today (dueDate == today), straight from Firestore.
  List<Map<String, dynamic>> _todayTasks = const [];

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateGreeting());
    _initStreams();
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    _sessionsSub?.cancel();
    _documentsSub?.cancel();
    _timer.cancel();
    super.dispose();
  }

  void _initStreams() {
    _tasksSub = TaskService.watchTasks().listen(_onTasks);
    _sessionsSub = GeminiStudyService.watchSessions().listen(_onSessions);
    _documentsSub = DocumentService.watchDocuments().listen((_) {});
  }

  DateTime? _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Lower priority rank = more urgent. Used as the second key after
  /// the "overdue vs future" split.
  int _priorityRank(dynamic p) {
    switch ((p ?? '').toString().toLowerCase()) {
      case 'high':
        return 0;
      case 'medium':
        return 1;
      case 'low':
        return 2;
      default:
        return 3;
    }
  }

  /// Sorts tasks by urgency:
  ///   1) overdue tasks first (regardless of priority)
  ///   2) within each bucket, higher priority first
  ///   3) within each priority, earliest due date first
  int _compareTaskUrgency(
      Map<String, dynamic> a, Map<String, dynamic> b, DateTime now) {
    final ad = _toDateTime(a['dueDate']);
    final bd = _toDateTime(b['dueDate']);
    final aOver = ad != null && ad.isBefore(now);
    final bOver = bd != null && bd.isBefore(now);
    if (aOver != bOver) return aOver ? -1 : 1;

    final ap = _priorityRank(a['priority']);
    final bp = _priorityRank(b['priority']);
    if (ap != bp) return ap.compareTo(bp);

    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  void _onTasks(List<Map<String, dynamic>> tasks) {
    var completed = 0;
    for (final t in tasks) {
      if (t['completed'] == true) completed++;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // Today's tasks → drive the "Today's Study Plan" card
    final todays = tasks.where((t) {
      final d = _toDateTime(t['dueDate']);
      if (d == null) return false;
      final dayOnly = DateTime(d.year, d.month, d.day);
      return !dayOnly.isBefore(today) && dayOnly.isBefore(tomorrow);
    }).toList()
      ..sort((a, b) {
        // Incomplete first, then by dueDate
        final ac = (a['completed'] == true) ? 1 : 0;
        final bc = (b['completed'] == true) ? 1 : 0;
        if (ac != bc) return ac.compareTo(bc);
        final ad = _toDateTime(a['dueDate']);
        final bd = _toDateTime(b['dueDate']);
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });

    // Upcoming list — includes overdue + future tasks. Sorted by a composite
    // weight: (1) overdue first, (2) priority rank, (3) due date soonest.
    // This makes a High-priority overdue item outrank a Low-priority future one.
    final upcoming = tasks.where((t) => t['completed'] != true).toList()
      ..sort((a, b) => _compareTaskUrgency(a, b, now));
    if (!mounted) return;
    setState(() {
      _completedTasks = completed;
      _totalTasks = tasks.length;
      _todayTasks = todays;
      _upcomingTasks = upcoming.take(2).toList();
    });
  }

  void _onSessions(List<Map<String, dynamic>> sessions) {
    var total = 0;
    for (final s in sessions) {
      final v = s['focusMinutes'];
      total += v is int ? v : (v is num ? v.toInt() : 0);
    }
    final studyDays = <DateTime>{};
    for (final s in sessions) {
      final ts = _toDateTime(s['timestamp']);
      if (ts != null) studyDays.add(DateTime(ts.year, ts.month, ts.day));
    }
    var streak = 0;
    if (studyDays.isNotEmpty) {
      final today = DateTime.now();
      var cursor = DateTime(today.year, today.month, today.day);
      if (!studyDays.contains(cursor)) {
        cursor = cursor.subtract(const Duration(days: 1));
      }
      while (studyDays.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }
    if (!mounted) return;
    setState(() {
      _totalStudyMinutes = total;
      _streak = streak;
    });
  }

  void _updateGreeting() {
    final h = DateTime.now().hour;
    setState(() {
      if (h < 12) {
        _greeting = 'Good Morning';
        _greetingEmoji = '☀️';
      } else if (h < 17) {
        _greeting = 'Good Afternoon';
        _greetingEmoji = '👋';
      } else {
        _greeting = 'Good Evening';
        _greetingEmoji = '🌙';
      }
    });
  }

  String _formatMinutes(int m) {
    if (m <= 0) return '0m';
    final h = m ~/ 60;
    final rem = m % 60;
    if (h == 0) return '${rem}m';
    if (rem == 0) return '${h}h';
    return '${h}h ${rem}m';
  }

  Future<void> _openTaskActions(Map<String, dynamic> task) async {
    final taskId =
        (task['id'] ?? task['taskId'] ?? '').toString();
    if (taskId.isEmpty) return;
    final title = (task['title'] ?? 'Task').toString();
    final isDone = task['completed'] == true;

    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                title,
                style: AppTheme.headingSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: Icon(
                isDone
                    ? Icons.refresh_rounded
                    : Icons.check_circle_outline_rounded,
                color: AppTheme.success,
              ),
              title: Text(isDone ? 'Mark as not done' : 'Mark complete'),
              onTap: () => Navigator.pop(ctx, 'toggle'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Edit task'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.error),
              title: const Text('Delete task',
                  style: TextStyle(color: AppTheme.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'toggle':
        await TaskService.toggleTask(taskId, !isDone);
        break;
      case 'edit':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTaskScreen(
              taskId: taskId,
              initialTitle: (task['title'] as String?) ?? '',
              initialDescription: (task['description'] as String?) ?? '',
              initialSubject: task['subject'] as String?,
              initialType: task['type'] as String?,
              initialPriority: task['priority'] as String?,
              initialDueDate: _toDateTime(task['dueDate']),
              initialEstimatedMinutes:
                  (task['estimatedMinutes'] as num?)?.toInt(),
            ),
          ),
        );
        break;
      case 'delete':
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete task?'),
            content: Text('Delete "$title"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await TaskService.deleteTask(taskId);
        }
        break;
    }
  }

  String _formatDue(dynamic rawDate) {
    final date = _toDateTime(rawDate);
    if (date == null) return 'No date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(date.year, date.month, date.day);
    final diff = due.difference(today).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  /// Returns (topLabel, dayLabel) that both fit in the 44×44 date badge.
  (String, String) _parseDateBadge(String due) {
    if (due == 'Today') return ('DUE', 'NOW');
    if (due == 'Tomorrow') return ('DUE', 'TMR');
    if (due == 'Overdue') return ('OVER', 'DUE');
    final parts = due.split(' ');
    if (parts.length >= 2) return (parts[0].toUpperCase(), parts[1]);
    return ('DUE', due.substring(0, due.length.clamp(0, 4)).toUpperCase());
  }

  int get _completedPlanCount =>
      _todayTasks.where((t) => t['completed'] == true).length;

  double get _progressFraction =>
      _totalTasks == 0 ? 0.0 : (_completedTasks / _totalTasks).clamp(0.0, 1.0);

  String get _currentUserName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Alex';
    return user.displayName?.split(' ').first ?? user.email?.split('@').first ?? 'Alex';
  }

  /// Bell icon → quick view of today's tasks + upcoming as an in-app inbox.
  /// We don't keep a separate notification log; this is a live snapshot.
  void _showNotificationsInbox() {
    final pending = _todayTasks.where((t) => t['completed'] != true).toList();
    final upcoming = _upcomingTasks;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded,
                      color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text('Notifications', style: AppTheme.headingSmall),
                ],
              ),
              const SizedBox(height: 14),
              if (pending.isEmpty && upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'You\'re all caught up. Nothing to remind you of.',
                      style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.getTextSecondary(true)),
                    ),
                  ),
                )
              else ...[
                if (pending.isNotEmpty) ...[
                  Text('Due today',
                      style: AppTheme.labelMedium
                          .copyWith(color: AppTheme.primaryColor)),
                  const SizedBox(height: 6),
                  ...pending.take(3).map((t) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.event_rounded,
                            color: AppTheme.primaryColor),
                        title: Text(t['title']?.toString() ?? ''),
                        subtitle: Text(t['subject']?.toString() ?? ''),
                      )),
                  const SizedBox(height: 8),
                ],
                if (upcoming.isNotEmpty) ...[
                  Text('Upcoming',
                      style: AppTheme.labelMedium
                          .copyWith(color: AppTheme.warning)),
                  const SizedBox(height: 6),
                  ...upcoming.map((t) => ListTile(
                        dense: true,
                        leading: const Icon(
                            Icons.schedule_rounded,
                            color: AppTheme.warning),
                        title: Text(t['title']?.toString() ?? ''),
                        subtitle: Text(_formatDue(t['dueDate'])),
                      )),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar icon → small menu (View profile / Sign out).
  void _showAvatarMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Account'),
              subtitle:
                  Text(FirebaseAuth.instance.currentUser?.email ?? '—'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Reload data'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: Color(0xFFFF4D4D)),
              title: const Text('Sign out',
                  style: TextStyle(color: Color(0xFFFF4D4D))),
              onTap: () async {
                Navigator.pop(ctx);
                await FirebaseAuth.instance.signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final bg = AppTheme.getBackgroundColor(isDark);
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);
    const primary = AppTheme.primaryColor;
    final outlineSoft = isDark ? const Color(0xFF2A2E32) : const Color(0xFFD4DEE4);
    final cardBg = AppTheme.getCardColor(isDark);
    final surfaceLow = isDark ? const Color(0xFF111415) : const Color(0xFFEAF2F6);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ───────────────────────────────────────────────────
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.getAppBarBg(isDark),
                border: Border(bottom: BorderSide(color: outlineSoft, width: 0.8)),
              ),
              child: Row(
                children: [
                  const IslaLogo(markSize: 28, textSize: 17),
                  const Spacer(),
                  IconButton(
                    onPressed: _showNotificationsInbox,
                    icon: Icon(Icons.notifications_outlined, color: textSecondary, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  const SizedBox(width: 4),
                  IslaProfileAvatar(
                    radius: 17,
                    onTap: _showAvatarMenu,
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting ──────────────────────────────────────────
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.manrope(
                          color: textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                          height: 1.2,
                        ),
                        children: [
                          TextSpan(text: '$_greeting, '),
                          TextSpan(
                            text: _currentUserName,
                            style: TextStyle(
                              foreground: Paint()
                                ..shader = IslaColors.cyanToBlue.createShader(
                                  const Rect.fromLTWH(0, 0, 180, 50),
                                ),
                            ),
                          ),
                          TextSpan(text: ' $_greetingEmoji'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready to make today count?',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Today's Study Plan ────────────────────────────────
                    _SectionHeader(
                      title: "Today's Study Plan",
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$_completedPlanCount/${_todayTasks.length} completed',
                          style: GoogleFonts.inter(
                            color: primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primary.withValues(alpha: 0.2)),
                      ),
                      child: _todayTasks.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.event_available_rounded,
                                        color: textSecondary, size: 32),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No tasks scheduled for today',
                                      style: GoogleFonts.inter(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add one from the Tasks tab to plan your day.',
                                      style: GoogleFonts.inter(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: List.generate(_todayTasks.length, (i) {
                                final item = _todayTasks[i];
                                final color = AppTheme.subjectColors[
                                    i % AppTheme.subjectColors.length];
                                final isLast = i == _todayTasks.length - 1;
                                final done = item['completed'] == true;
                                final taskId = (item['id'] ??
                                        item['taskId'] ??
                                        '')
                                    .toString();
                                final subject =
                                    (item['subject'] ?? 'General').toString();
                                final title =
                                    (item['title'] ?? '').toString();
                                final minutes =
                                    (item['estimatedMinutes'] as num?)
                                            ?.toInt() ??
                                        60;
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          14, 12, 14, 12),
                                      child: Row(
                                        children: [
                                          GestureDetector(
                                            onTap: taskId.isEmpty
                                                ? null
                                                : () => TaskService.toggleTask(
                                                    taskId, !done),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: done
                                                    ? primary
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: done
                                                      ? primary
                                                      : textSecondary
                                                          .withValues(
                                                              alpha: 0.4),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: done
                                                  ? const Icon(
                                                      Icons.check_rounded,
                                                      size: 14,
                                                      color: Colors.white)
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  subject,
                                                  style: GoogleFonts.inter(
                                                    color: done
                                                        ? textSecondary
                                                        : textPrimary,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 13,
                                                    decoration: done
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                                    decorationColor:
                                                        textSecondary,
                                                  ),
                                                ),
                                                Text(
                                                  title,
                                                  style: GoogleFonts.inter(
                                                    color: textSecondary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '$minutes min',
                                                style: GoogleFonts.inter(
                                                  color: textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: done
                                                      ? primary.withValues(
                                                          alpha: 0.15)
                                                      : color.withValues(
                                                          alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          4),
                                                ),
                                                child: Icon(
                                                  done
                                                      ? Icons.check_box_rounded
                                                      : Icons
                                                          .check_box_outline_blank_rounded,
                                                  size: 12,
                                                  color: done ? primary : color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isLast)
                                      Divider(
                                        height: 1,
                                        color:
                                            outlineSoft.withValues(alpha: 0.6),
                                        indent: 48,
                                        endIndent: 14,
                                      ),
                            ],
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Upcoming ──────────────────────────────────────────
                    _SectionHeader(
                      title: 'Upcoming',
                      trailing: TextButton(
                        onPressed: () =>
                            context.read<NavController>().goTasks(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'View all',
                          style: GoogleFonts.inter(
                            color: primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),

                    if (_upcomingTasks.isEmpty)
                      _buildDefaultUpcoming(
                        surfaceLow: surfaceLow,
                        primary: primary,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        outlineSoft: outlineSoft,
                        isDark: isDark,
                      )
                    else
                      ..._upcomingTasks.map((t) {
                        final due = _formatDue(t['dueDate']);
                        final (badgeTop, badgeDay) = _parseDateBadge(due);
                        return _UpcomingCard(
                          month: badgeTop,
                          day: badgeDay,
                          title: (t['title'] ?? 'Untitled').toString(),
                          subtitle: (t['type'] ?? 'Task').toString(),
                          isDark: isDark,
                          primary: primary,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          surfaceLow: surfaceLow,
                          outlineSoft: outlineSoft,
                          onTap: () => _openTaskActions(t),
                        );
                      }),

                    const SizedBox(height: 20),

                    // ── Daily Progress ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF111820) : cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: primary.withValues(alpha: 0.15)),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(100, 100),
                                  painter: _ArcProgressPainter(
                                    progress: _progressFraction,
                                    isDark: isDark,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(_progressFraction * 100).round()}%',
                                      style: GoogleFonts.manrope(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                      ),
                                    ),
                                    Text(
                                      'Done',
                                      style: GoogleFonts.inter(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Progress',
                                  style: GoogleFonts.manrope(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _totalTasks == 0
                                      ? 'No tasks yet — add one to start tracking.'
                                      : '$_completedTasks of $_totalTasks tasks done.',
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _MiniStat(
                                      label: 'Focus',
                                      value: _formatMinutes(_totalStudyMinutes),
                                      color: primary,
                                    ),
                                    const SizedBox(width: 16),
                                    _MiniStat(
                                      label: 'Streak',
                                      value: '${_streak}d',
                                      color: const Color(0xFFFF6B2B),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Quick Actions ─────────────────────────────────────
                    _SectionHeader(title: 'Quick Actions', isDark: isDark),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.add_task_rounded,
                            label: 'Add Task',
                            color: AppTheme.warning,
                            // Add Task is a sub-flow of Tasks — switch to the
                            // Tasks tab so the bottom nav stays visible, then
                            // push the AddTaskScreen on top.
                            onTap: () {
                              context.read<NavController>().goTasks();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.auto_awesome_rounded,
                            label: 'AI Tools',
                            color: AppTheme.primaryColor,
                            onTap: () =>
                                context.read<NavController>().goLibrary(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.bar_chart_rounded,
                            label: 'Progress',
                            color: AppTheme.success,
                            onTap: () =>
                                context.read<NavController>().goAnalytics(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultUpcoming({
    required Color surfaceLow,
    required Color primary,
    required Color textPrimary,
    required Color textSecondary,
    required Color outlineSoft,
    required bool isDark,
  }) {
    const exams = [
      _ExamItem(month: 'MAY', day: '24', title: 'Database Systems Quiz', subtitle: 'Tomorrow, 10:00 AM'),
      _ExamItem(month: 'MAY', day: '27', title: 'Operating Systems Midterm', subtitle: 'Next Tuesday, 09:00 AM'),
    ];
    return Column(
      children: exams
          .map((e) => _UpcomingCard(
                month: e.month,
                day: e.day,
                title: e.title,
                subtitle: e.subtitle,
                isDark: isDark,
                primary: primary,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                surfaceLow: surfaceLow,
                outlineSoft: outlineSoft,
              ))
          .toList(),
    );
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

class _ExamItem {
  final String month;
  final String day;
  final String title;
  final String subtitle;

  const _ExamItem({
    required this.month,
    required this.day,
    required this.title,
    required this.subtitle,
  });
}

// ─── Arc Progress Painter ─────────────────────────────────────────────────────

class _ArcProgressPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  const _ArcProgressPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const stroke = 8.0;
    const start = -pi * 0.85;
    const total = pi * 1.7;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = isDark ? const Color(0xFF1E2630) : const Color(0xFFE0EEF5)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, total, false, trackPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + total,
        colors: const [IslaColors.primary, IslaColors.tertiary],
      ).createShader(rect);
    canvas.drawArc(rect, start, total * progress.clamp(0, 1), false, progressPaint);
  }

  @override
  bool shouldRepaint(_ArcProgressPainter old) =>
      old.progress != progress || old.isDark != isDark;
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final bool isDark;

  const _SectionHeader({required this.title, this.trailing, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            color: AppTheme.getTextPrimary(isDark),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final String month;
  final String day;
  final String title;
  final String subtitle;
  final bool isDark;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color surfaceLow;
  final Color outlineSoft;
  final VoidCallback? onTap;

  const _UpcomingCard({
    required this.month,
    required this.day,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.surfaceLow,
    required this.outlineSoft,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outlineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month,
                  style: GoogleFonts.inter(
                    color: primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  day,
                  style: GoogleFonts.manrope(
                    color: primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
        ],
      ),
    );

    if (onTap == null) return card;
    return HoverLift(
      scale: 1.02,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: card,
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      glow: true,
      glowColor: color,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.getTextSecondary(isDark),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
