import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../services/gemini_study_service.dart';
import '../../services/unsplash_service.dart';
import '../../services/user_settings_service.dart';
import '../../widgets/confetti_overlay.dart';

class QuizScreen extends StatefulWidget {
  final Map<String, dynamic> document;
  final List<Map<String, dynamic>>? savedQuestions;

  const QuizScreen({super.key, required this.document, this.savedQuestions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _isGenerating = true;
  String? _error;
  bool _quizStarted = false;
  bool _quizCompleted = false;
  bool _showReview = false;
  int _currentQuestion = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _answered = false;
  List<Map<String, dynamic>> _questions = [];
  List<int> _userAnswers = [];
  String _loadingMessage = 'AI is creating your quiz';
  int _selectedCount = 5;
  final _service = GeminiStudyService();
  final Map<String, UnsplashPhoto?> _photoCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.savedQuestions != null && widget.savedQuestions!.isNotEmpty) {
      _questions = widget.savedQuestions!;
      _isGenerating = false;
    } else {
      _generateQuiz();
    }
  }

  void _fetchPhotos(List<Map<String, dynamic>> questions) {
    for (final q in questions) {
      final keyword = (q['imageKeyword'] ?? '').toString();
      if (keyword.isEmpty || _photoCache.containsKey(keyword)) continue;
      _photoCache[keyword] = null;
      UnsplashService.fetchPhoto(keyword).then((photo) {
        if (mounted && photo != null) {
          setState(() => _photoCache[keyword] = photo);
        }
      });
    }
  }

