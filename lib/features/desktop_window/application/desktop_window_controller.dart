import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_host.dart';
import 'package:evoly/features/desktop_window/domain/desktop_window_mode.dart';
import 'package:evoly/features/settings/data/settings_repository.dart';

class DesktopWindowController extends ChangeNotifier {
  DesktopWindowController({DesktopWindowHost? host})
      : _host = host ?? PluginDesktopWindowHost();

  static const String _trayIconPath = 'windows/runner/resources/app_icon.ico';

  static const Size fullDefaultSize = Size(1180, 760);
  static const Size fullMinimumSize = Size(900, 640);
  static const Size compactSize = Size(360, 184);
  static const Size compactExpandedSize = Size(360, 360);
  static const Color compactWindowBackground = Color(0x00000000);
  static const Color fullWindowBackground = Color(0xDCF4FBFF);
  static const Color fullWindowEffectTint = Color(0xD8F4FBFF);
  static const double compactScreenInset = 16;
  static const double compactSnapDistance = 24;

  final DesktopWindowHost _host;
  var _mode = DesktopWindowMode.full;
  var _compactExpanded = false;
  var _initialized = false;
  var _isExiting = false;
  var _trayReady = false;
  var _operationRevision = 0;
  var _notificationRevision = 0;
  var _settings = AppSettings.defaultSettings;
  Rect? _lastFullBounds;
  String? _pendingTaskId;
  Future<void> Function(Offset? position)? _saveCompactPosition;
  Future<void> Function(Duration duration)? _pauseReminders;
  Future<void> Function()? _resumeReminders;

  DesktopWindowMode get mode => _mode;

  bool get isWindows => _host.isWindows;

  bool get compactExpanded => _compactExpanded;

  bool get isCompact => _mode == DesktopWindowMode.compact;

  bool get hasTray => _trayReady;

  String? get pendingTaskId => _pendingTaskId;

  void updateSettings(
    AppSettings settings, {
    Future<void> Function(Offset? position)? saveCompactPosition,
    Future<void> Function(Duration duration)? pauseReminders,
    Future<void> Function()? resumeReminders,
  }) {
    final previousSettings = _settings;
    _settings = settings;
    _saveCompactPosition = saveCompactPosition;
    _pauseReminders = pauseReminders;
    _resumeReminders = resumeReminders;

    if (!_host.isWindows) {
      return;
    }

    final remindersPausedChanged =
        previousSettings.windowsRemindersPaused(DateTime.now()) !=
            settings.windowsRemindersPaused(DateTime.now());
    if (_trayReady && remindersPausedChanged) {
      unawaited(_refreshTrayMenu());
    }

    if (_mode != DesktopWindowMode.compact) {
      return;
    }

    final positionChanged = previousSettings.windowsCompactPosition !=
        settings.windowsCompactPosition;
    final alwaysOnTopChanged = previousSettings.windowsCompactAlwaysOnTop !=
        settings.windowsCompactAlwaysOnTop;
    if (positionChanged || alwaysOnTopChanged) {
      unawaited(
        _applyCompactWindow(
          _compactExpanded ? compactExpandedSize : compactSize,
        ),
      );
    }
  }

  String? consumePendingTaskId() {
    final taskId = _pendingTaskId;
    if (taskId == null) {
      return null;
    }

    _pendingTaskId = null;
    _notifyStateChanged();
    return taskId;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _host.initialize(
      onWindowClose: _handleWindowClose,
      onTrayIconMouseDown: _handleTrayIconMouseDown,
      onTrayIconRightMouseDown: _handleTrayIconRightMouseDown,
      onTrayMenuAction: _handleTrayMenuAction,
    );

    if (!_host.isWindows) {
      return;
    }

    await _host.setPreventClose(true);
    await _initializeTray();
  }

