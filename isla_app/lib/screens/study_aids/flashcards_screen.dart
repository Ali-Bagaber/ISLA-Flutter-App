import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../services/gemini_study_service.dart';

class FlashcardsScreen extends StatefulWidget {
  final Map<String, dynamic> document;

  const FlashcardsScreen({super.key, required this.document});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  bool _isGenerating = true;
  String? _error;
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<Map<String, String>> _flashcards = [];
  String _loadingMessage = 'Generating card 1 of 8...';
  bool _cancelled = false;
  final _service = GeminiStudyService();
  static const _totalCards = 5;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _error = null;
      _currentIndex = 0;
      _showAnswer = false;
      _flashcards = [];
      _cancelled = false;
      _loadingMessage = 'Generating flashcards...';
    });

    final title = widget.document['title'] ?? 'Unknown Document';
    final subject = widget.document['subject'] ?? 'General';

    try {
      final cards = await _service.generateFlashcards(
        title: title,
        subject: subject,
        count: _totalCards,
        onRetrying: () {
          if (mounted)
            setState(() => _loadingMessage =
                'AI is busy — retrying automatically, please wait...');
        },
      );
      if (_cancelled || !mounted) return;
      setState(() {
        _flashcards = cards;
        _isGenerating = false;
      });
      // Auto-save to Firestore
      GeminiStudyService.saveFlashcards(
        title: widget.document['title'] ?? '',
        subject: widget.document['subject'] ?? '',
        cards: _flashcards,
        documentId:
            widget.document['id'] ?? widget.document['documentId'] ?? '',
      );
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

  Future<void> _save() async {} // kept for compatibility

  void _nextCard() {
    setState(() {
      if (_currentIndex < _flashcards.length - 1) {
        _currentIndex++;
        _showAnswer = false;
      }
    });
  }

  void _previousCard() {
    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
        _showAnswer = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(isDark),
        surfaceTintColor: Colors.transparent,
        title: const Text('AI Flashcards'),
        actions: [
          if (!_isGenerating && _flashcards.isNotEmpty) ...[
            if (_flashcards.length >= _totalCards)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(
                  label: const Text('Saved',
                      style: TextStyle(fontSize: 11, color: AppTheme.success)),
                  avatar: const Icon(Icons.check_circle_rounded,
                      size: 13, color: AppTheme.success),
                  backgroundColor: AppTheme.success.withValues(alpha: 0.1),
                  side: BorderSide.none,
                ),
              ),
            TextButton(
              onPressed: null,
              child: Text(
                '${_currentIndex + 1}/${_flashcards.length}',
                style:
                    AppTheme.labelMedium.copyWith(color: AppTheme.primaryColor),
              ),
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
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation(AppTheme.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Generating Flashcards...',
                        style: AppTheme.headingSmall),
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
                : Column(
                    children: [
                      // Progress
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.document['title'] ?? '',
                                    style: AppTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${((_currentIndex + 1) / _flashcards.length * 100).toInt()}%',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_flashcards.length < _totalCards) ...[
                                      const SizedBox(width: 8),
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                              AppTheme.primaryColor),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (_currentIndex + 1) / _flashcards.length,
                              backgroundColor: AppTheme.surfaceColor,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),

                      // Flashcard
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _showAnswer = !_showAnswer),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                key: ValueKey<bool>(_showAnswer),
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: _showAnswer
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF8B5CF6),
                                            Color(0xFFA78BFA)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : const LinearGradient(
                                          colors: [
                                            AppTheme.primaryColor,
                                            AppTheme.primaryLight
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  borderRadius: AppTheme.borderRadiusLarge,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_showAnswer
                                              ? const Color(0xFF8B5CF6)
                                              : AppTheme.primaryColor)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _showAnswer ? 'Answer' : 'Question',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Text(
                                      _showAnswer
                                          ? (_flashcards[_currentIndex]
                                                  ['answer'] ??
                                              '')
                                          : (_flashcards[_currentIndex]
                                                  ['question'] ??
                                              ''),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const Spacer(),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.touch_app_rounded,
                                            color: Colors.white54, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          _showAnswer
                                              ? 'Tap to see question'
                                              : 'Tap to reveal answer',
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Navigation
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _currentIndex > 0 ? _previousCard : null,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(
                                    color: _currentIndex > 0
                                        ? AppTheme.primaryColor
                                        : AppTheme.textLight,
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Previous'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _currentIndex < _flashcards.length - 1
                                        ? _nextCard
                                        : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('Next'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ActionButton(
                              icon: Icons.shuffle_rounded,
                              label: 'Shuffle',
                              onTap: () {
                                setState(() {
                                  _flashcards.shuffle();
                                  _currentIndex = 0;
                                  _showAnswer = false;
                                });
                              },
                            ),
                            _ActionButton(
                              icon: Icons.save_rounded,
                              label: 'Save',
                              onTap: _save,
                            ),
                            _ActionButton(
                              icon: Icons.refresh_rounded,
                              label: 'Reset',
                              onTap: () => setState(() {
                                _currentIndex = 0;
                                _showAnswer = false;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(label, style: AppTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
