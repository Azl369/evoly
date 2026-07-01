import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/coach/application/rule_based_coach_service.dart';
import 'package:evoly/features/coach/data/coach_repository.dart';
import 'package:evoly/features/coach/domain/coach_insight.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

void main() {
  group('RuleBasedCoachService', () {
    final now = DateTime(2026, 6, 27, 10);

    test('returns overload suggestion when pending task count exceeds limit',
        () {
      final service = RuleBasedCoachService(
        _FakeCoachRepository(
          CoachTodayContext(
            todayTasks: List.generate(
              7,
              (index) => _task(
                id: 'task-$index',
                title: '任务 $index',
                priority: Priority.low,
                dueDateTime: now.add(Duration(hours: index + 1)),
              ),
            ),
            delayedGoalStats: const [],
          ),
        ),
      );

      final insight = service.generateFromContext(
        service.repositoryContext,
        now,
      );

      expect(insight.status, CoachInsightStatus.overloaded);
      expect(insight.overloadedByCount, isTrue);
      expect(
        insight.suggestions.any(
          (suggestion) => suggestion.type == CoachSuggestionType.reduce,
        ),
        isTrue,
      );
    });

    test('returns overload suggestion when estimated minutes exceed limit', () {
      final service = RuleBasedCoachService(
        _FakeCoachRepository(
          CoachTodayContext(
            todayTasks: [
              _task(
                id: 'task-1',
                estimatedMinutes: 180,
                dueDateTime: now.add(const Duration(hours: 1)),
              ),
              _task(
                id: 'task-2',
                estimatedMinutes: 90,
                dueDateTime: now.add(const Duration(hours: 2)),
              ),
            ],
            delayedGoalStats: const [],
          ),
        ),
      );

      final insight = service.generateFromContext(
        service.repositoryContext,
        now,
      );

      expect(insight.status, CoachInsightStatus.overloaded);
      expect(insight.overloadedByTime, isTrue);
      expect(insight.totalEstimatedMinutes, 270);
    });

    test('picks top 3 by priority and due time', () {
      final context = CoachTodayContext(
        todayTasks: [
          _task(
            id: 'low-soon',
            title: '低优先级快到期',
            priority: Priority.low,
            dueDateTime: now.add(const Duration(minutes: 10)),
          ),
          _task(
            id: 'high-later',
            title: '高优先级稍后',
            priority: Priority.high,
            dueDateTime: now.add(const Duration(hours: 5)),
          ),
          _task(
            id: 'medium-overdue',
            title: '中优先级已过期',
            priority: Priority.medium,
            dueDateTime: now.subtract(const Duration(minutes: 20)),
          ),
          _task(
            id: 'medium-later',
            title: '中优先级稍后',
            priority: Priority.medium,
            dueDateTime: now.add(const Duration(hours: 4)),
          ),
        ],
        delayedGoalStats: const [],
      );

      final service = RuleBasedCoachService(_FakeCoachRepository(context));
      final insight = service.generateFromContext(context, now);

      expect(insight.topTasks.map((task) => task.id), [
        'high-later',
        'medium-overdue',
        'medium-later',
      ]);
    });

    test('does not include completed tasks in top 3', () {
      final context = CoachTodayContext(
        todayTasks: [
          _task(
            id: 'done',
            priority: Priority.high,
            status: TaskStatus.completed,
            completedAt: now,
            dueDateTime: now.add(const Duration(minutes: 10)),
          ),
          _task(
            id: 'pending',
            priority: Priority.medium,
            dueDateTime: now.add(const Duration(hours: 1)),
          ),
        ],
        delayedGoalStats: const [],
      );

      final service = RuleBasedCoachService(_FakeCoachRepository(context));
      final insight = service.generateFromContext(context, now);

      expect(insight.topTasks.map((task) => task.id), ['pending']);
    });

    test('returns delay risk when a goal has repeated postponed tasks', () {
      final context = CoachTodayContext(
        todayTasks: [
          _task(id: 'pending', dueDateTime: now.add(const Duration(hours: 1))),
        ],
        delayedGoalStats: [
          CoachDelayedGoalStat(
            goalId: 'goal-1',
            goalTitle: '英语学习',
            postponedTaskCount: 2,
            latestPostponedAt: now,
          ),
        ],
      );

      final service = RuleBasedCoachService(_FakeCoachRepository(context));
      final insight = service.generateFromContext(context, now);

      expect(insight.status, CoachInsightStatus.delayRisk);
      expect(insight.delayedGoals.single.title, '英语学习');
      expect(
        insight.suggestions.any(
          (suggestion) => suggestion.type == CoachSuggestionType.delayRisk,
        ),
        isTrue,
      );
    });

    test('returns empty suggestion when there are no today tasks', () {
      const context = CoachTodayContext(
        todayTasks: [],
        delayedGoalStats: [],
      );

      const service = RuleBasedCoachService(_FakeCoachRepository(context));
      final insight = service.generateFromContext(context, now);

      expect(insight.status, CoachInsightStatus.empty);
      expect(insight.summary, '今天还没有可分析的任务。');
      expect(insight.suggestions.single.type, CoachSuggestionType.empty);
    });
  });
}

extension on RuleBasedCoachService {
  CoachTodayContext get repositoryContext {
    final repository = this.repository as _FakeCoachRepository;
    return repository.context;
  }
}

class _FakeCoachRepository implements CoachRepository {
  const _FakeCoachRepository(this.context);

  final CoachTodayContext context;

  @override
  Future<CoachTodayContext> loadTodayContext(DateTime now) async => context;
}

CoachTaskContext _task({
  required String id,
  String title = '任务',
  Priority priority = Priority.medium,
  TaskStatus status = TaskStatus.pending,
  int estimatedMinutes = 30,
  DateTime? dueDateTime,
  DateTime? completedAt,
}) {
  return CoachTaskContext(
    id: id,
    goalId: 'goal-1',
    title: title,
    priority: priority,
    status: status,
    estimatedMinutes: estimatedMinutes,
    dueDateTime: dueDateTime,
    completedAt: completedAt,
    goalTitle: '成长目标',
  );
}
