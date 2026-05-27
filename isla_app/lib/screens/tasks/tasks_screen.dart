import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/isla_logo.dart';
import '../planner/add_task_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _showCompleted = false;
  final Map<String, bool> _demoCompletion = <String, bool>{};

  final List<_TaskVm> _demoTasks = [
    _TaskVm(
      id: 'demo_1',
      title: 'Review Data Structures – Arrays & Linked Lists',
      description:
          'Complete chapter 4 exercises and summarise the key differences between array and linked list time complexities.',
      dueDate: DateTime.now().copyWith(hour: 14, minute: 0),
      category: 'STUDY',
      subject: 'Data Structures',
      completed: false,
      highlighted: true,
    ),
    _TaskVm(
      id: 'demo_2',
      title: 'Prepare OS Quiz – CPU Scheduling',
      description:
          'Revise Round-Robin, FCFS, and SJF scheduling algorithms. Practice past-paper questions from weeks 5–7.',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      category: 'EXAM PREP',
      subject: 'Operating Systems',
      completed: false,
    ),
    _TaskVm(
      id: 'demo_3',
      title: 'Database Normalization – Practice Problems',
      description:
          'Work through 1NF → 3NF normalization exercises in the textbook and verify answers with lecture slides.',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      category: 'ASSIGNMENT',
      subject: 'Database Systems',
      completed: false,
    ),
  ];

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _categoryFromTask(Map<String, dynamic> task) {
    final type = (task['type'] ?? '').toString().trim();
    final subject = (task['subject'] ?? '').toString().trim();
    if (type.isNotEmpty) return type.toUpperCase();
    if (subject.isNotEmpty && subject.toLowerCase() != 'no subject') {
      return subject.toUpperCase();
    }
    return 'TASK';
  }

  List<_TaskVm> _mapFirestoreTasks(List<Map<String, dynamic>> tasks) {
    return tasks.map((task) {
      final dueDate = _toDateTime(task['dueDate']);
      final isCompleted = task['completed'] == true;
      final title = (task['title'] ?? 'Untitled task').toString();
      final description = (task['description'] ?? '').toString();
      final priority = (task['priority'] ?? '').toString().toLowerCase();
      final isHighPriority = priority == 'high';
      final typeRaw =
          (task['type'] ?? task['taskType'] ?? 'Assignment').toString();
      final priorityRaw = (task['priority'] ?? 'Medium').toString();
      final subjectRaw = (task['subject'] ?? '').toString();

      return _TaskVm(
        id: (task['id'] ?? '').toString(),
        title: title,
        description: description,
        dueDate: dueDate,
        category: _categoryFromTask(task),
        completed: isCompleted,
        highlighted: isHighPriority,
        type: typeRaw,
        priority: priorityRaw,
        subject: subjectRaw,
      );
    }).toList();
  }

  /// Lower rank = more urgent.
  int _priorityRank(String? p) {
    switch ((p ?? '').toLowerCase()) {
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

  /// Same urgency comparator as the home screen — overdue first, then
  /// priority, then earliest due date.
  int _compareUrgency(_TaskVm a, _TaskVm b, DateTime now) {
    final aOver = a.dueDate != null && a.dueDate!.isBefore(now);
    final bOver = b.dueDate != null && b.dueDate!.isBefore(now);
    if (aOver != bOver) return aOver ? -1 : 1;

    final ap = _priorityRank(a.priority);
    final bp = _priorityRank(b.priority);
    if (ap != bp) return ap.compareTo(bp);

    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  String _formatDueLabel(DateTime? dueDate) {
    if (dueDate == null) return 'No date';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final dayDiff = dueDay.difference(today).inDays;

    if (dayDiff == 0) {
      return 'TODAY, ${_formatTime(dueDate)}';
    }
    if (dayDiff == 1) return 'TOMORROW';
    if (dayDiff > 1) {
      return '${_monthShort(dueDate.month)} ${dueDate.day}'.toUpperCase();
    }
    return 'OVERDUE';
  }

  IconData _dueIcon(DateTime? dueDate) {
    if (dueDate == null) return Icons.event_rounded;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final dayDiff = dueDay.difference(today).inDays;

    if (dayDiff == 0) return Icons.schedule_rounded;
    if (dayDiff == 1) return Icons.calendar_today_rounded;
    return Icons.event_rounded;
  }

  String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    return '$hour12:$minute $suffix';
  }

  void _toggleTask(_TaskVm task, bool nextValue) {
    if (task.id.startsWith('demo_')) {
      setState(() => _demoCompletion[task.id] = nextValue);
      return;
    }

    if (task.id.isEmpty) return;
    TaskService.toggleTask(task.id, nextValue);
  }

  void _openEditTask(_TaskVm task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          taskId: task.id,
          initialTitle: task.title,
          initialDescription: task.description,
          initialSubject: task.subject,
          initialType: task.type,
          initialPriority: task.priority,
          initialDueDate: task.dueDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = _TaskPalette.fromTheme(theme);

    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: _buildFab(palette),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: palette.appBarBackground,
                border: Border(
                  bottom: BorderSide(color: palette.outlineSoft),
                ),
              ),
              child: Row(
                children: [
                  const IslaLogo(markSize: 28, textSize: 17),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          context.read<ThemeProvider>().setDarkMode(!isDark);
                        },
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: palette.onSurfaceMute,
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'logout') {
                            await AuthService.signOut();
                            if (context.mounted) context.goNamed('splash');
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'logout',
                            child: Row(children: [
                              Icon(Icons.logout_rounded,
                                  color: palette.onSurfaceMute, size: 18),
                              const SizedBox(width: 8),
                              const Text('Sign Out'),
                            ]),
                          ),
                        ],
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: palette.surfaceHigh,
                          child: Icon(
                            Icons.person,
                            color: palette.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: TaskService.watchTasks(),
                builder: (context, snapshot) {
                  final fetched = _mapFirestoreTasks(snapshot.data ?? const []);
                  final source = fetched.isNotEmpty
                      ? fetched
                      : _demoTasks
                          .map(
                            (task) => task.copyWith(
                              completed:
                                  _demoCompletion[task.id] ?? task.completed,
                            ),
                          )
                          .toList();

                  final now = DateTime.now();
                  final pending = source.where((t) => !t.completed).toList()
                    ..sort((a, b) => _compareUrgency(a, b, now));
                  final completed = source.where((t) => t.completed).toList()
                    ..sort((a, b) {
                      // Completed ones: most recent due date first.
                      final ad = a.dueDate;
                      final bd = b.dueDate;
                      if (ad == null && bd == null) return 0;
                      if (ad == null) return 1;
                      if (bd == null) return -1;
                      return bd.compareTo(ad);
                    });
                  final list = _showCompleted ? completed : pending;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'Tasks',
                            style: GoogleFonts.manrope(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.8,
                              color: palette.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SegmentedToggle(
                          palette: palette,
                          pendingCount: pending.length,
                          completedCount: completed.length,
                          showCompleted: _showCompleted,
                          onChanged: (v) => setState(() => _showCompleted = v),
                        ),
                        const SizedBox(height: 16),
                        if (list.isEmpty)
                          _EmptyTasksCard(
                            palette: palette,
                            showCompleted: _showCompleted,
                          )
                        else
                          ...list.asMap().entries.map(
                                (entry) => _TaskCard(
                                  task: entry.value,
                                  palette: palette,
                                  primaryEmphasis: !_showCompleted &&
                                      (entry.key == 0 ||
                                          entry.value.highlighted),
                                  dueLabel:
                                      _formatDueLabel(entry.value.dueDate),
                                  dueIcon: _dueIcon(entry.value.dueDate),
                                  onToggle: () => _toggleTask(
                                    entry.value,
                                    !entry.value.completed,
                                  ),
                                  onDelete: entry.value.id.startsWith('demo_')
                                      ? null
                                      : () => TaskService.deleteTask(
                                            entry.value.id,
                                          ),
                                  onEdit: entry.value.id.startsWith('demo_')
                                      ? null
                                      : () => _openEditTask(entry.value),
                                ),
                              ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(_TaskPalette palette) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTaskScreen()),
        );
      },
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: IslaColors.cyanToBlue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(Icons.add_rounded, size: 32, color: palette.fabIcon),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final _TaskPalette palette;
  final int pendingCount;
  final int completedCount;
  final bool showCompleted;
  final ValueChanged<bool> onChanged;

  const _SegmentedToggle({
    required this.palette,
    required this.pendingCount,
    required this.completedCount,
    required this.showCompleted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: palette.glassPanel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.outlineSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segmentButton(
              label: 'Pending',
              count: pendingCount,
              active: !showCompleted,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _segmentButton(
              label: 'Completed',
              count: completedCount,
              active: showCompleted,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentButton({
    required String label,
    required int count,
    required bool active,
    required VoidCallback onTap,
  }) {
    final textColor = active ? palette.primary : palette.onSurfaceMute;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: active ? palette.segmentActive : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final _TaskVm task;
  final _TaskPalette palette;
  final bool primaryEmphasis;
  final String dueLabel;
  final IconData dueIcon;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _TaskCard({
    required this.task,
    required this.palette,
    required this.primaryEmphasis,
    required this.dueLabel,
    required this.dueIcon,
    required this.onToggle,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = primaryEmphasis ? palette.activeCard : palette.card;
    final categoryColor =
        primaryEmphasis ? palette.tertiary : palette.onSurfaceMute;

    final cardWidget = GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border(
            left: BorderSide(
              color: primaryEmphasis ? palette.primary : Colors.transparent,
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: Icon(
                  task.completed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color:
                      task.completed ? palette.primary : palette.onSurfaceMute,
                  size: 30,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: GoogleFonts.manrope(
                      color: palette.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (task.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      task.description,
                      style: GoogleFonts.inter(
                        color: palette.onSurfaceMute,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(dueIcon, color: palette.primary, size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          dueLabel,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: palette.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: palette.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Text(
                        task.category,
                        style: GoogleFonts.inter(
                          color: categoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onDelete == null) return cardWidget;
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: palette.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Delete Task?',
              style: GoogleFonts.manrope(
                color: palette.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'This will permanently remove "${task.title}".',
              style: GoogleFonts.inter(
                color: palette.onSurfaceMute,
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: palette.onSurfaceMute),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Delete',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF4E4E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ) ??
            false;
      },
      onDismissed: (_) => onDelete!(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4E4E),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      child: cardWidget,
    );
  }
}

class _EmptyTasksCard extends StatelessWidget {
  final _TaskPalette palette;
  final bool showCompleted;

  const _EmptyTasksCard({required this.palette, required this.showCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.outlineSoft),
      ),
      child: Column(
        children: [
          Icon(
            showCompleted ? Icons.done_all_rounded : Icons.task_alt_rounded,
            color: palette.primary,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            showCompleted
                ? 'No completed tasks yet.'
                : 'No pending tasks right now.',
            style: GoogleFonts.inter(
              color: palette.onSurfaceMute,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskVm {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final String category;
  final bool completed;
  final bool highlighted;
  final String type;
  final String priority;
  final String subject;

  const _TaskVm({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.category,
    required this.completed,
    this.highlighted = false,
    this.type = 'Assignment',
    this.priority = 'Medium',
    this.subject = '',
  });

  _TaskVm copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? category,
    bool? completed,
    bool? highlighted,
    String? type,
    String? priority,
    String? subject,
  }) {
    return _TaskVm(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      completed: completed ?? this.completed,
      highlighted: highlighted ?? this.highlighted,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      subject: subject ?? this.subject,
    );
  }
}

class _TaskPalette {
  final Color background;
  final Color appBarBackground;
  final Color navBackground;
  final Color glassPanel;
  final Color segmentActive;
  final Color card;
  final Color activeCard;
  final Color surfaceHigh;
  final Color primary;
  final Color tertiary;
  final Color onSurface;
  final Color onSurfaceMute;
  final Color outline;
  final Color outlineSoft;
  final Color fabIcon;

  const _TaskPalette({
    required this.background,
    required this.appBarBackground,
    required this.navBackground,
    required this.glassPanel,
    required this.segmentActive,
    required this.card,
    required this.activeCard,
    required this.surfaceHigh,
    required this.primary,
    required this.tertiary,
    required this.onSurface,
    required this.onSurfaceMute,
    required this.outline,
    required this.outlineSoft,
    required this.fabIcon,
  });

  factory _TaskPalette.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (isDark) {
      return _TaskPalette(
        background: IslaColors.background,
        appBarBackground: IslaColors.background.withValues(alpha: 0.95),
        navBackground: IslaColors.background.withValues(alpha: 0.92),
        glassPanel: IslaColors.surfaceContainer.withValues(alpha: 0.6),
        segmentActive: IslaColors.surfaceContainer,
        card: IslaColors.surfaceDim,
        activeCard: IslaColors.surfaceContainerLow,
        surfaceHigh: IslaColors.surfaceContainerHigh,
        primary: IslaColors.primary,
        tertiary: IslaColors.tertiary,
        onSurface: IslaColors.onSurface,
        onSurfaceMute: IslaColors.onSurfaceVariant,
        outline: IslaColors.outline,
        outlineSoft: IslaColors.outlineVariant.withValues(alpha: 0.4),
        fabIcon: IslaColors.onPrimaryContainer,
      );
    }

    return const _TaskPalette(
      background: Color(0xFFF4FBFE),
      appBarBackground: Color(0xF8FFFFFF),
      navBackground: Color(0xF8FFFFFF),
      glassPanel: Color(0xFFEAF2F6),
      segmentActive: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      activeCard: Color(0xFFEFFAFF),
      surfaceHigh: Color(0xFFE5F0F5),
      primary: Color(0xFF007E90),
      tertiary: Color(0xFF316FBC),
      onSurface: Color(0xFF0F1A1F),
      onSurfaceMute: Color(0xFF5A6770),
      outline: Color(0xFF9AA7AF),
      outlineSoft: Color(0xFFD4DEE4),
      fabIcon: Colors.white,
    );
  }
}