  Future<void> enterCompactMode({bool expanded = false}) async {
    final revision = ++_operationRevision;

    if (_host.isWindows) {
      await _rememberFullBounds();
    }

    final size = expanded ? compactExpandedSize : compactSize;

    if (_host.isWindows) {
      await _applyCompactWindow(size);
    }

    if (_isExiting || revision != _operationRevision) {
      return;
    }

    _pendingTaskId = null;
    _compactExpanded = expanded;
    _setMode(DesktopWindowMode.compact);
  }

  Future<void> enterFullMode({String? taskId}) async {
    final revision = ++_operationRevision;

    if (_host.isWindows) {
      await _applyFullWindow();
    }

    if (_isExiting || revision != _operationRevision) {
      return;
    }

    _pendingTaskId = taskId;
    _compactExpanded = false;
    _setMode(DesktopWindowMode.full);
  }

  Future<void> toggleCompactExpanded() async {
    if (_mode != DesktopWindowMode.compact) {
      await enterCompactMode(expanded: true);
      return;
    }

    final revision = ++_operationRevision;
    final expanded = !_compactExpanded;
    final size = expanded ? compactExpandedSize : compactSize;

    if (!expanded) {
      _compactExpanded = false;
      _notifyStateChanged();
    }

    if (_host.isWindows) {
      await _applyCompactWindow(size);
    }

    if (_isExiting ||
        revision != _operationRevision ||
        _mode != DesktopWindowMode.compact) {
      return;
    }

    if (expanded) {
      _compactExpanded = true;
      _notifyStateChanged();
    }
  }

  Future<void> hideWindow() async {
    final revision = ++_operationRevision;

    if (_host.isWindows && !_trayReady) {
      await enterCompactMode();
      return;
    }

    if (_host.isWindows) {
      await _rememberFullBounds();
      await _host.hide();
    }

    if (_isExiting || revision != _operationRevision) {
      return;
    }

    _setMode(DesktopWindowMode.hidden);
  }

  Future<void> exitApp() async {
    _isExiting = true;
    if (_host.isWindows) {
      await _host.destroyTray();
      await _host.destroy();
    }
  }

  void startCompactDrag() {
    if (!_host.isWindows) {
      return;
    }

    unawaited(_startCompactDrag());
  }

  void rememberCompactPosition() {
    if (!_host.isWindows) {
      return;
    }

    unawaited(_rememberCompactPosition());
  }

  Future<void> resetCompactPosition() async {
    _settings = _settings.copyWith(
      windowsCompactPositionX: null,
      windowsCompactPositionY: null,
    );

    if (_host.isWindows && _mode == DesktopWindowMode.compact) {
      await _applyCompactWindow(
        _compactExpanded ? compactExpandedSize : compactSize,
      );
    }
  }

  void _handleWindowClose() {
    if (!_host.isWindows || _isExiting) {
      return;
    }

    switch (_settings.windowsCloseBehavior) {
      case WindowsCloseBehavior.hideToTray:
        if (_trayReady) {
          unawaited(hideWindow());
        } else {
          unawaited(enterCompactMode());
        }
      case WindowsCloseBehavior.showCompact:
        unawaited(enterCompactMode());
      case WindowsCloseBehavior.exitApp:
        unawaited(exitApp());
    }
  }

  void _handleTrayIconMouseDown() {
    if (!_host.isWindows) {
      return;
    }

    switch (_settings.windowsTrayClickBehavior) {
      case WindowsTrayClickBehavior.showCompact:
        unawaited(enterCompactMode());
      case WindowsTrayClickBehavior.openFull:
        unawaited(enterFullMode());
    }
  }

  void _handleTrayIconRightMouseDown() {
    if (_host.isWindows) {
      unawaited(_host.popUpTrayContextMenu());
    }
  }

  void _handleTrayMenuAction(DesktopTrayMenuAction action) {
    switch (action) {
      case DesktopTrayMenuAction.openFull:
        unawaited(enterFullMode());
      case DesktopTrayMenuAction.showCompact:
        unawaited(enterCompactMode());
      case DesktopTrayMenuAction.pauseRemindersHour:
        unawaited(_pauseReminders?.call(const Duration(hours: 1)));
      case DesktopTrayMenuAction.resumeReminders:
        unawaited(_resumeReminders?.call());
      case DesktopTrayMenuAction.hideWindow:
        unawaited(hideWindow());
      case DesktopTrayMenuAction.exitApp:
        unawaited(exitApp());
    }
  }

