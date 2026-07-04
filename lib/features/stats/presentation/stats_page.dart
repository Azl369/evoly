import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/data_refresh_listener.dart';
import 'package:evoly/features/stats/data/stats_repository.dart';
import 'package:evoly/shared/ui/components/animated_progress_bar.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';
import 'package:evoly/shared/widgets/empty_state.dart';
import 'package:evoly/shared/widgets/evoly_navigation_bar.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({
    this.showBottomNavigationBar = true,
    super.key,
  });

  final bool showBottomNavigationBar;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with DataRefreshListener<StatsPage> {
  StatsSnapshot? _snapshot;
  var _loading = true;
  var _todayCompletedExpanded = false;
  var _todayPostponedExpanded = false;
  var _weekCompletedExpanded = false;
  var _weekPostponedExpanded = false;
  var _completionChartMode = _CompletionChartMode.line;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  @override
  Future<void> reloadDataForRefresh() => _loadStats();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadStats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: widget.showBottomNavigationBar
          ? const EvolyNavigationBar(selectedIndex: 3)
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(label: '正在整理统计');
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '统计加载失败',
        message: errorMessage,
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return const EmptyState(
        icon: Icons.bar_chart_outlined,
        title: '暂无统计数据',
        message: '完成任务后显示统计。',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          const AppSectionHeader(
            title: '今日概览',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ExpandableMetricCard(
            title: '今日完成',
            value: '${snapshot.todayCompletedTasks}',
            subtitle: '点击查看今日完成项目',
            icon: Icons.check_circle_outline,
            expanded: _todayCompletedExpanded,
            items: snapshot.todayCompletedItems,
            emptyMessage: '今天还没有完成项目。',
            listIcon: Icons.done_rounded,
            lineThrough: true,
            onTap: () {
              setState(() {
                _todayCompletedExpanded = !_todayCompletedExpanded;
              });
            },
          ),
          _ExpandableMetricCard(
            title: '今日延期',
            value: '${snapshot.todayPostponedTasks}',
            subtitle: '点击查看今日延期项目',
            icon: Icons.schedule_outlined,
            expanded: _todayPostponedExpanded,
            items: snapshot.todayPostponedItems,
            emptyMessage: '今天还没有延期项目。',
            listIcon: Icons.schedule_rounded,
            lineThrough: false,
            onTap: () {
              setState(() {
                _todayPostponedExpanded = !_todayPostponedExpanded;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const AppSectionHeader(
            title: '本周概览',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ExpandableMetricCard(
            title: '本周完成',
            value: '${snapshot.weekCompletedTasks}',
            subtitle: '点击查看本周完成项目',
            icon: Icons.task_alt_outlined,
            expanded: _weekCompletedExpanded,
            items: snapshot.weekCompletedItems,
            emptyMessage: '本周还没有完成项目。',
            listIcon: Icons.done_rounded,
            lineThrough: true,
            onTap: () {
              setState(() {
                _weekCompletedExpanded = !_weekCompletedExpanded;
              });
            },
          ),
          _ExpandableMetricCard(
            title: '本周延期',
            value: '${snapshot.weekPostponedTasks}',
            subtitle: '点击查看本周延期项目',
            icon: Icons.pending_actions_outlined,
            expanded: _weekPostponedExpanded,
            items: snapshot.weekPostponedItems,
            emptyMessage: '本周还没有延期项目。',
            listIcon: Icons.schedule_rounded,
            lineThrough: false,
            onTap: () {
              setState(() {
                _weekPostponedExpanded = !_weekPostponedExpanded;
              });
            },
          ),
          _MetricCard(
            title: '连续完成',
            value: '${snapshot.streakDays} 天',
            icon: Icons.local_fire_department_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          _CompletionChartCard(
            items: snapshot.weekCompletedItems,
            mode: _completionChartMode,
            onModeChanged: (mode) {
              setState(() {
                _completionChartMode = mode;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppSurfaceCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('目标完成率', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                AnimatedProgressBar(value: snapshot.goalCompletionRate),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${snapshot.completedGoals}/${snapshot.totalGoals} 个目标已完成',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<StatsRepository>();
      final snapshot = await repository.loadWeeklySnapshot();
      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppMetricCard(
      title: title,
      value: value,
      icon: icon,
    );
  }
}

class _ExpandableMetricCard extends StatelessWidget {
  const _ExpandableMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.expanded,
    required this.items,
    required this.emptyMessage,
    required this.listIcon,
    required this.lineThrough,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool expanded;
  final List<StatsTaskItem> items;
  final String emptyMessage;
  final IconData listIcon;
  final bool lineThrough;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        children: [
          ListTile(
            onTap: onTap,
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: AppSpacing.sm),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.expand_more_rounded),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _StatsTaskList(
              items: items,
              emptyMessage: emptyMessage,
              listIcon: listIcon,
              lineThrough: lineThrough,
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _StatsTaskList extends StatelessWidget {
  const _StatsTaskList({
    required this.items,
    required this.emptyMessage,
    required this.listIcon,
    required this.lineThrough,
  });

  final List<StatsTaskItem> items;
  final String emptyMessage;
  final IconData listIcon;
  final bool lineThrough;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Text(
          emptyMessage,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              dense: true,
              leading: Icon(listIcon),
              title: Text(
                item.title,
                style: TextStyle(
                  decoration: lineThrough ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                '${_formatDateTime(item.occurredAt)} · ${item.estimatedMinutes} 分钟',
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletionChartCard extends StatelessWidget {
  const _CompletionChartCard({
    required this.items,
    required this.mode,
    required this.onModeChanged,
  });

  final List<StatsTaskItem> items;
  final _CompletionChartMode mode;
  final ValueChanged<_CompletionChartMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chartColors = EvolyDesignTokens.of(context).chartPalette;
    final points = _buildWeekPoints(items);
    final total = points.fold<int>(0, (sum, point) => sum + point.count);
    final piePalette = [
      for (final color in chartColors)
        _ChartSliceStyle(
          start: color.withValues(alpha: 0.86),
          end: color,
        ),
    ];

    return AppSurfaceCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '本周完成图表',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              SegmentedButton<_CompletionChartMode>(
                segments: const [
                  ButtonSegment(
                    value: _CompletionChartMode.pie,
                    icon: Icon(Icons.pie_chart_outline_rounded),
                    label: Text('饼图'),
                  ),
                  ButtonSegment(
                    value: _CompletionChartMode.line,
                    icon: Icon(Icons.show_chart_rounded),
                    label: Text('折线'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  onModeChanged(selection.first);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '按本周每天的完成任务数统计。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (total == 0)
            Text(
              '本周暂无完成项目。',
              style: theme.textTheme.bodyMedium,
            )
          else if (mode == _CompletionChartMode.pie)
            _CompletionPieChart(points: points, palette: piePalette)
          else
            _CompletionLineChart(points: points),
        ],
      ),
    );
  }

  List<_DailyCompletionPoint> _buildWeekPoints(List<StatsTaskItem> items) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart =
        todayStart.subtract(Duration(days: todayStart.weekday - 1));
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return List.generate(7, (index) {
      final day = weekStart.add(Duration(days: index));
      final nextDay = day.add(const Duration(days: 1));
      final count = items.where((item) {
        return !item.occurredAt.isBefore(day) &&
            item.occurredAt.isBefore(nextDay);
      }).length;

      return _DailyCompletionPoint(label: labels[index], count: count);
    });
  }
}

class _CompletionPieChart extends StatelessWidget {
  const _CompletionPieChart({
    required this.points,
    required this.palette,
  });

  final List<_DailyCompletionPoint> points;
  final List<_ChartSliceStyle> palette;

  @override
  Widget build(BuildContext context) {
    final activePoints = points.where((point) => point.count > 0).toList();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: CustomPaint(
            painter: _PieChartPainter(points: points, palette: palette),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final point in activePoints)
              _ChartLegendItem(
                style: palette[points.indexOf(point) % palette.length],
                label: '${point.label} ${point.count}',
              ),
          ],
        ),
      ],
    );
  }
}

class _CompletionLineChart extends StatelessWidget {
  const _CompletionLineChart({required this.points});

  final List<_DailyCompletionPoint> points;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: CustomPaint(
            painter: _LineChartPainter(
              points: points,
              color: Theme.of(context).colorScheme.primary,
              axisColor: Theme.of(context).colorScheme.outlineVariant,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final point in points)
              Expanded(
                child: Text(
                  point.label.replaceFirst('周', ''),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final point in points)
              Expanded(
                child: Text(
                  '${point.count}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({
    required this.style,
    required this.label,
  });

  final _ChartSliceStyle style;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [style.start, style.end],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter({
    required this.points,
    required this.palette,
  });

  final List<_DailyCompletionPoint> points;
  final List<_ChartSliceStyle> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final total = points.fold<int>(0, (sum, point) => sum + point.count);
    if (total == 0) {
      return;
    }

    final radius = math.min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    var startAngle = -math.pi / 2;

    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      if (point.count == 0) {
        continue;
      }

      final sweepAngle = point.count / total * math.pi * 2;
      final style = palette[index % palette.length];
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          colors: [style.start, style.end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);
      canvas.drawArc(rect.deflate(1), startAngle, sweepAngle, true, paint);

      final dividerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.72);
      canvas.drawArc(
          rect.deflate(1), startAngle, sweepAngle, true, dividerPaint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.palette != palette;
  }
}

class _ChartSliceStyle {
  const _ChartSliceStyle({
    required this.start,
    required this.end,
  });

  final Color start;
  final Color end;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.points,
    required this.color,
    required this.axisColor,
  });

  final List<_DailyCompletionPoint> points;
  final Color color;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    const padding = EdgeInsets.fromLTRB(8, 12, 8, 20);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;
    final maxCount =
        math.max(1, points.map((point) => point.count).reduce(math.max));
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bottomLeft = Offset(padding.left, padding.top + chartHeight);
    final bottomRight =
        Offset(padding.left + chartWidth, padding.top + chartHeight);
    canvas.drawLine(bottomLeft, bottomRight, axisPaint);

    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index += 1) {
      final x = padding.left + chartWidth * index / (points.length - 1);
      final y = padding.top +
          chartHeight -
          chartHeight * points[index].count / maxCount;
      offsets.add(Offset(x, y));
    }

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final offset in offsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }

    canvas.drawPath(path, linePaint);
    for (final offset in offsets) {
      canvas.drawCircle(offset, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.axisColor != axisColor;
  }
}

class _DailyCompletionPoint {
  const _DailyCompletionPoint({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

enum _CompletionChartMode {
  pie,
  line,
}

String _formatDateTime(DateTime dateTime) {
  return '${dateTime.month.toString().padLeft(2, '0')}-'
      '${dateTime.day.toString().padLeft(2, '0')} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}
