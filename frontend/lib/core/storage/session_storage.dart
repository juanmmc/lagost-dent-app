import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/models/auth_session.dart';
import '../../features/auth/domain/models/user_role.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return const SessionStorage(FlutterSecureStorage());
});

class SessionStorage {
  const SessionStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth.token';
  static const _roleKey = 'auth.role';
  static const _personIdKey = 'auth.personId';
  static const _profileIdKey = 'auth.profileId';

  Future<void> save(AuthSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(key: _roleKey, value: session.role.name);
    await _storage.write(key: _personIdKey, value: session.personId);
    await _storage.write(key: _profileIdKey, value: session.profileId);
  }

  Future<AuthSession?> read() async {
    final token = await _storage.read(key: _tokenKey);
    final role = await _storage.read(key: _roleKey);
    final personId = await _storage.read(key: _personIdKey);
    final profileId = await _storage.read(key: _profileIdKey);

    if (token == null ||
        role == null ||
        personId == null ||
        profileId == null) {
      return null;
    }

    final parsedRole = UserRole.values
        .where((it) => it.name == role)
        .firstOrNull;
    if (parsedRole == null) return null;

    return AuthSession(
      token: token,
      role: parsedRole,
      personId: personId,
      profileId: profileId,
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _personIdKey);
    await _storage.delete(key: _profileIdKey);
  }
}