  @override
  void dispose() {
    unawaited(_host.dispose());
    super.dispose();
  }

  Future<void> _applyFullWindow() async {
    final bounds = _lastFullBounds ?? const Rect.fromLTWH(0, 0, 1180, 760);
    await _applyWindowEffect(
      DesktopWindowEffect.acrylic,
      color: fullWindowEffectTint,
      dark: false,
    );
    await _host.setBackgroundColor(fullWindowBackground);
    await _host.setTitleBarStyle(
      DesktopWindowTitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await _host.setAlwaysOnTop(true);
    await _host.setResizable(true);
    await _host.setMinimizable(true);
    await _host.setMaximizable(true);
    await _host.setSkipTaskbar(false);
    await _host.setMaximumSize(const Size(10000, 10000));
    await _host.setMinimumSize(fullMinimumSize);
    await _host.show();

    if (_lastFullBounds == null) {
      await _host.setSize(fullDefaultSize);
      await _host.center();
    } else {
      await _host.setBounds(bounds);
    }
    await _host.focus();
  }

  Future<void> _applyCompactWindow(Size size) async {
    final position = await _compactPosition(size);

    await _host.unmaximize();
    await _host.setBackgroundColor(compactWindowBackground);
    await _applyWindowEffect(
      DesktopWindowEffect.transparent,
      color: compactWindowBackground,
      dark: false,
    );
    await _host.setAsFrameless();
    await _host.setResizable(false);
    await _host.setMinimizable(false);
    await _host.setMaximizable(false);
    await _host.setAlwaysOnTop(_settings.windowsCompactAlwaysOnTop);
    await _host.setSkipTaskbar(false);
    await _host.setMinimumSize(size);
    await _host.setMaximumSize(size);
    await _host.setBounds(null, position: position, size: size);
    await _host.show(inactive: true);
  }

  Future<void> _applyWindowEffect(
    DesktopWindowEffect effect, {
    required Color color,
    required bool dark,
  }) async {
    try {
      await _host.setWindowEffect(effect, color: color, dark: dark);
    } catch (_) {
      // System backdrop support varies across Windows builds. Window state
      // changes should continue even when acrylic is unavailable.
    }
  }

  Future<void> _initializeTray() async {
    try {
      await _host.initializeTray(
        iconPath: _trayIconPath,
        tooltip: 'Evoly',
        remindersPaused: _settings.windowsRemindersPaused(DateTime.now()),
      );
      _trayReady = true;
    } catch (_) {
      // The tray icon is a convenience layer. Window mode switching still works
      // if the OS rejects the tray setup.
    }
  }

  Future<void> _refreshTrayMenu() async {
    try {
      await _host.updateTrayMenu(
        remindersPaused: _settings.windowsRemindersPaused(DateTime.now()),
      );
    } catch (_) {
      // Tray menu refresh is not critical to window mode switching.
    }
  }

  void _setMode(DesktopWindowMode mode) {
    if (_mode == mode) {
      _notifyStateChanged();
      return;
    }

    _mode = mode;
    _notifyStateChanged();
  }

  void _notifyStateChanged() {
    if (_isExiting || !hasListeners) {
      return;
    }

    final revision = ++_notificationRevision;
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    if (schedulerPhase == SchedulerPhase.persistentCallbacks ||
        schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isExiting || revision != _notificationRevision || !hasListeners) {
          return;
        }
        notifyListeners();
      });

