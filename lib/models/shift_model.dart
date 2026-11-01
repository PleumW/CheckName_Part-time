import 'package:flutter/material.dart';

class ShiftModel {
  final String id;
  final String userId;
  final String userName;
  final String storeName;
  final DateTime date;
  final String startTime; // e.g., "10:00"
  final String endTime;   // e.g., "18:00"
  final String role;      // e.g., "Barista", "Cat Care", "Cashier"
  final String branchLocation;
  final String status;    // 'upcoming', 'in_progress', 'completed', 'cancelled'
  final String? note;
  final Color? customColor;
  
  // Checkout & Checkin details
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final List<String> checkOutPhotos;
  final String? checkOutNote;

  // Welfare details
  final String? welfareItems;
  final double? welfareAmount;

  const ShiftModel({
    required this.id,
    required this.userId,
    this.userName = '',
    required this.storeName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.role,
    required this.branchLocation,
    this.status = 'upcoming',
    this.note,
    this.customColor,
    this.checkInTime,
    this.checkOutTime,
    this.checkOutPhotos = const [],
    this.checkOutNote,
    this.welfareItems,
    this.welfareAmount,
  });

  ShiftModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? storeName,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? role,
    String? branchLocation,
    String? status,
    String? note,
    Color? customColor,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    List<String>? checkOutPhotos,
    String? checkOutNote,
    String? welfareItems,
    double? welfareAmount,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      storeName: storeName ?? this.storeName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      role: role ?? this.role,
      branchLocation: branchLocation ?? this.branchLocation,
      status: status ?? this.status,
      note: note ?? this.note,
      customColor: customColor ?? this.customColor,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkOutPhotos: checkOutPhotos ?? this.checkOutPhotos,
      checkOutNote: checkOutNote ?? this.checkOutNote,
      welfareItems: welfareItems ?? this.welfareItems,
      welfareAmount: welfareAmount ?? this.welfareAmount,
    );
  }

  /// Returns true if this shift has a flexible start time (e.g. after school / classes)
  bool get isFlexibleStart {
    final s = startTime.toLowerCase();
    return s.contains('เลิกเรียน') ||
        s.contains('ไวที่สุด') ||
        s.contains('asap') ||
        (note != null && note!.contains('เลิกเรียนไวที่สุด'));
  }

  /// Parse hour:minute string to double (e.g., "10:30" -> 10.5)
  double get startHourDecimal {
    if (isFlexibleStart) {
      if (checkInTime != null) {
        return checkInTime!.hour + (checkInTime!.minute / 60.0);
      }
      return 16.5; // Default ~16:30 for grid placement before check-in
    }
    return _timeStringToDecimal(startTime);
  }

  double get endHourDecimal {
    return _timeStringToDecimal(endTime);
  }

  double get durationHours {
    if (isFlexibleStart) {
      if (checkInTime != null && checkOutTime != null) {
        final diff = checkOutTime!.difference(checkInTime!).inMinutes / 60.0;
        return diff > 0 ? diff : 0.0;
      } else if (checkInTime != null) {
        final checkInDecimal = checkInTime!.hour + (checkInTime!.minute / 60.0);
        final diff = endHourDecimal - checkInDecimal;
        return diff > 0 ? diff : 0.0;
      }
      final diff = endHourDecimal - 16.5;
      return diff > 0 ? diff : 0.0;
    }
    final diff = endHourDecimal - startHourDecimal;
    return diff > 0 ? diff : 0;
  }

  DateTime get scheduledStartDateTime {
    if (isFlexibleStart) {
      if (checkInTime != null) return checkInTime!;
      return DateTime(date.year, date.month, date.day, 16, 30);
    }
    final parts = startTime.split(':');
    final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 9) : 9;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  DateTime get scheduledEndDateTime {
    final parts = endTime.split(':');
    final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 17) : 17;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Returns true if checkInTime is later than scheduledStartDateTime + 15 minutes
  bool get isLateMoreThan15Mins {
    if (isFlexibleStart) return false; // กะเลิกเรียนไวที่สุด ไม่คิดค่าสาย
    if (checkInTime == null) return false;
    final graceDeadline = scheduledStartDateTime.add(const Duration(minutes: 15));
    return checkInTime!.isAfter(graceDeadline);
  }

  /// Display string for schedule times (e.g., "🎒 เลิกเรียนไวที่สุด - 21:30 น.")
  String get timeDisplay => isFlexibleStart ? '🎒 $startTime - $endTime น.' : '$startTime - $endTime น.';

  /// Returns true if checkOutTime is later than scheduledEndDateTime + 15 minutes
  bool get isOvertimeMoreThan15Mins {
    if (checkOutTime == null) return false;
    final otThreshold = scheduledEndDateTime.add(const Duration(minutes: 15));
    return checkOutTime!.isAfter(otThreshold);
  }

  /// Calculates total shift earnings in Baht:
  /// - Base rate: 40 THB/hr
  /// - Late > 15 mins: 1st hour earns 20 THB instead of 40 THB
  /// - Early check-in: Counted according to standard schedule
  /// - Check-out > 15 mins after end time: OT bonus +20 THB
  double get calculatedEarnings {
    final hours = durationHours;
    if (hours <= 0) return 0.0;

    double baseWage;
    if (isLateMoreThan15Mins) {
      final normalHours = hours > 1 ? (hours - 1) : 0.0;
      baseWage = (normalHours * 40.0) + 20.0; // 1st hour = 20 THB
    } else {
      baseWage = hours * 40.0;
    }

    final otBonus = isOvertimeMoreThan15Mins ? 20.0 : 0.0;
    return baseWage + otBonus;
  }

  static double _timeStringToDecimal(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = double.parse(parts[0]);
      final minute = parts.length > 1 ? double.parse(parts[1]) : 0.0;
      return hour + (minute / 60.0);
    } catch (_) {
      return 9.0;
    }
  }

  Color get storeColor {
    if (customColor != null) return customColor!;
    final normalized = storeName.toLowerCase();
    if (normalized.contains('tokio')) {
      return const Color(0xFFD97736); // Warm Caramel / Tokio
    } else if (normalized.contains('kita')) {
      return const Color(0xFF4E878C); // Teal Matcha / Kita
    } else if (normalized.contains('freshly') || normalized.contains('frashy')) {
      return const Color(0xFF9D65C9); // Pastel Berry / Freshly
    }
    return const Color(0xFF7A6C5D); // Mocha default
  }

  Color get storeBackgroundColor {
    return storeColor.withValues(alpha: 0.15);
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      return (value as dynamic).toDate();
    } catch (_) {
      return DateTime.now();
    }
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate();
    } catch (_) {
      return null;
    }
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map, String id) {
    return ShiftModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      storeName: map['storeName'] ?? '',
      date: _parseDate(map['date']),
      startTime: map['startTime'] ?? '10:00',
      endTime: map['endTime'] ?? '18:00',
      role: map['role'] ?? 'Staff',
      branchLocation: map['branchLocation'] ?? '',
      status: map['status'] ?? 'upcoming',
      note: map['note'],
      checkInTime: _parseNullableDate(map['checkInTime']),
      checkOutTime: _parseNullableDate(map['checkOutTime']),
      checkOutPhotos: List<String>.from(map['checkOutPhotos'] ?? []),
      checkOutNote: map['checkOutNote'],
      welfareItems: map['welfareItems'],
      welfareAmount: map['welfareAmount'] != null ? (map['welfareAmount'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'storeName': storeName,
      'date': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'startTime': startTime,
      'endTime': endTime,
      'role': role,
      'branchLocation': branchLocation,
      'status': status,
      'note': note,
      'checkInTime': checkInTime?.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'checkOutPhotos': checkOutPhotos,
      'checkOutNote': checkOutNote,
      'welfareItems': welfareItems,
      'welfareAmount': welfareAmount,
    };
  }
}
