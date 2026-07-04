import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/data_refresh_controller.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/desktop_window/application/compact_reminder_service.dart';
import 'package:evoly/features/desktop_window/domain/compact_reminder_snapshot.dart';
import 'package:evoly/features/reminders/application/task_reminder_service.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

class CompactReminderPanel extends StatefulWidget {
  const CompactReminderPanel({
    required this.expanded,
    required this.onToggleExpanded,
    required this.onOpenFullMode,
    required this.onHideWindow,
    required this.onStartDrag,
    required this.onEndDrag,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String?> onOpenFullMode;
  final VoidCallback onHideWindow;
  final VoidCallback onStartDrag;
  final VoidCallback onEndDrag;

  @override
  State<CompactReminderPanel> createState() => _CompactReminderPanelState();
}

class _CompactReminderPanelState extends State<CompactReminderPanel> {
  late Future<CompactReminderSnapshot> _snapshotFuture;
  int? _lastRefreshRevision;
  Timer? _dragFeedbackTimer;
  var _panelHovered = false;
  var _dragging = false;
  String? _dragFeedback;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = context.watch<DataRefreshController>().revision;
    final lastRevision = _lastRefreshRevision;
    _lastRefreshRevision = revision;

    if (lastRevision != null && lastRevision != revision) {
      _snapshotFuture = _loadSnapshot();
    }
  }

  @override
  void dispose() {
    _dragFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setPanelHovered(true),
      onExit: (_) => _setPanelHovered(false),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: FutureBuilder<CompactReminderSnapshot>(
              future: _snapshotFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                final child = switch (snapshot.connectionState) {
                  ConnectionState.waiting when data == null =>
                    const _CompactLoadingState(),
                  _ when snapshot.hasError => _CompactErrorState(
                      onRetry: _reload,
                    ),
                  _ => _CompactReminderContent(
                      snapshot: data,
                      expanded: widget.expanded,
                      actionsVisible: _panelHovered || _dragging,
                      dragFeedback: _dragFeedback,
                      onToggleExpanded: widget.onToggleExpanded,
                      onOpenFullMode: widget.onOpenFullMode,
                      onHideWindow: widget.onHideWindow,
                      onStartDrag: _handleStartDrag,
                      onEndDrag: _handleEndDrag,
                      onCompleteTask: _completeTask,
                      onPostponeTask: _postponeTask,
                      onRefresh: _reload,
                    ),
                };

                return AnimatedSwitcher(
                  duration: MotionTokens.fast,
                  switchInCurve: MotionTokens.gentle,
                  switchOutCurve: MotionTokens.gentle,
                  child: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<CompactReminderSnapshot> _loadSnapshot() {
    return context.read<CompactReminderService>().loadSnapshot(DateTime.now());
  }

  void _reload() {
    setState(() => _snapshotFuture = _loadSnapshot());
  }

  void _setPanelHovered(bool value) {
    if (_panelHovered == value) {
      return;
    }

    setState(() => _panelHovered = value);
  }

  void _handleStartDrag() {
    _dragFeedbackTimer?.cancel();
    setState(() {
      _dragging = true;
      _dragFeedback = '拖动中';
    });
    widget.onStartDrag();
  }

  void _handleEndDrag() {
    widget.onEndDrag();
    _dragFeedbackTimer?.cancel();
    if (!mounted) {
      return;
    }

    setState(() {
      _dragging = false;
      _dragFeedback = '位置已保存';
    });
    _dragFeedbackTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) {
        return;
      }

      setState(() => _dragFeedback = null);
    });
  }

  Future<void> _completeTask(String taskId) async {
    final taskRepository = context.read<TaskRepository>();
    final reminderService = context.read<TaskReminderService>();
    final task = await taskRepository.findById(taskId);
    if (task == null || task.isCompleted) {
      _reload();
      return;
    }

    final now = DateTime.now();
    await taskRepository.save(
      task.copyWith(
        status: TaskStatus.completed,
        completedAt: now,
        updatedAt: now,
      ),
    );
    await reminderService.saveForTask(taskId: taskId, remindAt: null);
    if (!mounted) {
      return;
    }

    context.read<DataRefreshController>().markChanged();
    _reload();
  }

  Future<void> _postponeTask(String taskId) async {
    final taskRepository = context.read<TaskRepository>();
    final task = await taskRepository.findById(taskId);
    if (task == null || task.isCompleted) {
      _reload();
      return;
    }

    final now = DateTime.now();
    final currentDueDate = task.dueDateTime ?? now;
    final nextDay = currentDueDate.add(const Duration(days: 1));
    await taskRepository.save(
      task.copyWith(
        status: TaskStatus.postponed,
        dueDateTime: DateTime(
          nextDay.year,
          nextDay.month,
          nextDay.day,
          currentDueDate.hour,
          currentDueDate.minute,
        ),
        updatedAt: now,
      ),
    );
    if (!mounted) {
      return;
    }

    context.read<DataRefreshController>().markChanged();
    _reload();
  }
}

class _CompactReminderContent extends StatelessWidget {
  const _CompactReminderContent({
    required this.snapshot,
    required this.expanded,
    required this.actionsVisible,
    required this.dragFeedback,
    required this.onToggleExpanded,
    required this.onOpenFullMode,
    required this.onHideWindow,
    required this.onStartDrag,
    required this.onEndDrag,
    required this.onCompleteTask,
    required this.onPostponeTask,
    required this.onRefresh,
  });

