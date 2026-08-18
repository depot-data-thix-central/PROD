// lib/presentation/thix_sante/patient/models/appointment_model.dart
class AppointmentModel {
  final String? id;
  final String patientId;
  final String doctorId;
  final DateTime dateRdv;
  final String type;
  final String motif;
  final String? creneau;
  final String statut;
  final int? prix;
  final int? dureeMinutes;
  final String? pjPath;
  final DateTime? createdAt;
  final Map<String,dynamic>? doctor;

  const AppointmentModel({
    this.id,
    required this.patientId,
    required this.doctorId,
    required this.dateRdv,
    required this.type,
    required this.motif,
    this.creneau,
    this.statut = 'demande',
    this.prix,
    this.dureeMinutes,
    this.pjPath,
    this.createdAt,
    this.doctor,
  });

  factory AppointmentModel.fromJson(Map<String,dynamic> json){
    return AppointmentModel(
      id: json['id']?.toString(),
      patientId: json['patient_id'].toString(),
      doctorId: json['doctor_id'].toString(),
      dateRdv: DateTime.parse(json['date_rdv'].toString()),
      type: json['type']?.toString()??'Cabinet',
      motif: json['motif']?.toString()??'',
      creneau: json['creneau']?.toString(),
      statut: json['statut']?.toString()??'demande',
      prix: json['prix'] is int? json['prix'] : int.tryParse(json['prix']?.toString()??''),
      dureeMinutes: json['duree_minutes'] is int? json['duree_minutes'] : int.tryParse(json['duree_minutes']?.toString()??''),
      pjPath: json['pj_path']?.toString(),
      createdAt: json['created_at']!=null? DateTime.tryParse(json['created_at'].toString()) : null,
      doctor: json['doctor'] is Map? Map<String,dynamic>.from(json['doctor']) : json['doctors'] is Map? Map<String,dynamic>.from(json['doctors']) : null,
    );
  }

  Map<String,dynamic> toJson()=> {
    if(id!=null) 'id': id,
    'patient_id': patientId,
    'doctor_id': doctorId,
    'date_rdv': dateRdv.toUtc().toIso8601String(),
    'type': type,
    'motif': motif,
    if(creneau!=null) 'creneau': creneau,
    'statut': statut,
    if(prix!=null) 'prix': prix,
    if(dureeMinutes!=null) 'duree_minutes': dureeMinutes,
    if(pjPath!=null) 'pj_path': pjPath,
  };
}
