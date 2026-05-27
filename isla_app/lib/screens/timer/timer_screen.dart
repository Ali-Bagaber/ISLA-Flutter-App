import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/document_service.dart';
import '../../services/gemini_checklist_service.dart';
import '../../services/gemini_study_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_settings_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/isla_logo.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

enum _SessionFlowStep { list, setup, checklist, timer, verify, complete }

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin {
  // Mutable defaults — overwritten on init from UserSettingsService.
  int _workDurationMinutes = 25;
  int _breakDurationMinutes = 5;
  int _defaultCycles = 4;
  static const Duration _checklistRequestCooldown = Duration(seconds: 3);
  static const Duration _minimumChecklistLoadingDuration = Duration(seconds: 3);

  // Seeded with the default work duration (25); overridden after settings load.
  int _currentSeconds = 25 * 60;
  int _phaseTotalSeconds = 25 * 60;
  int _completedSessions = 0;
  int _plannedCycles = 1;
  bool _isRunning = false;
  bool _isBreak = false;
  Timer? _timer;

  final _goalController = TextEditingController();
  final _sessionSubjectController = TextEditingController();
  final _sourceController = TextEditingController();
  final _manualItemController = TextEditingController();
  String? _selectedSessionSubject; // tracks dropdown choice
  final GeminiChecklistService _geminiChecklistService =
      GeminiChecklistService();

  bool _isGeneratingChecklist = false;
  String? _checklistError;
  final List<_SessionChecklistItem> _checklist = [];
  final ScrollController _checklistScrollController = ScrollController();
  final Set<String> _generatedChecklistSignatures = <String>{};
  Timer? _checklistSuccessTimer;
  Timer? _recentlyCompletedTimer;
  Timer? _allTasksCheckTimer;
  Timer? _allTasksPulseTimer;
  final Set<String> _morphingChecklistItemIds = <String>{};
  final Map<String, Timer> _checklistMorphTimers = <String, Timer>{};
  String? _recentlyCompletedItemId;
  int _activeChecklistIndex = 0;
  bool _showChecklistSuccess = false;
  bool _showAllTasksSuccessPulse = false;
  bool _showAllTasksSuccessCheck = false;
  int _lastGeneratedCount = 0;
  DateTime? _lastChecklistRequestAt;
  _SessionFlowStep _flowStep = _SessionFlowStep.list;
  bool _isForwardFlow = true;

  /// Document linked for AI context in the current session
  Map<String, dynamic>? _linkedDoc;

  /// True for ~1.4s right after the final cycle finishes — drives a smooth
  /// "ring → checkmark" celebration animation inside the timer circle before
  /// the flow advances to the Quick Check step.
  bool _isCompleteAnimating = false;

  // ── Verification / Quick Check state ────────────────────────────────────────
  bool _verifyLoading = false;
  String? _verifyError;
  List<Map<String, dynamic>> _verifyQuestions = [];
  final Map<int, int> _verifyAnswers = {}; // questionIndex → selectedOption
  int _verifyCorrect = 0;
  int _verifyTotal = 0;
  bool _verifySubmitted = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _loadFocusPrefs();
  }

  /// Pull the user's saved focus prefs (work/break/cycles) and apply them
  /// as the timer defaults. Falls back to the seeded 25/5/4 if anything fails.
  Future<void> _loadFocusPrefs() async {
    try {
      final s = await UserSettingsService.loadSettings();
      final f = (s['focus'] as Map?)?.cast<String, dynamic>() ?? {};
      final work = (f['workMinutes'] as num?)?.toInt() ?? 25;
      final brk = (f['breakMinutes'] as num?)?.toInt() ?? 5;
      final cycles = (f['cycles'] as num?)?.toInt() ?? 4;
      if (!mounted) return;
      setState(() {
        _workDurationMinutes = work;
        _breakDurationMinutes = brk;
        _defaultCycles = cycles;
        // Only seed the counters if the timer hasn't started yet.
        if (!_isRunning && _completedSessions == 0) {
          _currentSeconds = work * 60;
          _phaseTotalSeconds = work * 60;
        }
      });
    } catch (_) {
      // ignore — defaults already in place
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _checklistSuccessTimer?.cancel();
    _recentlyCompletedTimer?.cancel();
    _allTasksCheckTimer?.cancel();
    _allTasksPulseTimer?.cancel();
    for (final timer in _checklistMorphTimers.values) {
      timer.cancel();
    }
    _checklistScrollController.dispose();
    _pulseController.dispose();
    _goalController.dispose();
    _sessionSubjectController.dispose();
    _sourceController.dispose();
    _manualItemController.dispose();
    super.dispose();
  }

  void _startTimer() {
    final selectedCount = _checklist.where((item) => item.isSelected).length;
    setState(() {
      _plannedCycles = selectedCount > 0 ? selectedCount : _defaultCycles;
      _phaseTotalSeconds = max(_phaseTotalSeconds, _currentSeconds);
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds > 0) {
        setState(() => _currentSeconds--);
      } else {
        _onTimerComplete();
      }
    });
  }

  void _resetDraftSession() {
    _timer?.cancel();
    _checklistSuccessTimer?.cancel();
    _recentlyCompletedTimer?.cancel();
    _allTasksCheckTimer?.cancel();
    _allTasksPulseTimer?.cancel();
    for (final timer in _checklistMorphTimers.values) {
      timer.cancel();
    }
    _checklistMorphTimers.clear();
    _morphingChecklistItemIds.clear();
    _isRunning = false;
    _isBreak = false;
    _currentSeconds = _workDurationMinutes * 60;
    _phaseTotalSeconds = _workDurationMinutes * 60;
    _completedSessions = 0;
    _plannedCycles = 1;
    _goalController.clear();
    _sessionSubjectController.clear();
    _selectedSessionSubject = null;
    _sourceController.clear();
    _manualItemController.clear();
    _checklist.clear();
    _activeChecklistIndex = 0;
    _recentlyCompletedItemId = null;
    _generatedChecklistSignatures.clear();
    _checklistError = null;
    _showChecklistSuccess = false;
    _showAllTasksSuccessPulse = false;
    _showAllTasksSuccessCheck = false;
    _lastGeneratedCount = 0;
    _lastChecklistRequestAt = null;
    _linkedDoc = null;
  }

  int _stepIndex(_SessionFlowStep step) {
    switch (step) {
      case _SessionFlowStep.list:
        return 0;
      case _SessionFlowStep.setup:
        return 1;
      case _SessionFlowStep.checklist:
        return 2;
      case _SessionFlowStep.timer:
        return 3;
      case _SessionFlowStep.verify:
        return 4;
      case _SessionFlowStep.complete:
        return 5;
    }
  }

  void _setFlowStep(_SessionFlowStep next) {
    _isForwardFlow = _stepIndex(next) >= _stepIndex(_flowStep);
    _flowStep = next;
  }

  void _startNewSessionFlow() {
    setState(() {
      _resetDraftSession();
      _setFlowStep(_SessionFlowStep.setup);
    });
  }

  void _goBackInFlow() {
    if (_flowStep == _SessionFlowStep.list) return;

    setState(() {
      if (_flowStep == _SessionFlowStep.setup) {
        _setFlowStep(_SessionFlowStep.list);
      } else if (_flowStep == _SessionFlowStep.checklist) {
        _setFlowStep(_SessionFlowStep.setup);
      } else if (_flowStep == _SessionFlowStep.timer) {
        _timer?.cancel();
        _isRunning = false;
        _setFlowStep(_SessionFlowStep.checklist);
      } else if (_flowStep == _SessionFlowStep.complete) {
        _setFlowStep(_SessionFlowStep.timer);
      }
    });
  }

  void _continueToChecklistStep() {
    setState(() {
      _setFlowStep(_SessionFlowStep.checklist);
    });
  }

  void _continueToTimerStep() {
    final selectedCount = _checklist.where((item) => item.isSelected).length;
    if (_checklist.isEmpty || selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one checklist item before timer.'),
        ),
      );
      return;
    }

    setState(() {
      _plannedCycles = max(1, selectedCount);
      _setFlowStep(_SessionFlowStep.timer);
    });
  }

  void _markChecklistGenerated() {
    _checklistSuccessTimer?.cancel();
    _checklistSuccessTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _showChecklistSuccess = false);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    _allTasksCheckTimer?.cancel();
    _allTasksPulseTimer?.cancel();
    for (final timer in _checklistMorphTimers.values) {
      timer.cancel();
    }
    _checklistMorphTimers.clear();
    _morphingChecklistItemIds.clear();
    setState(() {
      _isRunning = false;
      _isBreak = false;
      _currentSeconds = _workDurationMinutes * 60;
      _phaseTotalSeconds = _workDurationMinutes * 60;
      _completedSessions = 0;
      _showAllTasksSuccessPulse = false;
      _showAllTasksSuccessCheck = false;
      for (final item in _checklist) {
        item.isCompleted = false;
      }
      _refreshChecklistFocus();
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    setState(() => _isRunning = false);

    if (!_isBreak) {
      // Fire a system notification so the user knows the focus block ended
      // even if the app is backgrounded.
      NotificationService.instance.showPomodoroComplete(
        subject: _sessionSubjectController.text.trim(),
      );

      var allDoneNow = false;
      setState(() {
        _completedSessions++;
        allDoneNow = _completeNextChecklistItem();
      });

      if (allDoneNow) {
        _triggerAllTasksSuccessAnimation();
      }

      if (_completedSessions >= _plannedCycles) {
        // Play a brief ring → checkmark animation, THEN advance to Quick Check.
        // Saving the session is deferred until after verification so the score
        // can include the verification result.
        setState(() {
          _isCompleteAnimating = true;
          // The ring is a countdown (full → empty). For the celebration we
          // want it full again — set currentSeconds back to the phase total
          // so _progress == 1.0 and the ring renders completely filled.
          _currentSeconds = _phaseTotalSeconds;
        });
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (!mounted) return;
          setState(() {
            _isCompleteAnimating = false;
            _isBreak = false;
            _currentSeconds = _workDurationMinutes * 60;
            _phaseTotalSeconds = _workDurationMinutes * 60;
            _setFlowStep(_SessionFlowStep.verify);
          });
          _loadVerifyQuestions();
        });
        return;
      }

      _showCycleCompleteDialog();
      setState(() {
        _isBreak = true;
        _currentSeconds = _breakDurationMinutes * 60;
        _phaseTotalSeconds = _breakDurationMinutes * 60;
      });
      return;
    }

    setState(() {
      _isBreak = false;
      _currentSeconds = _workDurationMinutes * 60;
      _phaseTotalSeconds = _workDurationMinutes * 60;
    });
  }

  bool _completeNextChecklistItem() {
    for (final item in _checklist) {
      if (item.isSelected && !item.isCompleted) {
        item.isCompleted = true;
        _startChecklistCompletionMorph(item.id);
        _recentlyCompletedItemId = item.id;
        _scheduleRecentCompletionClear();
        _activeChecklistIndex = _nextChecklistIndex(start: 0);
        return _allSelectedChecklistDone();
      }
    }
    return false;
  }

  int _nextChecklistIndex({int start = 0}) {
    for (var i = max(0, start); i < _checklist.length; i++) {
      final item = _checklist[i];
      if (item.isSelected && !item.isCompleted) {
        return i;
      }
    }
    return -1;
  }

  int _selectedChecklistCount() {
    return _checklist.where((item) => item.isSelected).length;
  }

  int _completedSelectedChecklistCount() {
    return _checklist
        .where((item) => item.isSelected && item.isCompleted)
        .length;
  }

  bool _allSelectedChecklistDone() {
    final selectedCount = _selectedChecklistCount();
    if (selectedCount == 0) return false;
    return _completedSelectedChecklistCount() == selectedCount;
  }

  void _refreshChecklistFocus() {
    final next = _nextChecklistIndex(start: 0);
    _activeChecklistIndex = next == -1 ? 0 : next;
  }

  void _cancelAllTasksSuccessTimers() {
    _allTasksCheckTimer?.cancel();
    _allTasksPulseTimer?.cancel();
  }

  void _cancelChecklistMorphTimer(String itemId) {
    _checklistMorphTimers.remove(itemId)?.cancel();
    _morphingChecklistItemIds.remove(itemId);
  }

  void _startChecklistCompletionMorph(String itemId) {
    _cancelChecklistMorphTimer(itemId);
    _morphingChecklistItemIds.add(itemId);
    _checklistMorphTimers[itemId] =
        Timer(const Duration(milliseconds: 340), () {
      if (!mounted) return;
      setState(() {
        _checklistMorphTimers.remove(itemId);
        _morphingChecklistItemIds.remove(itemId);
      });
    });
  }

  void _scheduleRecentCompletionClear() {
    _recentlyCompletedTimer?.cancel();
    _recentlyCompletedTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _recentlyCompletedItemId = null);
    });
  }

  void _triggerAllTasksSuccessAnimation() {
    _cancelAllTasksSuccessTimers();

    if (!mounted) return;
    setState(() {
      _showAllTasksSuccessPulse = true;
      _showAllTasksSuccessCheck = false;
    });

    _allTasksCheckTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => _showAllTasksSuccessCheck = true);
    });

    _allTasksPulseTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _showAllTasksSuccessPulse = false);
    });
  }

  void _animateChecklistTo(int index) {
    if (!_checklistScrollController.hasClients) return;
    final safeIndex = index.clamp(0, max(0, _checklist.length - 1));
    final targetOffset = safeIndex * 92.0;
    _checklistScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _markChecklistItemGuided(int index) {
    if (index < 0 || index >= _checklist.length) return;

    final currentExpected = _nextChecklistIndex(start: 0);
    final item = _checklist[index];

    if (!item.isSelected) {
      setState(() {
        item.isSelected = true;
        _refreshChecklistFocus();
      });
    }

    if (!item.isCompleted &&
        currentExpected != -1 &&
        index != currentExpected) {
      _animateChecklistTo(currentExpected);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete checklist steps in order for better flow.'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    var isNowAllDone = false;

    setState(() {
      item.isCompleted = !item.isCompleted;
      _recentlyCompletedItemId = item.isCompleted ? item.id : null;
      _refreshChecklistFocus();
      isNowAllDone = _allSelectedChecklistDone();

      if (!isNowAllDone) {
        _showAllTasksSuccessPulse = false;
        _showAllTasksSuccessCheck = false;
      }
    });

    if (!isNowAllDone) {
      _cancelAllTasksSuccessTimers();
    }

    if (item.isCompleted) {
      _startChecklistCompletionMorph(item.id);
      _scheduleRecentCompletionClear();

      if (isNowAllDone) {
        _triggerAllTasksSuccessAnimation();
      }

      final next = _nextChecklistIndex(start: index + 1);
      if (next != -1) {
        _animateChecklistTo(next);
      }
    } else {
      _cancelChecklistMorphTimer(item.id);
    }
  }

  void _adjustRemainingTime(int deltaMinutes) {
    final deltaSeconds = deltaMinutes * 60;
    final proposedCurrent = _currentSeconds + deltaSeconds;
    final proposedTotal = _phaseTotalSeconds + deltaSeconds;

    if (proposedCurrent < 60 || proposedTotal < 60) {
      return;
    }

    setState(() {
      _currentSeconds = proposedCurrent;
      _phaseTotalSeconds = proposedTotal;
    });
  }

  List<String> _extractKeywords(String text, {int maxKeywords = 8}) {
    const stopwords = <String>{
      'the',
      'and',
      'for',
      'with',
      'from',
      'that',
      'this',
      'your',
      'have',
      'into',
      'about',
      'then',
      'also',
      'just',
      'goal',
      'study',
      'session',
      'text',
      'notes',
      'paste',
      'here',
      'will',
      'should',
      'could',
      'after',
      'before',
      'when',
      'where',
      'what',
      'why',
      'how',
      'need',
      'must',
      'using',
    };

    final unique = <String>[];
    final tokens = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 3 && !stopwords.contains(t));

    for (final token in tokens) {
      if (!unique.contains(token)) {
        unique.add(token);
      }
      if (unique.length >= maxKeywords) break;
    }

    return unique;
  }

  String _normalizeChecklistText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _checklistTokens(String text) {
    final stop = <String>{
      'the',
      'and',
      'for',
      'with',
      'into',
      'from',
      'your',
      'this',
      'that',
      'one',
      'two',
      'three',
      'task',
      'study',
      'session',
      'cycle',
      'notes',
    };
    return _normalizeChecklistText(text)
        .split(' ')
        .where((w) => w.length >= 3 && !stop.contains(w))
        .toSet();
  }

  bool _isNearDuplicateChecklist(String candidate, Iterable<String> existing) {
    final normalizedCandidate = _normalizeChecklistText(candidate);
    final candidateTokens = _checklistTokens(candidate);
    if (candidateTokens.isEmpty) return true;

    for (final item in existing) {
      final normalizedItem = _normalizeChecklistText(item);
      if (normalizedCandidate == normalizedItem) return true;
      if (normalizedCandidate.contains(normalizedItem) ||
          normalizedItem.contains(normalizedCandidate)) {
        return true;
      }

      final itemTokens = _checklistTokens(item);
      if (itemTokens.isEmpty) continue;
      final overlap = candidateTokens.intersection(itemTokens).length;
      final union = candidateTokens.union(itemTokens).length;
      final similarity = union == 0 ? 0.0 : overlap / union;
      if (similarity >= 0.72 ||
          (overlap >= 4 &&
              overlap >= min(candidateTokens.length, itemTokens.length) - 1)) {
        return true;
      }
    }
    return false;
  }

  String _titleCaseWord(String word) {
    if (word.isEmpty) return word;
    if (word.contains(RegExp(r'\d'))) return word.toUpperCase();
    return '${word[0].toUpperCase()}${word.substring(1)}';
  }

  String _clip(String value, {int max = 48}) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max).trim()}...';
  }

  String _topicLabel({
    required String subject,
    required String goal,
    required String source,
  }) {
    final safeSubject = subject.trim();
    if (safeSubject.isNotEmpty) return safeSubject;
    final keywords = _extractKeywords('$goal $source', maxKeywords: 1);
    if (keywords.isNotEmpty) return _titleCaseWord(keywords.first);
    return 'the current topic';
  }

  List<String> _takeFreshChecklistItems({
    required List<String> candidates,
    required int needed,
    List<String> existingItems = const [],
  }) {
    final existing = [
      ..._checklist.map((e) => e.title),
      ...existingItems,
    ];

    final accepted = <String>[];
    for (final raw in candidates) {
      if (accepted.length >= needed) break;
      final item = raw.trim();
      if (item.length < 10) continue;

      final normalized = _normalizeChecklistText(item);
      if (normalized.isEmpty) continue;
      if (_generatedChecklistSignatures.contains(normalized)) continue;
      if (_isNearDuplicateChecklist(item, [...existing, ...accepted])) continue;

      _generatedChecklistSignatures.add(normalized);
      accepted.add(item);
    }
    return accepted;
  }

  Future<void> _generateChecklist({bool isRetry = false}) async {
    if (_isGeneratingChecklist) return;

    final goal = _goalController.text.trim();
    final subject = _sessionSubjectController.text.trim();
    final manualSource = _sourceController.text.trim();

    // Build rich doc context — use doc content first, then fall back to topic/goal
    final docTitle = (_linkedDoc?['title'] as String? ?? '').trim();
    final docSubject = (_linkedDoc?['subject'] as String? ?? '').trim();
    final docType = (_linkedDoc?['type'] as String? ?? '').trim();
    final docNotes = (_linkedDoc?['notes'] as String? ?? '').trim();
    final docExtracted =
        (_linkedDoc?['extractedText'] as String? ?? '').trim();
    // Trim file content for the prompt — checklist only needs ~6k chars of context.
    final docExtractedSnippet = docExtracted.length > 6000
        ? '${docExtracted.substring(0, 6000)}\n\n[...content truncated...]'
        : docExtracted;
    final docContext = _linkedDoc != null
        ? [
            if (docTitle.isNotEmpty) 'Document title: "$docTitle"',
            if (docSubject.isNotEmpty) 'Document subject: $docSubject',
            if (docType.isNotEmpty) 'Document type: $docType',
            if (docNotes.isNotEmpty) 'Document notes: $docNotes',
            if (docExtractedSnippet.isNotEmpty)
              'Document content:\n$docExtractedSnippet',
          ].join('\n')
        : '';

    // Priority: linked-doc subject → manual dropdown → empty
    final effectiveSubject = docSubject.isNotEmpty
        ? docSubject
        : subject.isNotEmpty
            ? subject
            : (docTitle.isNotEmpty ? docTitle : '');

    final source =
        [docContext, manualSource].where((s) => s.isNotEmpty).join('\n\n');
    final existingTitles = _checklist.map((item) => item.title).toList();
    const requestedNewItems = 3;

    if (goal.isEmpty && source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a study goal or source text first.'),
        ),
      );
      return;
    }

    final startedAt = DateTime.now();
    final now = DateTime.now();
    var queuedDelay = Duration.zero;
    if (_lastChecklistRequestAt != null) {
      final elapsed = now.difference(_lastChecklistRequestAt!);
      if (elapsed < _checklistRequestCooldown) {
        queuedDelay = _checklistRequestCooldown - elapsed;
      }
    }

    setState(() {
      _isGeneratingChecklist = true;
      _checklistError = null;
    });

    try {
      if (queuedDelay > Duration.zero) {
        await Future.delayed(queuedDelay);
      }

      _lastChecklistRequestAt = DateTime.now();

      final items = await _geminiChecklistService.generateChecklist(
        goal: goal,
        sourceText: source,
        sessionSubject: effectiveSubject,
        requestedItems: requestedNewItems,
        existingItems: existingTitles,
      );
      final freshFromAi = _takeFreshChecklistItems(
        candidates: items,
        needed: requestedNewItems,
        existingItems: existingTitles,
      );

      if (freshFromAi.isEmpty) {
        setState(() {
          _checklistError =
              'AI returned no usable items. Refine your goal and try again.';
        });
        return;
      }

      setState(() {
        _checklist.addAll(freshFromAi.map(_SessionChecklistItem.fromTitle));
        _lastGeneratedCount = freshFromAi.length;
        _checklistError = null;
        _showChecklistSuccess = true;
        _refreshChecklistFocus();
      });
      _markChecklistGenerated();
    } catch (error) {
      final message = error.toString().replaceAll('StateError: ', '').trim();
      setState(() {
        _checklistError = isRetry ? 'Retry failed: $message' : message;
      });
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < _minimumChecklistLoadingDuration) {
        await Future.delayed(_minimumChecklistLoadingDuration - elapsed);
      }
      if (mounted) {
        setState(() => _isGeneratingChecklist = false);
      }
    }
  }

  void _addManualChecklistItem() {
    final title = _manualItemController.text.trim();
    if (title.isEmpty) {
      return;
    }

    final normalized = _normalizeChecklistText(title);
    if (_isNearDuplicateChecklist(title, _checklist.map((e) => e.title))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This checklist item is already added.')),
      );
      return;
    }

    setState(() {
      _cancelAllTasksSuccessTimers();
      _showAllTasksSuccessPulse = false;
      _showAllTasksSuccessCheck = false;
      _generatedChecklistSignatures.add(normalized);
      _checklist.add(_SessionChecklistItem.fromTitle(title));
      _manualItemController.clear();
      _checklistError = null;
      _refreshChecklistFocus();
    });
  }

  void _showCycleCompleteDialog() {
    if (!mounted) return;
    // Don't block the user if they navigated away to a sub-screen
    // (e.g. document annotate, GPA calculator). The notification we
    // already fired in _onTimerFinished informs them.
    if (Navigator.of(context).canPop()) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Focus Cycle Complete'),
        content: Text(
          'Great progress. Start your 5-minute break now?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip Break'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTimer();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Break'),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog to pick a document from the user's library as AI context.
  Future<void> _showPickDocumentDialog() async {
    final docs = await DocumentService.watchDocuments().first;
    if (!mounted) return;

    final subject = _sessionSubjectController.text.trim();
    // Show docs for the selected subject first, then the rest
    final subjectDocs = subject.isEmpty
        ? docs
        : docs.where((d) => d['subject'] == subject).toList();
    final otherDocs = subject.isEmpty
        ? []
        : docs.where((d) => d['subject'] != subject).toList();

    final allOptions = [...subjectDocs, ...otherDocs];

    if (allOptions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No documents found. Upload a document first.'),
          ),
        );
      }
      return;
    }

    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Link a Document'),
        content: SizedBox(
          width: 340,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: allOptions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final doc = allOptions[i];
              return ListTile(
                leading: Icon(
                  _docTypeIcon(doc['type'] ?? ''),
                  color: AppTheme.primaryColor,
                ),
                title: Text(
                  doc['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  doc['subject'] ?? '',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.pop(ctx, doc),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (_linkedDoc != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, <String, dynamic>{}),
              child: const Text('Remove'),
            ),
        ],
      ),
    );

    if (picked == null) return;
    setState(() {
      _linkedDoc = picked.isEmpty ? null : picked;
    });
  }

  IconData _docTypeIcon(String type) {
    switch (type) {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      case 'PPTX':
        return Icons.slideshow_rounded;
      case 'DOCX':
        return Icons.article_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (_phaseTotalSeconds <= 0) return 0;
    return (_currentSeconds / _phaseTotalSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final showAppBar = _flowStep != _SessionFlowStep.list;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _flowStep == _SessionFlowStep.list
          ? Padding(
              padding: const EdgeInsets.only(bottom: 74),
              child: _buildNewSessionFloatingButton(isDark),
            )
          : null,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: AppTheme.getBackgroundColor(isDark),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _goBackInFlow,
              ),
              title: Text(_titleForStep()),
              actions: _flowStep == _SessionFlowStep.timer
                  ? [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: _showSessionOptions,
                      ),
                    ]
                  : [],
            )
          : null,
      body: SafeArea(
        top: !showAppBar,
        bottom: false,
        child: Container(
          decoration: AppTheme.getBackgroundDecoration(isDark),
          child: Column(
            children: [
              if (_flowStep != _SessionFlowStep.list) _buildFlowHeader(isDark),
              Expanded(
                child: kIsWeb
                    ? _buildFlowBody(isDark)
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 360),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (currentChild, previousChildren) {
                          // Keep only the active step mounted to avoid
                          // overlapping editable/hoverable widgets.
                          return SizedBox.expand(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: currentChild ?? const SizedBox.shrink(),
                            ),
                          );
                        },
                        transitionBuilder: (child, animation) {
                          final slideTween = Tween<Offset>(
                            begin: Offset(_isForwardFlow ? 0.08 : -0.08, 0),
                            end: Offset.zero,
                          );
                          final scaleTween =
                              Tween<double>(begin: 0.985, end: 1);

                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slideTween.animate(animation),
                              child: ScaleTransition(
                                scale: scaleTween.animate(animation),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: _buildFlowBody(isDark),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlowHeader(bool isDark) {
    const steps = [
      _SessionFlowStep.setup,
      _SessionFlowStep.checklist,
      _SessionFlowStep.timer,
      _SessionFlowStep.complete,
    ];
    const labels = ['Setup', 'Checklist', 'Focus', 'Complete'];
    final activeIndex = max(0, steps.indexOf(_flowStep));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.getCardDecoration(
        isDark,
        elevated: false,
        borderAlpha: 0.15,
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == activeIndex;
          final isDone = index < activeIndex;
          final borderColor = isActive || isDone
              ? AppTheme.primaryColor.withValues(alpha: isActive ? 0.55 : 0.35)
              : AppTheme.getSurfaceColor(isDark);

          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(right: index == steps.length - 1 ? 0 : 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isActive || isDone
                            ? AppTheme.primaryColor
                            : AppTheme.getSurfaceColor(isDark),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? Colors.white
                                      : AppTheme.getTextSecondary(isDark),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        labels[index],
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySmall.copyWith(
                          color: isActive
                              ? AppTheme.primaryColor
                              : AppTheme.getTextSecondary(isDark),
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Quick Check (verification) ────────────────────────────────────────────

  Future<void> _loadVerifyQuestions() async {
    setState(() {
      _verifyLoading = true;
      _verifyError = null;
      _verifyQuestions = [];
      _verifyAnswers.clear();
      _verifyCorrect = 0;
      _verifyTotal = 0;
      _verifySubmitted = false;
    });
    try {
      final docTitle = (_linkedDoc?['title'] as String?) ??
          _sessionSubjectController.text.trim();
      final docSubject = (_linkedDoc?['subject'] as String?) ??
          _sessionSubjectController.text.trim();
      final extracted = (_linkedDoc?['extractedText'] as String? ?? '').trim();
      final goal = _goalController.text.trim();
      final source = extracted.isNotEmpty
          ? extracted
          : (goal.isNotEmpty
              ? 'Study goal: $goal'
              : (_sourceController.text.trim()));

      final qs = await GeminiStudyService().generateQuiz(
        title: docTitle.isEmpty ? 'this session' : docTitle,
        subject: docSubject.isEmpty ? 'General' : docSubject,
        count: 3,
        documentText: source,
      );
      if (!mounted) return;
      setState(() {
        _verifyQuestions = qs.take(3).toList();
        _verifyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyLoading = false;
        _verifyError = e
            .toString()
            .replaceAll('StateError: ', '')
            .replaceAll('Bad state: ', '');
      });
    }
  }

  void _submitVerify() {
    if (_verifyQuestions.isEmpty) return;
    int correct = 0;
    for (var i = 0; i < _verifyQuestions.length; i++) {
      final picked = _verifyAnswers[i];
      final ans = (_verifyQuestions[i]['correct'] as num?)?.toInt() ?? 0;
      if (picked != null && picked == ans) correct++;
    }
    setState(() {
      _verifyCorrect = correct;
      _verifyTotal = _verifyQuestions.length;
      _verifySubmitted = true;
    });
    _saveSessionWithVerification(
        correct: correct, total: _verifyQuestions.length);
  }

  void _skipVerify() {
    setState(() {
      _verifyCorrect = 0;
      _verifyTotal = 0;
      _verifySubmitted = true;
    });
    _saveSessionWithVerification(correct: 0, total: 0);
  }

  void _saveSessionWithVerification(
      {required int correct, required int total}) {
    final selectedChecklistCount =
        _checklist.where((item) => item.isSelected).length;
    final completedChecklistCount =
        _checklist.where((item) => item.isSelected && item.isCompleted).length;

    // Save (non-blocking) and move to summary step.
    GeminiStudyService.saveSession(
      focusMinutes: _completedSessions * _workDurationMinutes,
      cycles: _completedSessions,
      subject: _sessionSubjectController.text.trim(),
      checklistDone: completedChecklistCount,
      checklistTotal: selectedChecklistCount,
      verifiedCorrect: correct,
      verifiedTotal: total,
    );
    setState(() => _setFlowStep(_SessionFlowStep.complete));
  }

  /// Same formula used in GeminiStudyService.saveSession — duplicated here
  /// so the Complete screen can show a transparent breakdown.
  ({int total, int cycleScore, int checklistScore, int verifyScore})
      _computeSessionScore({
    required int checklistDone,
    required int checklistTotal,
    required int cycles,
    required int verifiedCorrect,
    required int verifiedTotal,
  }) {
    final checklistRatio =
        checklistTotal > 0 ? (checklistDone / checklistTotal).clamp(0.0, 1.0) : 0.0;
    final cycleScore = (min(cycles, 4) * 10);
    final checklistScore = (checklistRatio * 20).round();
    final verifyRatio =
        verifiedTotal > 0 ? (verifiedCorrect / verifiedTotal).clamp(0.0, 1.0) : 0.0;
    final verifyScore = (verifyRatio * 30).round();
    const base = 10;
    final total =
        (base + cycleScore + checklistScore + verifyScore).clamp(0, 100);
    return (
      total: total,
      cycleScore: cycleScore,
      checklistScore: checklistScore,
      verifyScore: verifyScore,
    );
  }

  Widget _buildScoreBreakdown({
    required bool isDark,
    required int checklistDone,
    required int checklistTotal,
    required int cycles,
    required int verifiedCorrect,
    required int verifiedTotal,
  }) {
    final s = _computeSessionScore(
      checklistDone: checklistDone,
      checklistTotal: checklistTotal,
      cycles: cycles,
      verifiedCorrect: verifiedCorrect,
      verifiedTotal: verifiedTotal,
    );
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);
    final cardBg = AppTheme.getCardColor(isDark);
    final surface = AppTheme.getSurfaceColor(isDark);
    final color = s.total >= 75
        ? AppTheme.success
        : (s.total >= 50 ? AppTheme.primaryColor : AppTheme.warning);

    Widget row(String label, int score, int max, String reason) {
      final ratio = max == 0 ? 0.0 : (score / max).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                Text('$score / $max',
                    style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: surface,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(reason,
                style: TextStyle(color: textSecondary, fontSize: 11)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Session Score',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${s.total}',
                style: TextStyle(
                  color: color,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Text(
                  ' / 100',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Earned from cycles completed, checklist progress and Quick Check answers.',
            style: TextStyle(color: textSecondary, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 8),
          Divider(color: surface, height: 1),
          row('Base', 10, 10, 'Every completed session.'),
          row('Cycles', s.cycleScore, 40,
              '$cycles cycle${cycles == 1 ? '' : 's'} × 10 (cap 4)'),
          row('Checklist', s.checklistScore, 20,
              '$checklistDone of $checklistTotal items done'),
          row(
            'Verification',
            s.verifyScore,
            30,
            verifiedTotal == 0
                ? 'Skipped Quick Check — no points'
                : '$verifiedCorrect of $verifiedTotal questions correct',
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyStep(bool isDark) {
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textSecondary = AppTheme.getTextSecondary(isDark);
    final cardBg = AppTheme.getCardColor(isDark);
    final surface = AppTheme.getSurfaceColor(isDark);
    const accent = AppTheme.primaryColor;

    final allAnswered = _verifyQuestions.isNotEmpty &&
        _verifyAnswers.length == _verifyQuestions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intro card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.quiz_outlined,
                        color: AppTheme.primaryColor, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Quick Check',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Answer 3 short questions about what you just studied. Your score becomes part of the Session Score.',
                  style: TextStyle(
                      color: textSecondary, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_verifyLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 60),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Generating questions from your study material...',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            )
          else if (_verifyError != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.35)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.error, size: 32),
                  const SizedBox(height: 8),
                  Text(_verifyError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _skipVerify,
                        child: const Text('Skip'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _loadVerifyQuestions,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            ...List.generate(_verifyQuestions.length, (qi) {
              final q = _verifyQuestions[qi];
              final question = (q['question'] ?? '').toString();
              final options =
                  ((q['options'] as List?) ?? []).cast<String>().toList();
              final picked = _verifyAnswers[qi];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: surface),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Question ${qi + 1} of ${_verifyQuestions.length}',
                        style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text(question,
                        style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4)),
                    const SizedBox(height: 10),
                    ...List.generate(options.length, (oi) {
                      final selected = picked == oi;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => setState(() => _verifyAnswers[qi] = oi),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? accent.withValues(alpha: 0.12)
                                  : surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? accent
                                    : surface,
                                width: 1.4,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color:
                                      selected ? accent : textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(options[oi],
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 13,
                                      )),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),

          if (_verifyQuestions.isNotEmpty && _verifyError == null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _skipVerify,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: textSecondary),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: allAnswered ? _submitVerify : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(allAnswered
                        ? 'Submit & See Score'
                        : 'Answer ${_verifyQuestions.length - _verifyAnswers.length} more'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _titleForStep() {
    switch (_flowStep) {
      case _SessionFlowStep.list:
        return 'Sessions';
      case _SessionFlowStep.setup:
        return 'New Session';
      case _SessionFlowStep.checklist:
        return 'AI Checklist';
      case _SessionFlowStep.timer:
        return 'Focus Timer';
      case _SessionFlowStep.verify:
        return 'Quick Check';
      case _SessionFlowStep.complete:
        return 'Session Complete';
    }
  }

  Widget _buildFlowBody(bool isDark) {
    switch (_flowStep) {
      case _SessionFlowStep.list:
        return _buildStepEntrance(
          key: const ValueKey('animated-list-step'),
          child: _buildSessionListStep(isDark),
        );
      case _SessionFlowStep.setup:
        return _buildStepEntrance(
          key: const ValueKey('animated-setup-step'),
          child: _buildSessionSetupStep(isDark),
        );
      case _SessionFlowStep.checklist:
        return _buildStepEntrance(
          key: const ValueKey('animated-checklist-step'),
          child: _buildChecklistStep(isDark),
        );
      case _SessionFlowStep.timer:
        return _buildStepEntrance(
          key: const ValueKey('animated-timer-step'),
          child: _buildTimerStep(isDark),
        );
      case _SessionFlowStep.verify:
        return _buildStepEntrance(
          key: const ValueKey('animated-verify-step'),
          child: _buildVerifyStep(isDark),
        );
      case _SessionFlowStep.complete:
        return _buildStepEntrance(
          key: const ValueKey('animated-complete-step'),
          child: _buildCompletionStep(isDark),
        );
    }
  }

  Widget _buildStepEntrance({required Key key, required Widget child}) {
    if (kIsWeb) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      key: key,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, builtChild) {
        final dx = (_isForwardFlow ? 18.0 : -18.0) * (1 - value);
        final dy = 10.0 * (1 - value);
        return SizedBox.expand(
          child: Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(
                scale: 0.985 + (value * 0.015),
                child: builtChild,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _normalizeSubjectLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Other Tasks';
    if (value.toLowerCase() == 'no subject') return 'Other Tasks';
    return value;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _formatClock(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _formatDurationMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours <= 0) return '${remaining}m';
    if (remaining == 0) return '${hours}h';
    return '${hours}h ${remaining}m';
  }

  String _formatSessionRange(DateTime? endAt, int focusMinutes) {
    if (endAt == null) return 'Unknown time';
    final safeMinutes = max(1, focusMinutes);
    final startAt = endAt.subtract(Duration(minutes: safeMinutes));
    return '${_formatClock(startAt)} - ${_formatClock(endAt)}';
  }

  String _sessionBucketLabel(DateTime? dt) {
    if (dt == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(sessionDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return 'Earlier';
  }

  IconData _sessionIcon(String subject) {
    final value = subject.toLowerCase();
    if (value.contains('deep')) return Icons.psychology_alt_rounded;
    if (value.contains('read')) return Icons.menu_book_rounded;
    if (value.contains('code') || value.contains('program')) {
      return Icons.code_rounded;
    }
    if (value.contains('write')) return Icons.edit_note_rounded;
    if (value.contains('quiz')) return Icons.quiz_rounded;
    return Icons.timelapse_rounded;
  }

  int _sessionFocusScore(Map<String, dynamic> session) {
    final done = _toInt(session['checklistDone']);
    final total = _toInt(session['checklistTotal']);
    final cycles = _toInt(session['cycles']);
    final focusMinutes = _toInt(session['focusMinutes']);

    final checklistRatio = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.6;
    final score = 62 +
        (checklistRatio * 24).round() +
        (min(cycles, 4) * 3) +
        (focusMinutes >= 120
            ? 4
            : focusMinutes >= 60
                ? 2
                : 0);

    return score.clamp(55, 99).toInt();
  }

  Widget _buildSessionHistoryCard({
    required Map<String, dynamic> session,
    required bool isDark,
    required bool isFeatured,
  }) {
    final rawSubject =
        _normalizeSubjectLabel((session['subject'] ?? '').toString().trim());
    final subject = rawSubject == 'Other Tasks' ? 'Focus Session' : rawSubject;
    final focusMinutes = _toInt(session['focusMinutes']);
    final timestamp = _toDateTime(session['timestamp']);
    final durationLabel = _formatDurationMinutes(focusMinutes);
    final rangeLabel = _formatSessionRange(timestamp, focusMinutes);
    final score = _sessionFocusScore(session);

    final scoreColor = isFeatured
        ? AppTheme.primaryColor
        : isDark
            ? const Color(0xFF6AA9FF)
            : const Color(0xFF2B6CB0);

    return _HoverLift(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        child: IslaPremiumCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(isDark),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _sessionIcon(subject),
                      color: scoreColor,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.headingSmall.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.getTextPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          rangeLabel,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.getTextSecondary(isDark),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DURATION',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.getTextSecondary(isDark),
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          durationLabel,
                          style: AppTheme.headingSmall.copyWith(
                            color: AppTheme.getTextPrimary(isDark),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FOCUS SCORE',
                          style: AppTheme.bodySmall.copyWith(
                            color: scoreColor,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$score',
                          style: AppTheme.headingLarge.copyWith(
                            color: scoreColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  Widget _buildSessionListStep(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey('session-list-step'),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: const [
              IslaLogo(),
              Spacer(),
              IslaProfileAvatar(),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Session History',
              textAlign: TextAlign.center,
              style: AppTheme.headingLarge.copyWith(
                color: AppTheme.getTextPrimary(isDark),
                fontSize: 52,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Review your past states of flow.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.getTextSecondary(isDark),
                fontSize: 15.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: GeminiStudyService.watchSessions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSessionListLoading(isDark);
              }

              final sessions = [...(snapshot.data ?? <Map<String, dynamic>>[])];
              sessions.sort((a, b) {
                final aTime = _toDateTime(a['timestamp']);
                final bTime = _toDateTime(b['timestamp']);
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              if (sessions.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.getCardDecoration(
                    isDark,
                    elevated: false,
                    borderAlpha: 0.12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.getSurfaceColor(isDark),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.event_note_rounded,
                              color: AppTheme.getTextSecondary(isDark),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No sessions yet',
                              style: AppTheme.labelMedium.copyWith(
                                color: AppTheme.getTextPrimary(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Start your first focused flow and your history will appear here.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.getTextSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final recentSessions = sessions.take(12).toList();
              final grouped = <String, List<Map<String, dynamic>>>{
                'Today': <Map<String, dynamic>>[],
                'Yesterday': <Map<String, dynamic>>[],
                'Earlier': <Map<String, dynamic>>[],
              };

              for (final session in recentSessions) {
                final bucket =
                    _sessionBucketLabel(_toDateTime(session['timestamp']));
                grouped
                    .putIfAbsent(bucket, () => <Map<String, dynamic>>[])
                    .add(session);
              }

              final orderedBuckets = ['Today', 'Yesterday', 'Earlier'];
              final children = <Widget>[];
              var cardIndex = 0;

              for (final bucket in orderedBuckets) {
                final entries =
                    grouped[bucket] ?? const <Map<String, dynamic>>[];
                if (entries.isEmpty) continue;

                children.add(
                  Padding(
                    padding: EdgeInsets.only(
                        top: children.isEmpty ? 0 : 12, bottom: 10),
                    child: Text(
                      bucket.toUpperCase(),
                      style: AppTheme.labelMedium.copyWith(
                        color: bucket == 'Today'
                            ? AppTheme.primaryColor
                            : AppTheme.getTextSecondary(isDark),
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );

                for (final session in entries) {
                  final currentIndex = cardIndex;
                  final sessionTimestamp = _toDateTime(session['timestamp']);
                  children.add(
                    TweenAnimationBuilder<double>(
                      key: ValueKey(
                        'session-history-${bucket}_$currentIndex-${sessionTimestamp ?? ''}',
                      ),
                      duration:
                          Duration(milliseconds: 230 + (currentIndex * 45)),
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: _buildSessionHistoryCard(
                        session: session,
                        isDark: isDark,
                        isFeatured: currentIndex == 0,
                      ),
                    ),
                  );
                  cardIndex += 1;
                }
              }

              return Column(children: children);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNewSessionFloatingButton(bool isDark) {
    return _HoverLift(
      key: const ValueKey('new-session-button-float-lift'),
      child: InkWell(
        onTap: _startNewSessionFlow,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(isDark),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'NEW SESSION',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.primaryColor,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionListLoading(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TODAY',
          style: AppTheme.labelMedium.copyWith(
            color: AppTheme.primaryColor,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(
          2,
          (index) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(isDark),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppTheme.getSurfaceColor(isDark).withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.getSurfaceColor(isDark),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppTheme.getSurfaceColor(isDark),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 140,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.getSurfaceColor(isDark),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionSetupStep(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey('session-setup-step'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HoverLift(
            child: IslaPremiumCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step 1: Session Setup', style: AppTheme.headingSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Set your subject and goal before generating an AI checklist.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.getTextSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Course / subject dropdown ──────────────────────────
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: DocumentService.watchCourses(),
                    builder: (context, snap) {
                      final courses = snap.data ?? [];
                      final seenNames = <String>{};
                      final items = <DropdownMenuItem<String>>[
                        const DropdownMenuItem(
                          value: '',
                          child: Text('None (general session)'),
                        ),
                        ...courses
                            .map((c) => (c['name'] as String? ?? '').trim())
                            .where((name) =>
                                name.isNotEmpty && seenNames.add(name))
                            .map((name) => DropdownMenuItem(
                                value: name, child: Text(name))),
                      ];
                      final cur = _selectedSessionSubject;
                      final validVal =
                          (cur == null || !items.any((i) => i.value == cur))
                              ? ''
                              : cur;
                      return DropdownButtonFormField<String>(
                        value: validVal,
                        decoration: const InputDecoration(
                          labelText: 'Session subject (optional)',
                          prefixIcon: Icon(Icons.book_outlined),
                        ),
                        items: items,
                        onChanged: (v) {
                          setState(() {
                            _selectedSessionSubject = v;
                            _sessionSubjectController.text = v ?? '';
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _goalController,
                    decoration: const InputDecoration(
                      labelText: 'Main goal for this session',
                      hintText: 'Example: Understand stack/queue operations',
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Document context ──────────────────────────────────────
                  Text(
                    'Link Document (optional)',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.getTextSecondary(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _showPickDocumentDialog,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _linkedDoc != null
                            ? AppTheme.primaryColor.withOpacity(0.07)
                            : AppTheme.getSurfaceColor(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _linkedDoc != null
                              ? AppTheme.primaryColor.withOpacity(0.4)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _linkedDoc != null
                                ? _docTypeIcon(
                                    _linkedDoc!['type'] as String? ?? '')
                                : Icons.attach_file_rounded,
                            color: _linkedDoc != null
                                ? AppTheme.primaryColor
                                : AppTheme.getTextSecondary(isDark),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _linkedDoc != null
                                  ? (_linkedDoc!['title'] as String? ??
                                      'Linked document')
                                  : 'Tap to link a document for AI context',
                              style: AppTheme.bodySmall.copyWith(
                                color: _linkedDoc != null
                                    ? AppTheme.primaryColor
                                    : AppTheme.getTextSecondary(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_linkedDoc != null)
                            GestureDetector(
                              onTap: () => setState(() => _linkedDoc = null),
                              child: Icon(Icons.close_rounded,
                                  size: 16,
                                  color: AppTheme.getTextSecondary(isDark)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(isDark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Tip: Link a document so the AI reads it to generate a targeted checklist.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.getTextSecondary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: _HoverLift(
              child: ElevatedButton.icon(
                onPressed: _continueToChecklistStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue to Checklist'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistStep(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey('session-checklist-step'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        children: [
          _buildChecklistGeneratorCard(isDark),
          const SizedBox(height: 16),
          _buildChecklistCard(isDark),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HoverLift(
                  child: OutlinedButton.icon(
                    onPressed: _goBackInFlow,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HoverLift(
                  child: ElevatedButton.icon(
                    onPressed: _continueToTimerStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.timer_rounded),
                    label: const Text('Continue to Focus Timer'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerStep(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey('session-timer-step'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        children: [
          _buildCurrentTaskCard(isDark),
          const SizedBox(height: 20),
          Center(child: _buildTimerCircle(isDark)),
          const SizedBox(height: 16),
          _buildUpcomingPhaseCard(isDark),
          const SizedBox(height: 20),
          _buildControlButtons(isDark),
          const SizedBox(height: 20),
          _buildAiAdviceCard(isDark),
          const SizedBox(height: 12),
          _buildActiveChecklistPreview(isDark),
          const SizedBox(height: 12),
          _buildStatsCard(isDark),
          const SizedBox(height: 20),
          _buildExitFocusButton(isDark),
        ],
      ),
    );
  }

  Widget _buildCurrentTaskCard(bool isDark) {
    final subject = _sessionSubjectController.text.trim();
    final goal = _goalController.text.trim();
    final selected = _checklist.where((item) => item.isSelected).toList();
    final activeItem = selected.firstWhere(
      (item) => !item.isCompleted,
      orElse: () => selected.isNotEmpty ? selected.last : _SessionChecklistItem(id: '', title: ''),
    );
    final taskName = activeItem.title.isNotEmpty ? activeItem.title : (goal.isNotEmpty ? goal : 'Focus Session');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppTheme.getCardDecoration(
        isDark,
        accent: _isBreak ? AppTheme.success : AppTheme.primaryColor,
        accentAlpha: 0.1,
        borderAlpha: 0.28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isBreak ? AppTheme.success : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isBreak ? 'BREAK TIME' : 'CURRENT TASK',
                style: AppTheme.bodySmall.copyWith(
                  color: _isBreak ? AppTheme.success : AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                '${_completedSessions + (_isBreak ? 1 : 0)} of $_plannedCycles',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.getTextSecondary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            taskName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.getTextPrimary(isDark),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subject.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subject,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.getTextSecondary(isDark),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExitFocusButton(bool isDark) {
    return OutlinedButton.icon(
      onPressed: () {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
          _setFlowStep(_SessionFlowStep.checklist);
        });
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: BorderSide(
          color: AppTheme.primaryColor.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        foregroundColor: AppTheme.primaryColor,
      ),
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text(
        'Exit Focus Mode',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildUpcomingPhaseCard(bool isDark) {
    final label = _isBreak ? 'Upcoming: 25 min focus' : 'Upcoming: 5 min break';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.getCardColor(isDark).withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTheme.headingSmall.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.getTextPrimary(isDark),
        ),
      ),
    );
  }

  String _buildFocusAdviceText() {
    final subject = _sessionSubjectController.text.trim();
    final goal = _goalController.text.trim();
    final selected = _checklist.where((item) => item.isSelected).toList();
    final pending = selected.where((item) => !item.isCompleted).toList();
    final topic = _topicLabel(
        subject: subject, goal: goal, source: _sourceController.text);
    final goalHint = goal.isEmpty ? topic : _clip(goal, max: 38);
    final nextTask =
        pending.isNotEmpty ? _clip(pending.first.title, max: 56) : '';

    if (_isBreak) {
      final breakAdvice = <String>[
        'Take this break fully, then restart with $topic as your first target.',
        'Use this break to reset, then continue "$goalHint" with one clear action.',
        'When break ends, start with the most difficult part of $topic first.',
      ];
      return breakAdvice[
          (_completedSessions + topic.hashCode).abs() % breakAdvice.length];
    }

    final advice = <String>[
      if (nextTask.isNotEmpty) 'Start this cycle with: $nextTask',
      'Begin with the hardest subtopic in $topic while your focus is fresh.',
      'Stay on "$goalHint" for this cycle and avoid switching context.',
      'Before this cycle ends, test one concept from $topic without notes.',
      if (pending.length > 1)
        'Finish one checklist item completely before moving to the next.',
      'At the end of this cycle, mark one $topic concept that is still unclear.',
    ];
    return advice[(_completedSessions + pending.length + topic.hashCode).abs() %
        advice.length];
  }

  Widget _buildAiAdviceCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.13),
            AppTheme.getCardColor(isDark),
          ],
        ),
        borderRadius: AppTheme.borderRadiusLarge,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.11),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Focus Advice',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildFocusAdviceText(),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.getTextSecondary(isDark),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionStep(bool isDark) {
    final selected = _checklist.where((item) => item.isSelected).toList();
    final done = selected.where((item) => item.isCompleted).length;
    final subject = _sessionSubjectController.text.trim();
    final totalMinutes = _completedSessions * _workDurationMinutes;

    return SingleChildScrollView(
      key: const ValueKey('session-complete-step'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.getCardDecoration(
              isDark,
              accent: AppTheme.success,
              accentAlpha: 0.06,
              borderAlpha: 0.28,
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.success.withValues(alpha: 0.14),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.success,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Session Complete', style: AppTheme.headingSmall),
                const SizedBox(height: 6),
                Text(
                  subject.isEmpty
                      ? 'You finished your planned focus cycles.'
                      : 'You finished your planned focus cycles for $subject.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.getTextSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _CompletionMetric(
                        label: 'Focus Time',
                        value: '$totalMinutes min',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompletionMetric(
                        label: 'Cycles',
                        value: '$_completedSessions',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompletionMetric(
                        label: 'Checklist',
                        value: '$done/${selected.length}',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Session Score breakdown ────────────────────────────────────────
          _buildScoreBreakdown(
            isDark: isDark,
            checklistDone: done,
            checklistTotal: selected.length,
            cycles: _completedSessions,
            verifiedCorrect: _verifyCorrect,
            verifiedTotal: _verifyTotal,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.getCardDecoration(
              isDark,
              accent: AppTheme.primaryColor,
              accentAlpha: 0.04,
              borderAlpha: 0.18,
              elevated: false,
            ),
            child: Text(
              _buildFocusAdviceText(),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.getTextSecondary(isDark),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _resetDraftSession();
                      _setFlowStep(_SessionFlowStep.list);
                    });
                  },
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('Back to Sessions'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _plannedCycles += 1;
                      _isBreak = false;
                      _currentSeconds = _workDurationMinutes * 60;
                      _setFlowStep(_SessionFlowStep.timer);
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('One More Cycle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChecklistPreview(bool isDark) {
    final selected = _checklist.where((item) => item.isSelected).toList();
    final done = selected.where((item) => item.isCompleted).length;
    final ratio = selected.isEmpty ? 0.0 : done / selected.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getCardDecoration(
        isDark,
        accent: AppTheme.primaryColor,
        accentAlpha: 0.03,
        borderAlpha: 0.12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Checklist', style: AppTheme.headingSmall),
              Text(
                '$done/${selected.length}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: AppTheme.getSurfaceColor(isDark),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          if (selected.isEmpty)
            Text(
              'No selected checklist items.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.getTextSecondary(isDark),
              ),
            )
          else
            ...selected.map(
              (item) => CheckboxListTile(
                value: item.isCompleted,
                onChanged: (value) {
                  setState(() => item.isCompleted = value ?? false);
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.title,
                  style: AppTheme.bodySmall.copyWith(
                    decoration: item.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerCircle(bool isDark) {
    final phaseColor = _isBreak ? AppTheme.success : AppTheme.primaryColor;
    final totalSeconds = max(1, _phaseTotalSeconds);
    final tickSize = 1 / totalSeconds;
    // Tri-stop gradient — light cyan → primary → blue. Switches to green tones on break.
    final ringGradient = _isBreak
        ? [
            const Color(0xFF6EE7B7),
            AppTheme.success,
            const Color(0xFF22D3A4),
          ]
        : [
            AppTheme.primaryLight,
            AppTheme.primaryColor,
            AppTheme.subjectColors[5],
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        final ringSize = (availableWidth * 0.66).clamp(216.0, 248.0).toDouble();
        final ringStroke = (ringSize * 0.055).clamp(12.0, 15.0).toDouble();
        final orbitPadding = (ringStroke / 2) + 16;
        final orbitSize = ringSize + (orbitPadding * 2);
        final orbitDotSize = (ringSize * 0.034).clamp(7.0, 9.0).toDouble();
        final innerSize = (ringSize * 0.72).clamp(156.0, 180.0).toDouble();
        final timeFontSize = (ringSize * 0.23).clamp(48.0, 58.0).toDouble();
        final cycleFontSize = (ringSize * 0.065).clamp(12.0, 14.0).toDouble();

        return SizedBox(
          width: orbitSize,
          height: orbitSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Orbit dots (outer ring of small dots) ──────────────────────
              _buildOrbitDots(
                size: orbitSize,
                ringSize: ringSize,
                ringStroke: ringStroke,
                dotSize: orbitDotSize,
              ),

              // ── Ambient glow that breathes when running ────────────────────
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final pulse = _isRunning ? _pulseController.value : 0;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    width: ringSize,
                    height: ringSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: phaseColor.withValues(
                              alpha: _isRunning ? 0.26 + pulse * 0.10 : 0.12),
                          blurRadius: _isRunning ? 32 + pulse * 6 : 20,
                          spreadRadius: _isRunning ? 1.5 : 0,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ── Progress ring (track + sweep + leading dot + minute ticks) ─
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(
                    'timer-progress-${_currentSeconds}_${_isBreak ? 1 : 0}',
                  ),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  tween: Tween(
                    begin: (_progress + tickSize).clamp(0.0, 1.0),
                    end: _progress.clamp(0.0, 1.0),
                  ),
                  builder: (context, value, child) {
                    return CustomPaint(
                      painter: _TimerRingPainter(
                        progress: value,
                        trackColor: AppTheme.getSurfaceColor(isDark)
                            .withValues(alpha: 0.5),
                        tickColor: AppTheme.getTextSecondary(isDark)
                            .withValues(alpha: 0.18),
                        gradientColors: ringGradient,
                        leadingDotColor: phaseColor,
                        strokeWidth: ringStroke,
                      ),
                    );
                  },
                ),
              ),

              // ── Inner glass core (phase pill + time + cycle counter) ───────
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final scale = _isRunning
                      ? 1 + (_pulseController.value * 0.012)
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: innerSize,
                      height: innerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.getCardColor(isDark)
                                .withValues(alpha: 0.95),
                            AppTheme.getBackgroundColor(isDark)
                                .withValues(alpha: 0.92),
                          ],
                          radius: 0.85,
                        ),
                        border: Border.all(
                          color: phaseColor.withValues(alpha: 0.18),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: _isCompleteAnimating
                            ? _buildCompletionContent(
                                key: const ValueKey('timer-complete'),
                                innerSize: innerSize,
                                timeFontSize: timeFontSize,
                                cycleFontSize: cycleFontSize,
                              )
                            : _buildRunningContent(
                                key: const ValueKey('timer-running'),
                                isDark: isDark,
                                phaseColor: phaseColor,
                                innerSize: innerSize,
                                timeFontSize: timeFontSize,
                                cycleFontSize: cycleFontSize,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Inner content while the timer is running — phase pill, time, cycle.
  Widget _buildRunningContent({
    required Key key,
    required bool isDark,
    required Color phaseColor,
    required double innerSize,
    required double timeFontSize,
    required double cycleFontSize,
  }) {
    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Phase pill: FOCUS / BREAK
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: phaseColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: phaseColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: phaseColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isBreak ? 'BREAK' : 'FOCUS',
                style: TextStyle(
                  color: phaseColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: innerSize * 0.04),
        // Time — tabular numerals so digits don't jitter
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatTime(_currentSeconds),
            style: AppTheme.headingLarge.copyWith(
              fontSize: timeFontSize,
              fontWeight: FontWeight.w800,
              color: AppTheme.getTextPrimary(isDark),
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -1,
            ),
          ),
        ),
        SizedBox(height: innerSize * 0.04),
        // Cycle counter
        Text(
          'Cycle ${_completedSessions + (_isBreak ? 1 : 0)} of $_plannedCycles',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: cycleFontSize,
            fontWeight: FontWeight.w500,
            color: AppTheme.getTextSecondary(isDark),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  /// Inner content during the brief end-of-session celebration — a glowing
  /// scaled-in green check and a short "Session complete" caption. The
  /// surrounding ring already animates to 100% via the existing tween.
  Widget _buildCompletionContent({
    required Key key,
    required double innerSize,
    required double timeFontSize,
    required double cycleFontSize,
  }) {
    final iconSize = innerSize * 0.42;
    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.success.withValues(alpha: 0.18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.success.withValues(alpha: 0.55),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.check_rounded,
            color: AppTheme.success,
            size: iconSize * 0.66,
          ),
        ),
        SizedBox(height: innerSize * 0.05),
        Text(
          'Session complete',
          style: TextStyle(
            color: AppTheme.success,
            fontWeight: FontWeight.w800,
            fontSize: cycleFontSize + 1,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildOrbitDots({
    required double size,
    required double ringSize,
    required double ringStroke,
    required double dotSize,
  }) {
    const dotCount = 10;
    final center = size / 2;
    final radius = (ringSize / 2) + (ringStroke / 2) + 9;
    final angleStep = (2 * pi) / dotCount;
    final activeDot = ((_progress * dotCount).floor()).clamp(0, dotCount - 1);

    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: List.generate(dotCount, (index) {
            final angle = (-pi / 2) + (angleStep * index);
            final left = center + radius * cos(angle) - dotSize / 2;
            final top = center + radius * sin(angle) - dotSize / 2;
            final isActive = index == activeDot;

            return Positioned(
              left: left,
              top: top,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppTheme.primaryLight.withValues(alpha: 0.66)
                      : AppTheme.primaryColor.withValues(alpha: 0.28),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color:
                                AppTheme.primaryLight.withValues(alpha: 0.32),
                            blurRadius: 8,
                            spreadRadius: 0.2,
                          ),
                        ]
                      : const [],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildControlButtons(bool isDark) {
    final statusText = _isRunning
        ? (_isBreak ? 'Short break running' : 'Focus in progress')
        : (_currentSeconds == _phaseTotalSeconds
            ? 'Tap play to start this cycle'
            : 'Tap play to resume this cycle');

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _TimerControlPill(
                label: 'Reset',
                icon: Icons.refresh_rounded,
                onTap: _resetTimer,
                isDark: isDark,
                isPrimary: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimerControlPill(
                label: _isRunning ? 'Pause' : 'Play',
                icon:
                    _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onTap: _isRunning ? _pauseTimer : _startTimer,
                isDark: isDark,
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimerControlPill(
                label: 'Skip',
                icon: Icons.skip_next_rounded,
                onTap: () {
                  _timer?.cancel();
                  _onTimerComplete();
                },
                isDark: isDark,
                isPrimary: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _currentSeconds > 60
                    ? () => _adjustRemainingTime(-5)
                    : null,
                icon: const Icon(Icons.remove_rounded),
                label: const Text('-5 min'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _adjustRemainingTime(5),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.92),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('+5 min'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            statusText,
            key: ValueKey(statusText),
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.getTextSecondary(isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistGeneratorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.getCardDecoration(
        isDark,
        accent: AppTheme.primaryColor,
        accentAlpha: 0.05,
        borderAlpha: 0.16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Checklist Generator',
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.getTextPrimary(isDark),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _checklist.isEmpty
                ? 'Generate 3 focused actions from your goal and notes.'
                : 'Generate 3 more fresh actions without repeating existing ones.',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.getTextSecondary(isDark),
            ),
          ),
          const SizedBox(height: 10),
          // ── Course / subject dropdown (AI Generator panel) ──────────────
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: DocumentService.watchCourses(),
            builder: (context, snap) {
              final courses = snap.data ?? [];
              final seenNames2 = <String>{};
              final items = <DropdownMenuItem<String>>[
                const DropdownMenuItem(
                  value: '',
                  child: Text('None'),
                ),
                ...courses
                    .map((c) => (c['name'] as String? ?? '').trim())
                    .where((name) => name.isNotEmpty && seenNames2.add(name))
                    .map((name) =>
                        DropdownMenuItem(value: name, child: Text(name))),
              ];
              final cur = _selectedSessionSubject;
              final validVal =
                  (cur == null || !items.any((i) => i.value == cur)) ? '' : cur;
              return DropdownButtonFormField<String>(
                value: validVal,
                decoration: const InputDecoration(
                  labelText: 'Session subject (optional)',
                  prefixIcon: Icon(Icons.book_outlined),
                ),
                items: items,
                onChanged: (v) {
                  setState(() {
                    _selectedSessionSubject = v;
                    _sessionSubjectController.text = v ?? '';
                  });
                },
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _goalController,
            decoration: const InputDecoration(
              labelText: 'Study goal',
              hintText: 'Example: Master stack and queue operations',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sourceController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Session context text',
              hintText: 'Paste notes or extracted PDF/PPTX text here',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingChecklist
                      ? null
                      : () => _generateChecklist(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isGeneratingChecklist
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    _isGeneratingChecklist
                        ? 'Analyzing with AI...'
                        : (_checklist.isEmpty
                            ? 'Generate Checklist (3)'
                            : 'Generate 3 More'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGeneratingChecklist
                      ? null
                      : () => _generateChecklist(isRetry: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _showChecklistSuccess
                ? Container(
                    key: const ValueKey('checklist-success-pill'),
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.success,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lastGeneratedCount > 0
                                ? 'Added $_lastGeneratedCount new checklist item${_lastGeneratedCount == 1 ? '' : 's'}. Review and continue.'
                                : 'Checklist ready. Review and start focus timer.',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('checklist-no-success')),
          ),
          if (_isGeneratingChecklist) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceColor(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Analyzing and generating checklist...',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Understanding goal, subject, and notes. Preparing task order.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.getTextSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_checklistError != null) ...[
            const SizedBox(height: 8),
            Text(
              _checklistError!,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistCard(bool isDark) {
    final selectedCount = _selectedChecklistCount();
    final completedCount = _completedSelectedChecklistCount();
    final progress = selectedCount == 0 ? 0.0 : completedCount / selectedCount;
    final allDone = _allSelectedChecklistDone();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.getCardDecoration(
        isDark,
        accent: AppTheme.primaryColor,
        accentAlpha: 0.04,
        borderAlpha: 0.14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Session Checklist', style: AppTheme.headingSmall),
              Text(
                '$completedCount/$selectedCount',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              key:
                  ValueKey('checklist-progress-$completedCount-$selectedCount'),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: progress),
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppTheme.getSurfaceColor(isDark),
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.primaryColor),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualItemController,
                  decoration: const InputDecoration(
                    hintText: 'Add checklist item',
                  ),
                  onSubmitted: (_) => _addManualChecklistItem(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addManualChecklistItem,
                icon: const Icon(Icons.add_circle_rounded),
                color: AppTheme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_checklist.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceColor(isDark),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'No checklist yet. Generate one with AI or add items manually.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.getTextSecondary(isDark),
                ),
              ),
            )
          else
            Column(
              children: _buildChecklistRows(isDark),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: allDone
                ? _buildAllTasksCompletionBanner(isDark)
                : const SizedBox.shrink(
                    key: ValueKey('all-checklist-incomplete-hint'),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChecklistRows(bool isDark) {
    return List.generate(_checklist.length, (index) {
      final item = _checklist[index];
      final isFocused = index == _activeChecklistIndex &&
          item.isSelected &&
          !item.isCompleted;
      final isRecent = _recentlyCompletedItemId == item.id;

      return TweenAnimationBuilder<double>(
        key: ValueKey('animated-check-item-${item.id}'),
        duration: Duration(milliseconds: 220 + (index * 40)),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey(item.id),
          child: _HoverLift(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (item.isCompleted
                            ? AppTheme.success
                            : AppTheme.primaryColor)
                        .withValues(
                      alpha:
                          item.isCompleted ? 0.14 : (isFocused ? 0.12 : 0.06),
                    ),
                    AppTheme.getSurfaceColor(isDark).withValues(alpha: 0.48),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: item.isCompleted
                      ? AppTheme.success.withValues(alpha: 0.38)
                      : (isFocused
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor.withValues(alpha: 0.18)),
                  width: isFocused ? 1.5 : 1,
                ),
                boxShadow: isRecent
                    ? [
                        BoxShadow(
                          color: AppTheme.success.withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : const [],
              ),
              child: ListTile(
                onTap: () => _markChecklistItemGuided(index),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                leading: GestureDetector(
                  onTap: () => _markChecklistItemGuided(index),
                  child: _ChecklistStatusBadge(
                    isCompleted: item.isCompleted,
                    isFocused: isFocused,
                    isRecent: isRecent,
                    isMorphing: _morphingChecklistItemIds.contains(item.id),
                    isDark: isDark,
                    isRunning: _isRunning,
                    isSelected: item.isSelected,
                    progress: _progress,
                  ),
                ),
                title: Text(
                  item.title,
                  style: AppTheme.bodyMedium.copyWith(
                    decoration: item.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: item.isCompleted
                        ? AppTheme.getTextSecondary(isDark)
                        : AppTheme.getTextPrimary(isDark),
                  ),
                ),
                subtitle: item.isCompleted || isFocused
                    ? Text(
                        item.isCompleted
                            ? 'Completed'
                            : (_isRunning ? 'In progress' : 'Ready to start'),
                        style: AppTheme.bodySmall.copyWith(
                          color: isFocused
                              ? AppTheme.primaryColor
                              : AppTheme.getTextSecondary(isDark),
                          fontWeight:
                              isFocused ? FontWeight.w700 : FontWeight.w400,
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          item.isSelected = !item.isSelected;
                          if (!item.isSelected) {
                            item.isCompleted = false;
                            _cancelChecklistMorphTimer(item.id);
                          }
                          if (!_allSelectedChecklistDone()) {
                            _cancelAllTasksSuccessTimers();
                            _showAllTasksSuccessPulse = false;
                            _showAllTasksSuccessCheck = false;
                          }
                          _refreshChecklistFocus();
                        });
                      },
                      icon: Icon(
                        item.isSelected
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: item.isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.getTextSecondary(isDark),
                      ),
                      tooltip: item.isSelected
                          ? 'Included in flow'
                          : 'Excluded from flow',
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: AppTheme.getTextSecondary(isDark),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _cancelChecklistMorphTimer(item.id);
                          _checklist.removeAt(index);
                          if (!_allSelectedChecklistDone()) {
                            _cancelAllTasksSuccessTimers();
                            _showAllTasksSuccessPulse = false;
                            _showAllTasksSuccessCheck = false;
                          }
                          _refreshChecklistFocus();
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAllTasksCompletionBanner(bool isDark) {
    final isPulsing = _showAllTasksSuccessPulse;
    final showCheck = _showAllTasksSuccessCheck || !isPulsing;

    return AnimatedScale(
      key: const ValueKey('all-checklist-complete-hint'),
      scale: isPulsing ? 1.06 : 1,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: EdgeInsets.symmetric(
          horizontal: isPulsing ? 18 : 16,
          vertical: isPulsing ? 16 : 13,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.success.withValues(alpha: isPulsing ? 0.28 : 0.16),
              AppTheme.getCardColor(isDark).withValues(alpha: 0.82),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.success.withValues(alpha: isPulsing ? 0.54 : 0.34),
            width: isPulsing ? 1.4 : 1.1,
          ),
          boxShadow: isPulsing
              ? [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              width: isPulsing ? 62 : 52,
              height: isPulsing ? 62 : 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showCheck
                    ? AppTheme.success
                    : AppTheme.success.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppTheme.success
                      .withValues(alpha: showCheck ? 0.84 : 0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.75, end: 1)
                            .animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: showCheck
                      ? Icon(
                          Icons.check_rounded,
                          key: const ValueKey('all-done-check'),
                          color: Colors.white,
                          size: isPulsing ? 34 : 28,
                        )
                      : SizedBox(
                          key: const ValueKey('all-done-progress'),
                          width: 28,
                          height: 28,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: 1,
                                strokeWidth: 2.6,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppTheme.success,
                                ),
                                backgroundColor:
                                    AppTheme.success.withValues(alpha: 0.2),
                              ),
                              const Icon(
                                Icons.schedule_rounded,
                                color: AppTheme.success,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Checklist Complete',
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All checklist steps are done. Continue to Focus Timer.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.getTextPrimary(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    final totalFocusMinutes = _completedSessions * _workDurationMinutes;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getCardDecoration(
        isDark,
        accent: AppTheme.primaryColor,
        accentAlpha: 0.03,
        borderAlpha: 0.12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session Progress', style: AppTheme.headingSmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.timer_outlined,
                  value: '$totalFocusMinutes',
                  unit: 'min',
                  label: 'Focus Time',
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppTheme.getSurfaceColor(isDark),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.repeat_rounded,
                  value: '$_completedSessions',
                  unit: '',
                  label: 'Cycles Done',
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppTheme.getSurfaceColor(isDark),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.checklist_rounded,
                  value: '${_checklist.where((i) => i.isCompleted).length}',
                  unit: '',
                  label: 'Items Done',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSessionOptions() {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Session Rules', style: AppTheme.headingSmall),
            const SizedBox(height: 12),
            Text(
              'Pomodoro is fixed to 25 min focus + 5 min break.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Planned cycles are based on selected checklist items.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _resetTimer();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reset Session Progress'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionChecklistItem {
  final String id;
  String title;
  bool isSelected = true;
  bool isCompleted = false;

  _SessionChecklistItem({
    required this.id,
    required this.title,
  });

  factory _SessionChecklistItem.fromTitle(String title) {
    return _SessionChecklistItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_${title.hashCode}',
      title: title,
    );
  }
}

class _CompletionMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _CompletionMetric({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(isDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.getTextPrimary(isDark),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.getTextSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class IslaPremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const IslaPremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? 20;

    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(isDark),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppTheme.getSurfaceColor(isDark).withValues(alpha: 0.58),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HoverLift extends StatefulWidget {
  final Widget child;
  final double hoverScale;
  final double hoverOffsetY;
  final Duration duration;

  const _HoverLift({
    super.key,
    required this.child,
    this.hoverScale = 1.015,
    this.hoverOffsetY = -2,
    this.duration = const Duration(milliseconds: 170),
  });

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Avoid web pointer-tracker assertion loops from custom hover transforms.
      return widget.child;
    }

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : (_hovered ? widget.hoverScale : 1),
          duration: widget.duration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: widget.duration,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(
              0,
              _pressed ? 0 : (_hovered ? widget.hoverOffsetY : 0),
              0,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color tickColor;
  final List<Color> gradientColors;
  final Color leadingDotColor;
  final double strokeWidth;

  _TimerRingPainter({
    required this.progress,
    required this.trackColor,
    required this.tickColor,
    required this.gradientColors,
    required this.leadingDotColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: outerR);

    // ── 1. Track ring (very subtle) ──────────────────────────────────────────
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, -pi / 2, 2 * pi, false, trackPaint);

    // ── 2. Minute tick marks (12 around the dial) ────────────────────────────
    const tickCount = 12;
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final tickOuter = outerR - strokeWidth * 0.6;
    final tickInner = tickOuter - strokeWidth * 0.45;
    for (var i = 0; i < tickCount; i++) {
      final a = (-pi / 2) + (2 * pi * i / tickCount);
      final cosA = cos(a);
      final sinA = sin(a);
      canvas.drawLine(
        Offset(center.dx + cosA * tickInner, center.dy + sinA * tickInner),
        Offset(center.dx + cosA * tickOuter, center.dy + sinA * tickOuter),
        tickPaint,
      );
    }

    if (progress <= 0) return;

    // ── 3. Progress arc with sweep gradient and rounded caps ─────────────────
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: (3 * pi) / 2,
        colors: gradientColors,
      ).createShader(rect);
    final sweep = (2 * pi * progress).clamp(0.0, 2 * pi);
    canvas.drawArc(rect, -pi / 2, sweep, false, progressPaint);

    // ── 4. Glowing leading dot at the progress tip ───────────────────────────
    final tipAngle = (-pi / 2) + sweep;
    final tipPos = Offset(
      center.dx + cos(tipAngle) * outerR,
      center.dy + sin(tipAngle) * outerR,
    );
    // Outer soft glow
    canvas.drawCircle(
      tipPos,
      strokeWidth * 1.1,
      Paint()
        ..color = leadingDotColor.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.7),
    );
    // Bright core
    canvas.drawCircle(
      tipPos,
      strokeWidth * 0.42,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.leadingDotColor != leadingDotColor ||
        oldDelegate.gradientColors != gradientColors;
  }
}

class _TimerControlPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final bool isPrimary;

  const _TimerControlPill({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDark,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isPrimary
        ? AppTheme.darkBackground.withValues(alpha: 0.9)
        : AppTheme.getTextSecondary(isDark);

    return _HoverLift(
      hoverScale: 1.02,
      hoverOffsetY: -1.5,
      duration: const Duration(milliseconds: 140),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryLight, AppTheme.primaryColor],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.getSurfaceColor(isDark).withValues(alpha: 0.78),
                      AppTheme.getCardColor(isDark).withValues(alpha: 0.68),
                    ],
                  ),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: isPrimary
                  ? AppTheme.primaryLight.withValues(alpha: 0.72)
                  : AppTheme.getSurfaceColor(isDark).withValues(alpha: 0.78),
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.34),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: isPrimary ? 30 : 24,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.headingSmall.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistStatusBadge extends StatelessWidget {
  final bool isCompleted;
  final bool isFocused;
  final bool isRecent;
  final bool isMorphing;
  final bool isDark;
  final bool isRunning;
  final bool isSelected;
  final double progress;

  const _ChecklistStatusBadge({
    required this.isCompleted,
    required this.isFocused,
    required this.isRecent,
    required this.isMorphing,
    required this.isDark,
    required this.isRunning,
    required this.isSelected,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final activeProgress =
        ((isRunning ? progress : 0.14).clamp(0.08, 1.0)).toDouble();

    Widget indicator;
    if (isCompleted && isMorphing) {
      indicator = Container(
        key: const ValueKey('check-item-morphing'),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.success.withValues(alpha: 0.86),
            width: 1.8,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 2.2,
                backgroundColor: AppTheme.success.withValues(alpha: 0.24),
                valueColor: const AlwaysStoppedAnimation(AppTheme.success),
              ),
            ),
            const Icon(
              Icons.schedule_rounded,
              color: AppTheme.success,
              size: 11,
            ),
          ],
        ),
      );
    } else if (isCompleted) {
      indicator = Container(
        key: const ValueKey('check-item-done'),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppTheme.success,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isRecent
              ? [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.38),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 20,
        ),
      );
    } else if (isFocused && isSelected) {
      indicator = Container(
        key: const ValueKey('check-item-active'),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.86),
            width: 1.8,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: activeProgress,
                strokeWidth: 2.2,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.24),
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
            ),
            const Icon(
              Icons.schedule_rounded,
              color: AppTheme.primaryColor,
              size: 11,
            ),
          ],
        ),
      );
    } else {
      indicator = Container(
        key: const ValueKey('check-item-idle'),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.getTextSecondary(isDark).withValues(
              alpha: isSelected ? 0.72 : 0.4,
            ),
            width: 1.8,
          ),
        ),
        child: Icon(
          Icons.radio_button_unchecked_rounded,
          color: AppTheme.getTextSecondary(isDark),
          size: 18,
        ),
      );
    }

    return AnimatedScale(
      scale: isRecent ? 1.1 : 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.78, end: 1).animate(animation),
              child: child,
            ),
          );
        },
        child: indicator,
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style:
                  AppTheme.headingMedium.copyWith(color: AppTheme.primaryColor),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.primaryColor),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTheme.bodySmall),
      ],
    );
  }
}
