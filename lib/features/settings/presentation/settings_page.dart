import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/theme_preset.dart';
import 'package:evoly/dev/coverage_test_data_seeder.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_controller.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/settings/application/settings_controller.dart';
import 'package:evoly/features/settings/data/settings_repository.dart';
import 'package:evoly/features/sync/presentation/sync_account_section.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';
import 'package:evoly/shared/widgets/evoly_navigation_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    this.showBottomNavigationBar = true,
    super.key,
  });

  final bool showBottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;

    return AppPageScaffold(
      title: '设置',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          const _SettingsGroup(
            title: '提醒',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                value: true,
                onChanged: null,
                title: Text('每日计划提醒'),
                subtitle: Text('每天早上提醒今天要推进的目标'),
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                leading: Icon(Icons.notifications_outlined),
                title: Text('默认提醒时间'),
                subtitle: Text('08:30'),
              ),
            ],
          ),
          _SettingsGroup(
            title: '外观',
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题'),
                subtitle: Text(
                  '${settings.themeMode.label} · ${settings.themePreset.label}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showThemeSheet(context),
              ),
            ],
          ),
          if (Platform.isWindows)
            _SettingsGroup(
              title: '桌面模式',
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  leading: const Icon(Icons.desktop_windows_outlined),
                  title: const Text('Windows 桌面模式'),
                  subtitle: Text(
                    '${settings.windowsCloseBehavior.label} · '
                    '${settings.windowsTrayClickBehavior.label}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showWindowsDesktopSheet(context),
                ),
              ],
            ),
          const _SettingsGroup(
            title: '账号与同步',
            children: [
              SyncAccountSection(),
            ],
          ),
          if (kDebugMode)
            _SettingsGroup(
              title: '开发工具',
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('生成覆盖测试数据'),
                  subtitle: const Text('目标、任务、文档、提醒，各状态与长文本覆盖'),
                  onTap: () => _seedCoverageTestData(context),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: showBottomNavigationBar
          ? const EvolyNavigationBar(selectedIndex: 4)
          : null,
    );
  }

  Future<void> _showThemeSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _ThemeSettingsSheet(),
    );
  }

  Future<void> _showWindowsDesktopSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _WindowsDesktopSettingsSheet(),
    );
  }

  Future<void> _seedCoverageTestData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('正在生成覆盖测试数据...')),
    );

    try {
      final result = await CoverageTestDataSeeder(
        goalRepository: context.read<GoalRepository>(),
        taskRepository: context.read<TaskRepository>(),
        documentRepository: context.read<DocumentRepository>(),
        reminderRepository: context.read<ReminderRepository>(),
      ).seed();

      if (!context.mounted) {
        return;
      }

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '已生成：${result.goals} 个目标、${result.tasks} 个任务、'
            '${result.documents} 篇文档、${result.reminders} 条提醒',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('生成覆盖测试数据失败：$error')),
      );
    }
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);

    return AppSection(
      title: title,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: AppSurface(
        variant: AppSurfaceVariant.raised,
        padding: EdgeInsets.zero,
        child: ListTileTheme.merge(
          iconColor: tokens.textSecondary,
          textColor: tokens.textPrimary,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const _SettingsDivider(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Divider(
        height: 1,
        thickness: 1,
        color: tokens.borderSubtle,
      ),
    );
  }
}

class _WindowsDesktopSettingsSheet extends StatelessWidget {
  const _WindowsDesktopSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return ResponsiveBottomSheetBody(
      minHeight: 520,
      child: Consumer<SettingsController>(
        builder: (context, controller, _) {
          final settings = controller.settings;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Windows 桌面模式',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '关闭窗口时',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<WindowsCloseBehavior>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: WindowsCloseBehavior.hideToTray,
                    icon: Icon(Icons.system_update_alt_outlined),
                    label: Text('托盘'),
                  ),
                  ButtonSegment(
                    value: WindowsCloseBehavior.showCompact,
                    icon: Icon(Icons.space_dashboard_outlined),
                    label: Text('迷你'),
                  ),
                  ButtonSegment(
                    value: WindowsCloseBehavior.exitApp,
                    icon: Icon(Icons.power_settings_new_outlined),
                    label: Text('退出'),
                  ),
                ],
                selected: {settings.windowsCloseBehavior},
                onSelectionChanged: (selection) {
                  controller.updateWindowsCloseBehavior(selection.first);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '托盘左键',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<WindowsTrayClickBehavior>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: WindowsTrayClickBehavior.showCompact,
                    icon: Icon(Icons.space_dashboard_outlined),
                    label: Text('迷你'),
                  ),
                  ButtonSegment(
                    value: WindowsTrayClickBehavior.openFull,
                    icon: Icon(Icons.open_in_full_rounded),
                    label: Text('完整'),
                  ),
                ],
                selected: {settings.windowsTrayClickBehavior},
                onSelectionChanged: (selection) {
                  controller.updateWindowsTrayClickBehavior(selection.first);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.windowsCompactAlwaysOnTop,
                onChanged: controller.updateWindowsCompactAlwaysOnTop,
                title: const Text('迷你面板置顶'),
                subtitle: const Text('关闭后仍可手动从托盘打开。'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_paused_outlined),
                title: const Text('提醒暂停'),
                subtitle: Text(_reminderPauseLabel(settings)),
                trailing: TextButton(
                  onPressed: settings.windowsRemindersPaused(DateTime.now())
                      ? controller.resumeWindowsReminders
                      : () => controller.pauseWindowsRemindersFor(
                            const Duration(hours: 1),
                          ),
                  child: Text(
                    settings.windowsRemindersPaused(DateTime.now())
                        ? '恢复'
                        : '暂停 1 小时',
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location_outlined),
                title: const Text('重置迷你面板位置'),
                subtitle: const Text('下次显示回到主屏右上角。'),
                onTap: () => _resetCompactPosition(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resetCompactPosition(BuildContext context) async {
    final settingsController = context.read<SettingsController>();
    final messenger = ScaffoldMessenger.of(context);
    DesktopWindowController? desktopWindowController;
    try {
      desktopWindowController = context.read<DesktopWindowController>();
    } on ProviderNotFoundException {
      desktopWindowController = null;
    }

    await settingsController.updateWindowsCompactPosition(null);
    await desktopWindowController?.resetCompactPosition();

    if (!context.mounted) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('迷你面板位置已重置')),
    );
  }

  String _reminderPauseLabel(AppSettings settings) {
    final pauseUntil = settings.windowsReminderPauseUntil;
    if (pauseUntil == null || !pauseUntil.isAfter(DateTime.now())) {
      return '当前未暂停';
    }

    return '暂停至 ${pauseUntil.hour.toString().padLeft(2, '0')}:'
        '${pauseUntil.minute.toString().padLeft(2, '0')}';
  }
}

class _ThemeSettingsSheet extends StatelessWidget {
  const _ThemeSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return ResponsiveBottomSheetBody(
      minHeight: 360,
      child: Consumer<SettingsController>(
        builder: (context, controller, _) {
          final settings = controller.settings;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('主题', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Text(
                '主题模式',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('跟随'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('浅色'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('深色'),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) {
                  controller.updateThemeMode(selection.first);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '主题风格',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final preset in EvolyThemePreset.values) ...[
                _ThemePresetOption(
                  preset: preset,
                  selected: settings.themePreset == preset,
                  onTap: () => controller.updateThemePreset(preset),
                ),
                if (preset != EvolyThemePreset.values.last)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ThemePresetOption extends StatelessWidget {
  const _ThemePresetOption({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final EvolyThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = EvolyDesignTokens.of(context);
    final foregroundColor = selected
        ? tokens.hudAccentStrong
        : colorScheme.onSurface.withValues(alpha: 0.92);

    return Semantics(
      button: true,
      selected: selected,
      label: preset.label,
      child: AppGlassSurface(
        onTap: selected ? null : onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        radius: 14,
        selected: selected,
        elevated: selected,
        backgroundColor:
            selected ? tokens.glassSurfaceRaised : tokens.glassSurfaceSubtle,
        borderColor: selected ? tokens.glassBorderStrong : tokens.glassBorder,
        child: Row(
          children: [
            _ThemeHudPreview(preset: preset),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                preset.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: selected
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: tokens.hudAccentStrong,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeHudPreview extends StatelessWidget {
  const _ThemeHudPreview({required this.preset});

  final EvolyThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF101827) : const Color(0xFFF7FCFF);

    return SizedBox(
      width: 74,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                preset.seedColor.withValues(alpha: 0.26),
                base,
              ),
              Color.alphaBlend(
                preset.secondarySeedColor.withValues(alpha: 0.22),
                base,
              ),
              Color.alphaBlend(
                preset.tertiarySeedColor.withValues(alpha: 0.20),
                base,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: tokens.glassBorder),
          boxShadow: [
            BoxShadow(
              color: tokens.glassShadow.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: 8,
              right: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.34),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const SizedBox(height: 10),
              ),
            ),
            Positioned(
              left: 8,
              right: 26,
              bottom: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: preset.secondarySeedColor.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: const SizedBox(height: 5),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: preset.tertiarySeedColor,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
