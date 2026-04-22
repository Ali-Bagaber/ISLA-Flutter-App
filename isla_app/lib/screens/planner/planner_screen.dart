import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/isla_logo.dart';
import 'add_task_screen.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  bool _showCompleted = false;

  DateTime? _getDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
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

  String _formatDeadline(DateTime? dueDate) {
    if (dueDate == null) return 'No deadline';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = dueDay.difference(today).inDays;

    if (diff == 0) return 'Today, ${_formatTime(dueDate)}';
    if (diff == 1) return 'Tomorrow';
    if (diff < 0) return 'Overdue';
    if (diff <= 6) return 'In $diff days';
    return '${_monthShort(dueDate.month)} ${dueDate.day}';
  }

  String _formatMiniSchedule(DateTime? dueDate) {
    if (dueDate == null) return 'No schedule';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = dueDay.difference(today).inDays;

    if (diff == 0) return '${_formatTime(dueDate)} • Today';
    if (diff == 1) return '${_formatTime(dueDate)} • Tomorrow';
    if (diff < 0) return '${_formatTime(dueDate)} • Overdue';
    return '${_formatTime(dueDate)} • ${_monthShort(dueDate.month)} ${dueDate.day}';
  }

  bool _isDueToday(DateTime? dueDate) {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueDay == today;
  }

  bool _isUrgent(Map<String, dynamic> task) {
    final priority = (task['priority'] ?? '').toString().toLowerCase();
    if (priority == 'high') return true;

    final dueDate = _getDateTime(task['dueDate']);
    if (dueDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueDay.difference(today).inDays <= 1;
  }

  String _taskCategory(Map<String, dynamic> task) {
    final type = (task['type'] ?? '').toString().trim();
    final subject = (task['subject'] ?? '').toString().trim();
    if (type.isNotEmpty) return type.toUpperCase();
    if (subject.isNotEmpty && subject.toLowerCase() != 'no subject') {
      return subject.toUpperCase();
    }
    return 'TASK';
  }

  Color _subjectColor(String subject) {
    const subjects = ['BCS2033', 'BCS3012', 'BCS2042', 'BCS4051'];
    final index = subjects.indexOf(subject);
    if (index == -1) return AppTheme.primaryColor;
    return AppTheme.subjectColors[index % AppTheme.subjectColors.length];
  }

  Future<void> _openAddTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    );
  }

  Future<void> _openEditTask(Map<String, dynamic> task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          taskId: (task['id'] ?? '').toString(),
          initialTitle: (task['title'] ?? '').toString(),
          initialDescription: (task['description'] ?? '').toString(),
          initialSubject: (task['subject'] ?? '').toString(),
          initialType:
              (task['type'] ?? task['taskType'] ?? 'Assignment').toString(),
          initialPriority: (task['priority'] ?? 'Medium').toString(),
          initialDueDate: _getDateTime(task['dueDate']),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final background = AppTheme.getBackgroundColor(isDark);
    final card = AppTheme.getCardColor(isDark);
    final primary = AppTheme.primaryColor;
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);

    return Scaffold(
      backgroundColor: background,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.32),
                blurRadius: 24,
                spreadRadius: 3,
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'plannerFab',
            onPressed: _openAddTask,
            backgroundColor: primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_rounded, size: 34),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: SafeArea(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: TaskService.watchTasks(),
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? [];

              final pendingTasks = tasks
                  .where((task) => !(task['completed'] as bool? ?? false))
                  .toList();
              final completedTasks = tasks
                  .where((task) => task['completed'] as bool? ?? false)
                  .toList();

              final list = _showCompleted ? completedTasks : pendingTasks;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
                      child: Row(
                        children: [
                          Row(
                            children: const [
                              IslaLogo(),
                            ],
                          ),
                          const Spacer(),
                          const IslaProfileAvatar(),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      child: Column(
                        children: [
                          Text(
                            'Tasks',
                            style: AppTheme.headingLarge.copyWith(
                              fontSize: 58,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ORGANIZED CLARITY',
                            style: AppTheme.bodySmall.copyWith(
                              color: textSecondary,
                              letterSpacing: 3.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _TaskFilterToggle(
                            isDark: isDark,
                            showCompleted: _showCompleted,
                            pendingCount: pendingTasks.length,
                            completedCount: completedTasks.length,
                            onChanged: (next) {
                              setState(() => _showCompleted = next);
                            },
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                  ),
                  if (list.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptyTaskState(
                        isDark: isDark,
                        showCompleted: _showCompleted,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 170),
                      sliver: SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final task = list[index];
                          final dueDate = _getDateTime(task['dueDate']);
                          final title =
                              (task['title'] ?? 'Untitled Task').toString();
                          final description =
                              (task['description'] ?? '').toString().trim();
                          final isCompleted = task['completed'] == true;
                          final isUrgent = _isUrgent(task);
                          final category = _taskCategory(task);
                          final accent = _subjectColor(
                            (task['subject'] ?? '').toString(),
                          );
                          final isTodayTask = _isDueToday(dueDate);

                          final featured = isTodayTask;
                          final medium =
                              !featured && !_showCompleted && index == 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _SanctuaryTaskCard(
                              taskId: (task['id'] ?? 'task_$index').toString(),
                              isDark: isDark,
                              title: title,
                              description: description,
                              category: category,
                              deadline: _formatDeadline(dueDate),
                              miniSchedule: _formatMiniSchedule(dueDate),
                              isCompleted: isCompleted,
                              isUrgent: isUrgent,
                              featured: featured,
                              medium: medium,
                              accent: accent,
                              onToggle: () {
                                final id = task['id'] as String?;
                                if (id == null || id.isEmpty) return;
                                TaskService.toggleTask(id, !isCompleted);
                              },
                              onDelete: () {
                                final id = task['id'] as String?;
                                if (id == null || id.isEmpty) return;
                                TaskService.deleteTask(id);
                              },
                              onEdit: () => _openEditTask(task),
                              cardColor: card,
                              primary: primary,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TaskFilterToggle extends StatelessWidget {
  final bool isDark;
  final bool showCompleted;
  final int pendingCount;
  final int completedCount;
  final ValueChanged<bool> onChanged;

  const _TaskFilterToggle({
    required this.isDark,
    required this.showCompleted,
    required this.pendingCount,
    required this.completedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.getSurfaceColor(isDark);
    final active = AppTheme.primaryColor;
    final textSecondary = AppTheme.getTextSecondary(isDark);

    Widget item({
      required String label,
      required int count,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? active.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppTheme.labelMedium.copyWith(
                    color: selected ? active : textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: AppTheme.bodySmall.copyWith(
                      color: selected ? active : textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: surface.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          item(
            label: 'Pending',
            count: pendingCount,
            selected: !showCompleted,
            onTap: () => onChanged(false),
          ),
          item(
            label: 'Completed',
            count: completedCount,
            selected: showCompleted,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SanctuaryTaskCard extends StatelessWidget {
  final String taskId;
  final bool isDark;
  final String title;
  final String description;
  final String category;
  final String deadline;
  final String miniSchedule;
  final bool isCompleted;
  final bool isUrgent;
  final bool featured;
  final bool medium;
  final Color accent;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Color cardColor;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;

  const _SanctuaryTaskCard({
    required this.taskId,
    required this.isDark,
    required this.title,
    required this.description,
    required this.category,
    required this.deadline,
    required this.miniSchedule,
    required this.isCompleted,
    required this.isUrgent,
    required this.featured,
    required this.medium,
    required this.accent,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.cardColor,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = featured
        ? primary.withValues(alpha: 0.56)
        : AppTheme.getSurfaceColor(isDark).withValues(alpha: 0.58);

    return Dismissible(
      key: ValueKey(taskId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: AppTheme.error,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(featured ? 28 : 22),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: (featured ? primary : Colors.black).withValues(
                alpha: featured ? 0.2 : 0.14,
              ),
              blurRadius: featured ? 22 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (featured)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'DUE TODAY',
                      style: AppTheme.bodySmall.copyWith(
                        color: primary,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (medium)
                  Icon(
                    Icons.timer_outlined,
                    color: textSecondary,
                    size: 22,
                  )
                else
                  Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isCompleted ? AppTheme.success : accent,
                    size: 20,
                  ),
                const Spacer(),
                if (featured)
                  Icon(
                    Icons.today_rounded,
                    color: primary,
                    size: 22,
                  )
                else if (isUrgent)
                  Icon(
                    Icons.star_rounded,
                    color: primary,
                    size: 24,
                  )
                else
                  Text(
                    deadline,
                    style: AppTheme.bodySmall.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTheme.headingSmall.copyWith(
                color: textPrimary,
                fontSize: featured
                    ? 34.clamp(24, 34).toDouble()
                    : 28.clamp(20, 28).toDouble(),
                fontWeight: FontWeight.w500,
                height: 1.15,
                decoration: isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: AppTheme.bodyMedium.copyWith(
                  color: textSecondary,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (featured)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DEADLINE',
                          style: AppTheme.bodySmall.copyWith(
                            color: textSecondary,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deadline,
                          style: AppTheme.labelMedium.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 54,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: AppTheme.getSurfaceColor(isDark),
                          child: Icon(
                            Icons.person,
                            size: 12,
                            color: textSecondary,
                          ),
                        ),
                        Positioned(
                          left: 16,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: AppTheme.getSurfaceColor(isDark)
                                .withValues(alpha: 0.95),
                            child: Icon(
                              Icons.person_outline_rounded,
                              size: 12,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Text(
                    miniSchedule,
                    style: AppTheme.bodyMedium.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (isUrgent)
                    Text(
                      'Urgent',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: textSecondary,
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(isDark),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: isCompleted ? AppTheme.success : textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCompleted ? 'Completed' : 'Mark done',
                          style: AppTheme.bodySmall.copyWith(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  category,
                  style: AppTheme.bodySmall.copyWith(
                    color: accent,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  final bool isDark;
  final bool showCompleted;

  const _EmptyTaskState({
    required this.isDark,
    required this.showCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppTheme.getTextSecondary(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 140),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(isDark),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppTheme.getSurfaceColor(isDark).withValues(alpha: 0.65),
          ),
        ),
        child: Column(
          children: [
            Icon(
              showCompleted
                  ? Icons.check_circle_outline_rounded
                  : Icons.pending_actions_outlined,
              color: AppTheme.primaryColor,
              size: 38,
            ),
            const SizedBox(height: 10),
            Text(
              showCompleted
                  ? 'No completed tasks yet.'
                  : 'No pending tasks right now.',
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              showCompleted
                  ? 'Finish a task and it will appear here.'
                  : 'Tap + to create your next focused task.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
