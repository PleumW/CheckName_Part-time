class LeaveRequestModel {
  final String id;
  final String userId;
  final String employeeName;
  final String shiftId;
  final String storeName;
  final DateTime date;
  final String leaveType; // 'personal' (ลากิจ), 'urgent' (ลาด่วน)
  final String reason;
  final DateTime createdAt;
  final String status; // 'pending', 'approved', 'rejected'

  LeaveRequestModel({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.shiftId,
    required this.storeName,
    required this.date,
    required this.leaveType,
    required this.reason,
    required this.createdAt,
    this.status = 'pending',
  });

  bool get isUrgent => leaveType == 'urgent';
  String get leaveTypeThai => isUrgent ? 'ลาด่วน' : 'ลากิจ';

  LeaveRequestModel copyWith({
    String? id,
    String? userId,
    String? employeeName,
    String? shiftId,
    String? storeName,
    DateTime? date,
    String? leaveType,
    String? reason,
    DateTime? createdAt,
    String? status,
  }) {
    return LeaveRequestModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      employeeName: employeeName ?? this.employeeName,
      shiftId: shiftId ?? this.shiftId,
      storeName: storeName ?? this.storeName,
      date: date ?? this.date,
      leaveType: leaveType ?? this.leaveType,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
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

  factory LeaveRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return LeaveRequestModel(
      id: id,
      userId: map['userId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      shiftId: map['shiftId'] ?? '',
      storeName: map['storeName'] ?? '',
      date: _parseDate(map['date']),
      leaveType: map['leaveType'] ?? 'personal',
      reason: map['reason'] ?? '',
      createdAt: _parseDate(map['createdAt']),
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'employeeName': employeeName,
      'shiftId': shiftId,
      'storeName': storeName,
      'date': date.toIso8601String(),
      'leaveType': leaveType,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }
}
