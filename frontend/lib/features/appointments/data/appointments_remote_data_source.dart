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

  static const String _listForPatientPath = '/api/patients/{id}/appointments';
  static const String _associatesForPatientPath =
      '/api/patients/{id}/associates';
  static const String _listForDoctorPath = '/api/appointments/listForDoctor';
  static const String _genericListPath = '/api/appointments';
  static const String _availabilityPath = '/api/appointments/availability';

  Future<List<Appointment>> fetchAppointments({
    String? date,
    String? status,
    String? patientId,
    String? doctorId,
  }) async {
    final response = await _dio.get<dynamic>(
      _genericListPath,
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

  Future<List<Appointment>> fetchAppointmentsForPatient({
    required String patientId,
    String order = 'desc',
  }) async {
    final query = {'order': order};

    try {
      final response = await _dio.get<dynamic>(
        _listForPatientPath.replaceFirst('{id}', patientId),
        queryParameters: query,
      );
      final list = _extractList(response.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(Appointment.fromJson)
          .toList();
    } on DioException {
      return fetchAppointments(patientId: patientId);
    }
  }

  Future<List<Appointment>> fetchAppointmentsForDoctor({
    required String date,
    int? state,
    String? doctorId,
    String order = 'desc',
  }) async {
    final query = <String, dynamic>{'date': date, 'order': order};
    if (state != null) query['state'] = state;
    if (doctorId != null && doctorId.isNotEmpty) query['doctor_id'] = doctorId;

    try {
      final response = await _dio.get<dynamic>(
        _listForDoctorPath,
        queryParameters: query,
      );
      final list = _extractList(response.data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(Appointment.fromJson)
          .toList();
    } on DioException {
      return fetchAppointments(date: date, doctorId: doctorId);
    }
  }

  Future<List<DoctorOption>> fetchDoctors({String? query}) async {
    final response = await _dio.get<dynamic>(
      '/api/doctors',
      queryParameters: {if (query != null && query.isNotEmpty) 'q': query},
    );

    final list = _extractList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .map(DoctorOption.fromJson)
        .where((doctor) => doctor.isActive)
        .toList();
  }

  Future<List<DateTime>> fetchAvailability({
    required DateTime date,
    String from = '08:00',
    String to = '18:00',
  }) async {
    final response = await _dio.get<dynamic>(
      _availabilityPath,
      queryParameters: {'date': _formatDate(date), 'from': from, 'to': to},
    );

    final payload = response.data;
    List<dynamic> rawSlots = const [];

    if (payload is Map<String, dynamic>) {
      final directSlots = payload['available'];
      if (directSlots is List<dynamic>) {
        rawSlots = directSlots;
      } else {
        final nested = payload['data'];
        if (nested is Map<String, dynamic> &&
            nested['available'] is List<dynamic>) {
          rawSlots = nested['available'] as List<dynamic>;
        }
      }
    }

    return rawSlots.whereType<String>().map(DateTime.parse).toList();
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

  Future<List<PatientOption>> fetchAssociatesForPatient({
    required String patientId,
  }) async {
    final response = await _dio.get<dynamic>(
      _associatesForPatientPath.replaceFirst('{id}', patientId),
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
    String? depositSlipAttachmentId,
    bool byTitular = false,
  }) async {
    final path = byTitular
        ? '/api/appointments/by-titular'
        : '/api/appointments';

    await _dio.post<void>(
      path,
      data: {
        'patient_id': patientId,
        'doctor_id': doctorId,
        'scheduled_at': _formatDateTimeForBackend(scheduledAt),
        if (depositSlipAttachmentId != null &&
            depositSlipAttachmentId.isNotEmpty)
          'deposit_slip_attachment_id': depositSlipAttachmentId,
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

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatDateTimeForBackend(DateTime value) {
  final date = _formatDate(value);
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$date $hour:$minute:$second';
}

List<dynamic> _extractList(dynamic data) {
  if (data is List<dynamic>) return data;
  if (data is Map<String, dynamic>) {
    final dynamic list = data['data'] ?? data['results'] ?? data['items'];
    if (list is List<dynamic>) return list;
  }
  return const [];
}
