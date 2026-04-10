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
      final statusCode = error.response?.statusCode;
      final raw = error.response?.data?.toString().toLowerCase() ?? '';
      if (raw.contains('people_phone_unique') ||
          raw.contains('llave duplicada') ||
          raw.contains('sqlstate[23505]') ||
          raw.contains('el numero de celular ya esta registrado') ||
          raw.contains('el número de celular ya está registrado')) {
        return 'Ese teléfono ya está registrado. Intenta iniciar sesión con ese número.';
      }

      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        if (statusCode == 422) {
          final errors = data['errors'];
          if (errors is Map<String, dynamic>) {
            final phoneErrors = errors['phone'];
            if (phoneErrors is List && phoneErrors.isNotEmpty) {
              return phoneErrors.first.toString();
            }
            if (phoneErrors != null) return phoneErrors.toString();
          }
        }

        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;

        final errors = data['errors'];
        if (errors is Map<String, dynamic> && errors.isNotEmpty) {
          final firstKey = errors.keys.first;
          final firstValue = errors[firstKey];
          if (firstValue is List && firstValue.isNotEmpty) {
            return firstValue.first.toString();
          }
          if (firstValue != null) return firstValue.toString();
        }
      }
      return 'Error del servidor (${error.response?.statusCode ?? 'sin código'})';
    }
    return 'Ocurrió un error inesperado';
  }
}
