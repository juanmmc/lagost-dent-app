import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../core/network/attachments_remote_data_source.dart';
import '../../data/appointments_repository.dart';
import '../../domain/models/appointment.dart';

final patientAppointmentsControllerProvider =
    NotifierProvider<PatientAppointmentsController, PatientAppointmentsState>(
      PatientAppointmentsController.new,
    );

class PatientAppointmentsState {
  const PatientAppointmentsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.isLoadingAvailability = false,
    this.isUploadingReceipt = false,
    this.appointments = const [],
    this.doctors = const [],
    this.associatedPatients = const [],
    this.availableSlots = const [],
    this.selectedDoctorId,
    this.selectedDate,
    this.selectedTime,
    this.forAssociatedPatient = false,
    this.associatedPatientId = '',
    this.paymentReference = '',
    this.paymentReceiptAttachmentId,
    this.paymentReceiptPath,
    this.paymentReceiptFileName,
    this.error,
    this.success,
  });

  final bool isLoading;
  final bool isSubmitting;
  final bool isLoadingAvailability;
  final bool isUploadingReceipt;
  final List<Appointment> appointments;
  final List<DoctorOption> doctors;
  final List<PatientOption> associatedPatients;
  final List<TimeOfDay> availableSlots;
  final String? selectedDoctorId;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final bool forAssociatedPatient;
  final String associatedPatientId;
  final String paymentReference;
  final String? paymentReceiptAttachmentId;
  final String? paymentReceiptPath;
  final String? paymentReceiptFileName;
  final String? error;
  final String? success;

  PatientAppointmentsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    bool? isLoadingAvailability,
    bool? isUploadingReceipt,
    List<Appointment>? appointments,
    List<DoctorOption>? doctors,
    List<PatientOption>? associatedPatients,
    List<TimeOfDay>? availableSlots,
    String? selectedDoctorId,
    bool clearSelectedDoctorId = false,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
    TimeOfDay? selectedTime,
    bool clearSelectedTime = false,
    bool? forAssociatedPatient,
    String? associatedPatientId,
    String? paymentReference,
    String? paymentReceiptAttachmentId,
    bool clearPaymentReceiptAttachmentId = false,
    String? paymentReceiptPath,
    bool clearPaymentReceiptPath = false,
    String? paymentReceiptFileName,
    bool clearPaymentReceiptFileName = false,
    String? error,
    bool clearError = false,
    String? success,
    bool clearSuccess = false,
  }) {
    return PatientAppointmentsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoadingAvailability:
          isLoadingAvailability ?? this.isLoadingAvailability,
      isUploadingReceipt: isUploadingReceipt ?? this.isUploadingReceipt,
      appointments: appointments ?? this.appointments,
      doctors: doctors ?? this.doctors,
      associatedPatients: associatedPatients ?? this.associatedPatients,
      availableSlots: availableSlots ?? this.availableSlots,
      selectedDoctorId: clearSelectedDoctorId
          ? null
          : (selectedDoctorId ?? this.selectedDoctorId),
      selectedDate: clearSelectedDate
          ? null
          : (selectedDate ?? this.selectedDate),
      selectedTime: clearSelectedTime
          ? null
          : (selectedTime ?? this.selectedTime),
      forAssociatedPatient: forAssociatedPatient ?? this.forAssociatedPatient,
      associatedPatientId: associatedPatientId ?? this.associatedPatientId,
      paymentReference: paymentReference ?? this.paymentReference,
      paymentReceiptAttachmentId: clearPaymentReceiptAttachmentId
          ? null
          : (paymentReceiptAttachmentId ?? this.paymentReceiptAttachmentId),
      paymentReceiptPath: clearPaymentReceiptPath
          ? null
          : (paymentReceiptPath ?? this.paymentReceiptPath),
      paymentReceiptFileName: clearPaymentReceiptFileName
          ? null
          : (paymentReceiptFileName ?? this.paymentReceiptFileName),
      error: clearError ? null : (error ?? this.error),
      success: clearSuccess ? null : (success ?? this.success),
    );
  }
}

class PatientAppointmentsController extends Notifier<PatientAppointmentsState> {
  static const Set<String> _allowedReceiptExtensions = {
    'png',
    'jpg',
    'jpeg',
    'webp',
    'pdf',
  };

  late final AppointmentsRepository _repository;
  late final AttachmentsRemoteDataSource _attachments;

