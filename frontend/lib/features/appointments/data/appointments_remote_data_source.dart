import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/appointment.dart';

final appointmentsRemoteDataSourceProvider =
    Provider<AppointmentsRemoteDataSource>((ref) {
      final dio = ref.watch(dioProvider);
      return AppointmentsRemoteDataSource(dio);
    });

class AppointmentsRemoteDataSource {
  const AppointmentsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Appointment>> fetchAppointments({
    String? date,
    String? status,
    String? patientId,
    String? doctorId,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/appointments',
      queryParameters: {
        if (date != null && date.isNotEmpty) 'date': date,
        if (status != null && status.isNotEmpty) 'status': status,
        if (patientId != null && patientId.isNotEmpty) 'patient_id': patientId,
        if (doctorId != null && doctorId.isNotEmpty) 'doctor_id': doctorId,
      },
    );

    final list = _extractList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Appointment.fromJson)
        .toList();
  }

  Future<List<DoctorOption>> fetchDoctors({String? query}) async {
    final response = await _dio.get<dynamic>(
      '/api/doctors',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );

    final list = _extractList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .map(DoctorOption.fromJson)
        .where((doctor) => doctor.isActive)
        .toList();
  }

  Future<List<PatientOption>> searchPatientsByName(String query) async {
    final response = await _dio.get<dynamic>(
      '/api/patients',
      queryParameters: {'q': query},
    );

    final list = _extractList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .map(PatientOption.fromJson)
        .toList();
  }

  Future<void> createAppointment({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    String? paymentReference,
  }) async {
    await _dio.post<void>(
      '/api/appointments',
      data: {
        'patient_id': patientId,
        'doctor_id': doctorId,
        'scheduled_at': scheduledAt.toIso8601String(),
        if (paymentReference != null && paymentReference.isNotEmpty)
          'payment_reference': paymentReference,
      },
    );
  }

  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    try {
      await _dio.patch<void>(
        '/api/appointments/$appointmentId/status',
        data: {'status': status},
      );
    } on DioException {
      await _dio.patch<void>(
        '/api/appointments/$appointmentId',
        data: {'status': status},
      );
    }
  }
}

List<dynamic> _extractList(dynamic data) {
  if (data is List<dynamic>) return data;
  if (data is Map<String, dynamic>) {
    final dynamic list = data['data'] ?? data['results'] ?? data['items'];
    if (list is List<dynamic>) return list;
  }
  return const [];
}
