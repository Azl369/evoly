import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:evoly/app/app.dart';
import 'package:evoly/app/deep_link_protocol.dart';
import 'package:evoly/app/lifecycle.dart';
import 'package:evoly/app/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  await DeepLinkProtocol.registerIfSupported();
  await SupabaseBootstrap.initialize();

  final lifecycle = AppLifecycleCoordinator();
  await lifecycle.bootstrap();

  runApp(const EvolyApp());
}
