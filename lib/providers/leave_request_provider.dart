import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leave_request_model.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import 'notification_provider.dart';

class LeaveRequestNotifier extends StateNotifier<List<LeaveRequestModel>> {
  final Ref _ref;
  StreamSubscription<List<LeaveRequestModel>>? _subscription;

  LeaveRequestNotifier(this._ref) : super(const []) {
    _initRealtimeStream();
  }

  void _initRealtimeStream() {
    if (firestoreService.isAvailable) {
      _subscription = firestoreService.leaveRequestsStream().listen(
        (requests) {
          state = requests;
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

  Future<void> submitLeaveRequest(LeaveRequestModel request) async {
    // Optimistic update
    state = [request, ...state.where((r) => r.id != request.id)];

    // Sync to Cloud Firestore
    await firestoreService.saveLeaveRequest(request);

    // Send Realtime Notification to Admin
    final notif = AppNotificationModel(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: 'แจ้ง${request.leaveTypeThai}: ${request.employeeName}',
      body: 'ร้าน ${request.storeName} (วันที่ ${request.date.day}/${request.date.month}) - เหตุผล: ${request.reason}',
      timestamp: DateTime.now(),
      shiftId: request.shiftId,
      storeName: request.storeName,
      employeeName: request.employeeName,
      note: 'ประเภท: ${request.leaveTypeThai}\nเหตุผล: ${request.reason}',
      isRead: false,
    );

    _ref.read(notificationProvider.notifier).addCustomNotification(notif);
  }

  Future<void> deleteLeaveRequest(String requestId) async {
    state = state.where((r) => r.id != requestId).toList();
    await firestoreService.deleteLeaveRequest(requestId);
  }
}

final leaveRequestProvider =
    StateNotifierProvider<LeaveRequestNotifier, List<LeaveRequestModel>>((ref) {
  return LeaveRequestNotifier(ref);
});
