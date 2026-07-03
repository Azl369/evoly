import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/theme_preset.dart';
import 'package:evoly/dev/coverage_test_data_seeder.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/settings/application/settings_controller.dart';
import 'package:evoly/features/settings/data/settings_repository.dart';
import 'package:evoly/features/sync/presentation/sync_account_section.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const SwitchListTile(
            value: true,
            onChanged: null,
            title: Text('每日计划提醒'),
            subtitle: Text('每天早上提醒今天要推进的目标'),
          ),
          const ListTile(
            leading: Icon(Icons.notifications_outlined),
            title: Text('默认提醒时间'),
            subtitle: Text('08:30'),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题'),
            subtitle: Text(
              '${settings.themeMode.label} · ${settings.themePreset.label}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showThemeSheet(context),
          ),
          const SyncAccountSection(),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('生成覆盖测试数据'),
              subtitle: const Text('目标、任务、文档、提醒，各状态与长文本覆盖'),
              onTap: () => _seedCoverageTestData(context),
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
    final foregroundColor =
        selected ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final optionColor = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.62)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.42);
    final borderColor = selected
        ? colorScheme.primary.withValues(alpha: 0.28)
        : colorScheme.outlineVariant.withValues(alpha: 0.58);

    return Semantics(
      button: true,
      selected: selected,
      label: preset.label,
      child: AnimatedContainer(
        duration: MotionTokens.instant,
        curve: MotionTokens.standard,
        decoration: BoxDecoration(
          color: optionColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: selected ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  _ThemeSwatches(preset: preset),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      preset.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foregroundColor,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: selected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                          )
                        : const SizedBox.shrink(),
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

class _ThemeSwatches extends StatelessWidget {
  const _ThemeSwatches({required this.preset});

  final EvolyThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final outlineColor = Theme.of(context).colorScheme.outlineVariant;

    return SizedBox(
      width: 54,
      height: 32,
      child: Stack(
        children: [
          for (final entry in preset.previewSwatches.indexed)
            Positioned(
              left: entry.$1 * 14,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: entry.$2,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: outlineColor.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