  final CompactReminderSnapshot? snapshot;
  final bool expanded;
  final bool actionsVisible;
  final String? dragFeedback;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String?> onOpenFullMode;
  final VoidCallback onHideWindow;
  final VoidCallback onStartDrag;
  final VoidCallback onEndDrag;
  final ValueChanged<String> onCompleteTask;
  final ValueChanged<String> onPostponeTask;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    if (data == null) {
      return const _CompactLoadingState();
    }

    final skin = _CompactGlassSkin.of(context);
    final tokens = EvolyDesignTokens.of(context);

    return SizedBox.expand(
      child: AnimatedContainer(
        duration: MotionTokens.fast,
        curve: MotionTokens.gentle,
        decoration: BoxDecoration(
          gradient: skin.panelGradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: actionsVisible ? skin.borderActive : skin.border,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: skin.shadow,
              blurRadius: actionsVisible ? 20 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: tokens.glassBlurSigma + 4,
              sigmaY: tokens.glassBlurSigma + 4,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: skin.innerHighlight),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CompactHeader(
                          snapshot: data,
                          expanded: expanded,
                          actionsVisible: actionsVisible,
                          dragFeedback: dragFeedback,
                          onToggleExpanded: onToggleExpanded,
                          onOpenFullMode: () => onOpenFullMode(null),
                          onHideWindow: onHideWindow,
                          onStartDrag: onStartDrag,
                          onEndDrag: onEndDrag,
                          onRefresh: onRefresh,
                        ),
                        const SizedBox(height: 5),
                        _NextReminderBlock(
                          reminder: data.nextReminder,
                          onOpenTask: onOpenFullMode,
                        ),
                        const SizedBox(height: 5),
                        _CompactMetricGrid(snapshot: data, expanded: expanded),
                        Expanded(
                          child: _CompactExpandedArea(
                            expanded: expanded,
                            child: _HighPriorityTaskList(
                              tasks: data.highPriorityTasks,
                              onOpenTask: onOpenFullMode,
                              onCompleteTask: onCompleteTask,
                              onPostponeTask: onPostponeTask,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.snapshot,
    required this.expanded,
    required this.actionsVisible,
    required this.dragFeedback,
    required this.onToggleExpanded,
    required this.onOpenFullMode,
    required this.onHideWindow,
    required this.onStartDrag,
    required this.onEndDrag,
    required this.onRefresh,
  });

  final CompactReminderSnapshot snapshot;
  final bool expanded;
  final bool actionsVisible;
  final String? dragFeedback;
  final VoidCallback onToggleExpanded;
  final VoidCallback onOpenFullMode;
  final VoidCallback onHideWindow;
  final VoidCallback onStartDrag;
  final VoidCallback onEndDrag;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skin = _CompactGlassSkin.of(context);
    final feedback = dragFeedback;
    final statusText = feedback ?? '提醒面板';

    return Row(
      children: [
        Expanded(
          child: _CompactDragHandle(
            onStartDrag: onStartDrag,
            onEndDrag: onEndDrag,
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: skin.brandGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: skin.iconOnAccent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Evoly',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: skin.textStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: MotionTokens.fast,
                        switchInCurve: MotionTokens.gentle,
                        switchOutCurve: MotionTokens.gentle,
                        child: Text(
                          statusText,
                          key: ValueKey(statusText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: feedback == null
                                ? skin.textMuted
                                : skin.accentStrong,
                            fontWeight: feedback == null
                                ? FontWeight.w700
                                : FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _CompactIconButton(
          tooltip: '刷新',
          icon: Icons.refresh_rounded,
          onPressed: onRefresh,
          revealed: actionsVisible,
        ),
        _CompactIconButton(
          tooltip: expanded ? '收起' : '展开',
          icon: expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          onPressed: onToggleExpanded,
        ),
        _CompactIconButton(
          tooltip: '打开完整模式',
          icon: Icons.open_in_full_rounded,
          onPressed: onOpenFullMode,
          revealed: actionsVisible,
        ),
        _CompactIconButton(
          tooltip: '隐藏窗口',
          icon: Icons.visibility_off_outlined,
          onPressed: onHideWindow,
          revealed: actionsVisible,
        ),
      ],
    );
  }
}

class _CompactExpandedArea extends StatelessWidget {
  const _CompactExpandedArea({
    required this.expanded,
    required this.child,
  });

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: MotionTokens.normal,
        switchInCurve: MotionTokens.gentle,
        switchOutCurve: MotionTokens.gentle,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topLeft,
            children: [
              if (expanded) ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topLeft,
              child: child,
            ),
          );
        },
        child: expanded
            ? Padding(
                key: const ValueKey('expanded'),
                padding: const EdgeInsets.only(top: AppSpacing.compact),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: double.infinity,
                    child: child,
                  ),
                ),
              )
            : const SizedBox(
                key: ValueKey('collapsed'),
                width: double.infinity,
              ),
      ),
    );
  }
}

