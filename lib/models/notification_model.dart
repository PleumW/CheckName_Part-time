class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String shiftId;
  final String storeName;
  final String employeeName;
  final List<String> photos;
  final String note;
  final bool isRead;
  final String type; // 'checkout' or 'payment_slip'
  final String? targetUserId;
  final String? slipImage;
  final double? amountPaid;
  final String? welfareItems;
  final double? welfareAmount;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.shiftId = '',
    this.storeName = '',
    this.employeeName = '',
    this.photos = const [],
    this.note = '',
    this.isRead = false,
    this.type = 'checkout',
    this.targetUserId,
    this.slipImage,
    this.amountPaid,
    this.welfareItems,
    this.welfareAmount,
  });

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    String? shiftId,
    String? storeName,
    String? employeeName,
    List<String>? photos,
    String? note,
    bool? isRead,
    String? type,
    String? targetUserId,
    String? slipImage,
    double? amountPaid,
    String? welfareItems,
    double? welfareAmount,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      shiftId: shiftId ?? this.shiftId,
      storeName: storeName ?? this.storeName,
      employeeName: employeeName ?? this.employeeName,
      photos: photos ?? this.photos,
      note: note ?? this.note,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      targetUserId: targetUserId ?? this.targetUserId,
      slipImage: slipImage ?? this.slipImage,
      amountPaid: amountPaid ?? this.amountPaid,
      welfareItems: welfareItems ?? this.welfareItems,
      welfareAmount: welfareAmount ?? this.welfareAmount,
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

  factory AppNotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return AppNotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: _parseDate(map['timestamp']),
      shiftId: map['shiftId'] ?? '',
      storeName: map['storeName'] ?? '',
      employeeName: map['employeeName'] ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      note: map['note'] ?? '',
      isRead: map['isRead'] ?? false,
      type: map['type'] ?? 'checkout',
      targetUserId: map['targetUserId'],
      slipImage: map['slipImage'],
      amountPaid: map['amountPaid'] != null ? (map['amountPaid'] as num).toDouble() : null,
      welfareItems: map['welfareItems'],
      welfareAmount: map['welfareAmount'] != null ? (map['welfareAmount'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'shiftId': shiftId,
      'storeName': storeName,
      'employeeName': employeeName,
      'photos': photos,
      'note': note,
      'isRead': isRead,
      'type': type,
      'targetUserId': targetUserId,
      'slipImage': slipImage,
      'amountPaid': amountPaid,
      'welfareItems': welfareItems,
      'welfareAmount': welfareAmount,
    };
  }
}
