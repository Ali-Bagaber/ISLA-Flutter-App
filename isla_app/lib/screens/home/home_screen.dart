import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/document_service.dart';
import '../../services/gemini_study_service.dart';
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/isla_logo.dart';
import '../documents/documents_screen.dart';
import '../planner/add_task_screen.dart';
import '../study_aids/study_library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _currentTime;
  late String _greeting;
  late Timer _timer;

  StreamSubscription<List<Map<String, dynamic>>>? _tasksSub;
  StreamSubscription<List<Map<String, dynamic>>>? _documentsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _sessionsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _quizzesSub;

  int _pendingTasks = 0;
  int _overdueTasks = 0;
  int _completedTasks = 0;
  int _streak = 0;
  int _documentsCount = 0;
  int _quizzesCount = 0;
  int _totalStudyMinutes = 0;
  List<Map<String, dynamic>> _recentDocuments = const [];
  List<Map<String, dynamic>> _upcomingTasks = const [];

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
    _initStatsListeners();
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    _documentsSub?.cancel();
    _sessionsSub?.cancel();
    _quizzesSub?.cancel();
    _timer.cancel();
    super.dispose();
  }

  void _initStatsListeners() {
    _tasksSub = TaskService.watchTasks().listen(_updateTaskStats);

    _documentsSub = DocumentService.watchDocuments().listen((documents) {
      if (!mounted) return;
      setState(() {
        _documentsCount = documents.length;
        _recentDocuments = documents.take(3).toList();
      });
    });

    _sessionsSub =
        GeminiStudyService.watchSessions().listen(_updateSessionStats);

    _quizzesSub = GeminiStudyService.watchQuizResults().listen((quizzes) {
      if (!mounted) return;
      setState(() => _quizzesCount = quizzes.length);
    });
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  void _updateTaskStats(List<Map<String, dynamic>> tasks) {
    final now = DateTime.now();
    var pending = 0;
    var overdue = 0;
    var completed = 0;

    for (final task in tasks) {
      final isCompleted = task['completed'] == true;
      if (isCompleted) {
        completed += 1;
        continue;
      }

      pending += 1;
      final dueDate = _toDateTime(task['dueDate']);
      if (dueDate != null && dueDate.isBefore(now)) {
        overdue += 1;
      }
    }

    if (!mounted) return;
    setState(() {
      _pendingTasks = pending;
      _overdueTasks = overdue;
      _completedTasks = completed;
      _upcomingTasks = _getUpcomingTasks(tasks);
    });
  }

  List<Map<String, dynamic>> _getUpcomingTasks(
      List<Map<String, dynamic>> tasks) {
    final upcoming = tasks.where((task) => task['completed'] != true).toList();

    upcoming.sort((a, b) {
      final aDate = _toDateTime(a['dueDate']);
      final bDate = _toDateTime(b['dueDate']);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });

    return upcoming.take(3).toList();
  }

  void _updateSessionStats(List<Map<String, dynamic>> sessions) {
    var totalMinutes = 0;
    for (final session in sessions) {
      final value = session['focusMinutes'];
      if (value is int) {
        totalMinutes += value;
      } else if (value is num) {
        totalMinutes += value.toInt();
      }
    }

    if (!mounted) return;
    setState(() {
      _totalStudyMinutes = totalMinutes;
      _streak = _calculateStreak(sessions);
    });
  }

  int _calculateStreak(List<Map<String, dynamic>> sessions) {
    final studyDays = <DateTime>{};
    for (final session in sessions) {
      final timestamp = _toDateTime(session['timestamp']);
      if (timestamp == null) continue;
      studyDays.add(DateTime(timestamp.year, timestamp.month, timestamp.day));
    }

    if (studyDays.isEmpty) return 0;

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!studyDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (studyDays.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) return '${remainingMinutes}m';
    if (remainingMinutes == 0) return '${hours}h';
    return '${hours}h ${remainingMinutes}m';
  }

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown time';

    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  String _formatDueDate(DateTime? dueDate) {
    if (dueDate == null) return 'No due date';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final dayDiff = dueDay.difference(today).inDays;

    if (dayDiff < 0) return 'Overdue';
    if (dayDiff == 0) return 'Due Today';
    if (dayDiff == 1) return 'Due Tomorrow';
    return 'Due in $dayDiff days';
  }

  bool _isUrgent(DateTime? dueDate) {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueDay.difference(today).inDays <= 1;
  }

  Color _subjectColor(String subject) {
    const subjects = ['BCS2033', 'BCS3012', 'BCS2042', 'BCS4051'];
    final index = subjects.indexOf(subject);
    if (index == -1) return AppTheme.primaryColor;
    return AppTheme.subjectColors[index % AppTheme.subjectColors.length];
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour;

    setState(() {
      _currentTime =
          '${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      if (hour < 12) {
        _greeting = 'Good Morning';
      } else if (hour < 17) {
        _greeting = 'Good Afternoon';
      } else {
        _greeting = 'Good Evening';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IslaLogo(),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: AppTheme.getTextPrimary(isDark),
                      ),
                      onPressed: () => themeProvider.toggleTheme(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.getCardColor(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const IslaProfileAvatar(),
                  ],
                ),

                const SizedBox(height: 16),

                // Page title — matching Tasks page style
                Center(
                  child: Column(
                    children: [
                      Text(
                        _greeting,
                        style: AppTheme.headingLarge.copyWith(
                          fontSize: 52,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.getTextPrimary(isDark),
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'YOUR STUDY HUB',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.getTextSecondary(isDark),
                          letterSpacing: 3.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Task Statistics Row (like MyStudyLife)
                Row(
                  children: [
                    Expanded(
                      child: _TaskStatCard(
                        label: 'Pending Tasks',
                        count: '$_pendingTasks',
                        subLabel: 'All tasks',
                        color: AppTheme.warning,
                        icon: Icons.pending_actions_rounded,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TaskStatCard(
                        label: 'Overdue Tasks',
                        count: '$_overdueTasks',
                        subLabel: 'Due date passed',
                        color: AppTheme.error,
                        icon: Icons.error_outline_rounded,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _TaskStatCard(
                        label: 'Tasks Completed',
                        count: '$_completedTasks',
                        subLabel: 'All tasks',
                        color: AppTheme.success,
                        icon: Icons.check_circle_outline_rounded,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TaskStatCard(
                        label: 'Your Streak',
                        count: '$_streak',
                        subLabel: 'Consecutive days',
                        color: AppTheme.primaryColor,
                        icon: Icons.local_fire_department_rounded,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Today's Progress Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppTheme.borderRadiusLarge,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Focus Timer",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '25:00',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ready to start a focus session?',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text(
                          'Start Focus Timer',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Study Statistics
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(isDark),
                    borderRadius: AppTheme.borderRadiusLarge,
                    boxShadow: isDark ? [] : AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Study Time',
                            style: AppTheme.labelMedium.copyWith(
                              color: AppTheme.getTextPrimary(isDark),
                            ),
                          ),
                          Text(
                            _formatMinutes(_totalStudyMinutes),
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _ProgressItem(
                            icon: Icons.description_outlined,
                            label: 'Documents',
                            value: '$_documentsCount',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 24),
                          _ProgressItem(
                            icon: Icons.quiz_outlined,
                            label: 'Quizzes',
                            value: '$_quizzesCount',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 24),
                          _ProgressItem(
                            icon: Icons.task_alt_outlined,
                            label: 'Tasks',
                            value: '${_pendingTasks + _completedTasks}',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Quick Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Actions',
                      style: AppTheme.headingSmall.copyWith(
                        color: AppTheme.getTextPrimary(isDark),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudyLibraryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: const Text('My Library'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.upload_file_rounded,
                        label: 'Upload\nDocument',
                        color: const Color(0xFF10B981),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DocumentsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.add_task_rounded,
                        label: 'Add\nTask',
                        color: const Color(0xFFF59E0B),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddTaskScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.timer_rounded,
                        label: 'Start\nTimer',
                        color: const Color(0xFF8B5CF6),
                        onTap: () {
                          // Navigate to timer (handled by bottom nav)
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Recent Documents
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Documents',
                      style: AppTheme.headingSmall.copyWith(
                        color: AppTheme.getTextPrimary(isDark),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DocumentsScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'See All',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_recentDocuments.isEmpty)
                  _EmptySectionCard(
                    icon: Icons.description_outlined,
                    message: 'No documents yet. Upload your first document.',
                    isDark: isDark,
                  )
                else
                  ..._recentDocuments.map((doc) {
                    final subject = (doc['subject'] ?? 'General').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DocumentCard(
                        title: (doc['title'] ?? 'Untitled').toString(),
                        subject: subject,
                        date:
                            _formatRelativeTime(_toDateTime(doc['createdAt'])),
                        color: _subjectColor(subject),
                        isDark: isDark,
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // Upcoming Tasks
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming Tasks',
                      style: AppTheme.headingSmall.copyWith(
                        color: AppTheme.getTextPrimary(isDark),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddTaskScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'See All',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_upcomingTasks.isEmpty)
                  _EmptySectionCard(
                    icon: Icons.task_alt_outlined,
                    message: 'No upcoming tasks. Add a task to get started.',
                    isDark: isDark,
                  )
                else
                  ..._upcomingTasks.map((task) {
                    final dueDate = _toDateTime(task['dueDate']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TaskCard(
                        title: (task['title'] ?? 'Untitled Task').toString(),
                        dueDate: _formatDueDate(dueDate),
                        type: (task['type'] ?? 'Task').toString(),
                        isUrgent: _isUrgent(dueDate),
                        isDark: isDark,
                      ),
                    );
                  }),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _ProgressItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppTheme.getTextPrimary(isDark);
    final secondaryText = AppTheme.getTextSecondary(isDark);

    return Column(
      children: [
        Icon(icon, color: secondaryText, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: primaryText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: secondaryText, fontSize: 12),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadiusMedium,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: AppTheme.borderRadiusMedium,
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isDark;

  const _EmptySectionCard({
    required this.icon,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: isDark ? [] : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.getTextSecondary(isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.getTextSecondary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String title;
  final String subject;
  final String date;
  final Color color;
  final bool isDark;

  const _DocumentCard({
    required this.title,
    required this.subject,
    required this.date,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: isDark ? [] : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description_rounded, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.getTextPrimary(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        subject,
                        style: AppTheme.bodySmall.copyWith(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.getTextLight(isDark),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final String dueDate;
  final String type;
  final bool isUrgent;
  final bool isDark;

  const _TaskCard({
    required this.title,
    required this.dueDate,
    required this.type,
    required this.isUrgent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: isDark ? [] : AppTheme.cardShadow,
        border: isUrgent
            ? Border.all(color: AppTheme.error.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: isUrgent ? AppTheme.error : AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: isUrgent
                          ? AppTheme.error
                          : AppTheme.getTextSecondary(isDark),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dueDate,
                      style: AppTheme.bodySmall.copyWith(
                        color: isUrgent
                            ? AppTheme.error
                            : AppTheme.getTextSecondary(isDark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.getTextLight(isDark).withOpacity(0.1)
                            : AppTheme.getSurfaceColor(isDark),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type,
                        style: AppTheme.bodySmall.copyWith(
                          fontSize: 10,
                          color: AppTheme.getTextSecondary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Checkbox(
            value: false,
            onChanged: (value) {},
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

class _TaskStatCard extends StatelessWidget {
  final String label;
  final String count;
  final String subLabel;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _TaskStatCard({
    required this.label,
    required this.count,
    required this.subLabel,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: isDark ? [] : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: AppTheme.headingLarge.copyWith(
              fontSize: 28,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextPrimary(isDark),
            ),
          ),
          Text(
            subLabel,
            style: AppTheme.bodySmall.copyWith(
              fontSize: 10,
              color: AppTheme.getTextLight(isDark),
            ),
          ),
        ],
      ),
    );
  }
}
