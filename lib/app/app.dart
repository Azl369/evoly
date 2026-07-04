import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:evoly/app/app_dependencies.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_controller.dart';
import 'package:evoly/features/desktop_window/domain/desktop_window_mode.dart';
import 'package:evoly/features/desktop_window/presentation/compact_reminder_panel.dart';
import 'package:evoly/features/settings/application/settings_controller.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

class EvolyApp extends StatelessWidget {
  const EvolyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppDependencies(
      child: Consumer<SettingsController>(
        builder: (context, settingsController, _) {
          final settings = settingsController.settings;

          return MaterialApp(
            title: 'Evoly',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(settings.themePreset),
            darkTheme: AppTheme.dark(settings.themePreset),
            themeMode: settings.themeMode,
            themeAnimationDuration: MotionTokens.instant,
            themeAnimationCurve: MotionTokens.gentle,
            initialRoute: AppRoutes.today,
            onGenerateRoute: AppRouter.onGenerateRoute,
            builder: (context, child) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              final tokens = EvolyDesignTokens.of(context);
              final desktopWindow = context.watch<DesktopWindowController>();
              final navigatorChild = child ?? const SizedBox.shrink();
              final body = _DesktopWindowModeLayer(
                desktopWindow: desktopWindow,
                child: navigatorChild,
              );

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  statusBarBrightness:
                      isDark ? Brightness.dark : Brightness.light,
                  systemNavigationBarColor: tokens.pageBackground,
                  systemNavigationBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarDividerColor: Colors.transparent,
                ),
                child: body,
              );
            },
          );
        },
      ),
    );
  }
}

class _DesktopWindowModeLayer extends StatelessWidget {
  const _DesktopWindowModeLayer({
    required this.desktopWindow,
    required this.child,
  });

  final DesktopWindowController desktopWindow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compactMode = desktopWindow.mode == DesktopWindowMode.compact;
    final fullStageChild =
        desktopWindow.isWindows ? _WindowsFullGlassStage(child: child) : child;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _DesktopWindowModeStage(
            visible: !compactMode,
            child: fullStageChild,
          ),
        ),
        Positioned.fill(
          child: _DesktopWindowModeStage(
            visible: compactMode,
            child: CompactReminderPanel(
              expanded: desktopWindow.compactExpanded,
              onToggleExpanded: desktopWindow.toggleCompactExpanded,
              onOpenFullMode: (taskId) {
                desktopWindow.enterFullMode(taskId: taskId);
              },
              onHideWindow: desktopWindow.hideWindow,
              onStartDrag: desktopWindow.startCompactDrag,
              onEndDrag: desktopWindow.rememberCompactPosition,
            ),
          ),
        ),
      ],
    );
  }
}

class _WindowsFullGlassStage extends StatelessWidget {
  const _WindowsFullGlassStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EvolyDesignTokens.of(context);
    final stageTheme = theme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
    );

    return Theme(
      data: stageTheme,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.backgroundGradient),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: tokens.glassBlurSigma + 2,
            sigmaY: tokens.glassBlurSigma + 2,
          ),
          child: Column(
            children: [
              const _WindowsFullGlassTitleBar(),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowsFullGlassTitleBar extends StatefulWidget {
  const _WindowsFullGlassTitleBar();

  @override
  State<_WindowsFullGlassTitleBar> createState() =>
      _WindowsFullGlassTitleBarState();
}

class _WindowsFullGlassTitleBarState extends State<_WindowsFullGlassTitleBar>
    with WindowListener {
  var _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _maximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _maximized = false);
    }
  }

  Future<void> _loadMaximized() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted) {
        setState(() => _maximized = maximized);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = EvolyDesignTokens.of(context);
    final foreground = colorScheme.onSurface.withValues(alpha: 0.88);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              tokens.glassHighlight.withValues(alpha: 0.06),
              tokens.glassSurface,
            ),
            tokens.glassSurfaceSubtle,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: tokens.glassBorder),
        ),
      ),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tokens.hudAccent.withValues(alpha: 0.94),
                              colorScheme.tertiary.withValues(alpha: 0.88),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SizedBox.square(
                          dimension: 22,
                          child: Icon(
                            Icons.auto_awesome_motion_rounded,
                            size: 14,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Evoly',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _GlassWindowButton(
              icon: Icons.minimize_rounded,
              label: '最小化',
              onPressed: () => windowManager.minimize(),
            ),
            _GlassWindowButton(
              icon: _maximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              label: _maximized ? '还原' : '最大化',
              onPressed: () async {
                if (_maximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _GlassWindowButton(
              icon: Icons.close_rounded,
              label: '关闭',
              danger: true,
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassWindowButton extends StatefulWidget {
  const _GlassWindowButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  State<_GlassWindowButton> createState() => _GlassWindowButtonState();
}

class _GlassWindowButtonState extends State<_GlassWindowButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = EvolyDesignTokens.of(context);
    final hoveredColor = widget.danger
        ? colorScheme.error.withValues(alpha: 0.86)
        : tokens.hudAccent.withValues(alpha: 0.10);
    final iconColor = widget.danger && _hovered
        ? colorScheme.onError
        : colorScheme.onSurface.withValues(alpha: 0.78);

    return Semantics(
      button: true,
      label: widget.label,
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
            width: 44,
            height: 40,
            color: _hovered ? hoveredColor : Colors.transparent,
            child: Icon(widget.icon, size: 17, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _DesktopWindowModeStage extends StatelessWidget {
  const _DesktopWindowModeStage({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: TickerMode(
        enabled: visible,
        child: Offstage(
          offstage: !visible,
          child: child,
        ),
      ),
    );
  }
}
