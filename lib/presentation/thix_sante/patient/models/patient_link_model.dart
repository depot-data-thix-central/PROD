// lib/presentation/thix_sante/patient/models/patient_link_model.dart
class DoctorProfileLite {
  final String fullName;
  final String? speciality;
  final String? avatarUrl;
  final String thixId;
  DoctorProfileLite({required this.fullName, this.speciality, this.avatarUrl, required this.thixId});
  String get displaySpeciality => speciality??'Généraliste';
  bool get hasAvatar => avatarUrl!=null && avatarUrl!.isNotEmpty;
  String get initials => fullName.split(' ').map((e)=>e.isNotEmpty?e[0]:'').take(2).join().toUpperCase();
}

class PatientLinkModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorThixId;
  final bool isActive;
  final DoctorProfileLite? doctorProfile;
  PatientLinkModel({required this.id, required this.patientId, required this.doctorId, required this.doctorThixId, required this.isActive, this.doctorProfile});
}
