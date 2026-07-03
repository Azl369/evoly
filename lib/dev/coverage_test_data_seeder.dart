import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

class CoverageTestDataSeeder {
  const CoverageTestDataSeeder({
    required this.goalRepository,
    required this.taskRepository,
    required this.documentRepository,
    required this.reminderRepository,
  });

  final GoalRepository goalRepository;
  final TaskRepository taskRepository;
  final DocumentRepository documentRepository;
  final ReminderRepository reminderRepository;

  Future<CoverageSeedResult> seed({DateTime? clock}) async {
    final now = clock ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final goals = _buildGoals(now, today);
    final tasks = _buildTasks(now, today);
    final documents = _buildDocuments(now);
    final reminders = _buildReminders(now);

    for (final goal in goals) {
      await goalRepository.save(goal);
    }

    for (final task in tasks) {
      await taskRepository.save(task);
    }

    for (final document in documents) {
      await documentRepository.save(document);
    }

    await documentRepository.replaceLinkedGoals(
      'coverage-doc-project-note',
      const ['coverage-goal-today-focus'],
    );
    await documentRepository.replaceLinkedGoals(
      'coverage-doc-summary',
      const ['coverage-goal-docs'],
    );
    await documentRepository.replaceLinkedGoals(
      'coverage-doc-review',
      const ['coverage-goal-health', 'coverage-goal-learning'],
    );

    for (final reminder in reminders) {
      await reminderRepository.save(reminder);
    }

    return CoverageSeedResult(
      goals: goals.length,
      tasks: tasks.length,
      documents: documents.length,
      reminders: reminders.length,
    );
  }

