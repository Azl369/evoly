import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:uuid/uuid.dart';

class TaskReminderService {
  const TaskReminderService(this.repository);

  final ReminderRepository repository;

  Future<Reminder?> findForTask(String taskId) {
    return repository.findByTaskId(taskId);
  }

  Future<void> saveForTask({
    required String taskId,
    required DateTime? remindAt,
  }) async {
    await repository.disableForTask(taskId);

    if (remindAt == null) {
      return;
    }

    final now = DateTime.now();
    const uuid = Uuid();
    await repository.save(
      Reminder(
        id: uuid.v4(),
        targetType: ReminderTargetType.task,
        targetId: taskId,
        remindAt: remindAt,
        repeatRule: RepeatRule.none,
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
