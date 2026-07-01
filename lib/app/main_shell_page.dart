import 'package:flutter/material.dart';
import 'package:evoly/features/documents/presentation/document_library_page.dart';
import 'package:evoly/features/goals/presentation/goal_list_page.dart';
import 'package:evoly/features/settings/presentation/settings_page.dart';
import 'package:evoly/features/stats/presentation/stats_page.dart';
import 'package:evoly/features/today/presentation/today_page.dart';
import 'package:evoly/shared/widgets/evoly_navigation_bar.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    required this.initialIndex,
    super.key,
  });

  final int initialIndex;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  late int _selectedIndex;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 4).toInt();
    _pages = [
      TodayPage(
        key: const PageStorageKey('today-tab'),
        showBottomNavigationBar: false,
        onTopLevelDestinationSelected: _selectTab,
      ),
      const GoalListPage(
        key: PageStorageKey('goals-tab'),
        showBottomNavigationBar: false,
      ),
      const DocumentLibraryPage(
        key: PageStorageKey('documents-tab'),
        showBottomNavigationBar: false,
      ),
      const StatsPage(
        key: PageStorageKey('stats-tab'),
        showBottomNavigationBar: false,
      ),
      const SettingsPage(
        key: PageStorageKey('settings-tab'),
        showBottomNavigationBar: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var index = 0; index < _pages.length; index += 1)
            TickerMode(
              enabled: index == _selectedIndex,
              child: RepaintBoundary(child: _pages[index]),
            ),
        ],
      ),
      bottomNavigationBar: EvolyNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
      ),
    );
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) {
      return;
    }

    setState(() => _selectedIndex = index);
  }
}
