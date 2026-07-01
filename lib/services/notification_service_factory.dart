import 'dart:io';

import 'package:evoly/services/android_notification_service.dart';
import 'package:evoly/services/notification_service.dart';

/// 根据当前平台创建合适的通知服务实现。
NotificationService createNotificationService() {
  if (Platform.isAndroid) {
    return AndroidNotificationService();
  }
  if (Platform.isWindows) {
    return const WindowsToastNotificationService();
  }
  return const NoopNotificationService();
}
