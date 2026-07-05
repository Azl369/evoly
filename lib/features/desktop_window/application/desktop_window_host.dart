import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic_plugin;
import 'package:screen_retriever/screen_retriever.dart' as screen_plugin;
import 'package:tray_manager/tray_manager.dart' as tray_plugin;
import 'package:window_manager/window_manager.dart' as window_plugin;

enum DesktopWindowTitleBarStyle {
  normal,
  hidden,
}

enum DesktopWindowEffect {
  disabled,
  transparent,
  acrylic,
}

class DesktopWindowEffects {
  static Future<void>? _initialization;
  static var _ready = false;

  static bool get ready => _ready;

  static Future<void> ensureInitialized() {
    if (!Platform.isWindows) {
      return Future.value();
    }

    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    try {
      await acrylic_plugin.Window.initialize();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<void> setEffect(
    DesktopWindowEffect effect, {
    Color color = const Color(0x00000000),
    bool dark = false,
  }) {
    if (!Platform.isWindows || !_ready) {
      return Future.value();
    }

    return acrylic_plugin.Window.setEffect(
      effect: _toAcrylicEffect(effect),
      color: color,
      dark: dark,
    );
  }
}

enum DesktopTrayMenuAction {
  openFull,
  showCompact,
  pauseRemindersHour,
  resumeReminders,
  hideWindow,
  exitApp,
}

class DesktopDisplayInfo {
  const DesktopDisplayInfo({
    required this.visiblePosition,
    required this.visibleSize,
  });

  final Offset visiblePosition;
  final Size visibleSize;
}

abstract class DesktopWindowHost {
  bool get isWindows;

  Future<void> initialize({
    required VoidCallback onWindowClose,
    required VoidCallback onTrayIconMouseDown,
    required VoidCallback onTrayIconRightMouseDown,
    required ValueChanged<DesktopTrayMenuAction> onTrayMenuAction,
  });

  Future<void> dispose();

  Future<void> setPreventClose(bool value);

  Future<void> setTitleBarStyle(
    DesktopWindowTitleBarStyle style, {
    required bool windowButtonVisibility,
  });

  Future<void> setAsFrameless();

  Future<void> setBackgroundColor(Color color);

  Future<void> setWindowEffect(
    DesktopWindowEffect effect, {
    Color color = const Color(0x00000000),
    bool dark = false,
  });

  Future<void> setHasShadow(bool value);

  Future<void> setOpacity(double opacity);

  Future<void> setAlwaysOnTop(bool value);

  Future<void> setResizable(bool value);

  Future<void> setMinimizable(bool value);

  Future<void> setMaximizable(bool value);

  Future<void> setSkipTaskbar(bool value);

  Future<void> setMinimumSize(Size size);

  Future<void> setMaximumSize(Size size);

  Future<void> setSize(Size size);

  Future<void> setBounds(Rect? bounds, {Offset? position, Size? size});

  Future<Rect> getBounds();

  Future<void> center();

  Future<void> show({bool inactive = false});

  Future<void> hide();

  Future<void> destroy();

  Future<void> focus();

  Future<void> unmaximize();

  Future<void> startDragging();

  Future<DesktopDisplayInfo> getPrimaryDisplay();

  Future<void> initializeTray({
    required String iconPath,
    required String tooltip,
    required bool remindersPaused,
  });

  Future<void> updateTrayMenu({required bool remindersPaused});

  Future<void> destroyTray();

  Future<void> popUpTrayContextMenu();
}

class PluginDesktopWindowHost extends DesktopWindowHost
    with window_plugin.WindowListener, tray_plugin.TrayListener {
  static const String _trayOpenFullKey = 'open_full';
  static const String _trayShowCompactKey = 'show_compact';
  static const String _trayPauseRemindersHourKey = 'pause_reminders_hour';
  static const String _trayResumeRemindersKey = 'resume_reminders';
  static const String _trayHideKey = 'hide_window';
  static const String _trayExitKey = 'exit_app';

  VoidCallback? _onWindowClose;
  VoidCallback? _onTrayIconMouseDown;
  VoidCallback? _onTrayIconRightMouseDown;
  ValueChanged<DesktopTrayMenuAction>? _onTrayMenuAction;
  var _initialized = false;

  @override
  bool get isWindows => Platform.isWindows;

  @override
  Future<void> initialize({
    required VoidCallback onWindowClose,
    required VoidCallback onTrayIconMouseDown,
    required VoidCallback onTrayIconRightMouseDown,
    required ValueChanged<DesktopTrayMenuAction> onTrayMenuAction,
  }) async {
    _onWindowClose = onWindowClose;
    _onTrayIconMouseDown = onTrayIconMouseDown;
    _onTrayIconRightMouseDown = onTrayIconRightMouseDown;
    _onTrayMenuAction = onTrayMenuAction;

    if (!isWindows || _initialized) {
      return;
    }

    _initialized = true;
    window_plugin.windowManager.addListener(this);
    tray_plugin.trayManager.addListener(this);
  }

  @override
  Future<void> dispose() async {
    if (isWindows && _initialized) {
      window_plugin.windowManager.removeListener(this);
      tray_plugin.trayManager.removeListener(this);
    }
    _initialized = false;
  }

  @override
  Future<void> setPreventClose(bool value) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setPreventClose(value);
  }

  @override
  Future<void> setTitleBarStyle(
    DesktopWindowTitleBarStyle style, {
    required bool windowButtonVisibility,
  }) {
    if (!isWindows || !DesktopWindowEffects.ready) {
      return Future.value();
    }

    return window_plugin.windowManager.setTitleBarStyle(
      switch (style) {
        DesktopWindowTitleBarStyle.normal => window_plugin.TitleBarStyle.normal,
        DesktopWindowTitleBarStyle.hidden => window_plugin.TitleBarStyle.hidden,
      },
      windowButtonVisibility: windowButtonVisibility,
    );
  }

  @override
  Future<void> setAsFrameless() {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setAsFrameless();
  }

  @override
  Future<void> setBackgroundColor(Color color) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setBackgroundColor(color);
  }

