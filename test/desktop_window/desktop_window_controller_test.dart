import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_controller.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_host.dart';
import 'package:evoly/features/desktop_window/domain/desktop_window_mode.dart';
import 'package:evoly/features/settings/data/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopWindowController', () {
    test('enters compact mode and toggles expanded size', () async {
      final host = _FakeDesktopWindowHost();
      final controller = DesktopWindowController(host: host);
      await controller.initialize();

      await controller.enterCompactMode();

      expect(controller.mode, DesktopWindowMode.compact);
      expect(controller.compactExpanded, isFalse);
      expect(host.bounds.size, DesktopWindowController.compactSize);
      expect(host.bounds.topLeft, const Offset(1544, 16));
      expect(
        host.backgroundColor,
        DesktopWindowController.compactWindowBackground,
      );
      expect(host.windowEffect, DesktopWindowEffect.transparent);
      expect(
        host.windowEffectColor,
        DesktopWindowController.compactWindowBackground,
      );
      expect(host.framelessApplied, isTrue);

      await controller.toggleCompactExpanded();

      expect(controller.mode, DesktopWindowMode.compact);
      expect(controller.compactExpanded, isTrue);
      expect(host.bounds.size, DesktopWindowController.compactExpandedSize);
    });

    test('collapses content before shrinking the native compact window',
        () async {
      final host = _FakeDesktopWindowHost();
      final controller = DesktopWindowController(host: host);
      await controller.initialize();
      await controller.enterCompactMode(expanded: true);

      final pauseCompactBounds = Completer<void>();
      host.pauseNextCompactSetBounds = pauseCompactBounds;

      final collapseFuture = controller.toggleCompactExpanded();
      await Future<void>.delayed(Duration.zero);

      expect(controller.compactExpanded, isFalse);
      expect(host.bounds.size, DesktopWindowController.compactExpandedSize);

      pauseCompactBounds.complete();
      await collapseFuture;

      expect(host.bounds.size, DesktopWindowController.compactSize);
    });

    test('opens full mode with a pending task that is consumed once', () async {
      final host = _FakeDesktopWindowHost();
      final controller = DesktopWindowController(host: host);
      await controller.initialize();
      await controller.enterCompactMode();

      await controller.enterFullMode(taskId: 'task-1');

      expect(controller.mode, DesktopWindowMode.full);
      expect(
          host.backgroundColor, DesktopWindowController.fullWindowBackground);
      expect(host.windowEffect, DesktopWindowEffect.acrylic);
      expect(
        host.windowEffectColor,
        DesktopWindowController.fullWindowEffectTint,
      );
      expect(host.alwaysOnTop, isTrue);
      expect(host.titleBarStyle, DesktopWindowTitleBarStyle.hidden);
      expect(controller.pendingTaskId, 'task-1');
      expect(controller.consumePendingTaskId(), 'task-1');
      expect(controller.consumePendingTaskId(), isNull);
    });

    test('ignores stale compact operation after full mode wins', () async {
      final host = _FakeDesktopWindowHost();
      final controller = DesktopWindowController(host: host);
      await controller.initialize();

      final pauseCompactBounds = Completer<void>();
      host.pauseNextCompactSetBounds = pauseCompactBounds;

      final compactFuture = controller.enterCompactMode();
      await Future<void>.delayed(Duration.zero);

      await controller.enterFullMode();
      expect(controller.mode, DesktopWindowMode.full);

      pauseCompactBounds.complete();
      await compactFuture;

      expect(controller.mode, DesktopWindowMode.full);
      expect(controller.compactExpanded, isFalse);
    });

    test('honors close and tray click behavior settings', () async {
      final host = _FakeDesktopWindowHost();
      final controller = DesktopWindowController(host: host);
      await controller.initialize();

      controller.updateSettings(
        AppSettings.defaultSettings.copyWith(
          windowsCloseBehavior: WindowsCloseBehavior.showCompact,
          windowsTrayClickBehavior: WindowsTrayClickBehavior.openFull,
        ),
      );

      host.emitWindowClose();
      await Future<void>.delayed(Duration.zero);
      expect(controller.mode, DesktopWindowMode.compact);

      host.emitTrayIconMouseDown();
      await Future<void>.delayed(Duration.zero);
      expect(controller.mode, DesktopWindowMode.full);
    });

    test('handles tray pause and resume reminder actions', () async {
      final host = _FakeDesktopWindowHost();
      Duration? pausedDuration;
      var resumed = false;
      final controller = DesktopWindowController(host: host);
      await controller.initialize();
      controller.updateSettings(
        AppSettings.defaultSettings,
        pauseReminders: (duration) async => pausedDuration = duration,
        resumeReminders: () async => resumed = true,
      );

      host.emitTrayMenuAction(DesktopTrayMenuAction.pauseRemindersHour);
      await Future<void>.delayed(Duration.zero);
      expect(pausedDuration, const Duration(hours: 1));

      host.emitTrayMenuAction(DesktopTrayMenuAction.resumeReminders);
      await Future<void>.delayed(Duration.zero);
      expect(resumed, isTrue);

      controller.updateSettings(
        AppSettings.defaultSettings.copyWith(
          windowsReminderPauseUntil: DateTime.now().add(
            const Duration(hours: 1),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(host.remindersPausedInTray, isTrue);
    });

    test('uses and persists compact position', () async {
      final host = _FakeDesktopWindowHost();
      Offset? savedPosition;
      final controller = DesktopWindowController(host: host);
      await controller.initialize();
      controller.updateSettings(
        AppSettings.defaultSettings.copyWith(
          windowsCompactPositionX: 120,
          windowsCompactPositionY: 80,
        ),
        saveCompactPosition: (position) async => savedPosition = position,
      );

      await controller.enterCompactMode();
      expect(host.bounds.topLeft, const Offset(120, 80));

      host.bounds =
          Rect.fromLTWH(220, 140, host.bounds.width, host.bounds.height);
      controller.rememberCompactPosition();
      await Future<void>.delayed(Duration.zero);

      expect(savedPosition, const Offset(220, 140));
    });

    test('snaps compact position to visible edges after dragging', () async {
      final host = _FakeDesktopWindowHost();
      Offset? savedPosition;
      final controller = DesktopWindowController(host: host);
      await controller.initialize();
      controller.updateSettings(
        AppSettings.defaultSettings,
        saveCompactPosition: (position) async => savedPosition = position,
      );

      await controller.enterCompactMode();

      host.bounds =
          Rect.fromLTWH(1530, 140, host.bounds.width, host.bounds.height);
      controller.rememberCompactPosition();
      await Future<void>.delayed(Duration.zero);

      expect(host.bounds.topLeft, const Offset(1544, 140));
      expect(savedPosition, const Offset(1544, 140));
    });

    test('clamps compact position into the visible work area', () async {
      final host = _FakeDesktopWindowHost();
      Offset? savedPosition;
      final controller = DesktopWindowController(host: host);
      await controller.initialize();
      controller.updateSettings(
        AppSettings.defaultSettings,
        saveCompactPosition: (position) async => savedPosition = position,
      );

      await controller.enterCompactMode();

      host.bounds =
          Rect.fromLTWH(1900, -40, host.bounds.width, host.bounds.height);
      controller.rememberCompactPosition();
      await Future<void>.delayed(Duration.zero);

      expect(host.bounds.topLeft, const Offset(1544, 16));
      expect(savedPosition, const Offset(1544, 16));
    });
  });
}

class _FakeDesktopWindowHost implements DesktopWindowHost {
  VoidCallback _onWindowClose = () {};
  VoidCallback _onTrayIconMouseDown = () {};
  ValueChanged<DesktopTrayMenuAction> _onTrayMenuAction = (_) {};

  @override
  bool isWindows = true;

  Rect bounds = const Rect.fromLTWH(0, 0, 1180, 760);
  Completer<void>? pauseNextCompactSetBounds;
  bool trayInitialized = false;
  bool remindersPausedInTray = false;
  bool destroyed = false;
  bool framelessApplied = false;
  DesktopWindowTitleBarStyle? titleBarStyle;
  Color? backgroundColor;
  DesktopWindowEffect? windowEffect;
  Color? windowEffectColor;
  bool? windowEffectDark;
  bool? alwaysOnTop;

  void emitWindowClose() => _onWindowClose();

  void emitTrayIconMouseDown() => _onTrayIconMouseDown();

  void emitTrayMenuAction(DesktopTrayMenuAction action) {
    _onTrayMenuAction(action);
  }

  @override
  Future<void> initialize({
    required VoidCallback onWindowClose,
    required VoidCallback onTrayIconMouseDown,
    required VoidCallback onTrayIconRightMouseDown,
    required ValueChanged<DesktopTrayMenuAction> onTrayMenuAction,
  }) async {
    _onWindowClose = onWindowClose;
    _onTrayIconMouseDown = onTrayIconMouseDown;
    _onTrayMenuAction = onTrayMenuAction;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> setPreventClose(bool value) async {}

  @override
  Future<void> setTitleBarStyle(
    DesktopWindowTitleBarStyle style, {
    required bool windowButtonVisibility,
  }) async {
    titleBarStyle = style;
    framelessApplied = false;
  }

  @override
  Future<void> setAsFrameless() async {
    framelessApplied = true;
    titleBarStyle = null;
  }

  @override
  Future<void> setBackgroundColor(Color color) async {
    backgroundColor = color;
  }

  @override
  Future<void> setWindowEffect(
    DesktopWindowEffect effect, {
    Color color = const Color(0x00000000),
    bool dark = false,
  }) async {
    windowEffect = effect;
    windowEffectColor = color;
    windowEffectDark = dark;
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    alwaysOnTop = value;
  }

  @override
  Future<void> setResizable(bool value) async {}

  @override
  Future<void> setMinimizable(bool value) async {}

  @override
  Future<void> setMaximizable(bool value) async {}

  @override
  Future<void> setSkipTaskbar(bool value) async {}

  @override
  Future<void> setMinimumSize(Size size) async {}

  @override
  Future<void> setMaximumSize(Size size) async {}

  @override
  Future<void> setSize(Size size) async {
    bounds = Rect.fromLTWH(bounds.left, bounds.top, size.width, size.height);
  }

  @override
  Future<void> setBounds(Rect? bounds, {Offset? position, Size? size}) async {
    if (size == DesktopWindowController.compactSize ||
        size == DesktopWindowController.compactExpandedSize) {
      final pause = pauseNextCompactSetBounds;
      if (pause != null) {
        pauseNextCompactSetBounds = null;
        await pause.future;
      }
    }

    if (bounds != null) {
      this.bounds = bounds;
      return;
    }

    final nextPosition = position ?? this.bounds.topLeft;
    final nextSize = size ?? this.bounds.size;
    this.bounds = Rect.fromLTWH(
      nextPosition.dx,
      nextPosition.dy,
      nextSize.width,
      nextSize.height,
    );
  }

  @override
  Future<Rect> getBounds() async => bounds;

  @override
  Future<void> center() async {}

  @override
  Future<void> show({bool inactive = false}) async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> destroy() async {
    destroyed = true;
  }

  @override
  Future<void> focus() async {}

  @override
  Future<void> unmaximize() async {}

  @override
  Future<void> startDragging() async {}

  @override
  Future<DesktopDisplayInfo> getPrimaryDisplay() async {
    return const DesktopDisplayInfo(
      visiblePosition: Offset.zero,
      visibleSize: Size(1920, 1080),
    );
  }

  @override
  Future<void> initializeTray({
    required String iconPath,
    required String tooltip,
    required bool remindersPaused,
  }) async {
    trayInitialized = true;
    remindersPausedInTray = remindersPaused;
  }

  @override
  Future<void> updateTrayMenu({required bool remindersPaused}) async {
    remindersPausedInTray = remindersPaused;
  }

  @override
  Future<void> destroyTray() async {
    trayInitialized = false;
  }

  @override
  Future<void> popUpTrayContextMenu() async {}
}
