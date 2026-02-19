enum UserRole { patient, doctor }

extension UserRoleX on UserRole {
  bool get isPatient => this == UserRole.patient;
  bool get isDoctor => this == UserRole.doctor;
}
