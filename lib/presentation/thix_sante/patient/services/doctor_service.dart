// lib/presentation/thix_sante/patient/services/doctor_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/doctor_model.dart';

class DoctorService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  // Liste médecins liés - SANS RELATION
  Future<List<DoctorModel>> getMyLinkedDoctors() async {
    final links = await _db.from('health_links').select('id, doctor_id, patient_id, is_active').eq('patient_id', _uid).eq('is_active', true);
    if (links.isEmpty) return [];
    final ids = (links as List).map((e)=>e['doctor_id'].toString()).toList();

    // Essaie doctors, sinon profiles
    List<Map<String,dynamic>> profiles = [];
    try {
      final res = await _db.from('doctors').select('id, full_name, specialite, avatar_url, adresse, telephone, thix_id, rating, user_id').inFilter('id', ids);
      profiles = List<Map<String,dynamic>>.from(res);
    } catch (_) {
      final res = await _db.from('profiles').select('id, full_name, avatar_url, thix_id').inFilter('id', ids);
      profiles = List<Map<String,dynamic>>.from(res);
    }

    final map = {for(var p in profiles) p['id'].toString(): p};
    return (links as List).map((link){
      final pid = link['doctor_id'].toString();
      final prof = map[pid]?? {'id': pid, 'full_name': 'Dr Inconnu'};
      return DoctorModel.fromLinkAndProfile(link, prof);
    }).toList();
  }

  // Recherche nouveau médecin par nom / specialité / thix_id
  Future<List<DoctorModel>> searchDoctors({String query = '', String speciality = 'Tous'}) async {
    var q = _db.from('doctors').select('id, full_name, specialite, avatar_url, adresse, thix_id, rating').eq('is_active', true).limit(20);
    // Si table doctors n'existe pas, fallback profiles role=doctor
    try {
      final res = await q;
      var list = List<Map<String,dynamic>>.from(res);
      if(query.isNotEmpty){
        final low = query.toLowerCase();
        list = list.where((d)=> (d['full_name']?.toString().toLowerCase().contains(low)??false) || (d['thix_id']?.toString().toLowerCase().contains(low)??false)).toList();
      }
      if(speciality!='Tous'){
        list = list.where((d)=> (d['specialite']?.toString().toLowerCase().contains(speciality.toLowerCase())??false)).toList();
      }
      return list.map((d)=> DoctorModel(id: d['id'].toString(), thixId: d['thix_id']?.toString()??d['id'].toString().substring(0,8).toUpperCase(), fullName: d['full_name']?.toString()??'Dr', speciality: d['specialite']?.toString(), avatarUrl: d['avatar_url']?.toString(), adresse: d['adresse']?.toString(), rating: d['rating']!=null? double.tryParse(d['rating'].toString()):4.8)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> linkByThixId(String thixId) async {
    // Cherche doctor par thix_id
    final doc = await _db.from('doctors').select('id').eq('thix_id', thixId.toUpperCase().trim()).maybeSingle();
    if(doc==null) throw Exception('THIX ID introuvable');
    await _db.from('health_links').upsert({'patient_id': _uid, 'doctor_id': doc['id'], 'is_active': true}, onConflict: 'patient_id,doctor_id');
  }

  Stream<List<DoctorModel>> watchMyDoctors() {
    return _db.from('health_links').stream(primaryKey:['id']).eq('patient_id', _uid).map((rows){
      // stream ne peut pas faire 2 requêtes, on retourne vide et le provider refetch
      return <DoctorModel>[];
    });
  }
}
