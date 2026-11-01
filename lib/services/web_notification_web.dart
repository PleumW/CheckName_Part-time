// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;

void requestWebNotificationPermissionImpl() {
  try {
    if (js.context.hasProperty('requestSystemNotificationPermission')) {
      js.context.callMethod('requestSystemNotificationPermission');
    } else if (html.Notification.supported && html.Notification.permission != 'granted') {
      html.Notification.requestPermission();
    }
  } catch (_) {}
}

void showWebNotificationImpl(String title, String body, {String? icon, String? tag}) {
  try {
    if (js.context.hasProperty('showSystemNotification')) {
      js.context.callMethod('showSystemNotification', [title, body, icon ?? 'icons/Icon-192.png', tag]);
    } else if (html.Notification.supported && html.Notification.permission == 'granted') {
      html.Notification(
        title,
        body: body,
        icon: icon ?? 'icons/Icon-192.png',
      );
    }
  } catch (_) {}
}

bool isWebNotificationSupportedImpl() {
  try {
    return html.Notification.supported;
  } catch (_) {
    return false;
  }
}

String getNotificationPermissionImpl() {
  try {
    if (js.context.hasProperty('getNotificationPermission')) {
      return js.context.callMethod('getNotificationPermission').toString();
    }
    if (html.Notification.supported) {
      return html.Notification.permission ?? 'default';
    }
    return 'unsupported';
  } catch (_) {
    return 'unsupported';
  }
}

bool isWebNotificationGrantedImpl() {
  try {
    return getNotificationPermissionImpl() == 'granted';
  } catch (_) {
    return false;
  }
}

void playNotificationSoundImpl() {
  try {
    js.context.callMethod('playWebNotificationChime');
  } catch (_) {}
}

bool isIOSImpl() {
  try {
    if (js.context.hasProperty('isIOSDevice')) {
      return js.context.callMethod('isIOSDevice') == true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

bool isStandaloneImpl() {
  try {
    if (js.context.hasProperty('isStandalonePWA')) {
      return js.context.callMethod('isStandalonePWA') == true;
    }
    return false;
  } catch (_) {
    return false;
  }
}
