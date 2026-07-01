import 'package:evoly/services/android_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stableAndroidNotificationId returns deterministic positive ids', () {
    const reminderId = 'demo-v022-android-reminder-2m';

    final first = stableAndroidNotificationId(reminderId);
    final second = stableAndroidNotificationId(reminderId);

    expect(first, second);
    expect(first, greaterThan(0));
  });

  test('stableAndroidNotificationId differentiates reminder ids', () {
    final twoMinuteId =
        stableAndroidNotificationId('demo-v022-android-reminder-2m');
    final fiveMinuteId =
        stableAndroidNotificationId('demo-v022-android-reminder-5m');

    expect(twoMinuteId, isNot(fiveMinuteId));
  });
}
