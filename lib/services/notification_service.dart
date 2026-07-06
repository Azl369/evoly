import 'dart:io';

enum NotificationRepeat {
  none,
  daily,
  weekly,
  monthly,
}

abstract class NotificationService {
  Future<void> initialize();

  Future<void> showNow({
    required String id,
    required String title,
    required String body,
  });

  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    NotificationRepeat repeat = NotificationRepeat.none,
  });

  Future<void> cancel(String id);
}

class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showNow({
    required String id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    NotificationRepeat repeat = NotificationRepeat.none,
  }) async {}

  @override
  Future<void> cancel(String id) async {}
}

class WindowsToastNotificationService implements NotificationService {
  const WindowsToastNotificationService();

  static const _appId = 'Evoly.App';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showNow({
    required String id,
    required String title,
    required String body,
  }) async {
    if (!Platform.isWindows) {
      return;
    }

    final escapedTitle = _escapeXml(title);
    final escapedBody = _escapeXml(body);
    final escapedId = _escapeXml(id);

    final script = '''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
\$template = @"
<toast launch="evoly://reminder/$escapedId">
  <visual>
    <binding template="ToastGeneric">
      <text>$escapedTitle</text>
      <text>$escapedBody</text>
    </binding>
  </visual>
</toast>
"@
\$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
\$xml.LoadXml(\$template)
\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('$_appId').Show(\$toast)
''';

    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ],
    );

    if (result.exitCode != 0) {
      throw StateError('Windows Toast failed: ${result.stderr}');
    }
  }

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    NotificationRepeat repeat = NotificationRepeat.none,
  }) async {
    if (scheduledAt.isAfter(DateTime.now())) {
      return;
    }

    await showNow(id: id, title: title, body: body);
  }

  @override
  Future<void> cancel(String id) async {}

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
