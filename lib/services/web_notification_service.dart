import 'web_notification_stub.dart'
    if (dart.library.html) 'web_notification_web.dart' as impl;

class WebNotificationService {
  static void requestPermission() {
    impl.requestWebNotificationPermissionImpl();
  }

  static void showNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
  }) {
    impl.showWebNotificationImpl(title, body, icon: icon, tag: tag);
  }

  static bool get isSupported => impl.isWebNotificationSupportedImpl();

  static String get permission => impl.getNotificationPermissionImpl();

  static bool get isGranted => impl.isWebNotificationGrantedImpl();

  static void playNotificationSound() {
    impl.playNotificationSoundImpl();
  }

  static bool get isIOS => impl.isIOSImpl();

  static bool get isStandalone => impl.isStandaloneImpl();
}
