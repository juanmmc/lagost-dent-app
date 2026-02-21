import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/auth_session.dart';
import '../domain/models/user_role.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRemoteDataSource(dio);
});

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthSession> validatePatient({
    required String phone,
    required String birthdate,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/patients/validate',
      data: {'phone': phone, 'birthdate': birthdate},
    );

    final data = response.data ?? <String, dynamic>{};
    return AuthSession(
      token: data['token'] as String,
      role: UserRole.patient,
      personId: data['person_id'] as String,
      profileId: data['patient_id'] as String,
    );
  }

  Future<AuthSession> validateDoctor({
    required String phone,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/doctors/validate',
      data: {'phone': phone, 'password': password},
    );

    final data = response.data ?? <String, dynamic>{};
    return AuthSession(
      token: data['token'] as String,
      role: UserRole.doctor,
      personId: data['person_id'] as String,
      profileId: data['doctor_id'] as String,
    );
  }

  Future<void> registerPatient({
    required String phone,
    required String name,
    required String birthdate,
    String? titularPatientId,
  }) async {
    final payload = <String, dynamic>{
      'phone': phone,
      'name': name,
      'birthdate': birthdate,
      'birth_date': birthdate,
      if (titularPatientId != null && titularPatientId.isNotEmpty) ...{
        'titular_patient_id': titularPatientId,
        'titularPatientId': titularPatientId,
      },
    };

    try {
      await _dio.post<void>('/api/patients', data: payload);
    } on DioException catch (error) {
      if (kDebugMode) {
        debugPrint('❌ [REGISTER] payload=$payload');
        debugPrint('❌ [REGISTER] response=${error.response?.data}');
      }
      rethrow;
    }
  }
}
