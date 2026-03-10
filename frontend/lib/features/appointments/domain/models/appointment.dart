class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.status,
    required this.statusDescriptor,
    required this.scheduledAt,
    this.statusValue,
    this.patientName,
    this.doctorName,
    this.diagnosis,
    this.prescription,
    this.paymentReference,
    this.depositSlipAttachmentId,
    this.depositSlipAttachmentPath,
    this.depositSlipAttachmentMime,
    this.recipeAttachmentId,
    this.recipeAttachmentPath,
    this.rejectionReason,
  });

  final String id;
  final String patientId;
  final String doctorId;
  // Valor canónico para UI: descriptor legible para humanos.
  final String status;
  final String statusDescriptor;
  final int? statusValue;
  final DateTime scheduledAt;
  final String? patientName;
  final String? doctorName;
  final String? diagnosis;
  final String? prescription;
  final String? paymentReference;
  final String? depositSlipAttachmentId;
  final String? depositSlipAttachmentPath;
  final String? depositSlipAttachmentMime;
  final String? recipeAttachmentId;
  final String? recipeAttachmentPath;
  final String? rejectionReason;

  static const int pendingConfirmationStatusValue = 1;
  static const int confirmedStatusValue = 2;
  static const int attendedStatusValue = 3;
  static const int absentStatusValue = 4;
  static const int rejectedStatusValue = 5;

  bool get isPendingConfirmation =>
      statusValue == pendingConfirmationStatusValue ||
      _normalizedStatus == 'por confirmar' ||
      _normalizedStatus == 'por_confirmar' ||
      _normalizedStatus == 'pending' ||
      _normalizedStatus == 'pending_confirmation';

  bool get isConfirmed {
    if (statusValue == confirmedStatusValue) return true;
    if (statusValue != null) return false;
    if (isPendingConfirmation) return false;
    return _normalizedStatus == 'confirmada' ||
        _normalizedStatus == 'confirmado' ||
        _normalizedStatus == 'confirmed' ||
        _normalizedStatus == 'confirm';
  }

  bool get isDone =>
      statusValue == attendedStatusValue ||
      _normalizedStatus == 'completed' ||
      _normalizedStatus == 'atendida' ||
      _normalizedStatus == 'atendido';

  bool get isCancelled =>
      statusValue == rejectedStatusValue ||
      _normalizedStatus == 'cancelled' ||
      _normalizedStatus == 'cancelada' ||
      _normalizedStatus == 'cancelado' ||
      _normalizedStatus == 'rejected' ||
      _normalizedStatus == 'rechazada' ||
      _normalizedStatus == 'rechazado';

  bool get isAbsent =>
      statusValue == absentStatusValue ||
      _normalizedStatus == 'absent' ||
      _normalizedStatus == 'inasistencia' ||
      _normalizedStatus == 'ausente';

  String get _normalizedStatus => _normalizeStatus(statusDescriptor);

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final rawDate =
        json['scheduled_at'] ??
        json['scheduledAt'] ??
        json['date_time'] ??
        json['date'];

    final date = rawDate is String
        ? DateTime.tryParse(rawDate)
        : (rawDate is DateTime ? rawDate : null);

    final statusInfo = _parseStatus(json['status']);

    return Appointment(
      id: _asString(json['id']),
      patientId: _asString(
        json['patient_id'] ?? json['patientId'] ?? json['patient']?['id'],
      ),
      doctorId: _asString(
        json['doctor_id'] ?? json['doctorId'] ?? json['doctor']?['id'],
      ),
      status: statusInfo.descriptor,
      statusDescriptor: statusInfo.descriptor,
      statusValue: statusInfo.value,
      scheduledAt: date ?? DateTime.now(),
      patientName: _nullableString(
        json['patient_name'] ??
            json['patientName'] ??
            json['patient']?['name'] ??
            json['patient']?['person']?['name'],
      ),
      doctorName: _nullableString(
        json['doctor_name'] ??
            json['doctorName'] ??
            json['doctor']?['name'] ??
            json['doctor']?['person']?['name'],
      ),
      diagnosis: _nullableString(json['diagnosis']),
      prescription: _nullableString(json['prescription']),
      paymentReference: _nullableString(
        json['payment_reference'] ?? json['paymentReference'],
      ),
      depositSlipAttachmentId: _nullableString(
        json['deposit_slip_attachment_id'] ?? json['depositSlipAttachmentId'],
      ),
      depositSlipAttachmentPath: _nullableString(
        json['deposit_slip_attachment_path'] ??
            json['depositSlipAttachmentPath'] ??
            json['deposit_slip_attachment']?['path'],
      ),
      depositSlipAttachmentMime: _nullableString(
        json['deposit_slip_attachment_mime'] ??
            json['depositSlipAttachmentMime'] ??
            json['deposit_slip_attachment']?['mime'],
      ),
      recipeAttachmentId: _nullableString(
        json['recipe_attachment_id'] ?? json['recipeAttachmentId'],
      ),
      recipeAttachmentPath: _nullableString(
        json['recipe_attachment_path'] ??
            json['recipeAttachmentPath'] ??
            json['recipe_attachment']?['path'],
      ),
      rejectionReason: _nullableString(
        json['rejection_reason'] ?? json['rejectionReason'],
      ),
    );
  }
}

class AppointmentStatusInfo {
  const AppointmentStatusInfo({required this.descriptor, this.value});

  final String descriptor;
  final int? value;
}

AppointmentStatusInfo _parseStatus(dynamic rawStatus) {
  if (rawStatus is Map<String, dynamic>) {
    final descriptor = _asString(
      rawStatus['descriptor'] ?? rawStatus['label'] ?? rawStatus['name'],
      fallback: 'pending',
    );

    final value = _asInt(rawStatus['value'] ?? rawStatus['id']);
    return AppointmentStatusInfo(descriptor: descriptor, value: value);
  }

  if (rawStatus is num) {
    return AppointmentStatusInfo(
      descriptor: rawStatus.toString(),
      value: rawStatus.toInt(),
    );
  }

  return AppointmentStatusInfo(
    descriptor: _asString(rawStatus, fallback: 'pending'),
    value: null,
  );
}

class DoctorOption {
  const DoctorOption({
    required this.id,
    required this.name,
    this.specialty,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? specialty;
  final bool isActive;

  String get label {
    if (specialty == null || specialty!.trim().isEmpty) return name;
    return '$name · $specialty';
  }

  factory DoctorOption.fromJson(Map<String, dynamic> json) {
    return DoctorOption(
      id: _asString(json['id']),
      name: _asString(
        json['name'] ?? json['person']?['name'] ?? json['full_name'],
      ),
      specialty: _nullableString(
        json['specialty'] ?? json['speciality'] ?? json['specialty_name'],
      ),
      isActive: (json['is_active'] ?? json['active'] ?? true) == true,
    );
  }
}

class PatientOption {
  const PatientOption({required this.id, required this.name, this.phone});

  final String id;
  final String name;
  final String? phone;

  factory PatientOption.fromJson(Map<String, dynamic> json) {
    return PatientOption(
      id: _asString(json['id'] ?? json['patient_id']),
      name: _asString(
        json['name'] ?? json['person']?['name'] ?? json['full_name'],
      ),
      phone: _nullableString(json['phone'] ?? json['person']?['phone']),
    );
  }
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String? _nullableString(dynamic value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}

String _normalizeStatus(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}
