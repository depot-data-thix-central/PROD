import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilleService {
  final _db = Supabase.instance.client;
  static const _table = 'family_members';
  static const _bucket = 'avatars';

  Future<List<Map<String, dynamic>>> getMembers() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];
    final res = await _db.from(_table).select().eq('tuteur_id', uid).order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> addMember({
    required String thixId,
    required String nom,
    String? postnom,
    required String prenom,
    required DateTime dob,
    required String sexe,
    required String lien,
    String groupe = 'O+',
    double? poids,
    double? taille,
    String? avatarUrl,
  }) async {
    final uid = _db.auth.currentUser!.id;
    final payload = {
      'tuteur_id': uid,
      'thix_id': thixId.toUpperCase().trim(),
      'nom': nom,
      'postnom': postnom,
      'prenom': prenom,
      'date_naissance': dob.toIso8601String(),
      'sexe': sexe,
      'lien': lien,
      'role': '$lien - ${DateTime.now().year - dob.year} ans',
      'groupe_sanguin': groupe,
      'poids': poids,
      'taille': taille,
      'avatar_url': avatarUrl,
      'is_verified': true,
    };
    final res = await _db.from(_table).insert(payload).select().single();
    return res;
  }

  /// Upload universel par octets (fonctionne à la fois sur le Web, Android et iOS)
  Future<String> uploadAvatar(Uint8List imageBytes, String thixId) async {
    final fileName = '${_db.auth.currentUser!.id}/$thixId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    await _db.storage.from(_bucket).uploadBinary(
      fileName,
      imageBytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );

    return _db.storage.from(_bucket).getPublicUrl(fileName);
  }

  Future<void> deleteMember(String id) async {
    await _db.from(_table).delete().eq('id', id);
  }

  Future<bool> isThixIdExists(String thixId) async {
    final r = await _db.from(_table).select('id').eq('thix_id', thixId.trim().toUpperCase()).maybeSingle();
    return r != null;
  }
}
