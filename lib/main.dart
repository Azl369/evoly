import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:evoly/app/app.dart';
import 'package:evoly/app/lifecycle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  final lifecycle = AppLifecycleCoordinator();
  await lifecycle.bootstrap();

  runApp(const EvolyApp());
}
