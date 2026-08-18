// lib/presentation/thix_sante/patient/services/patient_service.dart
// =============================================================================
// Service: PatientService
// Role: Recherche patient/medecin par THIX ID UID, gestion profil sante
// Dependance: supabase_flutter uniquement, zero Dio
// =============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/thix_id_validator.dart';
import '../models/doctor_profile_model.dart';

class PatientService {
  PatientService({SupabaseClient? client})
      : _db = client?? Supabase.instance.client;

  final SupabaseClient _db;

  /// Recherche un profil par THIX ID complet.
  /// Utilise pour la liaison Mon Medecin Traitant.
  /// Lance Exception si format invalide ou profil introuvable.
  Future<Map<String, dynamic>> findProfileByThixId(String thixId) async {
    final String cleanId = ThixIdValidator.clean(thixId);

    if (!ThixIdValidator.isValidFormat(cleanId)) {
      throw const FormatException(
        'Format THIX ID invalide. Attendu: THIX-CD-0726-12345-ABC-1',
      );
    }

    final Map<String, dynamic>? result = await _db
      .from('profiles')
      .select(
          'uid, full_name, thix_id, thix_chat, avatar_url, country_or_origin, occupation, phone, is_verified')
      .eq('thix_id', cleanId)
      .maybeSingle();

    if (result == null) {
      throw Exception('Aucun profil trouve avec THIX ID: $cleanId');
    }
    return result;
  }

  /// Recherche un medecin par THIX ID.
  Future<DoctorProfileModel> findDoctorByThixId(String thixId) async {
    final Map<String, dynamic> json = await findProfileByThixId(thixId);
    return DoctorProfileModel.fromJson(json);
  }

  /// Recherche par UID interne Supabase.
  Future<Map<String, dynamic>?> findByUid(String uid) async {
    return await _db
      .from('profiles')
      .select()
      .eq('uid', uid)
      .maybeSingle();
  }

  /// Verifie si le THIX ID existe deja avant liaison.
  Future<bool> existsByThixId(String thixId) async {
    try {
      final String cleanId = ThixIdValidator.clean(thixId);
      final res = await _db
        .from('profiles')
        .select('uid')
        .eq('thix_id', cleanId)
        .maybeSingle();
      return res!= null;
    } catch (_) {
      return false;
    }
  }

  /// Recupere le profil courant connecte.
  Future<Map<String, dynamic>> getCurrentProfile() async {
    final User? user = _db.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifie');

    final data = await _db
      .from('profiles')
      .select()
      .eq('uid', user.id)
      .single();
    return data;
  }

  /// Met a jour les infos sante du patient dans profiles.
  Future<void> updateHealthInfo({
    String? bloodGroup,
    String? allergies,
    String? chronicDiseases,
    String? emergencyContact,
  }) async {
    final User? user = _db.auth.currentUser;
    if (user == null) throw Exception('Non authentifie');

    await _db.from('profiles').update({
      'blood_group': bloodGroup,
      'allergies': allergies,
      'chronic_diseases': chronicDiseases,
      'emergency_contact': emergencyContact,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('uid', user.id);
  }
}
