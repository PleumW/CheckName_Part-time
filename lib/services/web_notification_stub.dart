// Stub implementation for non-web platforms (Android, iOS, Windows, Tests)
import 'package:flutter/services.dart';

void requestWebNotificationPermissionImpl() {
  // No-op on non-web platforms
}

void showWebNotificationImpl(String title, String body, {String? icon, String? tag}) {
  // No-op on non-web platforms
}

bool isWebNotificationSupportedImpl() {
  return false;
}

String getNotificationPermissionImpl() {
  return 'unsupported';
}

bool isWebNotificationGrantedImpl() {
  return false;
}

void playNotificationSoundImpl() {
  try {
    SystemSound.play(SystemSoundType.alert);
  } catch (_) {}
}

bool isIOSImpl() {
  return false;
}

bool isStandaloneImpl() {
  return false;
}
