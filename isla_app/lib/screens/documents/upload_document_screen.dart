import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../services/document_service.dart';

class UploadDocumentScreen extends StatefulWidget {
  /// When launched from a course section, pre-fill the subject dropdown.
  final String? preselectedSubject;

  const UploadDocumentScreen({super.key, this.preselectedSubject});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  String? _selectedSubject;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  final _titleController = TextEditingController();

  // Courses loaded from Firestore — populated in initState
  List<String> _courseNames = [];

  bool _isSaving = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.preselectedSubject;
    // Subscribe to courses stream once
    DocumentService.watchCourses().listen((courses) {
      if (!mounted) return;
      final names =
          courses.map((c) => (c['name'] as String? ?? '').trim()).toList();
      setState(() {
        _courseNames = names;
        // If preselected subject is not in list yet, keep it selectable
        if (_selectedSubject != null &&
            !_courseNames.contains(_selectedSubject)) {
          _courseNames.add(_selectedSubject!);
        }
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'pptx', 'ppt', 'docx', 'doc'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _selectedFileName = file.name;
      _selectedFileBytes = file.bytes;
      // Pre-fill title with file name (without extension)
      if (_titleController.text.isEmpty) {
        final nameWithoutExt = file.name.contains('.')
            ? file.name.substring(0, file.name.lastIndexOf('.'))
            : file.name;
        _titleController.text = nameWithoutExt;
      }
    });
  }

  Future<void> _uploadDocument() async {
    if (_isSaving) return;
    if (_titleController.text.trim().isEmpty ||
        _selectedSubject == null ||
        _selectedFileName == null ||
        _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and pick a file'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = 0;
    });

    try {
      await DocumentService.uploadAndSaveDocument(
        title: _titleController.text.trim(),
        subject: _selectedSubject!,
        fileName: _selectedFileName!,
        fileBytes: _selectedFileBytes!,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(title: const Text('Upload Document')),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── File Picker Area ──────────────────────────────────────────
              InkWell(
                onTap: _isSaving ? null : _pickFile,
                borderRadius: AppTheme.borderRadiusLarge,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(isDark),
                    borderRadius: AppTheme.borderRadiusLarge,
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: _selectedFileName == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cloud_upload_rounded,
                                color: AppTheme.primaryColor,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tap to pick a file',
                              style: AppTheme.labelMedium.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'PDF, PPTX, DOCX supported',
                              style: AppTheme.bodySmall,
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.insert_drive_file_rounded,
                              color: AppTheme.primaryColor,
                              size: 44,
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                _selectedFileName!,
                                style: AppTheme.labelMedium,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedFileBytes != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatSize(_selectedFileBytes!.length),
                                style: AppTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _isSaving ? null : _pickFile,
                              child: const Text('Change file'),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Document Title ────────────────────────────────────────────
              Text('Document Title', style: AppTheme.labelMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  hintText: 'Enter document title',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),

              const SizedBox(height: 20),

              // ── Course / Subject Selection ────────────────────────────────
              Text('Select Course', style: AppTheme.labelMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: (_courseNames.contains(_selectedSubject) ||
                        _selectedSubject == null)
                    ? _selectedSubject
                    : null,
                decoration: const InputDecoration(
                  hintText: 'Choose a course',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: [
                  ..._courseNames.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s)),
                  ),
                  const DropdownMenuItem(
                    value: '__new__',
                    child: Row(children: [
                      Icon(Icons.add_rounded,
                          size: 18, color: AppTheme.primaryColor),
                      SizedBox(width: 6),
                      Text('Create new course',
                          style: TextStyle(color: AppTheme.primaryColor)),
                    ]),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == '__new__') {
                          _showCreateCourseDialog();
                        } else {
                          setState(() => _selectedSubject = value);
                        }
                      },
              ),

              const SizedBox(height: 32),

              // ── Upload progress ───────────────────────────────────────────
              if (_isSaving) ...[
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation(
                          AppTheme.primaryColor,
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    if (_uploadProgress > 0) ...[
                      const SizedBox(width: 10),
                      Text(
                        '${(_uploadProgress * 100).round()}%',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── Upload Button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _uploadDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Upload Document',
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
    );
  }

  Future<void> _showCreateCourseDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Course'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Course name',
            hintText: 'e.g. BCS2033 or Data Structures',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final name = controller.text.trim();
      await DocumentService.createCourse(name);
      if (mounted) setState(() => _selectedSubject = name);
    }
    controller.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
