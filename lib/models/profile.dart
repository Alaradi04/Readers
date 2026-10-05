class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.email,
    this.role = 'user',
    this.picture,
    this.privacy = 'private',
  });
  final String id;
  final String username;
  final String email;
  final String role;
  final String? picture;
  final String privacy;

  bool get isAdmin => role.trim().toLowerCase() == 'admin';
  bool get isPublic => privacy.trim().toLowerCase() == 'public';

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    id: map['id'] as String,
    username: map['username'] as String? ?? 'Reader',
    email: map['email'] as String? ?? '',
    role: map['role'] as String? ?? 'user',
    picture: map['picture'] as String?,
    privacy: (map['privacy'] ?? map['Privacy']) as String? ?? 'private',
  );
}
