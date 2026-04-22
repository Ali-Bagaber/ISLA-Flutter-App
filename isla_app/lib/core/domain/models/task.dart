enum TaskPriority { low, medium, high }

enum TaskStatus { pending, completed }

class Task {
  final String id;
  final String title;
  final String subject;
  final DateTime dueAt;
  final String notes;
  final int estimatedCycles;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? completedAt;

  const Task({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueAt,
    required this.notes,
    required this.estimatedCycles,
    required this.priority,
    required this.status,
    this.completedAt,
  });
}