      WidgetsBinding.instance.scheduleFrame();
      return;
    }

    notifyListeners();
  }

  Future<void> _rememberFullBounds() async {
    if (!_host.isWindows || _mode != DesktopWindowMode.full) {
      return;
    }

    try {
      _lastFullBounds = await _host.getBounds();
    } catch (_) {
      _lastFullBounds ??= Rect.fromLTWH(
        0,
        0,
        fullDefaultSize.width,
        fullDefaultSize.height,
      );
    }
  }

  Future<void> _startCompactDrag() async {
    try {
      await _host.startDragging();
      await _rememberCompactPosition();
    } catch (_) {
      // Dragging is a convenience affordance; it should not affect mode state.
    }
  }

  Future<void> _rememberCompactPosition() async {
    if (!_host.isWindows || _mode != DesktopWindowMode.compact) {
      return;
    }

    try {
      final bounds = await _host.getBounds();
      final position = await _normalizedCompactPosition(
        bounds.topLeft,
        bounds.size,
      );
      if (position != bounds.topLeft) {
        await _host.setBounds(null, position: position, size: bounds.size);
      }
      _settings = _settings.copyWith(
        windowsCompactPositionX: position.dx,
        windowsCompactPositionY: position.dy,
      );
      await _saveCompactPosition?.call(position);
    } catch (_) {
      // Position persistence should never interrupt desktop window controls.
    }
  }

  Future<Offset> _compactPosition(Size compactSize) async {
    try {
      final display = await _host.getPrimaryDisplay();
      final visiblePosition = display.visiblePosition;
      final visibleSize = display.visibleSize;
      final configuredPosition = _settings.windowsCompactPosition;
      if (configuredPosition != null) {
        return _clampToVisibleBounds(
          configuredPosition,
          compactSize,
          visiblePosition,
          visibleSize,
        );
      }

      return Offset(
        visiblePosition.dx +
            visibleSize.width -
            compactSize.width -
            compactScreenInset,
        visiblePosition.dy + compactScreenInset,
      );
    } catch (_) {
      return const Offset(compactScreenInset, compactScreenInset);
    }
  }

  Future<Offset> _normalizedCompactPosition(
    Offset position,
    Size compactSize,
  ) async {
    final display = await _host.getPrimaryDisplay();
    final clampedPosition = _clampToVisibleBounds(
      position,
      compactSize,
      display.visiblePosition,
      display.visibleSize,
    );

    return _snapToVisibleEdges(
      clampedPosition,
      compactSize,
      display.visiblePosition,
      display.visibleSize,
    );
  }

  Offset _clampToVisibleBounds(
    Offset position,
    Size compactSize,
    Offset visiblePosition,
    Size visibleSize,
  ) {
    final minX = visiblePosition.dx + compactScreenInset;
    final minY = visiblePosition.dy + compactScreenInset;
    final maxX = visiblePosition.dx +
        visibleSize.width -
        compactSize.width -
        compactScreenInset;
    final maxY = visiblePosition.dy +
        visibleSize.height -
        compactSize.height -
        compactScreenInset;

    return Offset(
      position.dx.clamp(minX, maxX < minX ? minX : maxX).toDouble(),
      position.dy.clamp(minY, maxY < minY ? minY : maxY).toDouble(),
    );
  }

  Offset _snapToVisibleEdges(
    Offset position,
    Size compactSize,
    Offset visiblePosition,
    Size visibleSize,
  ) {
    final minX = visiblePosition.dx + compactScreenInset;
    final minY = visiblePosition.dy + compactScreenInset;
    final maxX = visiblePosition.dx +
        visibleSize.width -
        compactSize.width -
        compactScreenInset;
    final maxY = visiblePosition.dy +
        visibleSize.height -
        compactSize.height -
        compactScreenInset;

    return Offset(
      _snapAxis(position.dx, minX, maxX < minX ? minX : maxX),
      _snapAxis(position.dy, minY, maxY < minY ? minY : maxY),
    );
  }

  double _snapAxis(double value, double min, double max) {
    if ((value - min).abs() <= compactSnapDistance) {
      return min;
    }
    if ((value - max).abs() <= compactSnapDistance) {
      return max;
    }
    return value;
  }
}
