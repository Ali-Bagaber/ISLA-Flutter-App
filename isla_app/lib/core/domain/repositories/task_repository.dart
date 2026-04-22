import '../models/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getTasks();
  Future<Task?> getTaskById(String id);
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String id);
}
