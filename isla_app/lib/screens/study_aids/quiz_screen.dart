import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';

class QuizScreen extends StatefulWidget {
  final Map<String, dynamic> document;

  const QuizScreen({super.key, required this.document});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _isGenerating = true;
  bool _quizStarted = false;
  bool _quizCompleted = false;
  int _currentQuestion = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _answered = false;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Which data structure follows LIFO principle?',
      'options': ['Queue', 'Stack', 'Array', 'Linked List'],
      'correct': 1,
    },
    {
      'question':
          'What is the time complexity of accessing an element in an array by index?',
      'options': ['O(n)', 'O(log n)', 'O(1)', 'O(n²)'],
      'correct': 2,
    },
    {
      'question':
          'Which data structure is best for implementing a breadth-first search?',
      'options': ['Stack', 'Queue', 'Tree', 'Hash Table'],
      'correct': 1,
    },
    {
      'question': 'What is the worst-case time complexity of Quick Sort?',
      'options': ['O(n)', 'O(n log n)', 'O(n²)', 'O(log n)'],
      'correct': 2,
    },
    {
      'question': 'Which data structure uses key-value pairs for storage?',
      'options': ['Array', 'Stack', 'Hash Table', 'Queue'],
      'correct': 2,
    },
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    });
  }

  void _selectAnswer(int index) {
    if (!_answered) {
      setState(() {
        _selectedAnswer = index;
        _answered = true;
        if (index == _questions[_currentQuestion]['correct']) {
          _score++;
        }
      });
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
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestion = 0;
      _score = 0;
      _selectedAnswer = null;
      _answered = false;
      _quizCompleted = false;
      _quizStarted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Quiz'),
        actions: [
          if (_quizStarted && !_quizCompleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '${_currentQuestion + 1}/${_questions.length}',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isGenerating
          ? _buildLoadingState()
          : _quizCompleted
              ? _buildResultState()
              : _quizStarted
                  ? _buildQuizState()
                  : _buildStartState(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.warning),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Generating Quiz...',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Creating questions from your document',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartState() {
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
              color: AppTheme.warning.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.quiz_rounded,
              size: 48,
              color: AppTheme.warning,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Quiz Ready!',
            style: AppTheme.headingLarge,
          ),
          const SizedBox(height: 8),
          Text(
            widget.document['title'],
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.borderRadiusMedium,
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                _QuizInfoRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Questions',
                  value: '${_questions.length}',
                ),
                const Divider(height: 24),
                const _QuizInfoRow(
                  icon: Icons.timer_outlined,
                  label: 'Est. Time',
                  value: '5 minutes',
                ),
                const Divider(height: 24),
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
              onPressed: () {
                setState(() => _quizStarted = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Start Quiz',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuizState() {
    final question = _questions[_currentQuestion];

    return Column(
      children: [
        // Progress
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
                // Question
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.borderRadiusLarge,
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
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
                      Text(
                        question['question'],
                        style: AppTheme.headingSmall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Options
                ...List.generate(
                  question['options'].length,
                  (index) => _OptionCard(
                    option: question['options'][index],
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

        // Next Button
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultState() {
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
              color:
                  (passed ? AppTheme.success : AppTheme.error).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
              size: 56,
              color: passed ? AppTheme.success : AppTheme.error,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            passed ? 'Congratulations!' : 'Keep Practicing!',
            style: AppTheme.headingLarge,
          ),
          const SizedBox(height: 8),
          Text(
            passed
                ? 'You passed the quiz!'
                : 'You can try again to improve your score',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.borderRadiusLarge,
              boxShadow: AppTheme.cardShadow,
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
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back to Document'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _restartQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
    if (!showResult) {
      return isSelected ? AppTheme.primaryColor : Colors.transparent;
    }
    if (isCorrect) return AppTheme.success;
    if (isSelected && !isCorrect) return AppTheme.error;
    return Colors.transparent;
  }

  Color get _backgroundColor {
    if (!showResult) {
      return isSelected
          ? AppTheme.primaryColor.withOpacity(0.05)
          : Colors.white;
    }
    if (isCorrect) return AppTheme.success.withOpacity(0.1);
    if (isSelected && !isCorrect) return AppTheme.error.withOpacity(0.1);
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['A', 'B', 'C', 'D'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _backgroundColor,
        borderRadius: AppTheme.borderRadiusMedium,
        child: InkWell(
          onTap: showResult ? null : onTap,
          borderRadius: AppTheme.borderRadiusMedium,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppTheme.borderRadiusMedium,
              border: Border.all(
                color: _borderColor,
                width: 2,
              ),
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
                    child:
                        showResult && (isCorrect || (isSelected && !isCorrect))
                            ? Icon(
                                isCorrect ? Icons.check : Icons.close,
                                color: Colors.white,
                                size: 20,
                              )
                            : Text(
                                labels[index],
                                style: AppTheme.labelMedium,
                              ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(option, style: AppTheme.bodyMedium),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
