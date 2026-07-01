import 'package:evoly/features/reminders/domain/reminder.dart';

abstract class ReminderRepository {
  Future<List<Reminder>> findEnabled();

  Future<List<Reminder>> findUpcoming(DateTime from, DateTime to);

  Future<List<Reminder>> findDue(DateTime now);

  Future<Reminder?> findByTaskId(String taskId);

  Future<void> save(Reminder reminder);

  Future<void> disable(String id);

  Future<void> disableForTask(String taskId);

  Future<void> markFired(String id, DateTime firedAt);
}
