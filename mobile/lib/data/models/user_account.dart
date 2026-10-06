class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class AuthSession {
  const AuthSession({required this.user, required this.token});

  final UserAccount user;
  final String token;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: UserAccount.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
    );
  }
}
