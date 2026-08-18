// lib/presentation/thix_sante/patient/services/patient_link_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/doctor_profile_model.dart';
import '../models/patient_link_model.dart';
import '../../core/thix_id_validator.dart';

class PatientLinkService {
  final _db = Supabase.instance.client;
  String get _uid {
    final u = _db.auth.currentUser;
    if(u==null) throw Exception('Non authentifié');
    return u.id;
  }

  Future<DoctorProfileModel> findDoctorByThixId(String thixId) async {
    final clean = ThixIdValidator.clean(thixId);
    var data = await _db.from('doctors').select().eq('thix_id', clean).maybeSingle();
    if(data==null){
      try{ data = await _db.from('doctors').select().eq('id', clean).maybeSingle(); }catch(_){}
    }
    if(data==null) throw Exception('Médecin introuvable avec THIX ID $clean');
    return DoctorProfileModel.fromJson(data);
  }

  Future<void> requestDoctorByThixId({required String doctorThixId}) async {
    final doctor = await findDoctorByThixId(doctorThixId);
    final existing = await _db.from('health_links').select('id, is_active').eq('patient_id', _uid).eq('doctor_id', doctor.uid).maybeSingle();
    if(existing!=null){
      if(existing['is_active']==true) throw Exception('Déjà lié au Dr ${doctor.fullName}');
      await _db.from('health_links').update({'is_active': true}).eq('id', existing['id']);
      return;
    }
    await _db.from('health_links').insert({'patient_id': _uid, 'doctor_id': doctor.uid, 'is_active': true});
  }

  // ===== METHODES QUI MANQUAIENT ET CASSAIENT LE BUILD =====

  Future<List<PatientLinkModel>> getActiveDoctors() async {
    final links = await _db.from('health_links').select('id, patient_id, doctor_id, is_active').eq('patient_id', _uid).eq('is_active', true);
    if((links as List).isEmpty) return [];
    final ids = links.map((e)=>e['doctor_id'].toString()).toList();
    final docs = await _db.from('doctors').select('id, thix_id, full_name, specialite, avatar_url').inFilter('id', ids);
    final map = {for(var d in docs) d['id'].toString(): d};
    return links.map((l){
      final d = map[l['doctor_id'].toString()];
      return PatientLinkModel(
        id: l['id'].toString(),
        patientId: l['patient_id'].toString(),
        doctorId: l['doctor_id'].toString(),
        doctorThixId: d?['thix_id']?.toString()?? l['doctor_id'].toString(),
        isActive: l['is_active']==true,
        doctorProfile: d!=null? DoctorProfileLite(
          fullName: d['full_name']?.toString()??'Dr',
          speciality: d['specialite']?.toString(),
          avatarUrl: d['avatar_url']?.toString(),
          thixId: d['thix_id']?.toString()??'',
        ):null,
      );
    }).toList();
  }

  // Alias pour compat ancien code
  Future<List<PatientLinkModel>> getMyActiveDoctors() => getActiveDoctors();

  Stream<List<PatientLinkModel>> watchMyDoctors() async* {
    while(true){
      yield await getActiveDoctors();
      await Future.delayed(const Duration(seconds: 15));
    }
  }

  Future<List<DoctorProfileModel>> getMyLinkedDoctors() async {
    final links = await _db.from('health_links').select('doctor_id').eq('patient_id', _uid).eq('is_active', true);
    if((links as List).isEmpty) return [];
    final ids = links.map((e)=>e['doctor_id'].toString()).toList();
    final res = await _db.from('doctors').select().inFilter('id', ids);
    return (res as List).map((e)=>DoctorProfileModel.fromJson(e)).toList();
  }
}