  Future<void> _generateQuiz({int? count}) async {
    final n = count ?? _selectedCount;
    setState(() {
      _isGenerating = true;
      _error = null;
      _currentQuestion = 0;
      _score = 0;
      _answered = false;
      _selectedAnswer = null;
      _quizCompleted = false;
      _quizStarted = false;
      _showReview = false;
      _userAnswers = [];
      _loadingMessage = 'AI is creating your quiz';
    });
    try {
      final qs = await _service.generateQuiz(
        title: widget.document['title'] ?? 'Unknown Document',
        subject: widget.document['subject'] ?? 'General',
        count: n,
        documentText: (widget.document['extractedText'] ??
                widget.document['notes'] ??
                widget.document['content'] ??
                widget.document['description'] ??
                '')
            .toString(),
        onRetrying: () {
          if (mounted) {
            setState(() => _loadingMessage =
                'AI is busy — retrying automatically, please wait...');
          }
        },
      );
      if (mounted) {
        setState(() {
          _questions = qs.isNotEmpty
              ? qs
              : [
                  {
                    'question': 'Could not generate questions',
                    'options': ['Try again'],
                    'correct': 0,
                  }
                ];
          _isGenerating = false;
        });
        _fetchPhotos(qs);
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

  void _selectAnswer(int index) {
    if (!_answered) {
      final isCorrect = index == _questions[_currentQuestion]['correct'];
      setState(() {
        _selectedAnswer = index;
        _answered = true;
        _userAnswers.add(index);
        if (isCorrect) _score++;
      });
      if (isCorrect) ConfettiBurst.fire(context, particleCount: 18);
    }
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      setState(() => _quizCompleted = true);
      _saveResult();
    }
  }

  Future<void> _saveResult() async {
    // +5 XP per correct answer (max 25 XP for a 5-question quiz).
    if (_score > 0) UserSettingsService.addXp(_score * 5).ignore();
    try {
      await GeminiStudyService.saveQuizWithResult(
        title: widget.document['title'] ?? '',
        subject: widget.document['subject'] ?? '',
        questions: _questions,
        score: _score,
        total: _questions.length,
        documentId:
            widget.document['id'] ?? widget.document['documentId'] ?? '',
      );
    } catch (_) {}
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestion = 0;
      _score = 0;
      _selectedAnswer = null;
      _answered = false;
      _quizCompleted = false;
      _showReview = false;
      _userAnswers = [];
      _quizStarted = true;
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
        leading: _showReview
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _showReview = false),
              )
            : null,
        title: Text(_showReview ? 'Review Answers' : 'Quiz'),
        actions: [
          if (_quizStarted && !_quizCompleted && !_showReview)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '${_currentQuestion + 1}/${_questions.length}',
                  style: AppTheme.labelMedium
                      .copyWith(color: AppTheme.primaryColor),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(isDark),
        child: _isGenerating
            ? _buildLoadingState()
            : _error != null
                ? _buildErrorState()
                : _showReview
                    ? _buildReviewState(isDark)
                    : _quizCompleted
                        ? _buildResultState(isDark)
                        : _quizStarted
                            ? _buildQuizState(isDark)
                            : _buildStartState(isDark),
      ),
    );
  }

  Widget _buildLoadingState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.warning),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Generating Quiz...', style: AppTheme.headingSmall),
            const SizedBox(height: 8),
            Text(_loadingMessage,
                style: AppTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _buildErrorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 44),
              const SizedBox(height: 16),
              Text(
                _error ?? 'An error occurred',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generateQuiz,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildStartState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline_rounded,
                size: 44, color: AppTheme.warning),
          ),
          const SizedBox(height: 32),
          Text('Quiz Ready!', style: AppTheme.headingLarge),
          const SizedBox(height: 8),
          Text(
            widget.document['title'] ?? '',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // ── Question count selector ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(isDark),
              borderRadius: AppTheme.borderRadiusMedium,
              boxShadow: isDark ? [] : AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Number of Questions',
                    style: AppTheme.labelMedium
                        .copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                Row(
                  children: [5, 10, 15].map((n) {
                    final selected = _selectedCount == n;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            if (_selectedCount != n) {
                              setState(() => _selectedCount = n);
                              _generateQuiz(count: n);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.warning.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppTheme.warning
                                    : AppTheme.textLight,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '$n',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected
                                    ? AppTheme.warning
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 24),
                _QuizInfoRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Questions',
                  value: '${_questions.length}',
                ),
                const Divider(height: 20),
                const _QuizInfoRow(
                  icon: Icons.emoji_events_outlined,
                  label: 'Pass Score',
                  value: '60%',
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isGenerating
                  ? null
                  : () => setState(() => _quizStarted = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isGenerating ? 'Generating…' : 'Start Quiz',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuizState(bool isDark) {
    final question = _questions[_currentQuestion];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: LinearProgressIndicator(
            value: (_currentQuestion + 1) / _questions.length,
            backgroundColor: AppTheme.surfaceColor,
            valueColor: const AlwaysStoppedAnimation(AppTheme.warning),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(isDark),
                    borderRadius: AppTheme.borderRadiusLarge,
                    boxShadow: isDark ? [] : AppTheme.cardShadow,
                  ),
                  child: Builder(builder: (context) {
                    final keyword = (question['imageKeyword'] ?? '').toString();
                    final photo = keyword.isNotEmpty ? _photoCache[keyword] : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (photo != null && photo.url.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: photo.url,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const SizedBox.shrink(),
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse(photo.photographerUrl)),
                            child: Text(
                              'Photo by ${photo.photographerName} on Unsplash',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Question ${_currentQuestion + 1}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(question['question'] ?? '',
                            style: AppTheme.headingSmall),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 24),
                ...List.generate(
                  (question['options'] as List?)?.length ?? 0,
                  (index) => _OptionCard(
                    option: (question['options'] as List)[index].toString(),
                    index: index,
                    isSelected: _selectedAnswer == index,
                    isCorrect: question['correct'] == index,
                    showResult: _answered,
                    onTap: () => _selectAnswer(index),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_answered)
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _currentQuestion < _questions.length - 1
                      ? 'Next Question'
                      : 'See Results',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultState(bool isDark) {
    final percentage = (_score / _questions.length * 100).toInt();
    final passed = percentage >= 60;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: (passed ? AppTheme.success : AppTheme.error)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
              size: 56,
              color: passed ? AppTheme.success : AppTheme.error,
            ),
          ),
          const SizedBox(height: 32),
          Text(passed ? 'Congratulations!' : 'Keep Practicing!',
              style: AppTheme.headingLarge),
          const SizedBox(height: 8),
          Text(
            passed
                ? 'You passed the quiz!'
                : 'You can try again to improve your score',
            style:
                AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(isDark),
              borderRadius: AppTheme.borderRadiusLarge,
              boxShadow: isDark ? [] : AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Text(
                  '$percentage%',
                  style: AppTheme.headingLarge.copyWith(
                    fontSize: 48,
                    color: passed ? AppTheme.success : AppTheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_score out of ${_questions.length} correct',
                  style: AppTheme.bodyMedium
                      .copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Review button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showReview = true),
              icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
              label: const Text('Review Answers'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _restartQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewState(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final q = _questions[i];
        final userAnswer = i < _userAnswers.length ? _userAnswers[i] : -1;
        final correct = (q['correct'] as int?) ?? 0;
        final isRight = userAnswer == correct;
        final options = (q['options'] as List?)?.cast<String>() ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(isDark),
            borderRadius: AppTheme.borderRadiusMedium,
            border: Border.all(
              color: isRight
                  ? AppTheme.success.withValues(alpha: 0.4)
                  : AppTheme.error.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isRight
                          ? AppTheme.success.withValues(alpha: 0.15)
                          : AppTheme.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRight ? Icons.check_rounded : Icons.close_rounded,
                      color: isRight ? AppTheme.success : AppTheme.error,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Q${i + 1}',
                    style: AppTheme.bodySmall.copyWith(
                      color: isRight ? AppTheme.success : AppTheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(q['question']?.toString() ?? '',
                  style: AppTheme.labelMedium),
              const SizedBox(height: 10),
              if (options.isNotEmpty) ...[
                if (!isRight && userAnswer >= 0 && userAnswer < options.length)
                  _ReviewOptionLine(
                      label: 'Your answer',
                      text: options[userAnswer],
                      color: AppTheme.error),
                if (correct < options.length)
                  _ReviewOptionLine(
                      label: 'Correct',
                      text: options[correct],
                      color: AppTheme.success),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReviewOptionLine extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _ReviewOptionLine(
      {required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style:
                      AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _QuizInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _QuizInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: 12),
        Text(label, style: AppTheme.bodyMedium),
        const Spacer(),
        Text(value, style: AppTheme.labelMedium),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String option;
  final int index;
  final bool isSelected;
  final bool isCorrect;
  final bool showResult;
  final VoidCallback onTap;

  const _OptionCard({
    required this.option,
    required this.index,
    required this.isSelected,
    required this.isCorrect,
    required this.showResult,
    required this.onTap,
  });

  Color get _borderColor {
    if (!showResult) return isSelected ? AppTheme.primaryColor : Colors.transparent;
    if (isCorrect) return AppTheme.success;
    if (isSelected && !isCorrect) return AppTheme.error;
    return Colors.transparent;
  }

  Color _bgColor(bool isDark) {
    if (!showResult) {
      return isSelected
          ? AppTheme.primaryColor.withValues(alpha: 0.05)
          : AppTheme.getCardColor(isDark);
    }
    if (isCorrect) return AppTheme.success.withValues(alpha: 0.08);
    if (isSelected && !isCorrect) return AppTheme.error.withValues(alpha: 0.08);
    return AppTheme.getCardColor(isDark);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = ['A', 'B', 'C', 'D'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _bgColor(isDark),
        borderRadius: AppTheme.borderRadiusMedium,
        child: InkWell(
          onTap: showResult ? null : onTap,
          borderRadius: AppTheme.borderRadiusMedium,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppTheme.borderRadiusMedium,
              border: Border.all(color: _borderColor, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: showResult && isCorrect
                        ? AppTheme.success
                        : showResult && isSelected && !isCorrect
                            ? AppTheme.error
                            : AppTheme.surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: showResult &&
                            (isCorrect || (isSelected && !isCorrect))
                        ? Icon(
                            isCorrect ? Icons.check : Icons.close,
                            color: Colors.white,
                            size: 20,
                          )
                        : Text(labels[index], style: AppTheme.labelMedium),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(option, style: AppTheme.bodyMedium)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
