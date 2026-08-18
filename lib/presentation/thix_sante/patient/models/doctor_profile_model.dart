// lib/presentation/thix_sante/patient/models/doctor_profile_model.dart
class DoctorProfileModel {
  final String uid; // doctors.id
  final String thixId;
  final String fullName;
  final String speciality;
  final String? avatarUrl;
  final bool isVerified;
  final String? adresse;
  final String? telephone;

  const DoctorProfileModel({
    required this.uid,
    required this.thixId,
    required this.fullName,
    this.speciality = 'Généraliste',
    this.avatarUrl,
    this.isVerified = true,
    this.adresse,
    this.telephone,
  });

  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
  String get initials => fullName.split(' ').map((e)=>e.isNotEmpty?e[0]:'').take(2).join().toUpperCase();
  String get displaySpeciality => speciality;

  factory DoctorProfileModel.fromJson(Map<String,dynamic> json){
    return DoctorProfileModel(
      uid: json['id'].toString(),
      thixId: (json['thix_id']??json['id'].toString()).toString(),
      fullName: json['full_name']?.toString()?? 'Dr Inconnu',
      speciality: json['specialite']?.toString()?? json['speciality']?.toString()?? 'Généraliste',
      avatarUrl: json['avatar_url']?.toString(),
      isVerified: true,
      adresse: json['adresse']?.toString(),
      telephone: json['telephone']?.toString(),
    );
  }
}