class _NextReminderBlock extends StatelessWidget {
  const _NextReminderBlock({
    required this.reminder,
    required this.onOpenTask,
  });

  final CompactReminderItem? reminder;
  final ValueChanged<String?> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skin = _CompactGlassSkin.of(context);
    final reminder = this.reminder;
    final status = _reminderStatus(reminder);

    return Semantics(
      button: reminder != null,
      label: reminder == null ? '暂无下一条提醒' : '打开下一条提醒',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: reminder == null ? null : () => onOpenTask(reminder.taskId),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: skin.cardGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: skin.cardBorder),
            boxShadow: [
              BoxShadow(
                color: skin.cardShadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '下一个提醒',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: skin.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(
                            reminder == null
                                ? '暂无'
                                : _formatTime(reminder.remindAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: reminder == null
                                  ? skin.textFaint
                                  : skin.accentStrong,
                              fontFeatures: const [
                                ui.FontFeature.tabularFigures(),
                              ],
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reminder?.title ?? '暂无提醒',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: skin.textStrong,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _CompactStatusPill(status: status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactStatusPill extends StatelessWidget {
  const _CompactStatusPill({required this.status});

  final _ReminderStatus status;

  @override
  Widget build(BuildContext context) {
    final skin = _CompactGlassSkin.of(context);
    final theme = Theme.of(context);
    final color = switch (status) {
      _ReminderStatus.empty => skin.textFaint,
      _ReminderStatus.due => skin.statusWarning,
      _ReminderStatus.upcoming => skin.statusSuccess,
    };
    final label = switch (status) {
      _ReminderStatus.empty => '暂无',
      _ReminderStatus.due => '已到时',
      _ReminderStatus.upcoming => '待提醒',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 6, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetricGrid extends StatelessWidget {
  const _CompactMetricGrid({
    required this.snapshot,
    required this.expanded,
  });

  final CompactReminderSnapshot snapshot;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: expanded ? 42 : 30,
      child: Row(
        children: [
          Expanded(
            child: _CompactMetricCard(
              label: '未完成',
              value: snapshot.pendingCount,
              icon: Icons.task_alt_rounded,
              expanded: expanded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompactMetricCard(
              label: '已到时',
              value: snapshot.overdueCount,
              icon: Icons.timer_outlined,
              emphasized: snapshot.overdueCount > 0,
              expanded: expanded,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetricCard extends StatelessWidget {
  const _CompactMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.expanded,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool expanded;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final skin = _CompactGlassSkin.of(context);
    final theme = Theme.of(context);
    final color = emphasized ? skin.statusWarning : skin.metricAccent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: skin.metricBackground,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: skin.cardBorder),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: expanded ? 7 : 3,
        ),
        child: Row(
          children: [
            Icon(icon, size: expanded ? 15 : 13, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: skin.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              value.toString(),
              style: (expanded
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.labelLarge)
                  ?.copyWith(
                color: color,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighPriorityTaskList extends StatelessWidget {
  const _HighPriorityTaskList({
    required this.tasks,
    required this.onOpenTask,
    required this.onCompleteTask,
    required this.onPostponeTask,
  });

  final List<CompactTaskItem> tasks;
  final ValueChanged<String?> onOpenTask;
  final ValueChanged<String> onCompleteTask;
  final ValueChanged<String> onPostponeTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skin = _CompactGlassSkin.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '高优先级',
              style: theme.textTheme.titleSmall?.copyWith(
                color: skin.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${tasks.length}/3',
              style: theme.textTheme.labelSmall?.copyWith(
                color: skin.textFaint,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (tasks.isEmpty)
          const _CompactEmptyLine()
        else
          for (final task in tasks)
            _CompactTaskRow(
              task: task,
              onOpen: () => onOpenTask(task.id),
              onComplete: () => onCompleteTask(task.id),
              onPostpone: () => onPostponeTask(task.id),
            ),
      ],
    );
  }
}

class _CompactTaskRow extends StatefulWidget {
  const _CompactTaskRow({
    required this.task,
    required this.onOpen,
    required this.onComplete,
    required this.onPostpone,
  });

  final CompactTaskItem task;
  final VoidCallback onOpen;
  final VoidCallback onComplete;
  final VoidCallback onPostpone;

  @override
  State<_CompactTaskRow> createState() => _CompactTaskRowState();
}

class _CompactTaskRowState extends State<_CompactTaskRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skin = _CompactGlassSkin.of(context);
    final borderColor = _hovered ? skin.borderActive : skin.cardBorder;
    final backgroundColor = _hovered ? skin.rowHover : skin.rowBackground;

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: MotionTokens.fast,
          curve: MotionTokens.gentle,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: _priorityColor(skin, widget.task.priority),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: skin.textStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.task.estimatedMinutes > 0) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${widget.task.estimatedMinutes}m',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: skin.textFaint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.xs),
                  _CompactIconButton(
                    tooltip: '完成',
                    icon: Icons.check_rounded,
                    onPressed: widget.onComplete,
                    revealed: _hovered,
                  ),
                  _CompactIconButton(
                    tooltip: '延后到明天',
                    icon: Icons.event_repeat_rounded,
                    onPressed: widget.onPostpone,
                    revealed: _hovered,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactEmptyLine extends StatelessWidget {
  const _CompactEmptyLine();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skin = _CompactGlassSkin.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 16,
            color: skin.textFaint,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '暂无高优先级任务',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: skin.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactLoadingState extends StatelessWidget {
  const _CompactLoadingState();

  @override
  Widget build(BuildContext context) {
    return _CompactStateShell(
      child: DefaultTextStyle.merge(
        style: TextStyle(color: _CompactGlassSkin.of(context).textMuted),
        child: const AppLoadingState(label: '加载提醒', compact: true),
      ),
    );
  }
}

class _CompactErrorState extends StatelessWidget {
  const _CompactErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skin = _CompactGlassSkin.of(context);

    return _CompactStateShell(
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: skin.statusWarning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '提醒加载失败',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: skin.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                '重试',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: skin.accentStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatefulWidget {
  const _CompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.revealed = true,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool revealed;

  @override
  State<_CompactIconButton> createState() => _CompactIconButtonState();
}

class _CompactIconButtonState extends State<_CompactIconButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final skin = _CompactGlassSkin.of(context);
    final backgroundColor =
        _hovered && widget.revealed ? skin.actionHover : Colors.transparent;

    return SizedBox.square(
      dimension: 28,
      child: ExcludeSemantics(
        excluding: !widget.revealed,
        child: IgnorePointer(
          ignoring: !widget.revealed,
          child: AnimatedOpacity(
            duration: MotionTokens.fast,
            curve: MotionTokens.gentle,
            opacity: widget.revealed ? 1 : 0,
            child: Semantics(
              button: true,
              label: widget.tooltip,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onPressed,
                  child: AnimatedContainer(
                    duration: MotionTokens.fast,
                    curve: MotionTokens.gentle,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(
                        color: _hovered && widget.revealed
                            ? skin.actionBorder
                            : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: 17,
                        color: skin.actionIcon,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactDragHandle extends StatelessWidget {
  const _CompactDragHandle({
    required this.child,
    required this.onStartDrag,
    required this.onEndDrag,
  });

  final Widget child;
  final VoidCallback onStartDrag;
  final VoidCallback onEndDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => onStartDrag(),
        onPanEnd: (_) => onEndDrag(),
        onPanCancel: onEndDrag,
        child: child,
      ),
    );
  }
}

Color _priorityColor(_CompactGlassSkin skin, Priority priority) {
  return switch (priority) {
    Priority.high => skin.statusWarning,
    Priority.medium => skin.metricAccent,
    Priority.low => skin.accent,
  };
}

String _formatTime(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}

enum _ReminderStatus {
  empty,
  due,
  upcoming,
}

_ReminderStatus _reminderStatus(CompactReminderItem? reminder) {
  if (reminder == null) {
    return _ReminderStatus.empty;
  }

  return reminder.remindAt.isBefore(DateTime.now())
      ? _ReminderStatus.due
      : _ReminderStatus.upcoming;
}

class _CompactStateShell extends StatelessWidget {
  const _CompactStateShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = _CompactGlassSkin.of(context);
    final tokens = EvolyDesignTokens.of(context);

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: skin.panelGradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: skin.border, width: 0.8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: tokens.glassBlurSigma + 4,
              sigmaY: tokens.glassBlurSigma + 4,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactGlassSkin {
  const _CompactGlassSkin({
    required this.panelGradient,
    required this.brandGradient,
    required this.cardGradient,
    required this.border,
    required this.borderActive,
    required this.innerHighlight,
    required this.cardBorder,
    required this.shadow,
    required this.cardShadow,
    required this.textStrong,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentStrong,
    required this.metricAccent,
    required this.statusSuccess,
    required this.statusWarning,
    required this.iconOnAccent,
    required this.metricBackground,
    required this.rowBackground,
    required this.rowHover,
    required this.actionIcon,
    required this.actionHover,
    required this.actionBorder,
  });

  final Gradient panelGradient;
  final Gradient brandGradient;
  final Gradient cardGradient;
  final Color border;
  final Color borderActive;
  final Color innerHighlight;
  final Color cardBorder;
  final Color shadow;
  final Color cardShadow;
  final Color textStrong;
  final Color textMuted;
  final Color textFaint;
  final Color accent;
  final Color accentStrong;
  final Color metricAccent;
  final Color statusSuccess;
  final Color statusWarning;
  final Color iconOnAccent;
  final Color metricBackground;
  final Color rowBackground;
  final Color rowHover;
  final Color actionIcon;
  final Color actionHover;
  final Color actionBorder;

  static _CompactGlassSkin of(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = EvolyDesignTokens.of(context);
    final isDark = colorScheme.brightness == Brightness.dark;
    final textBase = colorScheme.onSurface;
    final panelHighlight = Color.alphaBlend(
      tokens.glassHighlight.withValues(alpha: isDark ? 0.08 : 0.12),
      tokens.glassSurfaceRaised,
    );

    return _CompactGlassSkin(
      panelGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          panelHighlight,
          tokens.glassSurface,
          tokens.glassSurfaceSubtle,
        ],
      ),
      brandGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tokens.hudAccent,
          tokens.metricAccent,
        ],
      ),
      cardGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          tokens.glassSurfaceRaised,
          tokens.glassSurfaceSubtle,
        ],
      ),
      border: tokens.glassBorder,
      borderActive: tokens.glassBorderStrong,
      innerHighlight: tokens.glassHighlight,
      cardBorder: tokens.glassBorder,
      shadow: tokens.glassShadow,
      cardShadow: tokens.glassShadow.withValues(alpha: isDark ? 0.12 : 0.05),
      textStrong: textBase.withValues(alpha: 0.96),
      textMuted: textBase.withValues(alpha: 0.72),
      textFaint: textBase.withValues(alpha: 0.50),
      accent: tokens.hudAccent,
      accentStrong: tokens.hudAccentStrong,
      metricAccent: tokens.metricAccent,
      statusSuccess: tokens.statusSuccess,
      statusWarning: tokens.statusWarning,
      iconOnAccent: Colors.white,
      metricBackground: tokens.glassSurfaceSubtle,
      rowBackground: tokens.glassSurfaceSubtle,
      rowHover: Color.alphaBlend(
        tokens.hudAccent.withValues(alpha: isDark ? 0.12 : 0.08),
        tokens.glassSurfaceRaised,
      ),
      actionIcon: textBase.withValues(alpha: 0.88),
      actionHover: tokens.hudAccent.withValues(alpha: isDark ? 0.14 : 0.10),
      actionBorder: tokens.glassBorder,
    );
  }
}
