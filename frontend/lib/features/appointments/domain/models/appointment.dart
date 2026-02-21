class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.status,
    required this.scheduledAt,
    this.patientName,
    this.doctorName,
    this.diagnosis,
    this.prescription,
    this.paymentReference,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final String status;
  final DateTime scheduledAt;
  final String? patientName;
  final String? doctorName;
  final String? diagnosis;
  final String? prescription;
  final String? paymentReference;

  bool get isDone => status.toLowerCase() == 'completed';

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final rawDate =
        json['scheduled_at'] ??
        json['scheduledAt'] ??
        json['date_time'] ??
        json['date'];

    final date =
        rawDate is String
            ? DateTime.tryParse(rawDate)
            : (rawDate is DateTime ? rawDate : null);

    return Appointment(
      id: _asString(json['id']),
      patientId: _asString(
        json['patient_id'] ?? json['patientId'] ?? json['patient']?['id'],
      ),
      doctorId: _asString(
        json['doctor_id'] ?? json['doctorId'] ?? json['doctor']?['id'],
      ),
      status: _asString(json['status'], fallback: 'pending'),
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
    );
  }
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
  const PatientOption({
    required this.id,
    required this.name,
    this.phone,
  });

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

String? _nullableString(dynamic value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}
