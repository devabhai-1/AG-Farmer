class AgroUserProfile {
  final String uid;
  final String name;
  final String email;
  final String address;
  final String phone;
  final int? age;
  final bool acceptedPolicy;
  final String provider; // email | google
  final bool profileComplete;

  const AgroUserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.address = '',
    this.phone = '',
    this.age,
    this.acceptedPolicy = false,
    this.provider = 'email',
    this.profileComplete = false,
  });

  factory AgroUserProfile.fromMap(String uid, Map<dynamic, dynamic> map) {
    return AgroUserProfile(
      uid: uid,
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      age: map['age'] is int ? map['age'] as int : int.tryParse('${map['age'] ?? ''}'),
      acceptedPolicy: map['acceptedPolicy'] == true,
      provider: (map['provider'] ?? 'email').toString(),
      profileComplete: map['profileComplete'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'address': address,
        'phone': phone,
        'age': age,
        'acceptedPolicy': acceptedPolicy,
        'provider': provider,
        'profileComplete': profileComplete,
        'plan': 'free',
        'updatedAt': DateTime.now().toIso8601String(),
        'lastLoginAt': DateTime.now().toIso8601String(),
      };

  AgroUserProfile copyWith({
    String? name,
    String? email,
    String? address,
    String? phone,
    int? age,
    bool? acceptedPolicy,
    String? provider,
    bool? profileComplete,
  }) {
    return AgroUserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      acceptedPolicy: acceptedPolicy ?? this.acceptedPolicy,
      provider: provider ?? this.provider,
      profileComplete: profileComplete ?? this.profileComplete,
    );
  }
}
