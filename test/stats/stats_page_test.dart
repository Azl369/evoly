import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/features/stats/data/stats_repository.dart';
import 'package:evoly/features/stats/presentation/stats_page.dart';
import 'package:evoly/shared/ui/components/app_components.dart';

void main() {
  testWidgets('stats page renders dashboard surfaces and expands task lists',
      (tester) async {
    final now = DateTime.now();
    final snapshot = StatsSnapshot(
      todayCompletedTasks: 1,
      weekCompletedTasks: 3,
      todayPostponedTasks: 1,
      weekPostponedTasks: 2,
      goalCompletionRate: 0.5,
      streakDays: 4,
      totalGoals: 6,
      completedGoals: 3,
      todayCompletedItems: [
        StatsTaskItem(
          id: 'today-done',
          title: '写完统计页',
          occurredAt: now,
          estimatedMinutes: 45,
        ),
      ],
      weekCompletedItems: [
        StatsTaskItem(
          id: 'week-done-1',
          title: '整理 dashboard',
          occurredAt: now.subtract(const Duration(days: 1)),
          estimatedMinutes: 30,
        ),
        StatsTaskItem(
          id: 'week-done-2',
          title: '检查图表',
          occurredAt: now,
          estimatedMinutes: 20,
        ),
      ],
      todayPostponedItems: [
        StatsTaskItem(
          id: 'today-postponed',
          title: '延后截图检查',
          occurredAt: now,
          estimatedMinutes: 15,
        ),
      ],
      weekPostponedItems: const [],
    );

    await tester.pumpWidget(
      Provider<StatsRepository>.value(
        value: _FakeStatsRepository(snapshot),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const StatsPage(showBottomNavigationBar: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('统计'), findsOneWidget);
    expect(find.text('今日概览'), findsOneWidget);
    expect(find.text('本周概览'), findsOneWidget);
    expect(find.byType(AppSurface), findsAtLeastNWidgets(2));

    await tester.tap(find.text('今日完成'));
    await tester.pumpAndSettle();

    expect(find.text('写完统计页'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('本周完成图表'), findsOneWidget);
    expect(find.text('目标完成率'), findsOneWidget);
  });
}

class _FakeStatsRepository implements StatsRepository {
  const _FakeStatsRepository(this.snapshot);

  final StatsSnapshot snapshot;

  @override
  Future<StatsSnapshot> loadWeeklySnapshot() async => snapshot;
}
