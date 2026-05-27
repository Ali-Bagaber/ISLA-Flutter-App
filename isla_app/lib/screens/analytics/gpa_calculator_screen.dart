import 'package:flutter/material.dart';
import '../../services/gpa_service.dart';
import '../../theme/app_theme.dart';

/// Multi-semester GPA / CGPA calculator.
///
/// User can add semesters, each containing courses with credits + grade.
/// CGPA is the credit-weighted average of all courses across all semesters.
class GPACalculatorScreen extends StatefulWidget {
  const GPACalculatorScreen({super.key});

  @override
  State<GPACalculatorScreen> createState() => _GPACalculatorScreenState();
}

class _GPACalculatorScreenState extends State<GPACalculatorScreen> {
  List<Map<String, dynamic>> _semesters = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stream = GpaService.watchGpaRecord();
    stream.first.then((record) {
      if (!mounted) return;
      setState(() {
        final list = (record?['semesters'] as List?) ?? [];
        _semesters = list
            .cast<Map<String, dynamic>>()
            .map((s) => {
                  'id': s['id'] ?? _genId('sem'),
                  'name': s['name'] ?? 'Semester',
                  'courses': ((s['courses'] as List?) ?? [])
                      .cast<Map<String, dynamic>>()
                      .map((c) => {
                            'id': c['id'] ?? _genId('c'),
                            'name': c['name'] ?? '',
                            'credits':
                                (c['credits'] as num? ?? 3).toInt(),
                            'grade': c['grade'] ?? 'B',
                          })
                      .toList(),
                })
            .toList();
        _loading = false;
      });
    });
  }

  String _genId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await GpaService.saveSemesters(_semesters);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addSemester() {
    setState(() {
      _semesters.add({
        'id': _genId('sem'),
        'name': 'Semester ${_semesters.length + 1}',
        'courses': <Map<String, dynamic>>[],
      });
    });
    _save();
  }

  void _removeSemester(int index) {
    setState(() => _semesters.removeAt(index));
    _save();
  }

  void _renameSemester(int index, String name) {
    setState(() => _semesters[index]['name'] = name);
    _save();
  }

  void _addCourse(int semIndex) {
    setState(() {
      (_semesters[semIndex]['courses'] as List).add({
        'id': _genId('c'),
        'name': '',
        'credits': 3,
        'grade': 'B',
      });
    });
    _save();
  }

  void _updateCourse(int semIndex, int courseIndex, Map<String, dynamic> patch) {
    setState(() {
      final courses = _semesters[semIndex]['courses'] as List;
      courses[courseIndex] = {...courses[courseIndex], ...patch};
    });
    _save();
  }

  void _removeCourse(int semIndex, int courseIndex) {
    setState(() {
      (_semesters[semIndex]['courses'] as List).removeAt(courseIndex);
    });
    _save();
  }

  Color _gpaColor(double gpa) {
    if (gpa >= 3.5) return AppTheme.success;
    if (gpa >= 3.0) return AppTheme.primaryColor;
    if (gpa >= 2.0) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);
    final cardBg = AppTheme.getCardColor(isDark);
    final surface = AppTheme.getSurfaceColor(isDark);

    final cgpa = GpaService.computeCgpa(_semesters);
    final totalCredits = GpaService.computeTotalCredits(_semesters);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('GPA / CGPA Calculator'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSemester,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Semester',
            style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // CGPA banner
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _gpaColor(cgpa),
                        _gpaColor(cgpa).withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CURRENT CGPA',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cgpa.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalCredits credits  ·  ${_semesters.length} semester${_semesters.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_semesters.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: surface),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.school_outlined,
                            size: 40, color: textSecondary),
                        const SizedBox(height: 10),
                        Text('No semesters yet',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "Add Semester" to start tracking your GPA.',
                          style:
                              TextStyle(color: textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                for (var i = 0; i < _semesters.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SemesterCard(
                      key: ValueKey(_semesters[i]['id']),
                      semester: _semesters[i],
                      cardBg: cardBg,
                      surface: surface,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      gpaColor: _gpaColor,
                      onRename: (name) => _renameSemester(i, name),
                      onDelete: () => _removeSemester(i),
                      onAddCourse: () => _addCourse(i),
                      onUpdateCourse: (ci, patch) => _updateCourse(i, ci, patch),
                      onRemoveCourse: (ci) => _removeCourse(i, ci),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SemesterCard extends StatefulWidget {
  final Map<String, dynamic> semester;
  final Color cardBg;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color Function(double gpa) gpaColor;
  final void Function(String name) onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddCourse;
  final void Function(int courseIndex, Map<String, dynamic> patch)
      onUpdateCourse;
  final void Function(int courseIndex) onRemoveCourse;

  const _SemesterCard({
    super.key,
    required this.semester,
    required this.cardBg,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.gpaColor,
    required this.onRename,
    required this.onDelete,
    required this.onAddCourse,
    required this.onUpdateCourse,
    required this.onRemoveCourse,
  });

  @override
  State<_SemesterCard> createState() => _SemesterCardState();
}

class _SemesterCardState extends State<_SemesterCard> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.semester['name'] as String? ?? '');
  }

  @override
  void didUpdateWidget(covariant _SemesterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newName = widget.semester['name'] as String? ?? '';
    if (newName != _nameCtrl.text) _nameCtrl.text = newName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courses = ((widget.semester['courses'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final gpa = GpaService.computeGpa(courses);
    final credits = courses.fold<int>(
        0, (s, c) => s + (c['credits'] as num? ?? 0).toInt());
    final color = widget.gpaColor(gpa);

    return Container(
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.surface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    onSubmitted: widget.onRename,
                    onEditingComplete: () => widget.onRename(_nameCtrl.text),
                    style: TextStyle(
                      color: widget.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'GPA  ${gpa.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: widget.textSecondary,
                  tooltip: 'Delete semester',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$credits credits  ·  ${courses.length} course${courses.length == 1 ? '' : 's'}',
              style: TextStyle(color: widget.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: widget.surface),

          for (var ci = 0; ci < courses.length; ci++)
            _CourseRow(
              key: ValueKey(courses[ci]['id']),
              course: courses[ci],
              surface: widget.surface,
              textPrimary: widget.textPrimary,
              textSecondary: widget.textSecondary,
              onChange: (patch) => widget.onUpdateCourse(ci, patch),
              onRemove: () => widget.onRemoveCourse(ci),
            ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onAddCourse,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Course'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatefulWidget {
  final Map<String, dynamic> course;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final void Function(Map<String, dynamic> patch) onChange;
  final VoidCallback onRemove;

  const _CourseRow({
    super.key,
    required this.course,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.onChange,
    required this.onRemove,
  });

  @override
  State<_CourseRow> createState() => _CourseRowState();
}

class _CourseRowState extends State<_CourseRow> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.course['name'] as String? ?? '');
  }

  @override
  void didUpdateWidget(covariant _CourseRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newName = widget.course['name'] as String? ?? '';
    if (newName != _nameCtrl.text) _nameCtrl.text = newName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credits = (widget.course['credits'] as num? ?? 3).toInt();
    final grade = (widget.course['grade'] ?? 'B').toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TextField(
              controller: _nameCtrl,
              onChanged: (v) => widget.onChange({'name': v}),
              style: TextStyle(color: widget.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Course name',
                hintStyle:
                    TextStyle(color: widget.textSecondary, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 70,
            child: DropdownButtonFormField<int>(
              initialValue: credits,
              isDense: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
              items: const [1, 2, 3, 4, 5, 6]
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c}cr',
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => widget.onChange({'credits': v ?? 3}),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 70,
            child: DropdownButtonFormField<String>(
              initialValue: GpaService.grades.contains(grade) ? grade : 'B',
              isDense: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
              items: GpaService.grades
                  .map((g) => DropdownMenuItem(
                      value: g,
                      child:
                          Text(g, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => widget.onChange({'grade': v ?? 'B'}),
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: widget.textSecondary,
            tooltip: 'Remove course',
          ),
        ],
      ),
    );
  }
}
