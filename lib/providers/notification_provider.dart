import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../services/web_notification_service.dart';

class NotificationNotifier extends StateNotifier<List<AppNotificationModel>> {
  StreamSubscription<List<AppNotificationModel>>? _subscription;

  NotificationNotifier() : super([]) {
    _initRealtimeStream();
  }

  void _initRealtimeStream() {
    if (firestoreService.isAvailable) {
      _subscription = firestoreService.notificationsStream().listen(
        (firestoreNotifs) {
          state = firestoreNotifs;
        },
        onError: (_) {},
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void addNotification({
    required String shiftId,
    required String storeName,
    required String employeeName,
    required List<String> photos,
    required String note,
    String? welfareItems,
    double? welfareAmount,
  }) {
    final newNotif = AppNotificationModel(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: '🔔 พนักงานส่งงาน (Check Out) แล้ว',
      body: '$employeeName เช็คเอาท์ที่ $storeName แนบรูปถ่าย ${photos.length} รูป และหมายเหตุงาน',
      timestamp: DateTime.now(),
      shiftId: shiftId,
      storeName: storeName,
      employeeName: employeeName,
      photos: photos,
      note: note,
      isRead: false,
      type: 'checkout',
      welfareItems: welfareItems,
      welfareAmount: welfareAmount,
    );

    state = [newNotif, ...state];

    // Show Web Browser Notification if on Web
    WebNotificationService.showNotification(
      title: newNotif.title,
      body: newNotif.body,
    );

    // Realtime Cloud Firestore Sync
    firestoreService.saveNotification(newNotif);
  }

  void sendPaymentNotification({
    required String targetUserId,
    required String employeeName,
    required double amountPaid,
    required String slipImage,
    String note = '',
  }) {
    final newNotif = AppNotificationModel(
      id: 'notif-pay-${DateTime.now().millisecondsSinceEpoch}',
      title: '💸 แจ้งเตือนการโอนเงิน (ชำระค่าจ้างแล้ว)',
      body: 'คุณได้รับเงินโอนจำนวน ฿${amountPaid.toStringAsFixed(0)} บาทเรียบร้อยแล้ว!',
      timestamp: DateTime.now(),
      employeeName: employeeName,
      targetUserId: targetUserId,
      type: 'payment_slip',
      slipImage: slipImage,
      amountPaid: amountPaid,
      note: note,
      isRead: false,
    );

    state = [newNotif, ...state];

    // Realtime Cloud Firestore Sync
    firestoreService.saveNotification(newNotif);
  }

  void sendShiftAssignedNotification({
    required String targetUserId,
    required String employeeName,
    required String storeName,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String role,
    required String shiftId,
    String note = '',
  }) {
    final thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    final dateStr = '${date.day} ${thaiMonths[date.month - 1]} ${date.year + 543}';
    final newNotif = AppNotificationModel(
      id: 'notif-shift-${DateTime.now().millisecondsSinceEpoch}',
      title: '📅 มีการจัดตารางงานใหม่ให้คุณ!',
      body: 'คุณมีกะงานที่ร้าน $storeName วันที่ $dateStr เวลา $startTime - $endTime น. (ตำแหน่ง: $role)',
      timestamp: DateTime.now(),
      shiftId: shiftId,
      storeName: storeName,
      employeeName: employeeName,
      targetUserId: targetUserId,
      type: 'new_shift',
      note: note,
      isRead: false,
    );

    state = [newNotif, ...state];

    // Realtime Cloud Firestore Sync
    firestoreService.saveNotification(newNotif);
  }

  void sendShiftUpdatedNotification({
    required String targetUserId,
    required String employeeName,
    required String storeName,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String role,
    required String shiftId,
    String note = '',
  }) {
    final thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    final dateStr = '${date.day} ${thaiMonths[date.month - 1]} ${date.year + 543}';
    final newNotif = AppNotificationModel(
      id: 'notif-shift-upd-${DateTime.now().millisecondsSinceEpoch}',
      title: '🔄 มีการปรับปรุงกะงานของคุณ',
      body: 'กะงานที่ร้าน $storeName วันที่ $dateStr ปรับเป็นเวลา $startTime - $endTime น. ($role)',
      timestamp: DateTime.now(),
      shiftId: shiftId,
      storeName: storeName,
      employeeName: employeeName,
      targetUserId: targetUserId,
      type: 'new_shift',
      note: note,
      isRead: false,
    );

    state = [newNotif, ...state];

    firestoreService.saveNotification(newNotif);
  }

  void addCustomNotification(AppNotificationModel notif) {
    state = [notif, ...state.where((n) => n.id != notif.id)];
    WebNotificationService.showNotification(
      title: notif.title,
      body: notif.body,
    );
    firestoreService.saveNotification(notif);
  }

  void markAsRead(String id) {
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    // Realtime Cloud Firestore Sync
    firestoreService.markNotificationAsRead(id);
  }

  void markAllAsRead() {
    final ids = state.map((n) => n.id).toList();
    state = state.map((n) => n.copyWith(isRead: true)).toList();

    // Realtime Cloud Firestore Sync
    firestoreService.markAllNotificationsAsRead(ids);
  }

  void deleteNotification(String id) {
    state = state.where((n) => n.id != id).toList();

    // Realtime Cloud Firestore Sync
    firestoreService.deleteNotification(id);
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<AppNotificationModel>>((ref) {
  return NotificationNotifier();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationProvider);
  return notifs.where((n) => !n.isRead).length;
});

final userNotificationsProvider = Provider.family<List<AppNotificationModel>, String>((ref, userId) {
  final notifs = ref.watch(notificationProvider);
  return notifs.where((n) {
    if (n.targetUserId == null || n.targetUserId!.isEmpty) return true;
    return n.targetUserId == userId;
  }).toList();
});

final userUnreadNotificationCountProvider = Provider.family<int, String>((ref, userId) {
  final list = ref.watch(userNotificationsProvider(userId));
  return list.where((n) => !n.isRead).length;
});

final userHasUnreadShiftNotificationProvider = Provider.family<bool, String>((ref, userId) {
  final list = ref.watch(userNotificationsProvider(userId));
  return list.any((n) => !n.isRead && (n.type == 'new_shift' || n.type == 'update_shift'));
});

