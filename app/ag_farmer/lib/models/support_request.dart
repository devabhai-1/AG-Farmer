enum SupportStatus { pending, active, resolved, closed }

class SupportRequest {
  final String id;
  final String uid;
  final String userName;
  final String userPhone;
  final String userEmail;
  final String planId;
  final String token;
  final String message;
  final SupportStatus status;
  final String createdAt;
  final String? updatedAt;
  final String? adminNote;

  const SupportRequest({
    required this.id,
    required this.uid,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
    required this.planId,
    required this.token,
    required this.message,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.adminNote,
  });

  factory SupportRequest.fromMap(String id, Map<dynamic, dynamic> map) {
    return SupportRequest(
      id: id,
      uid: (map['uid'] ?? '').toString(),
      userName: (map['userName'] ?? '').toString(),
      userPhone: (map['userPhone'] ?? '').toString(),
      userEmail: (map['userEmail'] ?? '').toString(),
      planId: (map['planId'] ?? 'free').toString(),
      token: (map['token'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      status: _statusFrom((map['status'] ?? 'pending').toString()),
      createdAt: (map['createdAt'] ?? '').toString(),
      updatedAt: map['updatedAt']?.toString(),
      adminNote: map['adminNote']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'userName': userName,
        'userPhone': userPhone,
        'userEmail': userEmail,
        'planId': planId,
        'token': token,
        'message': message,
        'status': status.name,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'adminNote': adminNote,
      };

  static SupportStatus _statusFrom(String raw) {
    return SupportStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SupportStatus.pending,
    );
  }
}
