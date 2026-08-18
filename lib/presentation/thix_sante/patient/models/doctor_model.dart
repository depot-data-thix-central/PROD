// lib/presentation/thix_sante/patient/models/doctor_model.dart
class DoctorModel {
  final String id; // = doctor_id
  final String thixId;
  final String fullName;
  final String? speciality;
  final String? avatarUrl;
  final String? adresse;
  final String? telephone;
  final double? rating;
  final bool isOnline;
  final String? userId;

  const DoctorModel({
    required this.id,
    required this.thixId,
    required this.fullName,
    this.speciality,
    this.avatarUrl,
    this.adresse,
    this.telephone,
    this.rating,
    this.isOnline = true,
    this.userId,
  });

  String get initials => fullName.isNotEmpty? fullName.split(' ').map((e)=>e.isNotEmpty?e[0]:'').take(2).join().toUpperCase() : 'D';
  String get displaySpeciality => speciality?? 'Généraliste';
  bool get hasAvatar => avatarUrl!= null && avatarUrl!.isNotEmpty;

  factory DoctorModel.fromLinkAndProfile(Map<String,dynamic> link, Map<String,dynamic> profile){
    return DoctorModel(
      id: link['doctor_id'].toString(),
      thixId: profile['thix_id']?.toString()?? link['doctor_id'].toString().substring(0,8).toUpperCase(),
      fullName: profile['full_name']?.toString()?? 'Dr. Inconnu',
      speciality: profile['specialite']?.toString()?? profile['speciality']?.toString(),
      avatarUrl: profile['avatar_url']?.toString(),
      adresse: profile['adresse']?.toString(),
      telephone: profile['telephone']?.toString(),
      rating: profile['rating']!= null? double.tryParse(profile['rating'].toString()) : 4.8,
      isOnline: true,
      userId: profile['id']?.toString(),
    );
  }
}

class PatientLinkModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorThixId;
  final bool isActive;
  final DoctorModel? doctorProfile;
  PatientLinkModel({required this.id, required this.patientId, required this.doctorId, required this.doctorThixId, required this.isActive, this.doctorProfile});
  bool get isLinked => isActive;
}
