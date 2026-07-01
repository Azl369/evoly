import 'package:flutter/material.dart';
import 'package:evoly/app/router.dart';

class EvolyNavigationBar extends StatelessWidget {
  const EvolyNavigationBar({
    required this.selectedIndex,
    this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == selectedIndex) {
          return;
        }

        final destinationSelected = onDestinationSelected;
        if (destinationSelected != null) {
          destinationSelected(index);
          return;
        }

        final route = switch (index) {
          0 => AppRoutes.today,
          1 => AppRoutes.goals,
          2 => AppRoutes.documents,
          3 => AppRoutes.stats,
          _ => AppRoutes.settings,
        };

        Navigator.pushReplacementNamed(context, route);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.today_outlined), label: '今日'),
        NavigationDestination(icon: Icon(Icons.flag_outlined), label: '目标'),
        NavigationDestination(
          icon: Icon(Icons.library_books_outlined),
          label: '文档库',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          label: '统计',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: '设置',
        ),
      ],
    );
  }
}
