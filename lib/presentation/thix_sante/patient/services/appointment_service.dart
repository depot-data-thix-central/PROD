// lib/presentation/thix_sante/patient/services/appointment_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_model.dart';

class AppointmentService {
  final _db = Supabase.instance.client;
  String get _uid {
    final u = _db.auth.currentUser;
    if (u == null) throw Exception('Non authentifié');
    return u.id;
  }

  // FIX: 2 requêtes sans FK - plus de doctors!inner
  Future<List<Map<String, dynamic>>> getMyLinkedDoctors() async {
    // 1. Récupère les doctor_id liés
    final links = await _db
       .from('health_links')
       .select('doctor_id')
       .eq('patient_id', _uid)
       .eq('is_active', true);

    if (links.isEmpty) return [];

    final doctorIds = (links as List).map((e) => e['doctor_id'].toString()).toList();

    // 2. Récupère les infos doctors séparément
    // On essaie profiles d'abord, puis doctors si existe
    try {
      final doctors = await _db
         .from('doctors')
         .select('id, full_name, specialite, avatar_url, adresse, telephone')
         .inFilter('id', doctorIds);

      // Remap pour garder doctor_id + doctors
      return (doctors as List).map((d) {
        return {
          'doctor_id': d['id'],
          'doctors': d,
        };
      }).toList();
    } catch (_) {
      // Fallback: si table doctors n'existe pas, utilise profiles
      final profiles = await _db
         .from('profiles')
         .select('id, full_name, avatar_url')
         .inFilter('id', doctorIds);

      return (profiles as List).map((p) {
        return {
          'doctor_id': p['id'],
          'doctors': {
            'id': p['id'],
            'full_name': p['full_name']?? 'Docteur',
            'specialite': 'Généraliste',
            'avatar_url': p['avatar_url'],
          }
        };
      }).toList();
    }
  }

  Future<List<String>> getTakenSlots({required String doctorId, required DateTime date}) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final res = await _db
       .from('appointments')
       .select('creneau')
       .eq('doctor_id', doctorId)
       .gte('date_rdv', start.toIso8601String())
       .lt('date_rdv', end.toIso8601String())
       .neq('statut', 'annule');
    return (res as List).map((e) => e['creneau'].toString()).toList();
  }

  Future<List<AppointmentModel>> getMyAppointments() async {
    final res = await _db.from('appointments').select().eq('patient_id', _uid).order('date_rdv');
    return (res as List).map((e) => AppointmentModel.fromJson(e)).toList();
  }

  Future<AppointmentModel> createAppointment({
    required String doctorId,
    required DateTime date,
    required String creneau,
    required String type,
    required String motif,
  }) async {
    final h = int.parse(creneau.split(':')[0]);
    final m = int.parse(creneau.split(':')[1]);
    final dateRdv = DateTime(date.year, date.month, date.day, h, m).toUtc();

    final taken = await getTakenSlots(doctorId: doctorId, date: date);
    if (taken.contains(creneau)) throw Exception('Créneau $creneau déjà pris');

    final prix = type == 'Domicile'? 25000 : type == 'Téléconsultation'? 10000 : 15000;
    final duree = type == 'Domicile'? 60 : type == 'Téléconsultation'? 20 : 30;

    final inserted = await _db.from('appointments').insert({
      'patient_id': _uid,
      'doctor_id': doctorId,
      'date_rdv': dateRdv.toIso8601String(),
      'type': type,
      'motif': motif,
      'creneau': creneau,
      'statut': 'demande',
      'prix': prix,
      'duree_minutes': duree,
    }).select().single();

    return AppointmentModel.fromJson(inserted);
  }
}
