import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_controller.dart';
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
  DesktopWindowController? _desktopWindowController;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final DesktopWindowController controller;
    try {
      controller = context.read<DesktopWindowController>();
    } on ProviderNotFoundException {
      return;
    }

    if (_desktopWindowController == controller) {
      return;
    }

    _desktopWindowController?.removeListener(_handleDesktopWindowChanged);
    _desktopWindowController = controller;
    controller.addListener(_handleDesktopWindowChanged);
    _handleDesktopWindowChanged();
  }

  @override
  void dispose() {
    _desktopWindowController?.removeListener(_handleDesktopWindowChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useNavigationRail = constraints.maxWidth >= 900;
        final extendNavigationRail = constraints.maxWidth >= 1180;
        final content = IndexedStack(
          index: _selectedIndex,
          children: [
            for (var index = 0; index < _pages.length; index += 1)
              TickerMode(
                enabled: index == _selectedIndex,
                child: RepaintBoundary(child: _pages[index]),
              ),
          ],
        );

        return Scaffold(
          body: useNavigationRail
              ? Row(
                  children: [
                    EvolyNavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectTab,
                      extended: extendNavigationRail,
                      trailing: _DesktopCompactModeButton(
                        extended: extendNavigationRail,
                      ),
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: useNavigationRail
              ? null
              : EvolyNavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectTab,
                ),
        );
      },
    );
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) {
      return;
    }

    setState(() => _selectedIndex = index);
  }

  void _handleDesktopWindowChanged() {
    if (!mounted) {
      return;
    }

    if (_desktopWindowController?.pendingTaskId == null ||
        _selectedIndex == 0) {
      return;
    }

    setState(() => _selectedIndex = 0);
  }
}

class _DesktopCompactModeButton extends StatelessWidget {
  const _DesktopCompactModeButton({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DesktopWindowController>();
    if (!controller.isWindows) {
      return const SizedBox.shrink();
    }

    if (!extended) {
      return Tooltip(
        message: '迷你模式',
        child: IconButton(
          icon: const Icon(Icons.space_dashboard_outlined),
          onPressed: () => controller.enterCompactMode(),
        ),
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.space_dashboard_outlined, size: 18),
      label: const Text('迷你模式'),
      onPressed: () => controller.enterCompactMode(),
    );
  }
}
