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

enum _Confidence { know, unsure, dontKnow }

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  bool _isGenerating = true;
  String? _error;
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<Map<String, String>> _allCards = [];
  List<Map<String, String>> _deck = [];        // current deck being studied
  Map<int, _Confidence> _confidence = {};      // originalIndex → confidence
  bool _inReviewMode = false;
  bool _sessionComplete = false;
  String _loadingMessage = 'Generating flashcards...';
  bool _cancelled = false;
  final _service = GeminiStudyService();
  static const _totalCards = 8;

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
      _allCards = [];
      _deck = [];
      _confidence = {};
      _inReviewMode = false;
      _sessionComplete = false;
      _cancelled = false;
      _loadingMessage = 'Generating flashcards...';
    });

    try {
      final cards = await _service.generateFlashcards(
        title: widget.document['title'] ?? 'Unknown Document',
        subject: widget.document['subject'] ?? 'General',
        count: _totalCards,
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
      if (_cancelled || !mounted) return;
      setState(() {
        _allCards = cards;
        _deck = List.from(cards);
        _isGenerating = false;
      });
      GeminiStudyService.saveFlashcards(
        title: widget.document['title'] ?? '',
        subject: widget.document['subject'] ?? '',
        cards: cards,
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

  void _rate(_Confidence rating) {
    setState(() {
      _confidence[_currentIndex] = rating;
      _showAnswer = false;
      if (_currentIndex < _deck.length - 1) {
        _currentIndex++;
      } else {
        _finishDeck();
      }
    });
  }

  void _finishDeck() {
    final needReview = <Map<String, String>>[];
    for (var i = 0; i < _deck.length; i++) {
      final c = _confidence[i];
      if (c == _Confidence.unsure || c == _Confidence.dontKnow) {
        needReview.add(_deck[i]);
      }
    }

    if (needReview.isEmpty) {
      _sessionComplete = true;
    } else {
      _deck = needReview;
      _currentIndex = 0;
      _confidence = {};
      _inReviewMode = true;
    }
  }

  void _restart() {
    setState(() {
      _deck = List.from(_allCards);
      _currentIndex = 0;
      _showAnswer = false;
      _confidence = {};
      _inReviewMode = false;
      _sessionComplete = false;
    });
  }

  int get _knowCount =>
      _confidence.values.where((c) => c == _Confidence.know).length;
  int get _unsureCount =>
      _confidence.values.where((c) => c == _Confidence.unsure).length;
  int get _dontKnowCount =>
      _confidence.values.where((c) => c == _Confidence.dontKnow).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(isDark),
        surfaceTintColor: Colors.transparent,
        title: Text(_inReviewMode ? 'Review Round' : 'AI Flashcards'),
        actions: [
          if (!_isGenerating && _deck.isNotEmpty && !_sessionComplete)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_currentIndex + 1}/${_deck.length}',
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
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : _sessionComplete
                    ? _buildComplete(isDark)
                    : _buildCard(isDark),
      ),
    );
  }

  Widget _buildLoading() => Center(
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
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Generating Flashcards...', style: AppTheme.headingSmall),
            const SizedBox(height: 8),
            Text(_loadingMessage,
                style: AppTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 44),
              const SizedBox(height: 16),
              Text(_error!,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.error),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generate,
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

  Widget _buildComplete(bool isDark) {
    final total = _allCards.length;
    final pct = total > 0 ? (_knowCount / total * 100).toInt() : 0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_rounded,
                size: 46, color: AppTheme.success),
          ),
          const SizedBox(height: 24),
          Text('Session Complete!', style: AppTheme.headingLarge),
          const SizedBox(height: 8),
          Text('You reviewed all ${_allCards.length} cards',
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),
          // Score breakdown
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(isDark),
              borderRadius: AppTheme.borderRadiusLarge,
              boxShadow: isDark ? [] : AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Text('$pct% Mastered',
                    style: AppTheme.headingLarge.copyWith(
                        fontSize: 36, color: AppTheme.success)),
                const SizedBox(height: 16),
                _ScoreLine(
                    label: 'Know it',
                    count: _knowCount,
                    total: total,
                    color: AppTheme.success),
                const SizedBox(height: 8),
                _ScoreLine(
                    label: 'Almost',
                    count: _unsureCount,
                    total: total,
                    color: AppTheme.warning),
                const SizedBox(height: 8),
                _ScoreLine(
                    label: 'Still learning',
                    count: _dontKnowCount,
                    total: total,
                    color: AppTheme.error),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Study Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(bool isDark) {
    final card = _deck[_currentIndex];
    return Column(
      children: [
        // ── Progress bar ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      _inReviewMode
                          ? 'Reviewing ${_deck.length} cards'
                          : (widget.document['title'] ?? ''),
                      style: AppTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${((_currentIndex + 1) / _deck.length * 100).toInt()}%',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _deck.length,
                backgroundColor: AppTheme.surfaceColor,
                valueColor:
                    const AlwaysStoppedAnimation(AppTheme.primaryColor),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),

        // ── Card ────────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Container(
                  key: ValueKey<String>(
                      '${_currentIndex}_$_showAnswer'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: _showAnswer
                        ? const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
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
                                ? const Color(0xFF6366F1)
                                : AppTheme.primaryColor)
                            .withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
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
                          color: Colors.white.withValues(alpha: 0.2),
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
                      const SizedBox(height: 28),
                      Text(
                        _showAnswer
                            ? (card['answer'] ?? '')
                            : (card['question'] ?? ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.touch_app_rounded,
                              color: Colors.white54, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            _showAnswer
                                ? 'Tap to see question'
                                : 'Tap to reveal answer',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
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

        // ── Confidence buttons (shown after answer is revealed) ─────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _showAnswer
              ? Padding(
                  key: const ValueKey('confidence'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    children: [
                      Text(
                        'How well did you know this?',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ConfidenceButton(
                            label: "Don't Know",
                            icon: Icons.close_rounded,
                            color: AppTheme.error,
                            onTap: () => _rate(_Confidence.dontKnow),
                          ),
                          const SizedBox(width: 8),
                          _ConfidenceButton(
                            label: 'Almost',
                            icon: Icons.remove_rounded,
                            color: AppTheme.warning,
                            onTap: () => _rate(_Confidence.unsure),
                          ),
                          const SizedBox(width: 8),
                          _ConfidenceButton(
                            label: 'Know It',
                            icon: Icons.check_rounded,
                            color: AppTheme.success,
                            onTap: () => _rate(_Confidence.know),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : Padding(
                  key: const ValueKey('hint'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Text(
                    'Tap the card to reveal the answer',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }
}

class _ConfidenceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ConfidenceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _ScoreLine({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: AppTheme.bodySmall, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$count',
            style: AppTheme.bodySmall
                .copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
