import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/nav_controller.dart';
import '../../services/task_service.dart';
import '../../widgets/confetti_overlay.dart';
import '../../widgets/isla_logo.dart';
import '../../widgets/notifications_inbox_sheet.dart';
import '../planner/add_task_screen.dart';

enum _TimeGroup { overdue, morning, afternoon, evening, anytime }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final Map<String, bool> _demoCompletion = <String, bool>{};
  final Map<String, bool> _sectionCollapsed = {};

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
        estimatedMinutes: (task['estimatedMinutes'] as num?)?.toInt() ?? 0,
        setReminder: task['setReminder'] as bool? ?? true,
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
    if (dueDate == null) return Icons.calendar_today_rounded;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final dayDiff = dueDay.difference(today).inDays;

    if (dayDiff == 0) return Icons.access_time_rounded;
    if (dayDiff == 1) return Icons.calendar_today_rounded;
    return Icons.calendar_today_rounded;
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

  /// Commit the completion change to data. Called by [_TaskTile] AFTER its
  /// check/exit animation has played (on complete) or immediately (on uncheck).
  void _commitToggle(_TaskVm task, bool value) {
    if (task.id.startsWith('demo_')) {
      setState(() => _demoCompletion[task.id] = value);
      return;
    }
    if (task.id.isEmpty) return;
    TaskService.toggleTask(task.id, value);
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
          initialEstimatedMinutes: task.estimatedMinutes,
          initialSetReminder: task.setReminder,
        ),
      ),
    );
  }

  void _showNotificationsSheet() => showIslaNotificationsInbox(context);

  // ── Time grouping helpers ──────────────────────────────────────────────────

  _TimeGroup _timeGroupFor(_TaskVm task) {
    if (task.dueDate == null) return _TimeGroup.anytime;
    if (task.dueDate!.isBefore(DateTime.now())) return _TimeGroup.overdue;
    final h = task.dueDate!.hour;
    if (h >= 5 && h < 12) return _TimeGroup.morning;
    if (h >= 12 && h < 18) return _TimeGroup.afternoon;
    if (h >= 18 && h < 23) return _TimeGroup.evening;
    return _TimeGroup.anytime;
  }

  String _groupLabel(_TimeGroup g) {
    switch (g) {
      case _TimeGroup.overdue: return 'OVERDUE';
      case _TimeGroup.morning: return 'MORNING';
      case _TimeGroup.afternoon: return 'AFTERNOON';
      case _TimeGroup.evening: return 'EVENING';
      case _TimeGroup.anytime: return 'ANYTIME';
    }
  }

  IconData _groupIcon(_TimeGroup g) {
    switch (g) {
      case _TimeGroup.overdue: return Icons.warning_amber_rounded;
      case _TimeGroup.morning: return Icons.wb_twilight_rounded;
      case _TimeGroup.afternoon: return Icons.wb_sunny_rounded;
      case _TimeGroup.evening: return Icons.nightlight_round;
      case _TimeGroup.anytime: return Icons.access_time_rounded;
    }
  }

  Color _groupColor(_TimeGroup g, _TaskPalette palette) {
    switch (g) {
      case _TimeGroup.overdue: return const Color(0xFFFF4E4E);
      case _TimeGroup.morning: return const Color(0xFFFFB347);
      case _TimeGroup.afternoon: return const Color(0xFF00C2D4);
      case _TimeGroup.evening: return const Color(0xFF8B5CF6);
      case _TimeGroup.anytime: return palette.onSurfaceMute;
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'assignment': return Icons.assignment_rounded;
      case 'exam': return Icons.quiz_rounded;
      case 'revision': return Icons.menu_book_rounded;
      case 'quiz': return Icons.help_outline_rounded;
      case 'project': return Icons.work_rounded;
      default: return Icons.task_alt_rounded;
    }
  }

  Color _colorForType(String type, _TaskPalette palette) {
    switch (type.toLowerCase()) {
      case 'assignment': return const Color(0xFF00C2D4);
      case 'exam': return const Color(0xFFFF4E4E);
      case 'revision': return const Color(0xFF8B5CF6);
      case 'quiz': return const Color(0xFFFFB347);
      case 'project': return const Color(0xFF10B981);
      default: return palette.primary;
    }
  }

  Widget _buildDateHeader(int total, int done, _TaskPalette palette) {
    final now = DateTime.now();
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                days[now.weekday - 1],
                style: GoogleFonts.manrope(
                  fontSize: 38, fontWeight: FontWeight.w800,
                  letterSpacing: -1.2, color: palette.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.check_circle_outline_rounded, color: palette.primary, size: 14),
                const SizedBox(width: 5),
                Text(
                  '$done / $total',
                  style: GoogleFonts.manrope(
                    color: palette.primary, fontSize: 13, fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ],
        ),
        Text(
          '${months[now.month - 1]} ${now.day}, ${now.year}',
          style: GoogleFonts.inter(color: palette.onSurfaceMute, fontSize: 13),
        ),
      ],
    );
  }

  List<Widget> _buildGroupedSections(List<_TaskVm> tasks, _TaskPalette palette) {
    final groups = <_TimeGroup, List<_TaskVm>>{
      for (final g in _TimeGroup.values) g: [],
    };
    for (final t in tasks) groups[_timeGroupFor(t)]!.add(t);

    final widgets = <Widget>[];
    for (final group in _TimeGroup.values) {
      final groupTasks = groups[group]!;
      if (groupTasks.isEmpty) continue;
      final label = _groupLabel(group);
      final collapsed = _sectionCollapsed[label] ?? false;
      final color = _groupColor(group, palette);

      // Section header
      widgets.add(
        GestureDetector(
          onTap: () => setState(() => _sectionCollapsed[label] = !collapsed),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Icon(_groupIcon(group), color: color, size: 15),
              const SizedBox(width: 8),
              Text(
                '$label (${groupTasks.length})',
                style: GoogleFonts.manrope(
                  color: color, fontWeight: FontWeight.w700,
                  fontSize: 11, letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTaskScreen())),
                child: Icon(Icons.add_rounded, color: color.withValues(alpha: 0.8), size: 18),
              ),
              const SizedBox(width: 8),
              Icon(
                collapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                color: color.withValues(alpha: 0.7), size: 18,
              ),
            ]),
          ),
        ),
      );

      if (!collapsed) {
        for (final task in groupTasks) {
          widgets.add(_buildNewTaskCard(task, palette));
        }
      }
      widgets.add(const SizedBox(height: 4));
    }
    return widgets;
  }

  Widget _buildNewTaskCard(_TaskVm task, _TaskPalette palette,
      {bool inCompletedSection = false}) {
    return _TaskTile(
      key: ValueKey(
          'tile_${inCompletedSection ? 'done' : 'pending'}_${task.id}'),
      task: task,
      palette: palette,
      typeColor: _colorForType(task.type, palette),
      typeIcon: _iconForType(task.type),
      dueLabel: _formatDueLabel(task.dueDate),
      inCompletedSection: inCompletedSection,
      onToggle: (value) => _commitToggle(task, value),
      onConfetti: () => ConfettiBurst.fire(context),
      onEdit: task.id.startsWith('demo_') ? null : () => _openEditTask(task),
      onDelete: task.id.startsWith('demo_')
          ? null
          : () => TaskService.deleteTask(task.id),
    );
  }

  Widget _buildCompletedSection(List<_TaskVm> completed, _TaskPalette palette) {
    final collapsed = _sectionCollapsed['DONE'] ?? true;
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _sectionCollapsed['DONE'] = !collapsed),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.outlineSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.done_all_rounded, color: palette.onSurfaceMute, size: 15),
              const SizedBox(width: 8),
              Text(
                'COMPLETED (${completed.length})',
                style: GoogleFonts.manrope(color: palette.onSurfaceMute, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.2),
              ),
              const Spacer(),
              Icon(collapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                  color: palette.onSurfaceMute, size: 18),
            ]),
          ),
        ),
        if (!collapsed) ...[
          const SizedBox(height: 8),
          ...completed.map((task) =>
              _buildNewTaskCard(task, palette, inCompletedSection: true)),
        ],
      ],
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<NavController>().goTo(6);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign Out'),
              onTap: () async {
                Navigator.pop(ctx);
                await AuthService.signOut();
                if (mounted) context.goNamed('splash');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  IconButton(
                    onPressed: _showNotificationsSheet,
                    icon: Icon(Icons.notifications_outlined,
                        color: palette.onSurfaceMute, size: 22),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  const SizedBox(width: 4),
                  IslaProfileAvatar(
                    radius: 17,
                    onTap: _showProfileSheet,
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
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateHeader(source.length, completed.length, palette),
                        const SizedBox(height: 20),
                        if (pending.isEmpty)
                          _EmptyTasksCard(palette: palette, showCompleted: false)
                        else
                          ..._buildGroupedSections(pending, palette),
                        if (completed.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildCompletedSection(completed, palette),
                        ],
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
        child: Icon(Icons.add_rounded, size: 28, color: palette.fabIcon),
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
                  size: 26,
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
                      Icon(dueIcon, color: palette.primary, size: 16),
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
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
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
            showCompleted ? Icons.done_all_rounded : Icons.checklist_rounded,
            color: palette.primary,
            size: 26,
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
  final int estimatedMinutes;
  final bool setReminder;

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
    this.estimatedMinutes = 0,
    this.setReminder = true,
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
    int? estimatedMinutes,
    bool? setReminder,
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
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      setReminder: setReminder ?? this.setReminder,
    );
  }
}

