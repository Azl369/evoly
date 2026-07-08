import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/coach/data/coach_repository.dart';
import 'package:evoly/features/coach/domain/coach_insight.dart';

class RuleBasedCoachService {
  const RuleBasedCoachService(this.repository);

  final CoachRepository repository;

  static const overloadTaskCount = 6;
  static const overloadEstimatedMinutes = 240;

  Future<CoachInsight> generateTodayInsight(DateTime now) async {
    final context = await repository.loadTodayContext(now);
    return generateFromContext(context, now);
  }

  CoachInsight generateFromContext(
    CoachTodayContext context,
    DateTime now,
  ) {
    final todayTasks = context.todayTasks;
    final pendingTasks = todayTasks.where((task) => !task.isCompleted).toList();
    final completedTaskCount = todayTasks.length - pendingTasks.length;
    final totalEstimatedMinutes = pendingTasks.fold<int>(
      0,
      (total, task) => total + task.estimatedMinutes,
    );

    final delayedGoals = context.delayedGoalStats.map((stat) {
      return CoachDelayedGoal(
        id: stat.goalId,
        title: stat.goalTitle,
        postponedTaskCount: stat.postponedTaskCount,
        latestPostponedAt: stat.latestPostponedAt,
      );
    }).toList();

    if (todayTasks.isEmpty) {
      return CoachInsight(
        status: CoachInsightStatus.empty,
        summary: '今天还没有可分析的任务。',
        pendingTaskCount: 0,
        completedTaskCount: 0,
        totalEstimatedMinutes: 0,
        topTasks: const [],
        delayedGoals: delayedGoals,
        suggestions: const [
          CoachSuggestion(
            type: CoachSuggestionType.empty,
            severity: CoachSuggestionSeverity.info,
            title: '添加今日任务',
            description: '创建一个 15 到 30 分钟的任务。',
          ),
        ],
      );
    }

    if (pendingTasks.isEmpty) {
      return CoachInsight(
        status: CoachInsightStatus.completed,
        summary: '今天的任务已全部完成。',
        pendingTaskCount: 0,
        completedTaskCount: completedTaskCount,
        totalEstimatedMinutes: 0,
        topTasks: const [],
        delayedGoals: delayedGoals,
        suggestions: const [
          CoachSuggestion(
            type: CoachSuggestionType.celebration,
            severity: CoachSuggestionSeverity.success,
            title: '记录复盘',
            description: '用 3 分钟记录今天的完成情况。',
          ),
        ],
      );
    }

    final overloadedByCount = pendingTasks.length > overloadTaskCount;
    final overloadedByTime = totalEstimatedMinutes > overloadEstimatedMinutes;
    final topTasks = _pickTopTasks(pendingTasks, now);
    final suggestions = _buildSuggestions(
      pendingTasks: pendingTasks,
      topTasks: topTasks,
      delayedGoals: delayedGoals,
      overloadedByCount: overloadedByCount,
      overloadedByTime: overloadedByTime,
    );

    final status = overloadedByCount || overloadedByTime
        ? CoachInsightStatus.overloaded
        : delayedGoals.isNotEmpty
            ? CoachInsightStatus.delayRisk
            : CoachInsightStatus.normal;

    return CoachInsight(
      status: status,
      summary: _summaryFor(
        pendingTaskCount: pendingTasks.length,
        totalEstimatedMinutes: totalEstimatedMinutes,
        overloadedByCount: overloadedByCount,
        overloadedByTime: overloadedByTime,
        hasDelayRisk: delayedGoals.isNotEmpty,
      ),
      pendingTaskCount: pendingTasks.length,
      completedTaskCount: completedTaskCount,
      totalEstimatedMinutes: totalEstimatedMinutes,
      overloadedByCount: overloadedByCount,
      overloadedByTime: overloadedByTime,
      topTasks: topTasks,
      delayedGoals: delayedGoals,
      suggestions: suggestions,
    );
  }

