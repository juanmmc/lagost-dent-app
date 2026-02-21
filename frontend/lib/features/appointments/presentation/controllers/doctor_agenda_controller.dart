import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/appointments_repository.dart';
import '../../domain/models/appointment.dart';

final doctorAgendaControllerProvider =
    NotifierProvider<DoctorAgendaController, DoctorAgendaState>(
      DoctorAgendaController.new,
    );

class DoctorAgendaState {
  const DoctorAgendaState({
    this.isLoading = false,
    this.isActionLoading = false,
    this.agenda = const [],
    this.selectedDate,
    this.selectedStatus,
    this.patients = const [],
    this.searchQuery = '',
    this.error,
    this.success,
  });

  final bool isLoading;
  final bool isActionLoading;
  final List<Appointment> agenda;
  final DateTime? selectedDate;
  final String? selectedStatus;
  final List<PatientOption> patients;
  final String searchQuery;
  final String? error;
  final String? success;

  DoctorAgendaState copyWith({
    bool? isLoading,
    bool? isActionLoading,
    List<Appointment>? agenda,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
    String? selectedStatus,
    bool clearSelectedStatus = false,
    List<PatientOption>? patients,
    String? searchQuery,
    String? error,
    bool clearError = false,
    String? success,
    bool clearSuccess = false,
  }) {
    return DoctorAgendaState(
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      agenda: agenda ?? this.agenda,
      selectedDate:
          clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
      selectedStatus:
          clearSelectedStatus ? null : (selectedStatus ?? this.selectedStatus),
      patients: patients ?? this.patients,
      searchQuery: searchQuery ?? this.searchQuery,
      error: clearError ? null : (error ?? this.error),
      success: clearSuccess ? null : (success ?? this.success),
    );
  }
}

class DoctorAgendaController extends Notifier<DoctorAgendaState> {
  late final AppointmentsRepository _repository;

  @override
  DoctorAgendaState build() {
    _repository = ref.watch(appointmentsRepositoryProvider);
    Future<void>.microtask(loadAgenda);
    return const DoctorAgendaState();
  }

  Future<void> loadAgenda() async {
    final auth = ref.read(authControllerProvider).session;
    if (auth == null) {
      state = state.copyWith(error: 'Sesión no disponible');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final data = await _repository.fetchAppointments(
        doctorId: auth.profileId,
        date: _formatDate(state.selectedDate),
        status: state.selectedStatus,
      );
      state = state.copyWith(isLoading: false, agenda: data);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _repository.resolveErrorMessage(error),
      );
    }
  }

  void setDate(DateTime? date) {
    state = state.copyWith(selectedDate: date, clearError: true, clearSuccess: true);
    loadAgenda();
  }

  void setStatus(String? status) {
    state = state.copyWith(selectedStatus: status, clearError: true, clearSuccess: true);
    loadAgenda();
  }

  Future<void> updateStatus({
    required String appointmentId,
    required String status,
  }) async {
    state = state.copyWith(
      isActionLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await _repository.updateAppointmentStatus(
        appointmentId: appointmentId,
        status: status,
      );
      await loadAgenda();
      state = state.copyWith(
        isActionLoading: false,
        success: 'Estado actualizado',
      );
    } catch (error) {
      state = state.copyWith(
        isActionLoading: false,
        error: _repository.resolveErrorMessage(error),
      );
    }
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value, clearError: true, clearSuccess: true);
  }

  Future<void> searchPatients() async {
    final query = state.searchQuery.trim();
    if (query.isEmpty) {
      state = state.copyWith(patients: const []);
      return;
    }

    state = state.copyWith(isActionLoading: true, clearError: true, clearSuccess: true);
    try {
      final results = await _repository.searchPatientsByName(query);
      state = state.copyWith(isActionLoading: false, patients: results);
    } catch (error) {
      state = state.copyWith(
        isActionLoading: false,
        error: _repository.resolveErrorMessage(error),
      );
    }
  }

  Future<void> bookForPatient({
    required String patientId,
    required DateTime scheduledAt,
  }) async {
    final auth = ref.read(authControllerProvider).session;
    if (auth == null) {
      state = state.copyWith(error: 'Sesión no disponible');
      return;
    }

    state = state.copyWith(
      isActionLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _repository.createAppointment(
        patientId: patientId,
        doctorId: auth.profileId,
        scheduledAt: scheduledAt,
      );

      await loadAgenda();
      state = state.copyWith(
        isActionLoading: false,
        success: 'Cita creada para el paciente',
      );
    } catch (error) {
      state = state.copyWith(
        isActionLoading: false,
        error: _repository.resolveErrorMessage(error),
      );
    }
  }
}

String? _formatDate(DateTime? date) {
  if (date == null) return null;
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