  @override
  PatientAppointmentsState build() {
    _repository = ref.watch(appointmentsRepositoryProvider);
    _attachments = ref.watch(attachmentsRemoteDataSourceProvider);
    Future<void>.microtask(loadInitialData);
    return const PatientAppointmentsState();
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    final auth = ref.read(authControllerProvider).session;
    if (auth == null) {
      state = state.copyWith(isLoading: false, error: 'Sesión no disponible');
      return;
    }

    try {
      final results = await Future.wait([
        _repository.fetchAppointmentsForPatient(
          patientId: auth.profileId,
          order: 'desc',
        ),
        _repository.fetchDoctors(),
        _repository.fetchAssociatesForPatient(patientId: auth.profileId),
      ]);

      state = state.copyWith(
        isLoading: false,
        appointments: results[0] as List<Appointment>,
        doctors: results[1] as List<DoctorOption>,
        associatedPatients: results[2] as List<PatientOption>,
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
    state = state.copyWith(
      selectedDoctorId: id,
      clearError: true,
      clearSuccess: true,
    );
  }

  Future<void> setDate(DateTime date) async {
    state = state.copyWith(
      selectedDate: date,
      clearSelectedTime: true,
      availableSlots: const [],
      isLoadingAvailability: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final rawSlots = await _repository.fetchAvailability(date: date);
      final slots =
          rawSlots
              .map((slot) => slot.toLocal())
              .map((slot) => TimeOfDay(hour: slot.hour, minute: slot.minute))
              .toSet()
              .toList()
            ..sort(
              (a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute),
            );

      state = state.copyWith(
        availableSlots: slots,
        isLoadingAvailability: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingAvailability: false,
        availableSlots: const [],
        error: _repository.resolveErrorMessage(error),
      );
    }
  }

  void setTime(TimeOfDay time) {
    state = state.copyWith(
      selectedTime: time,
      clearError: true,
      clearSuccess: true,
    );
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
    state = state.copyWith(
      associatedPatientId: value,
      clearError: true,
      clearSuccess: true,
    );
  }

  void setPaymentReference(String value) {
    state = state.copyWith(
      paymentReference: value,
      clearError: true,
      clearSuccess: true,
    );
  }

  Future<void> uploadPaymentReceipt(PlatformFile file) async {
    const maxBytes = 5 * 1024 * 1024;
    final extension = (file.extension ?? '').toLowerCase();
    if (!_allowedReceiptExtensions.contains(extension)) {
      state = state.copyWith(
        error: 'Formato inválido. Solo se permite: PNG, JPG, WEBP o PDF',
      );
      return;
    }

    if (file.size > maxBytes) {
      state = state.copyWith(error: 'El archivo excede el límite de 5MB');
      return;
    }

    state = state.copyWith(
      isUploadingReceipt: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final uploaded = await _attachments.uploadAttachment(
        file: file,
        type: 'payment_receipt',
      );

      state = state.copyWith(
        isUploadingReceipt: false,
        paymentReference: uploaded.id,
        paymentReceiptAttachmentId: uploaded.id,
        paymentReceiptPath: uploaded.path,
        paymentReceiptFileName: file.name,
        success: 'Comprobante adjuntado correctamente',
      );
    } catch (error) {
      state = state.copyWith(
        isUploadingReceipt: false,
        error: _attachments.resolveErrorMessage(error),
      );
    }
  }

  void clearPaymentReceipt() {
    state = state.copyWith(
      paymentReference: '',
      clearPaymentReceiptAttachmentId: true,
      clearPaymentReceiptPath: true,
      clearPaymentReceiptFileName: true,
      clearError: true,
      clearSuccess: true,
    );
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

    if (state.availableSlots.isEmpty) {
      state = state.copyWith(
        error: 'No hay horas disponibles para la fecha seleccionada',
      );
      return false;
    }

    if (!state.availableSlots.contains(state.selectedTime)) {
      state = state.copyWith(
        error: 'Selecciona una hora disponible para la fecha elegida',
      );
      return false;
    }

    final depositSlipAttachmentId =
        state.paymentReceiptAttachmentId?.trim() ?? '';
    if (depositSlipAttachmentId.isEmpty) {
      state = state.copyWith(
        error: 'Debes adjuntar el comprobante de pago para agendar la cita',
      );
      return false;
    }

    final patientId = state.forAssociatedPatient
        ? state.associatedPatientId.trim()
        : auth.profileId;

    if (patientId.isEmpty) {
      state = state.copyWith(error: 'Selecciona un paciente asociado');
      return false;
    }

    final scheduledAt = DateTime(
      state.selectedDate!.year,
      state.selectedDate!.month,
      state.selectedDate!.day,
      state.selectedTime!.hour,
      state.selectedTime!.minute,
    );

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await _repository.createAppointment(
        patientId: patientId,
        doctorId: state.selectedDoctorId!,
        scheduledAt: scheduledAt,
        depositSlipAttachmentId: depositSlipAttachmentId,
        byTitular: state.forAssociatedPatient,
      );

      final updated = await _repository.fetchAppointmentsForPatient(
        patientId: auth.profileId,
        order: 'desc',
      );
      state = state.copyWith(
        isSubmitting: false,
        appointments: updated,
        clearSelectedDate: true,
        clearSelectedTime: true,
        clearSelectedDoctorId: true,
        paymentReference: '',
        clearPaymentReceiptAttachmentId: true,
        clearPaymentReceiptPath: true,
        clearPaymentReceiptFileName: true,
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
