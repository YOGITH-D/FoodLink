class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role; // 'provider' or 'receiver'
  final String address;
  final double latitude;
  final double longitude;
  final String phone;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    return AppUser(
      uid: documentId,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'receiver',
      address: map['address'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      phone: map['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
    };
  }
}
