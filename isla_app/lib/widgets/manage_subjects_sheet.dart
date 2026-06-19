import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_settings_service.dart';
import '../theme/app_theme.dart';

class ManageSubjectsSheet extends StatefulWidget {
  const ManageSubjectsSheet({super.key});

  @override
  State<ManageSubjectsSheet> createState() => _ManageSubjectsSheetState();
}

class _ManageSubjectsSheetState extends State<ManageSubjectsSheet> {
  List<String> _subjects = [];
  bool _loading = true;
  final _addCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    UserSettingsService.loadUserSubjects().then((s) {
      if (mounted) setState(() { _subjects = List.from(s); _loading = false; });
    });
  }

  @override
  void dispose() { _addCtrl.dispose(); super.dispose(); }

  Future<void> _save() => UserSettingsService.saveSubjects(_subjects);

  Future<void> _addSubject() async {
    final name = _addCtrl.text.trim();
    if (name.isEmpty || _subjects.contains(name)) return;
    setState(() => _subjects.add(name));
    _addCtrl.clear();
    await _save();
  }

  Future<void> _deleteSubject(String s) async {
    setState(() => _subjects.remove(s));
    await _save();
  }

  Future<void> _renameSubject(String old) async {
    final ctrl = TextEditingController(text: old);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Subject'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == old) return;
    setState(() {
      final idx = _subjects.indexOf(old);
      if (idx != -1) _subjects[idx] = newName;
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: textSecondary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Manage Subjects',
                    style: GoogleFonts.manrope(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('Subjects appear in task creation and study planning.',
                    style: GoogleFonts.inter(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addCtrl,
                          onSubmitted: (_) => _addSubject(),
                          decoration: InputDecoration(
                            hintText: 'Add new subject…',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addSubject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: _subjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final s = _subjects[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.getCardColor(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.getSurfaceColor(isDark)),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.menu_book_rounded, size: 18, color: AppTheme.primaryColor),
                        title: Text(s, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 18, color: textSecondary),
                              onPressed: () => _renameSubject(s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                              onPressed: () => _deleteSubject(s),
                            ),
                          ],
                        ),
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
}
