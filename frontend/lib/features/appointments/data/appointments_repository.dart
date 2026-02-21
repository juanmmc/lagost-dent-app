import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/appointment.dart';
import 'appointments_remote_data_source.dart';

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  final remote = ref.watch(appointmentsRemoteDataSourceProvider);
  return AppointmentsRepository(remote);
});

class AppointmentsRepository {
  const AppointmentsRepository(this._remote);

  final AppointmentsRemoteDataSource _remote;

  Future<List<Appointment>> fetchAppointments({
    String? date,
    String? status,
    String? patientId,
    String? doctorId,
  }) {
    return _remote.fetchAppointments(
      date: date,
      status: status,
      patientId: patientId,
      doctorId: doctorId,
    );
  }

  Future<List<DoctorOption>> fetchDoctors({String? query}) {
    return _remote.fetchDoctors(query: query);
  }

  Future<List<PatientOption>> searchPatientsByName(String query) {
    return _remote.searchPatientsByName(query);
  }

  Future<void> createAppointment({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    String? paymentReference,
  }) {
    return _remote.createAppointment(
      patientId: patientId,
      doctorId: doctorId,
      scheduledAt: scheduledAt,
      paymentReference: paymentReference,
    );
  }

  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) {
    return _remote.updateAppointmentStatus(
      appointmentId: appointmentId,
      status: status,
    );
  }

  String resolveErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;
      }
      return 'No se pudo completar la operación de citas';
    }
    return 'Ocurrió un error inesperado';
  }
}
