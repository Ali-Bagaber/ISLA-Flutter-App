enum PomodoroPhase { focus, breakTime }

enum PomodoroRunStatus { planned, running, paused, completed, stopped }

class PomodoroRun {
  final String id;
  final String sessionId;
  final int cycleIndex;
  final PomodoroPhase phase;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int pausedSeconds;
  final PomodoroRunStatus status;

  const PomodoroRun({
    required this.id,
    required this.sessionId,
    required this.cycleIndex,
    required this.phase,
    required this.startedAt,
    this.endedAt,
    required this.pausedSeconds,
    required this.status,
  });
}
