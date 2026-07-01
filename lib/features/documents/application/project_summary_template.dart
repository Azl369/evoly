import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

String buildProjectSummaryMarkdown({
  required Goal goal,
  required List<TaskItem> tasks,
  required double progress,
  required DateTime generatedAt,
}) {
  final completedTasks = tasks.where((task) => task.isCompleted).toList();
  final unfinishedTasks = tasks.where((task) => !task.isCompleted).toList();
  final progressPercent = (progress * 100).round();
  final generatedDate = _formatDate(generatedAt);

  String taskLine(TaskItem task, {required bool completed}) {
    final mark = completed ? 'x' : ' ';
    final status = task.status.label;
    return '- [$mark] ${task.title}（$status，${task.priority.label}优先级）';
  }

  String taskLines(List<TaskItem> items, {required bool completed}) {
    if (items.isEmpty) {
      return '- 暂无';
    }

    return items.map((task) => taskLine(task, completed: completed)).join('\n');
  }

  final goalDescription = goal.description.trim().isEmpty
      ? '（这里补充这个目标最初想解决什么问题，以及为什么重要。）'
      : goal.description.trim();

  return '''
# 项目总结：${goal.title}

> 由 Evoly 于 $generatedDate 生成。你可以继续编辑，把真实过程和经验补充完整。

## 1. 项目目标

$goalDescription

## 2. 完成结果

- 当前进度：$progressPercent%
- 子任务总数：${tasks.length}
- 已完成任务：${completedTasks.length}
- 未完成 / 延期任务：${unfinishedTasks.length}

请在这里补充最终交付物、实际结果和验收结论。

## 3. 已完成任务

${taskLines(completedTasks, completed: true)}

## 4. 未完成 / 延期任务

${taskLines(unfinishedTasks, completed: false)}

## 5. 关键过程记录

- 做过哪些关键决策？
- 哪些步骤最有效？
- 哪些地方花了比预期更多的时间？

## 6. 遇到的问题

- 问题 1：
- 问题 2：
- 问题 3：

## 7. 解决方案

- 方案 1：
- 方案 2：
- 方案 3：

## 8. 可复用经验

- 下次遇到类似目标，可以复用什么流程、模板或判断？

## 9. 下次可以改进

- 哪些事情可以更早做？
- 哪些任务可以拆得更小？
- 哪些风险应该提前处理？
''';
}

String _formatDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
}
