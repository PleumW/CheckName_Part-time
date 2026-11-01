class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String nickname;
  final String email;
  final String role; // 'admin' or 'user'
  final String bankAccount;
  final String? profileImage;
  final String? rfid;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.nickname = '',
    this.email = '',
    required this.role,
    required this.bankAccount,
    this.profileImage,
    this.rfid,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get displayName => nickname.isNotEmpty ? nickname : (firstName.isNotEmpty ? firstName : 'พนักงาน');

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      nickname: data['nickname'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      bankAccount: data['bankAccount'] ?? '',
      profileImage: data['profileImage'],
      rfid: data['rfid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nickname,
      'email': email,
      'role': role,
      'bankAccount': bankAccount,
      'profileImage': profileImage,
      'rfid': rfid,
    };
  }

  UserModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? nickname,
    String? email,
    String? role,
    String? bankAccount,
    String? profileImage,
    String? rfid,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      role: role ?? this.role,
      bankAccount: bankAccount ?? this.bankAccount,
      profileImage: profileImage ?? this.profileImage,
      rfid: rfid ?? this.rfid,
    );
  }
}
