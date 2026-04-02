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

  Future<Appointment> fetchAppointmentDetail({required String appointmentId}) {
    return _remote.fetchAppointmentDetail(appointmentId: appointmentId);
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

  Future<List<PatientOption>> searchPatientsByName(
    String query, {
    int limit = 7,
  }) {
    return _remote.searchPatientsByName(query, limit: limit);
  }

  Future<List<PatientOption>> fetchAssociatesForPatient({
    required String patientId,
  }) {
    return _remote.fetchAssociatesForPatient(patientId: patientId);
  }

  Future<PatientOption> createAssociatedPatient({
    required String titularPatientId,
    required String name,
    required String phone,
    required String birthdate,
  }) {
    return _remote.createAssociatedPatient(
      titularPatientId: titularPatientId,
      name: name,
      phone: phone,
      birthdate: birthdate,
    );
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

  Future<Appointment> rescheduleAppointment({
    required String appointmentId,
    required DateTime newScheduledAt,
    String? reason,
  }) {
    return _remote.rescheduleAppointment(
      appointmentId: appointmentId,
      newScheduledAt: newScheduledAt,
      reason: reason,
    );
  }

  Future<Appointment> confirmAppointment({required String appointmentId}) {
    return _remote.confirmAppointment(appointmentId: appointmentId);
  }

  Future<Appointment> rejectAppointment({
    required String appointmentId,
    required String reason,
  }) {
    return _remote.rejectAppointment(
      appointmentId: appointmentId,
      reason: reason,
    );
  }

  Future<Appointment> attendAppointment({
    required String appointmentId,
    required String diagnosisText,
    String? recipeAttachmentId,
  }) {
    return _remote.attendAppointment(
      appointmentId: appointmentId,
      diagnosisText: diagnosisText,
      recipeAttachmentId: recipeAttachmentId,
    );
  }

  Future<Appointment> markAppointmentAbsent({required String appointmentId}) {
    return _remote.markAppointmentAbsent(appointmentId: appointmentId);
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
