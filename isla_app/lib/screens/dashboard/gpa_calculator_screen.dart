import 'package:flutter/material.dart';
import '../../services/document_service.dart';
import '../../theme/app_theme.dart';

class GPACalculatorScreen extends StatelessWidget {
  const GPACalculatorScreen({super.key});

  static const List<String> _grades = [
    'A+',
    'A',
    'A-',
    'B+',
    'B',
    'B-',
    'C+',
    'C',
    'C-',
    'D+',
    'D',
    'F',
  ];

  static const Map<String, double> _gradePoints = {
    'A+': 4.00,
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

  static double _computeGpa(List<Map<String, dynamic>> courses) {
    double pts = 0;
    int creds = 0;
    for (final c in courses) {
      final g = ((c['grade'] ?? '') as String).trim().toUpperCase();
      final cr = (c['credits'] as num? ?? 3).toInt();
      final p = _gradePoints[g];
      if (p != null && cr > 0) {
        pts += p * cr;
        creds += cr;
      }
    }
    return creds == 0 ? 0.0 : double.parse((pts / creds).toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(title: const Text('GPA Calculator')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DocumentService.watchCourses(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final courses = snap.data ?? [];
          final gpa = _computeGpa(courses);
          final totalCredits = courses.fold<int>(
              0, (s, c) => s + (c['credits'] as num? ?? 3).toInt());

          return Column(
            children: [
              // â”€â”€ GPA Banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _bannerColor(gpa),
                      _bannerColor(gpa).withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppTheme.borderRadiusLarge,
                ),
                child: Column(
                  children: [
                    Text('Calculated GPA',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      courses.isEmpty ? 'â€”' : gpa.toStringAsFixed(2),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_standing(gpa),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Chip(label: 'Total Credits', value: '$totalCredits'),
                        const SizedBox(width: 16),
                        _Chip(label: 'Courses', value: '${courses.length}'),
                      ],
                    ),
                  ],
                ),
              ),

              // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Courses', style: AppTheme.headingSmall),
                    TextButton.icon(
                      onPressed: () => _showAddSheet(context),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Course'),
                    ),
                  ],
                ),
              ),

              // â”€â”€ List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Expanded(
                child: courses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.school_outlined,
                                size: 64, color: AppTheme.textLight),
                            const SizedBox(height: 16),
                            Text('No courses yet',
                                style: AppTheme.bodyMedium
                                    .copyWith(color: AppTheme.textSecondary)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _showAddSheet(context),
                              child: const Text('Add Your First Course'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        itemCount: courses.length,
                        itemBuilder: (ctx, i) {
                          final c = courses[i];
                          final docId = c['id'] as String? ??
                              c['courseId'] as String? ??
                              '';
                          final grade = ((c['grade'] ?? '') as String)
                              .trim()
                              .toUpperCase();
                          final credits = (c['credits'] as num? ?? 3).toInt();
                          final validGrade =
                              _grades.contains(grade) ? grade : 'B+';
                          return _CourseCard(
                            name: (c['name'] as String? ?? '').trim(),
                            credits: credits,
                            grade: validGrade,
                            grades: _grades,
                            gradePoints: _gradePoints,
                            isDark: isDark,
                            onGradeChanged: (g) =>
                                DocumentService.updateCourse(docId, grade: g),
                            onCreditsChanged: (cr) =>
                                DocumentService.updateCourse(docId,
                                    credits: cr),
                            onDelete: () => DocumentService.deleteCourse(docId),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _bannerColor(double gpa) {
    if (gpa >= 3.5) return AppTheme.success;
    if (gpa >= 3.0) return AppTheme.primaryColor;
    if (gpa >= 2.0) return AppTheme.warning;
    return AppTheme.error;
  }

  String _standing(double gpa) {
    if (gpa >= 3.5) return "Dean's List";
    if (gpa >= 3.0) return 'Good Standing';
    if (gpa >= 2.0) return 'Satisfactory';
    return 'Needs Improvement';
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddCourseBottomSheet(grades: _grades),
    );
  }
}

// â”€â”€ GPA Chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }
}

// â”€â”€ Course Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _CourseCard extends StatelessWidget {
  final String name;
  final int credits;
  final String grade;
  final List<String> grades;
  final Map<String, double> gradePoints;
  final bool isDark;
  final ValueChanged<String> onGradeChanged;
  final ValueChanged<int> onCreditsChanged;
  final VoidCallback onDelete;

  const _CourseCard({
    required this.name,
    required this.credits,
    required this.grade,
    required this.grades,
    required this.gradePoints,
    required this.isDark,
    required this.onGradeChanged,
    required this.onCreditsChanged,
    required this.onDelete,
  });

  Color get _gradeColor {
    final p = gradePoints[grade] ?? 0;
    if (p >= 3.5) return AppTheme.success;
    if (p >= 3.0) return AppTheme.primaryColor;
    if (p >= 2.0) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(
          color: AppTheme.getTextSecondary(isDark).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          // Name + credit chip row
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTheme.labelMedium.copyWith(
                        color: AppTheme.getTextPrimary(isDark))),
                const SizedBox(height: 6),
                // Credit selector: 1 2 3 4
                Row(
                  children: [1, 2, 3, 4].map((c) {
                    final sel = credits == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => onCreditsChanged(c),
                        borderRadius: BorderRadius.circular(6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 32,
                          height: 28,
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.primaryColor
                                : AppTheme.getSurfaceColor(isDark),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$c',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : AppTheme.getTextSecondary(isDark),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 2),
                Text('credits',
                    style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.getTextSecondary(isDark),
                        fontSize: 10)),
              ],
            ),
          ),

          // Grade dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _gradeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gradeColor.withValues(alpha: 0.3)),
            ),
            child: DropdownButton<String>(
              value: grade,
              underline: const SizedBox(),
              isDense: true,
              dropdownColor: isDark ? const Color(0xFF1E2227) : Colors.white,
              style: TextStyle(
                  color: _gradeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
              items: grades
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onGradeChanged(v);
              },
            ),
          ),

          // Delete
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 20),
            color: AppTheme.getTextSecondary(isDark),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Add Course Bottom Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AddCourseBottomSheet extends StatefulWidget {
  final List<String> grades;
  const _AddCourseBottomSheet({required this.grades});

  @override
  State<_AddCourseBottomSheet> createState() => _AddCourseBottomSheetState();
}

class _AddCourseBottomSheetState extends State<_AddCourseBottomSheet> {
  final _nameCtrl = TextEditingController();
  int _credits = 3;
  String _grade = 'B+';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Add Course', style: AppTheme.headingSmall),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Course Name',
              hintText: 'e.g., Data Structures',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Credit Hours', style: AppTheme.labelMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [1, 2, 3, 4].map((c) {
                        final sel = _credits == c;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => setState(() => _credits = c),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppTheme.primaryColor
                                      : AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('$c',
                                      style: TextStyle(
                                        color: sel
                                            ? Colors.white
                                            : AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      )),
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
                      items: widget.grades
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _grade = v);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final name = _nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setState(() => _saving = true);
                      await DocumentService.createCourse(name,
                          credits: _credits, grade: _grade);
                      if (context.mounted) Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add Course'),
            ),
          ),
        ],
      ),
    );
  }
}
