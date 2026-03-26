import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';

class UploadDocumentScreen extends StatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  String? _selectedSubject;
  String? _selectedFile;
  final _titleController = TextEditingController();

  final List<String> _subjects = [
    'BCS2033',
    'BCS3012',
    'BCS2042',
    'BCS4051',
    'Add New Subject',
  ];

  void _pickFile() {
    // Simulate file picking
    setState(() {
      _selectedFile = 'lecture_notes_chapter5.pdf';
    });
  }

  void _uploadDocument() {
    if (_titleController.text.isNotEmpty &&
        _selectedSubject != null &&
        _selectedFile != null) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(title: const Text('Upload Document')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload Area
            InkWell(
              onTap: _pickFile,
              borderRadius: AppTheme.borderRadiusLarge,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.borderRadiusLarge,
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _selectedFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_upload_rounded,
                              color: AppTheme.primaryColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to upload document',
                            style: AppTheme.labelMedium.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supports PDF, PPTX, DOCX',
                            style: AppTheme.bodySmall,
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.success,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(_selectedFile!, style: AppTheme.labelMedium),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() => _selectedFile = null);
                            },
                            child: const Text('Change file'),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Document Title
            Text('Document Title', style: AppTheme.labelMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Enter document title',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),

            const SizedBox(height: 20),

            // Subject Selection
            Text('Select Subject', style: AppTheme.labelMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              decoration: const InputDecoration(
                hintText: 'Choose a subject',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              items: _subjects.map((subject) {
                return DropdownMenuItem(value: subject, child: Text(subject));
              }).toList(),
              onChanged: (value) {
                if (value == 'Add New Subject') {
                  _showAddSubjectDialog();
                } else {
                  setState(() => _selectedSubject = value);
                }
              },
            ),

            const SizedBox(height: 20),

            // Tags (Optional)
            Text('Tags (Optional)', style: AppTheme.labelMedium),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'e.g., lecture, chapter5, midterm',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),

            const SizedBox(height: 32),

            // AI Processing Options
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: AppTheme.borderRadiusMedium,
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Processing',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _AIOptionCheckbox(
                    title: 'Auto-generate summary',
                    subtitle: 'Create summary after upload',
                  ),
                  const _AIOptionCheckbox(
                    title: 'Generate flashcards',
                    subtitle: 'Create flashcards automatically',
                  ),
                  const _AIOptionCheckbox(
                    title: 'Generate quiz',
                    subtitle: 'Create quiz questions',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Upload Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _uploadDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Upload Document',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Subject'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter subject code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _subjects.insert(_subjects.length - 1, controller.text);
                  _selectedSubject = controller.text;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _AIOptionCheckbox extends StatefulWidget {
  final String title;
  final String subtitle;

  const _AIOptionCheckbox({required this.title, required this.subtitle});

  @override
  State<_AIOptionCheckbox> createState() => _AIOptionCheckboxState();
}

class _AIOptionCheckboxState extends State<_AIOptionCheckbox> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: _isChecked,
      onChanged: (value) => setState(() => _isChecked = value ?? false),
      title: Text(widget.title, style: AppTheme.bodyMedium),
      subtitle: Text(widget.subtitle, style: AppTheme.bodySmall),
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: AppTheme.primaryColor,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
