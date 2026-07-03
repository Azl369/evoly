import 'dart:io';

import 'package:flutter/foundation.dart';

class DeepLinkProtocol {
  const DeepLinkProtocol._();

  static const scheme = 'evoly';
  static const authCallbackUrl = '$scheme://auth-callback';

  static Future<void> registerIfSupported() async {
    if (!Platform.isWindows) {
      return;
    }

    await _registerWindowsProtocol();
  }

  static Future<void> _registerWindowsProtocol() async {
    final command = '"${Platform.resolvedExecutable}" "%1"';

    await _regAdd(
      r'HKCU\Software\Classes\evoly',
      valueName: '',
      data: 'URL:Evoly',
    );
    await _regAdd(
      r'HKCU\Software\Classes\evoly',
      valueName: 'URL Protocol',
      data: '',
    );
    await _regAdd(
      r'HKCU\Software\Classes\evoly\shell\open\command',
      valueName: '',
      data: command,
    );
  }

  static Future<void> _regAdd(
    String key, {
    required String valueName,
    required String data,
  }) async {
    final args = <String>['add', key, '/f'];
    if (valueName.isEmpty) {
      args.add('/ve');
    } else {
      args.addAll(['/v', valueName]);
    }
    args.addAll(['/t', 'REG_SZ', '/d', data]);

    final result = await Process.run('reg', args);
    if (result.exitCode != 0) {
      debugPrint(
        'Failed to register Evoly deep link protocol: ${result.stderr}',
      );
    }
  }
}
