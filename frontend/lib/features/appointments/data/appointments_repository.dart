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

  Future<List<Appointment>> fetchAppointmentsForPatient({
    required String patientId,
    String order = 'desc',
  }) {
    return _remote.fetchAppointmentsForPatient(
      patientId: patientId,
      order: order,
    );
  }

  Future<List<Appointment>> fetchAppointmentsForDoctor({
    required String date,
    int? state,
    String? doctorId,
    String order = 'desc',
  }) {
    return _remote.fetchAppointmentsForDoctor(
      date: date,
      state: state,
      doctorId: doctorId,
      order: order,
    );
  }

  Future<List<DoctorOption>> fetchDoctors({String? query}) {
    return _remote.fetchDoctors(query: query);
  }

  Future<List<DateTime>> fetchAvailability({
    required DateTime date,
    String from = '08:00',
    String to = '18:00',
  }) {
    return _remote.fetchAvailability(date: date, from: from, to: to);
  }

  Future<List<PatientOption>> searchPatientsByName(String query) {
    return _remote.searchPatientsByName(query);
  }

  Future<List<PatientOption>> fetchAssociatesForPatient({
    required String patientId,
  }) {
    return _remote.fetchAssociatesForPatient(patientId: patientId);
  }

  Future<void> createAppointment({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    String? depositSlipAttachmentId,
    bool byTitular = false,
  }) {
    return _remote.createAppointment(
      patientId: patientId,
      doctorId: doctorId,
      scheduledAt: scheduledAt,
      depositSlipAttachmentId: depositSlipAttachmentId,
      byTitular: byTitular,
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
