import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:evoly/app/app.dart';
import 'package:evoly/app/deep_link_protocol.dart';
import 'package:evoly/app/lifecycle.dart';
import 'package:evoly/app/supabase_bootstrap.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_controller.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  await DeepLinkProtocol.registerIfSupported();
  await SupabaseBootstrap.initialize();

  if (Platform.isWindows) {
    await DesktopWindowEffects.ensureInitialized();
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: DesktopWindowController.fullDefaultSize,
        minimumSize: DesktopWindowController.fullMinimumSize,
        center: true,
        alwaysOnTop: true,
        backgroundColor: DesktopWindowController.fullWindowBackground,
        title: 'Evoly',
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
      () async {
        await DesktopWindowEffects.setEffect(
          DesktopWindowEffect.acrylic,
          color: DesktopWindowController.fullWindowEffectTint,
          dark: false,
        );
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  final lifecycle = AppLifecycleCoordinator();
  await lifecycle.bootstrap();

  runApp(const EvolyApp());
}
