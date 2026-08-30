class UserProfile {
  final String id;
  final String phone;
  final bool isVerified;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.phone,
    required this.isVerified,
    required this.createdAt,
  });
}