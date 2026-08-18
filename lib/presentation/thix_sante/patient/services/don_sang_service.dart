// lib/presentation/thix_sante/patient/services/don_sang_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class DonSangService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<List<Map<String,dynamic>>> getCentresWithStock(String groupe) async {
    final res = await _db.from('blood_centres').select().order('nom');
    return List<Map<String,dynamic>>.from(res);
  }

  Future<List<Map<String,dynamic>>> getAlertes() async {
    return List<Map<String,dynamic>>.from(await _db.from('blood_alerts').select('*, blood_centres(nom)').eq('is_active', true).order('created_at', ascending: false).limit(5));
  }

  Future<Map<String,dynamic>?> getEligibilite() async {
    final last = await _db.from('blood_donations').select('date_prochain_don, date_don').eq('donor_id', _uid).order('date_don', ascending: false).limit(1).maybeSingle();
    if(last==null) return {'eligible': true, 'next_date': null};
    final next = DateTime.parse(last['date_prochain_don'].toString());
    final eligible = DateTime.now().isAfter(next);
    return {'eligible': eligible, 'next_date': next, 'last_don': DateTime.parse(last['date_don'].toString())};
  }

  Future<List<Map<String,dynamic>>> getHistorique() async {
    return List<Map<String,dynamic>>.from(await _db.from('blood_donations').select('*, blood_centres(nom)').eq('donor_id', _uid).order('date_don', ascending: false));
  }

  Future<void> prendreRdvDon({required String groupe, required String centreId, required DateTime date, required Map<String,dynamic> questionnaire}) async {
    // Vérif éligibilité
    final elig = await getEligibilite();
    if(elig!=null && elig['eligible']==false) throw Exception('Non éligible avant ${elig['next_date']}');
    // Vérif questionnaire
    if(questionnaire['poids']!=null && (questionnaire['poids'] as num) < 50) throw Exception('Poids minimum 50kg');
    if(questionnaire['hemoglobine']!=null && (questionnaire['hemoglobine'] as num) < 12) throw Exception('Hémoglobine trop basse');

    await _db.from('blood_donations').insert({
      'donor_id': _uid,
      'centre_id': centreId,
      'groupe_sanguin': groupe,
      'date_don': date.toIso8601String(),
      'statut': 'prevu',
      'poids_kg': questionnaire['poids'],
      'hemoglobine': questionnaire['hemoglobine'],
      'tension': questionnaire['tension'],
    });
  }

  Future<void> demanderSang({required String groupe, required String urgence, required int poches, required String tel, String? raison, String? centreId}) async {
    await _db.from('blood_requests').insert({
      'requester_id': _uid,
      'groupe_recherche': groupe,
      'urgence': urgence,
      'quantite_poche': poches,
      'telephone_contact': tel,
      'raison': raison,
      'centre_id': centreId,
    });
  }

  int getStockForGroupe(Map<String,dynamic> centre, String groupe){
    switch(groupe){ case 'O+': return centre['stock_o_pos']??0; case 'O-': return centre['stock_o_neg']??0; case 'A+': return centre['stock_a_pos']??0; case 'A-': return centre['stock_a_neg']??0; case 'B+': return centre['stock_b_pos']??0; case 'B-': return centre['stock_b_neg']??0; case 'AB+': return centre['stock_ab_pos']??0; case 'AB-': return centre['stock_ab_neg']??0; default: return 0; }
  }
}
