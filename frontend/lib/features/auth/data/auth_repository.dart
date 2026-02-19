import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/auth_session.dart';
import 'auth_remote_data_source.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remote = ref.watch(authRemoteDataSourceProvider);
  return AuthRepository(remote);
});

class AuthRepository {
  const AuthRepository(this._remote);

  final AuthRemoteDataSource _remote;

  Future<AuthSession> loginPatient({
    required String phone,
    required String birthdate,
  }) {
    return _remote.validatePatient(phone: phone, birthdate: birthdate);
  }

  Future<AuthSession> loginDoctor({
    required String phone,
    required String password,
  }) {
    return _remote.validateDoctor(phone: phone, password: password);
  }

  Future<void> registerPatient({
    required String phone,
    required String name,
    required String birthdate,
    String? titularPatientId,
  }) {
    return _remote.registerPatient(
      phone: phone,
      name: name,
      birthdate: birthdate,
      titularPatientId: titularPatientId,
    );
  }

  String resolveErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;
      }
      return 'Error de conexión con el servidor';
    }
    return 'Ocurrió un error inesperado';
  }
}