  @override
  Future<void> setWindowEffect(
    DesktopWindowEffect effect, {
    Color color = const Color(0x00000000),
    bool dark = false,
  }) {
    if (!isWindows) {
      return Future.value();
    }

    return DesktopWindowEffects.setEffect(effect, color: color, dark: dark);
  }

  @override
  Future<void> setHasShadow(bool value) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setHasShadow(value);
  }

  @override
  Future<void> setOpacity(double opacity) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setOpacity(opacity);
  }

  @override
  Future<void> setAlwaysOnTop(bool value) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setAlwaysOnTop(value);
  }

  @override
  Future<void> setResizable(bool value) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setResizable(value);
  }

  @override
  Future<void> setMinimizable(bool value) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setMinimizable(value);
  }

  @override
  Future<void> setMaximizable(bool value) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setMaximizable(value);
  }

  @override
  Future<void> setSkipTaskbar(bool value) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setSkipTaskbar(value);
  }

  @override
  Future<void> setMinimumSize(Size size) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setMinimumSize(size);
  }

  @override
  Future<void> setMaximumSize(Size size) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setMaximumSize(size);
  }

  @override
  Future<void> setSize(Size size) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setSize(size);
  }

  @override
  Future<void> setBounds(Rect? bounds, {Offset? position, Size? size}) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.setBounds(
      bounds,
      position: position,
      size: size,
    );
  }

  @override
  Future<Rect> getBounds() {
    if (!isWindows) {
      return Future.value(Rect.zero);
    }
    return window_plugin.windowManager.getBounds();
  }

  @override
  Future<void> center() {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.center();
  }

  @override
  Future<void> show({bool inactive = false}) {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.show(inactive: inactive);
  }

  @override
  Future<void> hide() {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.hide();
  }

  @override
  Future<void> destroy() {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.destroy();
  }

  @override
  Future<void> focus() {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.focus();
  }

  @override
  Future<void> unmaximize() {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.unmaximize();
  }

  @override
  Future<void> startDragging() {
    if (!isWindows) {
      return Future.value();
    }
    return window_plugin.windowManager.startDragging();
  }

  @override
  Future<DesktopDisplayInfo> getPrimaryDisplay() async {
    final display = await screen_plugin.screenRetriever.getPrimaryDisplay();
    return DesktopDisplayInfo(
      visiblePosition: display.visiblePosition ?? Offset.zero,
      visibleSize: display.visibleSize ?? display.size,
    );
  }

  @override
  Future<void> initializeTray({
    required String iconPath,
    required String tooltip,
    required bool remindersPaused,
  }) async {
    if (!isWindows) {
      return;
    }

    await tray_plugin.trayManager.setIcon(iconPath);
    await tray_plugin.trayManager.setToolTip(tooltip);
    await updateTrayMenu(remindersPaused: remindersPaused);
  }

  @override
  Future<void> updateTrayMenu({required bool remindersPaused}) async {
    if (!isWindows) {
      return;
    }

    await tray_plugin.trayManager.setContextMenu(
      tray_plugin.Menu(
        items: [
          tray_plugin.MenuItem(key: _trayOpenFullKey, label: '打开 Evoly'),
          tray_plugin.MenuItem(key: _trayShowCompactKey, label: '显示迷你面板'),
          tray_plugin.MenuItem(
            key: remindersPaused
                ? _trayResumeRemindersKey
                : _trayPauseRemindersHourKey,
            label: remindersPaused ? '恢复提醒' : '暂停提醒 1 小时',
          ),
          tray_plugin.MenuItem(key: _trayHideKey, label: '隐藏窗口'),
          tray_plugin.MenuItem.separator(),
          tray_plugin.MenuItem(key: _trayExitKey, label: '退出'),
        ],
      ),
    );
  }

  @override
  Future<void> destroyTray() {
    if (!isWindows) {
      return Future.value();
    }
    return tray_plugin.trayManager.destroy();
  }

  @override
  Future<void> popUpTrayContextMenu() {
    if (!isWindows) {
      return Future.value();
    }
    return tray_plugin.trayManager.popUpContextMenu();
  }

  @override
  void onWindowClose() {
    _onWindowClose?.call();
  }

  @override
  void onTrayIconMouseDown() {
    _onTrayIconMouseDown?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    _onTrayIconRightMouseDown?.call();
  }

  @override
  void onTrayMenuItemClick(tray_plugin.MenuItem menuItem) {
    final action = switch (menuItem.key) {
      _trayOpenFullKey => DesktopTrayMenuAction.openFull,
      _trayShowCompactKey => DesktopTrayMenuAction.showCompact,
      _trayPauseRemindersHourKey => DesktopTrayMenuAction.pauseRemindersHour,
      _trayResumeRemindersKey => DesktopTrayMenuAction.resumeReminders,
      _trayHideKey => DesktopTrayMenuAction.hideWindow,
      _trayExitKey => DesktopTrayMenuAction.exitApp,
      _ => null,
    };

    if (action != null) {
      _onTrayMenuAction?.call(action);
    }
  }
}

acrylic_plugin.WindowEffect _toAcrylicEffect(DesktopWindowEffect effect) {
  return switch (effect) {
    DesktopWindowEffect.disabled => acrylic_plugin.WindowEffect.disabled,
    DesktopWindowEffect.transparent => acrylic_plugin.WindowEffect.transparent,
    DesktopWindowEffect.acrylic => acrylic_plugin.WindowEffect.acrylic,
  };
}
