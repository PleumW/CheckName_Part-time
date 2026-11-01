import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/shift_model.dart';
import '../models/notification_model.dart';
import '../models/leave_request_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ================= Shifts (ตารางกะงาน Realtime) =================

  Stream<List<ShiftModel>> shiftsStream() {
    if (!isAvailable) return const Stream.empty();

    return _firestore.collection('shifts').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ShiftModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> saveShift(ShiftModel shift) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('shifts').doc(shift.id).set(shift.toMap());
    } catch (e) {
      // Ignored or logged if offline
    }
  }

  Future<void> updateShift(String shiftId, Map<String, dynamic> data) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('shifts').doc(shiftId).update(data);
    } catch (e) {
      // Ignored or logged if offline
    }
  }

  Future<void> deleteShift(String shiftId) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('shifts').doc(shiftId).delete();
    } catch (e) {
      // Ignored or logged if offline
    }
  }

  // ================= Notifications (การแจ้งเตือน Realtime) =================

  Stream<List<AppNotificationModel>> notificationsStream() {
    if (!isAvailable) return const Stream.empty();

    return _firestore
        .collection('notifications')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return AppNotificationModel.fromMap(doc.data(), doc.id);
      }).toList();

      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Future<void> saveNotification(AppNotificationModel notif) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('notifications').doc(notif.id).set(notif.toMap());
    } catch (e) {
      // Ignored or logged if offline
    }
  }

  Future<void> markNotificationAsRead(String notifId) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('notifications').doc(notifId).update({'isRead': true});
    } catch (e) {
      // Ignored or logged if offline
    }
  }

  Future<void> markAllNotificationsAsRead(List<String> notifIds) async {
    if (!isAvailable) return;
    try {
      final batch = _firestore.batch();
      for (final id in notifIds) {
        final docRef = _firestore.collection('notifications').doc(id);
        batch.update(docRef, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      // Ignored or logged if offline
    }
  }

  Future<void> deleteNotification(String notifId) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('notifications').doc(notifId).delete();
    } catch (e) {
      // Ignored or logged if offline
    }
  }

  // ================= Leave Requests (ระบบลางาน Realtime) =================

  Stream<List<LeaveRequestModel>> leaveRequestsStream() {
    if (!isAvailable) return const Stream.empty();

    return _firestore.collection('leave_requests').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return LeaveRequestModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> saveLeaveRequest(LeaveRequestModel request) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('leave_requests').doc(request.id).set(request.toMap());
    } catch (e) {
      // Ignored or logged if offline
    }
  }

  Future<void> deleteLeaveRequest(String requestId) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('leave_requests').doc(requestId).delete();
    } catch (e) {
      // Ignored or logged if offline
    }
  }

  // ================= Users (รายชื่อพนักงานทั้งหมด Realtime) =================

  late final List<UserModel> _localUsers = [];
  final StreamController<List<UserModel>> _usersController = StreamController<List<UserModel>>.broadcast();

  Stream<List<UserModel>> usersStream() {
    if (!isAvailable) {
      return Stream.multi((controller) {
        controller.add(List<UserModel>.from(_localUsers));
        final sub = _usersController.stream.listen(controller.add);
        controller.onCancel = () => sub.cancel();
      });
    }

    return _firestore.collection('users').snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return const <UserModel>[];
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> saveUser(UserModel user) async {
    final idx = _localUsers.indexWhere((u) => u.id == user.id);
    if (idx != -1) {
      _localUsers[idx] = user;
    } else {
      _localUsers.add(user);
    }
    _usersController.add(List<UserModel>.from(_localUsers));

    if (isAvailable) {
      try {
        await _firestore.collection('users').doc(user.id).set(user.toMap());
      } catch (e) {
        // Ignored or logged if offline
      }
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    if (isAvailable) {
      try {
        await _firestore.collection('users').doc(userId).update(data);
      } catch (e) {
        // Ignored or logged if offline
      }
    }
  }

  Future<void> deleteUser(String userId) async {
    _localUsers.removeWhere((u) => u.id == userId);
    _usersController.add(List<UserModel>.from(_localUsers));

    if (isAvailable) {
      try {
        await _firestore.collection('users').doc(userId).delete();
      } catch (e) {
        // Ignored or logged if offline
      }
    }
  }
}

final firestoreService = FirestoreService();
