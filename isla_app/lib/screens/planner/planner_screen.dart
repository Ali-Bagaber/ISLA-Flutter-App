import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import 'add_task_screen.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  final List<Map<String, dynamic>> _tasks = [
    {
      'title': 'Assignment 2 - OOP',
      'subject': 'BCS2033',
      'dueDate': DateTime.now().add(const Duration(days: 1)),
      'type': 'Assignment',
      'priority': 'High',
      'completed': false,
      'color': AppTheme.error,
    },
    {
      'title': 'Midterm Exam - Database',
      'subject': 'BCS2042',
      'dueDate': DateTime.now().add(const Duration(days: 3)),
      'type': 'Exam',
      'priority': 'High',
      'completed': false,
      'color': AppTheme.warning,
    },
    {
      'title': 'Read Chapter 5 - SE',
      'subject': 'BCS3012',
      'dueDate': DateTime.now().add(const Duration(days: 5)),
      'type': 'Revision',
      'priority': 'Medium',
      'completed': false,
      'color': AppTheme.info,
    },
    {
      'title': 'Lab Report - Web Dev',
      'subject': 'BCS4051',
      'dueDate': DateTime.now().add(const Duration(days: 7)),
      'type': 'Assignment',
      'priority': 'Medium',
      'completed': true,
      'color': AppTheme.success,
    },
    {
      'title': 'Quiz Preparation',
      'subject': 'BCS2033',
      'dueDate': DateTime.now().add(const Duration(days: 2)),
      'type': 'Revision',
      'priority': 'Low',
      'completed': false,
      'color': AppTheme.primaryColor,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _tasks.where((task) {
      final taskDate = task['dueDate'] as DateTime;
      return taskDate.year == day.year &&
          taskDate.month == day.month &&
          taskDate.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Study Planner'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'List View'),
            Tab(text: 'Calendar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListView(isDark),
          _buildCalendarView(isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildListView(bool isDark) {
    final pendingTasks = _tasks.where((t) => !t['completed']).toList();
    final completedTasks = _tasks.where((t) => t['completed']).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.pending_actions_rounded,
                  value: '${pendingTasks.length}',
                  label: 'Pending',
                  color: AppTheme.warning,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline_rounded,
                  value: '${completedTasks.length}',
                  label: 'Completed',
                  color: AppTheme.success,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.priority_high_rounded,
                  value: '${pendingTasks.where((t) => t['priority'] == 'High').length}',
                  label: 'Urgent',
                  color: AppTheme.error,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Pending Tasks
          Text(
            'Pending Tasks', 
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 12),
          
          if (pendingTasks.isEmpty)
            _EmptyState(
              icon: Icons.task_alt_rounded,
              message: 'No pending tasks!',
            )
          else
            ...pendingTasks.map((task) => _TaskCard(
              task: task,
              isDark: isDark,
              onToggle: () {
                setState(() {
                  task['completed'] = !task['completed'];
                });
              },
            )),
          
          const SizedBox(height: 24),
          
          // Completed Tasks
          if (completedTasks.isNotEmpty) ...[
            Text(
              'Completed', 
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),
            ...completedTasks.map((task) => _TaskCard(
              task: task,
              isDark: isDark,
              onToggle: () {
                setState(() {
                  task['completed'] = !task['completed'];
                });
              },
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarView(bool isDark) {
    return Column(
      children: [
        // Calendar
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(isDark),
            borderRadius: AppTheme.borderRadiusLarge,
            boxShadow: AppTheme.cardShadow,
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: const TextStyle(color: AppTheme.error),
              selectedDecoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppTheme.warning,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
          ),
        ),
        
        // Selected Day Tasks
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasks for ${_selectedDay?.day}/${_selectedDay?.month}/${_selectedDay?.year}',
                  style: AppTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _getEventsForDay(_selectedDay ?? _focusedDay).isEmpty
                      ? _EmptyState(
                          icon: Icons.event_available_rounded,
                          message: 'No tasks for this day',
                        )
                      : ListView.builder(
                          itemCount: _getEventsForDay(_selectedDay ?? _focusedDay).length,
                          itemBuilder: (context, index) {
                            final task = _getEventsForDay(_selectedDay ?? _focusedDay)[index];
                            return _TaskCard(
                              task: task,
                              onToggle: () {
                                setState(() {
                                  task['completed'] = !task['completed'];
                                });
                              },
                              isDark: isDark,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.getCardColor(isDark) : color.withOpacity(0.1),
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.headingMedium.copyWith(color: color),
          ),
          Text(
            label, 
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.getTextSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onToggle;
  final bool isDark;

  const _TaskCard({
    required this.task, 
    required this.onToggle,
    required this.isDark,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference < 0) return 'Overdue';
    return 'In $difference days';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = task['completed'] as bool;
    final dueDate = task['dueDate'] as DateTime;
    final isOverdue = dueDate.isBefore(DateTime.now()) && !isCompleted;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: isDark ? [] : AppTheme.cardShadow,
        border: isOverdue
            ? Border.all(color: AppTheme.error.withOpacity(0.5))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppTheme.borderRadiusMedium,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.success
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted
                          ? AppTheme.success
                          : AppTheme.textLight,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              
              // Task Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['title'],
                      style: AppTheme.labelMedium.copyWith(
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCompleted
                            ? AppTheme.textLight
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (task['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task['subject'],
                            style: TextStyle(
                              color: task['color'] as Color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task['type'],
                            style: AppTheme.bodySmall.copyWith(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Due Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: isOverdue ? AppTheme.error : AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(dueDate),
                    style: AppTheme.bodySmall.copyWith(
                      color: isOverdue ? AppTheme.error : AppTheme.textSecondary,
                      fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.textLight),
          const SizedBox(height: 12),
          Text(message, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
