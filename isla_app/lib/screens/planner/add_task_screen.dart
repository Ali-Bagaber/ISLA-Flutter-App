import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../services/task_service.dart';
import '../../services/document_service.dart';

class AddTaskScreen extends StatefulWidget {
  final String? taskId;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialSubject;
  final String? initialType;
  final String? initialPriority;
  final DateTime? initialDueDate;

  const AddTaskScreen({
    super.key,
    this.taskId,
    this.initialTitle,
    this.initialDescription,
    this.initialSubject,
    this.initialType,
    this.initialPriority,
    this.initialDueDate,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String? _selectedSubject;
  final _descriptionController = TextEditingController();

  String _selectedType = 'Assignment';
  String _selectedPriority = 'Medium';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 23, minute: 59);
  bool _setReminder = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null) {
      _titleController.text = widget.initialTitle ?? '';
      _descriptionController.text = widget.initialDescription ?? '';
      _selectedSubject = widget.initialSubject;
      _selectedType = widget.initialType ?? 'Assignment';
      _selectedPriority = widget.initialPriority ?? 'Medium';
      if (widget.initialDueDate != null) {
        _selectedDate = widget.initialDueDate!;
        _selectedTime = TimeOfDay.fromDateTime(widget.initialDueDate!);
      }
    }
  }

  final List<String> _taskTypes = [
    'Assignment',
    'Exam',
    'Revision',
    'Quiz',
    'Project',
    'Other',
  ];
  final List<String> _priorities = ['High', 'Medium', 'Low'];

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveTask() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final dueDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final subject = _selectedSubject ?? '';
      final subjectVal = subject.isEmpty ? 'No Subject' : subject;

      if (widget.taskId != null) {
        await TaskService.updateTask(
          widget.taskId!,
          title: _titleController.text.trim(),
          subject: subjectVal,
          dueDate: dueDateTime,
          type: _selectedType,
          priority: _selectedPriority,
          description: _descriptionController.text.trim(),
        ).timeout(const Duration(seconds: 20));
      } else {
        await TaskService.addTask(
          title: _titleController.text.trim(),
          subject: subjectVal,
          dueDate: dueDateTime,
          type: _selectedType,
          priority: _selectedPriority,
          description: _descriptionController.text.trim(),
        ).timeout(const Duration(seconds: 20));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.taskId != null
              ? 'Task updated successfully!'
              : 'Task added successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceAll('StateError: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? 'Failed to add task.' : message),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return AppTheme.error;
      case 'Medium':
        return AppTheme.warning;
      case 'Low':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final surface = AppTheme.getSurfaceColor(isDark);
    final card = AppTheme.getCardColor(isDark);
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: Text(widget.taskId != null ? 'Edit Task' : 'Add Task'),
      ),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task Title
                Text('Task Title', style: AppTheme.labelMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Enter task title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Subject
                Text('Subject / Course', style: AppTheme.labelMedium),
                const SizedBox(height: 8),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: DocumentService.watchCourses(),
                  builder: (context, coursesSnap) {
                    final courses = coursesSnap.data ?? [];
                    final items = [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('No course'),
                      ),
                      ...courses.map((c) {
                        final name = c['name'] as String? ?? '';
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        );
                      }),
                    ];
                    return DropdownButtonFormField<String>(
                      value: items.any((i) => i.value == _selectedSubject)
                          ? _selectedSubject
                          : '',
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.book_outlined),
                      ),
                      items: items,
                      onChanged: (v) => setState(() => _selectedSubject = v),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Task Type
                Text('Task Type', style: AppTheme.labelMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _taskTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedType = value!);
                  },
                ),

                const SizedBox(height: 20),

                // Due Date & Time
                Text('Due Date & Time', style: AppTheme.labelMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        borderRadius: AppTheme.borderRadiusMedium,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: AppTheme.borderRadiusMedium,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _selectTime,
                        borderRadius: AppTheme.borderRadiusMedium,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: AppTheme.borderRadiusMedium,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                color: textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _selectedTime.format(context),
                                style: AppTheme.bodyMedium.copyWith(
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Priority
                Text('Priority', style: AppTheme.labelMedium),
                const SizedBox(height: 8),
                Row(
                  children: _priorities.map((priority) {
                    final isSelected = _selectedPriority == priority;
                    final color = _getPriorityColor(priority);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: priority != _priorities.last ? 8 : 0,
                        ),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedPriority = priority),
                          borderRadius: AppTheme.borderRadiusMedium,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.15)
                                  : surface,
                              borderRadius: AppTheme.borderRadiusMedium,
                              border: Border.all(
                                color: isSelected ? color : surface,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  priority == 'High'
                                      ? Icons.keyboard_double_arrow_up_rounded
                                      : priority == 'Medium'
                                          ? Icons.drag_handle_rounded
                                          : Icons
                                              .keyboard_double_arrow_down_rounded,
                                  color: isSelected ? color : textSecondary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  priority,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: isSelected ? color : textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Description
                Text('Description (Optional)', style: AppTheme.labelMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Add more details about this task...',
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 20),

                // Reminder Toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: AppTheme.borderRadiusMedium,
                    boxShadow: isDark ? [] : AppTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Set Reminder', style: AppTheme.labelMedium),
                            Text(
                              'Get notified before due date',
                              style: AppTheme.bodySmall.copyWith(
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _setReminder,
                        onChanged: (value) =>
                            setState(() => _setReminder = value),
                        activeThumbColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Add Task',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