  List<CoachTopTask> _pickTopTasks(
    List<CoachTaskContext> pendingTasks,
    DateTime now,
  ) {
    final sorted = [...pendingTasks]..sort((left, right) {
        final scoreCompare = _scoreTask(right, now).compareTo(
          _scoreTask(left, now),
        );
        if (scoreCompare != 0) {
          return scoreCompare;
        }

        final leftDue = left.dueDateTime;
        final rightDue = right.dueDateTime;
        if (leftDue == null && rightDue == null) {
          return left.title.compareTo(right.title);
        }
        if (leftDue == null) {
          return 1;
        }
        if (rightDue == null) {
          return -1;
        }

        return leftDue.compareTo(rightDue);
      });

    return sorted.take(3).map((task) {
      return CoachTopTask(
        id: task.id,
        title: task.title,
        priority: task.priority,
        goalTitle: task.goalTitle,
        dueDateTime: task.dueDateTime,
        reason: _reasonFor(task, now),
      );
    }).toList();
  }

  int _scoreTask(CoachTaskContext task, DateTime now) {
    final priorityScore = switch (task.priority) {
      Priority.high => 300,
      Priority.medium => 200,
      Priority.low => 100,
    };

    final dueDate = task.dueDateTime;
    var dueScore = 0;
    if (dueDate != null) {
      final minutesUntilDue = dueDate.difference(now).inMinutes;
      if (minutesUntilDue < 0) {
        dueScore = 120;
      } else if (minutesUntilDue <= 60) {
        dueScore = 90;
      } else if (minutesUntilDue <= 180) {
        dueScore = 60;
      } else {
        dueScore = 30;
      }
    }

    return priorityScore + dueScore;
  }

  String _reasonFor(CoachTaskContext task, DateTime now) {
    final dueDate = task.dueDateTime;
    if (dueDate != null && dueDate.isBefore(now)) {
      return '已过计划时间';
    }
    if (task.priority == Priority.high) {
      return '高优先级';
    }
    if (dueDate != null && dueDate.difference(now).inHours <= 3) {
      return '截止时间靠前';
    }

    return '优先级和时间靠前';
  }

  List<CoachSuggestion> _buildSuggestions({
    required List<CoachTaskContext> pendingTasks,
    required List<CoachTopTask> topTasks,
    required List<CoachDelayedGoal> delayedGoals,
    required bool overloadedByCount,
    required bool overloadedByTime,
  }) {
    final suggestions = <CoachSuggestion>[];

    if (overloadedByCount || overloadedByTime) {
      suggestions.add(
        const CoachSuggestion(
          type: CoachSuggestionType.reduce,
          severity: CoachSuggestionSeverity.warning,
          title: '减少今日任务',
          description: '建议只保留最重要的 3 件事，其他任务延期或降级处理。',
        ),
      );
    }

    if (topTasks.any((task) => task.priority == Priority.high)) {
      suggestions.add(
        const CoachSuggestion(
          type: CoachSuggestionType.focus,
          severity: CoachSuggestionSeverity.info,
          title: '先做最高优先级',
          description: '从 Top 3 的第一项开始，完成后再处理下一项。',
        ),
      );
    }

    if (delayedGoals.isNotEmpty) {
      suggestions.add(
        CoachSuggestion(
          type: CoachSuggestionType.delayRisk,
          severity: CoachSuggestionSeverity.warning,
          title: '有项目正在反复延期',
          description: '把「${delayedGoals.first.title}」拆成更小的下一步，先做 15 分钟。',
        ),
      );
    }

    if (suggestions.isEmpty) {
      suggestions.add(
        const CoachSuggestion(
          type: CoachSuggestionType.focus,
          severity: CoachSuggestionSeverity.info,
          title: '任务量可控',
          description: '按 Top 3 顺序处理。',
        ),
      );
    }

    return suggestions.take(4).toList();
  }

  String _summaryFor({
    required int pendingTaskCount,
    required int totalEstimatedMinutes,
    required bool overloadedByCount,
    required bool overloadedByTime,
    required bool hasDelayRisk,
  }) {
    if (overloadedByCount || overloadedByTime) {
      return '今天有 $pendingTaskCount 个未完成任务，预计 $totalEstimatedMinutes 分钟，建议保留 Top 3。';
    }

    if (hasDelayRisk) {
      return '今天任务量可控，但有项目出现延期信号。';
    }

    return '今天有 $pendingTaskCount 个待完成任务，任务量可控。';
  }
}