// ── Task tile with smooth completion animation ───────────────────────────────

class _TaskTile extends StatefulWidget {
  final _TaskVm task;
  final _TaskPalette palette;
  final Color typeColor;
  final IconData typeIcon;
  final String dueLabel;
  final bool inCompletedSection;
  final void Function(bool value) onToggle;
  final VoidCallback onConfetti;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TaskTile({
    super.key,
    required this.task,
    required this.palette,
    required this.typeColor,
    required this.typeIcon,
    required this.dueLabel,
    required this.inCompletedSection,
    required this.onToggle,
    required this.onConfetti,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _collapse;
  late final Animation<double> _fade;
  late final Animation<double> _slide;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 620));
    // Hold ~260ms (check + strikethrough) then collapse/fade/slide away.
    _collapse = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.42, 1.0, curve: Curves.easeInCubic));
    _fade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.42, 0.85, curve: Curves.easeOut));
    _slide = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.42, 1.0, curve: Curves.easeIn));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onToggle(true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onCheck() {
    if (widget.task.completed) {
      // Already complete → uncheck immediately (moves back to its time group).
      widget.onToggle(false);
      return;
    }
    if (_completing) return;
    widget.onConfetti();
    setState(() => _completing = true);
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final showChecked = widget.task.completed || _completing;
    final dim = widget.inCompletedSection || _completing;

    Widget card = GestureDetector(
      onTap: widget.onEdit,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dim ? 0.55 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _completing
                  ? p.primary.withValues(alpha: 0.5)
                  : p.outlineSoft,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.typeIcon, color: widget.typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: GoogleFonts.manrope(
                        color: p.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        decoration: showChecked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: p.onSurfaceMute,
                      ),
                      child: Text(widget.task.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      if (widget.task.subject.isNotEmpty) ...[
                        Text(widget.task.subject,
                            style: GoogleFonts.inter(
                                color: p.onSurfaceMute, fontSize: 11)),
                        Text(' · ',
                            style: GoogleFonts.inter(
                                color: p.onSurfaceMute, fontSize: 11)),
                      ],
                      if (widget.task.estimatedMinutes > 0)
                        Text('${widget.task.estimatedMinutes}m',
                            style: GoogleFonts.inter(
                                color: p.onSurfaceMute, fontSize: 11)),
                    ]),
                    const SizedBox(height: 4),
                    Text(widget.dueLabel,
                        style: GoogleFonts.inter(
                            color: widget.typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _AnimatedCheckbox(
                completed: showChecked,
                activeColor: p.primary,
                inactiveColor: p.onSurfaceMute.withValues(alpha: 0.35),
                onTap: _onCheck,
              ),
            ],
          ),
        ),
      ),
    );

    // While completing: collapse height + fade + slide right.
    if (_completing) {
      card = AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: (1 - _collapse.value).clamp(0.0, 1.0),
            child: Opacity(
              opacity: (1 - _fade.value).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(_slide.value * 60, 0),
                child: child,
              ),
            ),
          ),
        ),
        child: card,
      );
    }

    if (widget.onDelete == null) return card;

    return Dismissible(
      key: ValueKey('dismiss_${widget.task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async =>
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: p.card,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Delete Task?',
                  style: GoogleFonts.manrope(
                      color: p.onSurface, fontWeight: FontWeight.w700)),
              content: Text('This will permanently remove "${widget.task.title}".',
                  style: GoogleFonts.inter(
                      color: p.onSurfaceMute, fontSize: 14)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(color: p.onSurfaceMute))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Delete',
                        style: GoogleFonts.inter(
                            color: const Color(0xFFFF4E4E),
                            fontWeight: FontWeight.w700))),
              ],
            ),
          ) ??
          false,
      onDismissed: (_) => widget.onDelete!(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: const Color(0xFFFF4E4E),
            borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      child: card,
    );
  }
}

// ── Animated checkbox ─────────────────────────────────────────────────────────

class _AnimatedCheckbox extends StatefulWidget {
  final bool completed;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _AnimatedCheckbox({
    required this.completed,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  State<_AnimatedCheckbox> createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<_AnimatedCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.85), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: widget.completed
              ? Icon(Icons.check_circle_rounded,
                  key: const ValueKey('checked'),
                  color: widget.activeColor,
                  size: 28)
                  .animate()
                  .scale(duration: 200.ms, curve: Curves.elasticOut)
              : Icon(Icons.radio_button_unchecked_rounded,
                  key: const ValueKey('unchecked'),
                  color: widget.inactiveColor,
                  size: 28),
        ),
      ),
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
