import 'user_role.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.personId,
    required this.profileId,
  });

  final String token;
  final UserRole role;
  final String personId;
  final String profileId;
}
