import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/appointments_repository.dart';
import '../../domain/models/appointment.dart';

final patientAppointmentsControllerProvider = NotifierProvider<
  PatientAppointmentsController,
  PatientAppointmentsState
>(PatientAppointmentsController.new);

class PatientAppointmentsState {
  const PatientAppointmentsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.appointments = const [],
    this.doctors = const [],
    this.selectedDoctorId,
    this.selectedDate,
    this.selectedTime,
    this.forAssociatedPatient = false,
    this.associatedPatientId = '',
    this.paymentReference = '',
    this.error,
    this.success,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<Appointment> appointments;
  final List<DoctorOption> doctors;
  final String? selectedDoctorId;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final bool forAssociatedPatient;
  final String associatedPatientId;
  final String paymentReference;
  final String? error;
  final String? success;

  PatientAppointmentsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<Appointment>? appointments,
    List<DoctorOption>? doctors,
    String? selectedDoctorId,
    bool clearSelectedDoctorId = false,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
    TimeOfDay? selectedTime,
    bool clearSelectedTime = false,
    bool? forAssociatedPatient,
    String? associatedPatientId,
    String? paymentReference,
    String? error,
    bool clearError = false,
    String? success,
    bool clearSuccess = false,
  }) {
    return PatientAppointmentsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      appointments: appointments ?? this.appointments,
      doctors: doctors ?? this.doctors,
      selectedDoctorId:
          clearSelectedDoctorId
              ? null
              : (selectedDoctorId ?? this.selectedDoctorId),
      selectedDate:
          clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
      selectedTime:
          clearSelectedTime ? null : (selectedTime ?? this.selectedTime),
      forAssociatedPatient: forAssociatedPatient ?? this.forAssociatedPatient,
      associatedPatientId: associatedPatientId ?? this.associatedPatientId,
      paymentReference: paymentReference ?? this.paymentReference,
      error: clearError ? null : (error ?? this.error),
      success: clearSuccess ? null : (success ?? this.success),
    );
  }
}

class PatientAppointmentsController extends Notifier<PatientAppointmentsState> {
  late final AppointmentsRepository _repository;

  @override
  PatientAppointmentsState build() {
    _repository = ref.watch(appointmentsRepositoryProvider);
    Future<void>.microtask(loadInitialData);
    return const PatientAppointmentsState();
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    final auth = ref.read(authControllerProvider).session;
    if (auth == null) {
      state = state.copyWith(isLoading: false, error: 'Sesión no disponible');
      return;
    }

    try {
      final results = await Future.wait([
        _repository.fetchAppointments(patientId: auth.profileId),
        _repository.fetchDoctors(),
      ]);

      state = state.copyWith(
        isLoading: false,
        appointments: results[0] as List<Appointment>,
        doctors: results[1] as List<DoctorOption>,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _repository.resolveErrorMessage(error),
      );
    }
  }

  void setDoctor(String? id) {
    state = state.copyWith(selectedDoctorId: id, clearError: true, clearSuccess: true);
  }

  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date, clearError: true, clearSuccess: true);
  }

  void setTime(TimeOfDay time) {
    state = state.copyWith(selectedTime: time, clearError: true, clearSuccess: true);
  }

  void setForAssociatedPatient(bool value) {
    state = state.copyWith(
      forAssociatedPatient: value,
      associatedPatientId: value ? state.associatedPatientId : '',
      clearError: true,
      clearSuccess: true,
    );
  }

  void setAssociatedPatientId(String value) {
    state = state.copyWith(associatedPatientId: value, clearError: true, clearSuccess: true);
  }

  void setPaymentReference(String value) {
    state = state.copyWith(paymentReference: value, clearError: true, clearSuccess: true);
  }

  Future<bool> bookAppointment() async {
    final auth = ref.read(authControllerProvider).session;
    if (auth == null) {
      state = state.copyWith(error: 'Sesión no disponible');
      return false;
    }

    if (state.selectedDoctorId == null ||
        state.selectedDate == null ||
        state.selectedTime == null) {
      state = state.copyWith(error: 'Completa doctor, fecha y hora');
      return false;
    }

    final patientId =
        state.forAssociatedPatient
            ? state.associatedPatientId.trim()
            : auth.profileId;

    if (patientId.isEmpty) {
      state = state.copyWith(error: 'Indica el ID del paciente asociado');
      return false;
    }

    final scheduledAt = DateTime(
      state.selectedDate!.year,
      state.selectedDate!.month,
      state.selectedDate!.day,
      state.selectedTime!.hour,
      state.selectedTime!.minute,
    );

    state = state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true);
    try {
      await _repository.createAppointment(
        patientId: patientId,
        doctorId: state.selectedDoctorId!,
        scheduledAt: scheduledAt,
        paymentReference: state.paymentReference.trim().isEmpty
            ? null
            : state.paymentReference.trim(),
      );

      final updated = await _repository.fetchAppointments(patientId: auth.profileId);
      state = state.copyWith(
        isSubmitting: false,
        appointments: updated,
        clearSelectedDate: true,
        clearSelectedTime: true,
        clearSelectedDoctorId: true,
        paymentReference: '',
        associatedPatientId: '',
        forAssociatedPatient: false,
        success: 'Cita agendada correctamente',
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: _repository.resolveErrorMessage(error),
      );
      return false;
    }
  }
}
