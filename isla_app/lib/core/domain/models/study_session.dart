enum StudySessionStatus { planned, active, paused, completed, stopped }

class StudySession {
  final String id;
  final String taskId;
  final String subjectSnapshot;
  final String goal;
  final int plannedCycles;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final StudySessionStatus status;

  const StudySession({
    required this.id,
    required this.taskId,
    required this.subjectSnapshot,
    required this.goal,
    required this.plannedCycles,
    this.startedAt,
    this.endedAt,
    required this.status,
  });
}
