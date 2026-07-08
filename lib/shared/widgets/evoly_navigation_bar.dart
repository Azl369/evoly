import 'package:flutter/material.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

const _destinations = [
  _EvolyNavigationDestination(
    icon: Icons.today_outlined,
    selectedIcon: Icons.today_rounded,
    label: '计划',
  ),
  _EvolyNavigationDestination(
    icon: Icons.flag_outlined,
    selectedIcon: Icons.flag_rounded,
    label: '项目',
  ),
  _EvolyNavigationDestination(
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books_rounded,
    label: '文档库',
  ),
  _EvolyNavigationDestination(
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart_rounded,
    label: '统计',
  ),
  _EvolyNavigationDestination(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    label: '设置',
  ),
];

class _EvolyNavigationDestination {
  const _EvolyNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

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
      onDestinationSelected: (index) => _selectDestination(context, index),
      destinations: [
        for (final destination in _destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }

  void _selectDestination(BuildContext context, int index) {
    if (index == selectedIndex) {
      return;
    }

    final destinationSelected = onDestinationSelected;
    if (destinationSelected != null) {
      destinationSelected(index);
      return;
    }

    Navigator.pushReplacementNamed(context, _routeForIndex(index));
  }
}

class EvolyNavigationRail extends StatelessWidget {
  const EvolyNavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.extended = false,
    this.trailing,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = EvolyDesignTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              tokens.glassHighlight.withValues(alpha: 0.06),
              tokens.glassSurface,
            ),
            tokens.glassSurfaceSubtle,
          ],
        ),
        border: Border(
          right: BorderSide(color: tokens.glassBorder),
        ),
      ),
      child: SafeArea(
        child: NavigationRail(
          selectedIndex: selectedIndex,
          extended: extended,
          minWidth: 76,
          minExtendedWidth: 184,
          groupAlignment: -0.86,
          backgroundColor: Colors.transparent,
          indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.50),
          selectedIconTheme: IconThemeData(color: tokens.hudAccentStrong),
          unselectedIconTheme: IconThemeData(
            color: colorScheme.onSurfaceVariant,
          ),
          selectedLabelTextStyle:
              Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: tokens.hudAccentStrong,
                    fontWeight: FontWeight.w700,
                  ),
          unselectedLabelTextStyle: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: colorScheme.onSurfaceVariant),
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.lg,
            ),
            child: _RailBrand(extended: extended),
          ),
          trailing: trailing == null
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  child: trailing,
                ),
          destinations: [
            for (final destination in _destinations)
              NavigationRailDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: Text(destination.label),
              ),
          ],
          onDestinationSelected: (index) {
            if (index == selectedIndex) {
              return;
            }
            onDestinationSelected(index);
          },
        ),
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = EvolyDesignTokens.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.hudAccent,
                colorScheme.tertiary,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.glassBorder),
          ),
          child: const SizedBox.square(
            dimension: 40,
            child: Icon(
              Icons.auto_awesome_motion_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        if (extended) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Evoly',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

String _routeForIndex(int index) {
  return switch (index) {
    0 => AppRoutes.today,
    1 => AppRoutes.goals,
    2 => AppRoutes.documents,
    3 => AppRoutes.stats,
    _ => AppRoutes.settings,
  };
}
