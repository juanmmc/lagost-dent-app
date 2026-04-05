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
  static const String _associatesForPatientPath = '/api/patients/{id}/associates';
  static const String _listForDoctorPath = '/api/appointments/listForDoctor';
  static const String _genericListPath = '/api/appointments';
  static const String _detailPath = '/api/appointments/{id}';
  static const String _availabilityPath = '/api/appointments/availability';

  Future<List<Appointment>> fetchAppointments({
    String? date,
    String? status,
    int? state,
    String? patientId,
    String? doctorId,
    String? order,
  }) async {
    final response = await _dio.get<dynamic>(
      _genericListPath,
      queryParameters: {
        if (date?.isNotEmpty ?? false) 'date': date,
        if (status?.isNotEmpty ?? false) 'status': status,
        'state': ?state,
        if (patientId?.isNotEmpty ?? false) 'patient_id': patientId,
        if (doctorId?.isNotEmpty ?? false) 'doctor_id': doctorId,
        if (order?.isNotEmpty ?? false) 'order': order,
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
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404 || statusCode == 405) {
        return fetchAppointments(patientId: patientId, order: order);
      }
      rethrow;
    }
  }

  Future<List<Appointment>> fetchAppointmentsForDoctor({
    required String date,
    int? state,
    String? doctorId,
    String? patientId,
    String order = 'desc',
  }) async {
    final query = <String, dynamic>{'date': date, 'order': order};
    if (state != null) query['state'] = state;
    if (doctorId?.isNotEmpty ?? false) query['doctor_id'] = doctorId;
    if (patientId?.isNotEmpty ?? false) {
      query['patient_id'] = patientId;
    }

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
      return fetchAppointments(
        date: date,
        state: state,
        patientId: patientId,
        doctorId: doctorId,
        order: order,
      );
    }
  }

  Future<Appointment> fetchAppointmentDetail({
    required String appointmentId,
  }) async {
    final response = await _dio.get<dynamic>(
      _detailPath.replaceFirst('{id}', appointmentId),
    );
    return Appointment.fromJson(_extractItem(response.data));
  }

  Future<List<DoctorOption>> fetchDoctors({String? query}) async {
    final response = await _dio.get<dynamic>(
      '/api/doctors',
      queryParameters: {if (query?.isNotEmpty ?? false) 'q': query},
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

  Future<List<PatientOption>> searchPatientsByName(
    String query, {
    int limit = 7,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/patients/search',
      queryParameters: {'name': query.trim(), 'limit': limit.clamp(1, 7)},
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

  Future<PatientOption> createAssociatedPatient({
    required String titularPatientId,
    required String name,
    required String phone,
    required String birthdate,
  }) async {
    final response = await _dio.post<dynamic>(
      '/api/patients',
      data: {
        'phone': phone,
        'name': name,
        'birthdate': birthdate,
        'titular_patient_id': titularPatientId,
      },
    );

    return PatientOption.fromJson(_extractItem(response.data));
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
        if (depositSlipAttachmentId?.isNotEmpty ?? false)
          'deposit_slip_attachment_id': depositSlipAttachmentId,
      },
    );
  }

  Future<void> createAppointmentByDoctor({
    required String patientId,
    required DateTime scheduledAt,
  }) async {
    await _dio.post<void>(
      '/api/appointments/by-doctor',
      data: {
        'patient_id': patientId,
        'scheduled_at': _formatDateTimeForBackend(scheduledAt),
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

  Future<Appointment> rescheduleAppointment({
    required String appointmentId,
    required DateTime newScheduledAt,
    String? reason,
  }) async {
    final response = await _dio.patch<dynamic>(
      '/api/appointments/$appointmentId/reschedule',
      data: {
        'new_scheduled_at': _formatDateTimeForBackend(newScheduledAt),
        if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
      },
    );

    return Appointment.fromJson(_extractItem(response.data));
  }

  Future<Appointment> confirmAppointment({
    required String appointmentId,
  }) async {
    final response = await _dio.patch<dynamic>(
      '/api/appointments/$appointmentId/confirm',
    );

    return Appointment.fromJson(_extractItem(response.data));
  }

  Future<Appointment> rejectAppointment({
    required String appointmentId,
    required String reason,
  }) async {
    final response = await _dio.patch<dynamic>(
      '/api/appointments/$appointmentId/reject',
      data: {'reason': reason},
    );

    return Appointment.fromJson(_extractItem(response.data));
  }

  Future<Appointment> attendAppointment({
    required String appointmentId,
    required String diagnosisText,
    String? recipeAttachmentId,
  }) async {
    final response = await _dio.patch<dynamic>(
      '/api/appointments/$appointmentId/attend',
      data: {
        'diagnosis_text': diagnosisText,
        if (recipeAttachmentId?.trim().isNotEmpty ?? false)
          'recipe_attachment_id': recipeAttachmentId!.trim(),
      },
    );

    return Appointment.fromJson(_extractItem(response.data));
  }

  Future<Appointment> markAppointmentAbsent({
    required String appointmentId,
  }) async {
    final response = await _dio.patch<dynamic>(
      '/api/appointments/$appointmentId/absent',
    );

    return Appointment.fromJson(_extractItem(response.data));
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

Map<String, dynamic> _extractItem(dynamic data) {
  if (data is Map<String, dynamic>) {
    final nested = data['data'];
    if (nested is Map<String, dynamic>) return nested;
    return data;
  }
  throw const FormatException('Respuesta invalida de la cita');
}
