import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift_model.dart';
import '../services/firestore_service.dart';
import 'notification_provider.dart';

class ShiftState {
  final DateTime selectedWeekStart; // Monday of current selected week
  final List<ShiftModel> shifts;
  final String selectedStoreFilter; // 'All' or specific store
  final bool isLoading;

  ShiftState({
    required this.selectedWeekStart,
    required this.shifts,
    this.selectedStoreFilter = 'All',
    this.isLoading = false,
  });

  ShiftState copyWith({
    DateTime? selectedWeekStart,
    List<ShiftModel>? shifts,
    String? selectedStoreFilter,
    bool? isLoading,
  }) {
    return ShiftState(
      selectedWeekStart: selectedWeekStart ?? this.selectedWeekStart,
      shifts: shifts ?? this.shifts,
      selectedStoreFilter: selectedStoreFilter ?? this.selectedStoreFilter,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Get the 7 days of the selected week (Mon - Sun)
  List<DateTime> get daysOfWeek {
    return List.generate(7, (index) {
      return DateTime(
        selectedWeekStart.year,
        selectedWeekStart.month,
        selectedWeekStart.day + index,
      );
    });
  }

  /// Get filtered shifts for the active week and store filter
  List<ShiftModel> get currentWeekShifts {
    final start = DateTime(selectedWeekStart.year, selectedWeekStart.month, selectedWeekStart.day);
    final end = start.add(const Duration(days: 7));

    return shifts.where((shift) {
      final shiftDate = DateTime(shift.date.year, shift.date.month, shift.date.day);
      final inWeek = (shiftDate.isAtSameMomentAs(start) || shiftDate.isAfter(start)) &&
          shiftDate.isBefore(end);
      if (!inWeek) return false;

      if (selectedStoreFilter != 'All' && shift.storeName != selectedStoreFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Shifts for a specific day
  List<ShiftModel> shiftsForDay(DateTime date) {
    return currentWeekShifts.where((shift) {
      return shift.date.year == date.year &&
          shift.date.month == date.month &&
          shift.date.day == date.day;
    }).toList();
  }

  /// All shifts for a specific day regardless of store/week filters
  List<ShiftModel> allShiftsForDay(DateTime date) {
    return shifts.where((shift) {
      return shift.date.year == date.year &&
          shift.date.month == date.month &&
          shift.date.day == date.day;
    }).toList();
  }

  /// Today's shift specifically for a user (matches userId or nickname or fullName)
  ShiftModel? todayShiftForUser(String userId, {String? nickname, String? fullName}) {
    final now = DateTime.now();
    for (final s in shifts) {
      if (s.date.year != now.year || s.date.month != now.month || s.date.day != now.day) {
        continue;
      }
      final matchesId = s.userId.isNotEmpty && s.userId == userId;
      final matchesNickname = nickname != null && nickname.isNotEmpty && s.userName == nickname;
      final matchesFullName = fullName != null && fullName.isNotEmpty && s.userName == fullName;
      if (matchesId || matchesNickname || matchesFullName) {
        return s;
      }
    }
    return null;
  }

  /// All upcoming shifts for a user sorted chronologically (from today onwards)
  List<ShiftModel> upcomingShiftsForUser(String userId, {String? nickname, String? fullName}) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final list = shifts.where((s) {
      final sDate = DateTime(s.date.year, s.date.month, s.date.day);
      if (sDate.isBefore(todayStart)) return false;

      final matchesId = s.userId.isNotEmpty && s.userId == userId;
      final matchesNickname = nickname != null && nickname.isNotEmpty && s.userName == nickname;
      final matchesFullName = fullName != null && fullName.isNotEmpty && s.userName == fullName;
      return matchesId || matchesNickname || matchesFullName;
    }).toList();

    list.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      return a.startHourDecimal.compareTo(b.startHourDecimal);
    });

    return list;
  }

  /// Next upcoming shift for a user after today
  ShiftModel? nextUpcomingShiftForUser(String userId, {String? nickname, String? fullName}) {
    final upcoming = upcomingShiftsForUser(userId, nickname: nickname, fullName: fullName);
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    for (final s in upcoming) {
      final sDate = DateTime(s.date.year, s.date.month, s.date.day);
      if (sDate.isAfter(todayEnd) ||
          (sDate.isAtSameMomentAs(DateTime(now.year, now.month, now.day)) && s.status == 'upcoming')) {
        return s;
      }
    }
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  /// Total hours for this week
  double get totalWeeklyHours {
    return currentWeekShifts.fold(0.0, (sum, shift) => sum + shift.durationHours);
  }

  /// Total shifts this week
  int get totalWeeklyShifts {
    return currentWeekShifts.length;
  }
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  final Ref _ref;
  StreamSubscription<List<ShiftModel>>? _subscription;

  ShiftNotifier(this._ref)
      : super(ShiftState(
          selectedWeekStart: _getMondayOfCurrentWeek(DateTime.now()),
          shifts: const [],
        )) {
    _initRealtimeStream();
  }

  void _initRealtimeStream() {
    _subscription?.cancel();
    if (firestoreService.isAvailable) {
      _subscription = firestoreService.shiftsStream().listen(
        (firestoreShifts) {
          state = state.copyWith(shifts: firestoreShifts);
        },
        onError: (_) {},
      );
    }
  }

  void ensureStreamInitialized() {
    if (_subscription == null && firestoreService.isAvailable) {
      _initRealtimeStream();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  static DateTime _getMondayOfCurrentWeek(DateTime date) {
    // DateTime.weekday: Monday = 1, Sunday = 7
    final diff = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - diff);
  }

  void selectStoreFilter(String store) {
    state = state.copyWith(selectedStoreFilter: store);
  }

  void nextWeek() {
    final newStart = state.selectedWeekStart.add(const Duration(days: 7));
    state = state.copyWith(selectedWeekStart: newStart);
  }

  void previousWeek() {
    final newStart = state.selectedWeekStart.subtract(const Duration(days: 7));
    state = state.copyWith(selectedWeekStart: newStart);
  }

  void goToToday() {
    final todayMonday = _getMondayOfCurrentWeek(DateTime.now());
    state = state.copyWith(selectedWeekStart: todayMonday);
  }

  /// Add a new shift (used by Admin or scheduler)
  void addShift(ShiftModel shift) {
    state = state.copyWith(
      shifts: [...state.shifts, shift],
    );

    // Sync to Cloud Firestore Realtime
    firestoreService.saveShift(shift);
  }

  /// Delete/cancel a shift
  void deleteShift(String shiftId) {
    state = state.copyWith(
      shifts: state.shifts.where((s) => s.id != shiftId).toList(),
    );

    // Sync to Cloud Firestore Realtime
    firestoreService.deleteShift(shiftId);
  }

  /// Update/edit an existing shift (used by Admin)
  void updateShift(ShiftModel shift) {
    state = state.copyWith(
      shifts: state.shifts.map((s) => s.id == shift.id ? shift : s).toList(),
    );

    // Sync to Cloud Firestore Realtime
    firestoreService.saveShift(shift);
  }

  /// Check in to a shift
  void checkIn(String shiftId) {
    final now = DateTime.now();

    state = state.copyWith(
      shifts: state.shifts.map((s) {
        if (s.id == shiftId) {
          return s.copyWith(
            status: 'in_progress',
            checkInTime: now,
          );
        }
        return s;
      }).toList(),
    );

    // Sync to Cloud Firestore Realtime
    firestoreService.updateShift(shiftId, {
      'status': 'in_progress',
      'checkInTime': now.toIso8601String(),
    });
  }

  /// Check out from a shift, save photos, note & welfare details, and trigger notification to Admin
  void checkOut(
    String shiftId, {
    required List<String> photos,
    required String note,
    String employeeName = 'คุณพนักงาน',
    String? welfareItems,
    double? welfareAmount,
  }) {
    final now = DateTime.now();
    ShiftModel? checkedShift;

    state = state.copyWith(
      shifts: state.shifts.map((s) {
        if (s.id == shiftId) {
          final updated = s.copyWith(
            status: 'completed',
            checkOutTime: now,
            checkOutPhotos: photos,
            checkOutNote: note,
            welfareItems: welfareItems,
            welfareAmount: welfareAmount,
          );
          checkedShift = updated;
          return updated;
        }
        return s;
      }).toList(),
    );

    // Sync to Cloud Firestore Realtime
    firestoreService.updateShift(shiftId, {
      'status': 'completed',
      'checkOutTime': now.toIso8601String(),
      'checkOutPhotos': photos,
      'checkOutNote': note,
      'welfareItems': welfareItems,
      'welfareAmount': welfareAmount,
    });

    // Send notification to Admin (which also syncs to Firestore)
    if (checkedShift != null) {
      _ref.read(notificationProvider.notifier).addNotification(
            shiftId: shiftId,
            storeName: checkedShift!.storeName,
            employeeName: employeeName,
            photos: photos,
            note: note,
            welfareItems: welfareItems,
            welfareAmount: welfareAmount,
          );
    }
  }
}

final shiftProvider = StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  return ShiftNotifier(ref);
});
