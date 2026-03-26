import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';

class GPACalculatorScreen extends StatefulWidget {
  const GPACalculatorScreen({super.key});

  @override
  State<GPACalculatorScreen> createState() => _GPACalculatorScreenState();
}

class _GPACalculatorScreenState extends State<GPACalculatorScreen> {
  final List<Map<String, dynamic>> _courses = [
    {'name': 'Data Structures', 'code': 'BCS2033', 'credit': 3, 'grade': 'A-'},
    {'name': 'Software Engineering', 'code': 'BCS3012', 'credit': 3, 'grade': 'B+'},
    {'name': 'Database Systems', 'code': 'BCS2042', 'credit': 3, 'grade': 'A'},
    {'name': 'Web Development', 'code': 'BCS4051', 'credit': 3, 'grade': 'B'},
  ];

  final List<String> _grades = ['A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'F'];
  
  final Map<String, double> _gradePoints = {
    'A': 4.00,
    'A-': 3.67,
    'B+': 3.33,
    'B': 3.00,
    'B-': 2.67,
    'C+': 2.33,
    'C': 2.00,
    'C-': 1.67,
    'D+': 1.33,
    'D': 1.00,
    'F': 0.00,
  };

  double _calculateGPA() {
    if (_courses.isEmpty) return 0.0;
    
    double totalPoints = 0;
    int totalCredits = 0;
    
    for (var course in _courses) {
      final credit = course['credit'] as int;
      final grade = course['grade'] as String;
      totalPoints += credit * (_gradePoints[grade] ?? 0);
      totalCredits += credit;
    }
    
    return totalCredits > 0 ? totalPoints / totalCredits : 0.0;
  }

  void _addCourse() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddCourseBottomSheet(
        onAdd: (course) {
          setState(() => _courses.add(course));
        },
        grades: _grades,
      ),
    );
  }

  void _removeCourse(int index) {
    setState(() => _courses.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final gpa = _calculateGPA();
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('GPA Calculator'),
      ),
      body: Column(
        children: [
          // GPA Display
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gpa >= 3.5
                      ? AppTheme.success
                      : gpa >= 3.0
                          ? AppTheme.primaryColor
                          : gpa >= 2.0
                              ? AppTheme.warning
                              : AppTheme.error,
                  gpa >= 3.5
                      ? AppTheme.success.withOpacity(0.8)
                      : gpa >= 3.0
                          ? AppTheme.primaryLight
                          : gpa >= 2.0
                              ? AppTheme.warning.withOpacity(0.8)
                              : AppTheme.error.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppTheme.borderRadiusLarge,
            ),
            child: Column(
              children: [
                Text(
                  'Calculated GPA',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  gpa.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    gpa >= 3.5
                        ? "Dean's List"
                        : gpa >= 3.0
                            ? 'Good Standing'
                            : gpa >= 2.0
                                ? 'Satisfactory'
                                : 'Needs Improvement',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GPAStatChip(
                      label: 'Total Credits',
                      value: '${_courses.fold(0, (sum, c) => sum + (c['credit'] as int))}',
                    ),
                    const SizedBox(width: 16),
                    _GPAStatChip(
                      label: 'Courses',
                      value: '${_courses.length}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Course List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Courses', style: AppTheme.headingSmall),
                TextButton.icon(
                  onPressed: _addCourse,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Course'),
                ),
              ],
            ),
          ),
          
          // Course List
          Expanded(
            child: _courses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 64,
                          color: AppTheme.textLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No courses added yet',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _addCourse,
                          child: const Text('Add Your First Course'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) {
                      final course = _courses[index];
                      return _CourseCard(
                        name: course['name'],
                        code: course['code'],
                        credit: course['credit'],
                        grade: course['grade'],
                        gradePoints: _gradePoints,
                        grades: _grades,
                        onGradeChanged: (newGrade) {
                          setState(() => _courses[index]['grade'] = newGrade);
                        },
                        onDelete: () => _removeCourse(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GPAStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _GPAStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final String name;
  final String code;
  final int credit;
  final String grade;
  final Map<String, double> gradePoints;
  final List<String> grades;
  final ValueChanged<String> onGradeChanged;
  final VoidCallback onDelete;

  const _CourseCard({
    required this.name,
    required this.code,
    required this.credit,
    required this.grade,
    required this.gradePoints,
    required this.grades,
    required this.onGradeChanged,
    required this.onDelete,
  });

  Color _getGradeColor() {
    final points = gradePoints[grade] ?? 0;
    if (points >= 3.5) return AppTheme.success;
    if (points >= 3.0) return AppTheme.primaryColor;
    if (points >= 2.0) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.borderRadiusMedium,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Course Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTheme.labelMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
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
                        code,
                        style: AppTheme.bodySmall.copyWith(fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$credit Credits',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Grade Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getGradeColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getGradeColor().withOpacity(0.3)),
            ),
            child: DropdownButton<String>(
              value: grade,
              underline: const SizedBox(),
              isDense: true,
              style: TextStyle(
                color: _getGradeColor(),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              items: grades.map((g) {
                return DropdownMenuItem(value: g, child: Text(g));
              }).toList(),
              onChanged: (value) {
                if (value != null) onGradeChanged(value);
              },
            ),
          ),
          
          // Delete Button
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 20),
            color: AppTheme.textLight,
          ),
        ],
      ),
    );
  }
}

class _AddCourseBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  final List<String> grades;

  const _AddCourseBottomSheet({
    required this.onAdd,
    required this.grades,
  });

  @override
  State<_AddCourseBottomSheet> createState() => _AddCourseBottomSheetState();
}

class _AddCourseBottomSheetState extends State<_AddCourseBottomSheet> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  int _credit = 3;
  String _grade = 'B+';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Add Course', style: AppTheme.headingSmall),
          const SizedBox(height: 24),
          
          // Course Name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Course Name',
              hintText: 'e.g., Data Structures',
            ),
          ),
          const SizedBox(height: 16),
          
          // Course Code
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Course Code',
              hintText: 'e.g., BCS2033',
            ),
          ),
          const SizedBox(height: 16),
          
          // Credit Hours & Grade
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Credit Hours', style: AppTheme.labelMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [1, 2, 3, 4].map((c) {
                        final isSelected = _credit == c;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => setState(() => _credit = c),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '$c',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Grade', style: AppTheme.labelMedium),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _grade,
                      underline: const SizedBox(),
                      items: widget.grades.map((g) {
                        return DropdownMenuItem(value: g, child: Text(g));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _grade = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Add Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty &&
                    _codeController.text.isNotEmpty) {
                  widget.onAdd({
                    'name': _nameController.text,
                    'code': _codeController.text,
                    'credit': _credit,
                    'grade': _grade,
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Add Course'),
            ),
          ),
        ],
      ),
    );
  }
}