  List<Goal> _buildGoals(DateTime now, DateTime today) {
    return [
      Goal(
        id: 'coverage-goal-today-focus',
        title: '今日高压发布检查 - 长标题用于测试目标卡片换行和编辑弹层密度',
        description: '覆盖高优先级、进行中、长描述、临近截止日期和多任务进度。用于观察列表卡片、详情页、Coach 和编辑目标弹层。',
        type: GoalType.oneTime,
        priority: Priority.high,
        status: GoalStatus.inProgress,
        startDate: today.subtract(const Duration(days: 2)),
        dueDate: today.add(const Duration(days: 1)),
        progress: 0.42,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(minutes: 8)),
      ),
      Goal(
        id: 'coverage-goal-learning',
        title: 'Flutter 动效练习',
        description: '覆盖未开始、中优先级、未来截止日期。',
        type: GoalType.longTerm,
        priority: Priority.medium,
        status: GoalStatus.notStarted,
        startDate: today,
        dueDate: today.add(const Duration(days: 21)),
        progress: 0,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      Goal(
        id: 'coverage-goal-health',
        title: '晨间健康节律',
        description: '覆盖已暂停、低优先级、无截止日期和周期目标。',
        type: GoalType.recurring,
        priority: Priority.low,
        status: GoalStatus.paused,
        startDate: today.subtract(const Duration(days: 14)),
        progress: 0.30,
        createdAt: now.subtract(const Duration(days: 18)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Goal(
        id: 'coverage-goal-docs',
        title: '文档库与知识沉淀',
        description: '覆盖已完成目标、满进度、关联文档和统计完成率。',
        type: GoalType.longTerm,
        priority: Priority.high,
        status: GoalStatus.completed,
        startDate: today.subtract(const Duration(days: 30)),
        dueDate: today.subtract(const Duration(days: 1)),
        progress: 1,
        createdAt: now.subtract(const Duration(days: 32)),
        updatedAt: now.subtract(const Duration(hours: 6)),
      ),
      Goal(
        id: 'coverage-goal-archive',
        title: '已放弃的旧计划',
        description: '覆盖已放弃状态、低进度和历史日期。',
        type: GoalType.oneTime,
        priority: Priority.low,
        status: GoalStatus.abandoned,
        startDate: today.subtract(const Duration(days: 45)),
        dueDate: today.subtract(const Duration(days: 20)),
        progress: 0.08,
        createdAt: now.subtract(const Duration(days: 46)),
        updatedAt: now.subtract(const Duration(days: 12)),
      ),
      Goal(
        id: 'coverage-goal-no-desc',
        title: '无描述短目标',
        type: GoalType.oneTime,
        priority: Priority.medium,
        status: GoalStatus.inProgress,
        startDate: today.subtract(const Duration(days: 3)),
        dueDate: today,
        progress: 0.66,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(minutes: 35)),
      ),
    ];
  }

  List<TaskItem> _buildTasks(DateTime now, DateTime today) {
    DateTime at(int hour, [int minute = 0]) {
      return DateTime(today.year, today.month, today.day, hour, minute);
    }

    return [
      TaskItem(
        id: 'coverage-task-high-today-long',
        goalId: 'coverage-goal-today-focus',
        title: '高优先级今日任务 - 很长的标题用于测试任务卡片、今日页分组和编辑子任务弹层的换行表现',
        description: '覆盖长标题、长说明、今日截止、高优先级和待完成状态。',
        priority: Priority.high,
        status: TaskStatus.pending,
        estimatedMinutes: 75,
        dueDateTime: at(9, 30),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(minutes: 12)),
      ),
      TaskItem(
        id: 'coverage-task-completed-today',
        goalId: 'coverage-goal-today-focus',
        title: '今天已完成：回归编辑目标弹层',
        description: '用于统计页今日完成、连续天数和完成反馈。',
        priority: Priority.medium,
        status: TaskStatus.completed,
        estimatedMinutes: 30,
        dueDateTime: at(10),
        completedAt: at(10, 25),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: at(10, 25),
      ),
      TaskItem(
        id: 'coverage-task-postponed-today',
        goalId: 'coverage-goal-today-focus',
        title: '今天已延期：等待接口确认',
        description: '用于 Coach 延期风险和统计页今日延期。',
        priority: Priority.low,
        status: TaskStatus.postponed,
        estimatedMinutes: 45,
        dueDateTime: at(14),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      TaskItem(
        id: 'coverage-task-pending-evening',
        goalId: 'coverage-goal-no-desc',
        title: '今晚检查主题切换流畅度',
        description: '覆盖晚间截止、普通标题和中优先级。',
        priority: Priority.medium,
        status: TaskStatus.pending,
        estimatedMinutes: 25,
        dueDateTime: at(23, 50),
        createdAt: now.subtract(const Duration(hours: 10)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
      ),
      TaskItem(
        id: 'coverage-task-cancelled-today',
        goalId: 'coverage-goal-today-focus',
        title: '已取消：旧版下拉框回归测试',
        description: '今日页应排除取消任务，详情页仍可覆盖取消状态。',
        priority: Priority.high,
        status: TaskStatus.cancelled,
        estimatedMinutes: 20,
        dueDateTime: at(15),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      TaskItem(
        id: 'coverage-task-tomorrow',
        goalId: 'coverage-goal-learning',
        title: '明天任务：整理动效 token',
        description: '覆盖未来日期。',
        priority: Priority.high,
        status: TaskStatus.pending,
        estimatedMinutes: 60,
        dueDateTime: at(11).add(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      TaskItem(
        id: 'coverage-task-no-due',
        goalId: 'coverage-goal-learning',
        title: '无截止时间：阅读 Material 3 表单密度',
        description: '覆盖无截止时间在详情页和编辑页里的展示。',
        priority: Priority.medium,
        status: TaskStatus.pending,
        estimatedMinutes: 40,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
      TaskItem(
        id: 'coverage-task-overdue',
        goalId: 'coverage-goal-health',
        title: '昨日未完成：补一次拉伸',
        description: '覆盖过期但未完成。',
        priority: Priority.medium,
        status: TaskStatus.pending,
        estimatedMinutes: 15,
        dueDateTime: at(8).subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      TaskItem(
        id: 'coverage-task-postponed-week',
        goalId: 'coverage-goal-health',
        title: '本周延期：晨跑改成散步',
        description: '覆盖周延期统计。',
        priority: Priority.low,
        status: TaskStatus.postponed,
        estimatedMinutes: 35,
        dueDateTime: at(7).subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      TaskItem(
        id: 'coverage-task-completed-yesterday',
        goalId: 'coverage-goal-docs',
        title: '昨天已完成：整理文档文件夹',
        description: '用于连续完成天数。',
        priority: Priority.high,
        status: TaskStatus.completed,
        estimatedMinutes: 50,
        dueDateTime: at(18).subtract(const Duration(days: 1)),
        completedAt: at(18, 10).subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: at(18, 10).subtract(const Duration(days: 1)),
      ),
      TaskItem(
        id: 'coverage-task-completed-two-days-ago',
        goalId: 'coverage-goal-docs',
        title: '前天已完成：补充音乐 Markdown 样例',
        description: '用于连续完成天数和文档预览。',
        priority: Priority.medium,
        status: TaskStatus.completed,
        estimatedMinutes: 35,
        dueDateTime: at(20).subtract(const Duration(days: 2)),
        completedAt: at(20, 20).subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: at(20, 20).subtract(const Duration(days: 2)),
      ),
      TaskItem(
        id: 'coverage-task-completed-three-days-ago',
        goalId: 'coverage-goal-docs',
        title: '三天前已完成：补齐统计图文字标签',
        description: '用于连续完成天数下探。',
        priority: Priority.low,
        status: TaskStatus.completed,
        estimatedMinutes: 25,
        dueDateTime: at(19).subtract(const Duration(days: 3)),
        completedAt: at(19, 15).subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: at(19, 15).subtract(const Duration(days: 3)),
      ),
      TaskItem(
        id: 'coverage-task-abandoned-cancelled',
        goalId: 'coverage-goal-archive',
        title: '已取消：旧计划中的任务',
        description: '覆盖已放弃目标下的取消任务。',
        priority: Priority.low,
        status: TaskStatus.cancelled,
        estimatedMinutes: 90,
        dueDateTime: at(16).subtract(const Duration(days: 21)),
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now.subtract(const Duration(days: 20)),
      ),
    ];
  }

  List<EvolyDocument> _buildDocuments(DateTime now) {
    return [
      EvolyDocument(
        id: 'coverage-doc-project-note',
        title: '覆盖测试：目标编辑和今日页检查清单',
        contentMarkdown: '''
# 今日 UI 覆盖清单

- [ ] 编辑目标弹层：键盘弹出时高度是否自然
- [ ] 优先级/目标状态：长按后上下滑动选择
- [ ] Today Coach：浅色高级感、卡片密度
- [ ] 任务卡片：长标题、延期、完成、删除反馈

> 这份文档关联到高压发布目标，用于测试文档文件夹里的最新文档摘要。
''',
        type: DocumentType.projectNote,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(minutes: 18)),
      ),
      EvolyDocument(
        id: 'coverage-doc-summary',
        title: '覆盖测试：已完成目标总结',
        contentMarkdown: '''
# 已完成目标总结

本条用于测试目标完成状态、统计完成率、文档库项目总结类型。

## 结果

- 完成率：100%
- 复盘状态：可归档
- 下一步：把可复用组件抽到共享层
''',
        type: DocumentType.projectSummary,
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(hours: 6)),
      ),
      EvolyDocument(
        id: 'coverage-doc-review',
        title: '覆盖测试：一次 UI 重构复盘',
        contentMarkdown: '''
# UI 重构复盘

## 做得好的地方

1. 用 token 收束颜色和间距。
2. 把选择器从弹框改成悬浮滑动。
3. 保留信息密度，减少无意义留白。

## 需要继续观察

- 小屏横屏时 BottomSheet 是否仍然稳定。
- 系统字体调大到 1.3x 后卡片是否溢出。
- 主题切换期间是否还有明显掉帧。
''',
        type: DocumentType.review,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      EvolyDocument(
        id: 'coverage-doc-knowledge',
        title: '覆盖测试：Markdown 数学与音乐块',
        contentMarkdown: r'''
# Markdown 能力覆盖

Inline math $x^2 + y^2 = z^2$.

$$
E = mc^2
$$

```chordpro
{title: Evoly Theme}
[C]Focus [G]flows [Am]quietly
```

```tab
e|---0-1-3-|
B|---------|
G|---------|
D|---------|
A|---------|
E|---------|
```

```abc
X:1
T:C Major Scale
K:C
C D E F |
```
''',
        type: DocumentType.knowledge,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      EvolyDocument(
        id: 'coverage-doc-untitled',
        title: '',
        contentMarkdown: '',
        type: DocumentType.projectNote,
        createdAt: now.subtract(const Duration(hours: 12)),
        updatedAt: now.subtract(const Duration(hours: 12)),
      ),
    ];
  }

  List<Reminder> _buildReminders(DateTime now) {
    return [
      Reminder(
        id: 'coverage-reminder-task-soon',
        targetType: ReminderTargetType.task,
        targetId: 'coverage-task-high-today-long',
        remindAt: now.add(const Duration(minutes: 20)),
        repeatRule: RepeatRule.none,
        advanceMinutes: 10,
        enabled: true,
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(minutes: 5)),
      ),
      Reminder(
        id: 'coverage-reminder-goal-weekly',
        targetType: ReminderTargetType.goal,
        targetId: 'coverage-goal-learning',
        remindAt: now.add(const Duration(days: 2)),
        repeatRule: RepeatRule.weekly,
        advanceMinutes: 0,
        enabled: true,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Reminder(
        id: 'coverage-reminder-disabled-fired',
        targetType: ReminderTargetType.task,
        targetId: 'coverage-task-completed-yesterday',
        remindAt: now.subtract(const Duration(days: 1, hours: 1)),
        repeatRule: RepeatRule.none,
        advanceMinutes: 0,
        enabled: false,
        firedAt: now.subtract(const Duration(days: 1, hours: 1)),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}

class CoverageSeedResult {
  const CoverageSeedResult({
    required this.goals,
    required this.tasks,
    required this.documents,
    required this.reminders,
  });

  final int goals;
  final int tasks;
  final int documents;
  final int reminders;
}
