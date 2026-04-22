import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../services/gemini_study_service.dart';

class SummaryScreen extends StatefulWidget {
  final Map<String, dynamic> document;

  const SummaryScreen({super.key, required this.document});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _isGenerating = true;
  String _summary = '';
  String? _error;
  String _loadingMessage = 'AI is analyzing your document';
  final _service = GeminiStudyService();

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _error = null;
      _loadingMessage = 'AI is analyzing your document';
    });
    try {
      final result = await _service.generateSummary(
        title: widget.document['title'] ?? 'Unknown Document',
        subject: widget.document['subject'] ?? 'General',
        onRetrying: () {
          if (mounted)
            setState(() => _loadingMessage =
                'AI is busy — retrying automatically, please wait...');
        },
      );
      if (mounted) {
        setState(() {
          _summary = result;
          _isGenerating = false;
        });
        // Auto-save to Firestore
        GeminiStudyService.saveSummary(
          title: widget.document['title'] ?? '',
          subject: widget.document['subject'] ?? '',
          content: result,
          documentId:
              widget.document['id'] ?? widget.document['documentId'] ?? '',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e
              .toString()
              .replaceAll('StateError: ', '')
              .replaceAll('Bad state: ', '');
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(isDark),
        surfaceTintColor: Colors.transparent,
        title: const Text('AI Summary'),
        actions: [
          if (!_isGenerating && _summary.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Saved',
                    style: TextStyle(fontSize: 12, color: AppTheme.success)),
                avatar: const Icon(Icons.check_circle_rounded,
                    size: 14, color: AppTheme.success),
                backgroundColor: AppTheme.success.withValues(alpha: 0.1),
                side: BorderSide.none,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _summary));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        ],
      ),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: _isGenerating
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppTheme.success),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Generating Summary...', style: AppTheme.headingSmall),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.error, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: AppTheme.bodyMedium
                                .copyWith(color: AppTheme.error),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _generate,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Document Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            borderRadius: AppTheme.borderRadiusMedium,
                            border: Border.all(
                              color: AppTheme.success.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.success),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Summary Generated by Gemini AI',
                                      style: AppTheme.labelMedium
                                          .copyWith(color: AppTheme.success),
                                    ),
                                    Text(widget.document['title'] ?? '',
                                        style: AppTheme.bodySmall),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Summary Content
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.getCardColor(isDark),
                            borderRadius: AppTheme.borderRadiusLarge,
                            boxShadow: isDark ? [] : AppTheme.cardShadow,
                          ),
                          child: Text(
                            _summary,
                            style: AppTheme.bodyMedium.copyWith(height: 1.7),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _generate,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(
                                      color: AppTheme.primaryColor),
                                ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Regenerate'),
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
