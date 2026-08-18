import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/certificate.dart';

String _genHash() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = Random.secure();
  return List.generate(24, (_) => chars[rnd.nextInt(chars.length)]).join();
}

class CertificatesNotifier extends FamilyAsyncNotifier<List<Certificate>, String> {
  @override
  Future<List<Certificate>> build(String userId) async {
    // ✅ CORRIGÉ : Utilisation directe du client pour éviter les erreurs d'import
    final client = Supabase.instance.client;
    
    final res = await client.from('certificates')
     .select('id,formation_id,verification_hash,issued_at,formation:formations(id,title,image_url)')
     .eq('user_id', userId)
     .order('issued_at', ascending: false)
     .limit(100); 
    return res.map((e) => Certificate.fromJson(e)).toList();
  }

  Future<Certificate?> getByFormation(String formationId) async {
    final client = Supabase.instance.client;
    final res = await client.from('certificates')
     .select()
     .eq('user_id', arg)
     .eq('formation_id', formationId)
     .maybeSingle();
    return res == null ? null : Certificate.fromJson(res);
  }

  Future<Certificate?> generateCertificate(String formationId) async {
    final userId = arg;
    final client = Supabase.instance.client;
    try {
      final res = await client.from('certificates').insert({
        'user_id': userId,
        'formation_id': formationId,
        'verification_hash': _genHash(),
      }).select('id,formation_id,verification_hash,issued_at').single();
      
      final cert = Certificate.fromJson(res);
      ref.invalidateSelf();
      return cert;
    } catch (e) {
      rethrow;
    }
  }
}

final certificatesProvider = AsyncNotifierProvider.family<CertificatesNotifier, List<Certificate>, String>(CertificatesNotifier.new);

final certificateByIdProvider = FutureProvider.family<Certificate?, String>((ref, String certId) async {
  final client = Supabase.instance.client;
  final res = await client.from('certificates').select().eq('id', certId).maybeSingle();
  return res == null ? null : Certificate.fromJson(res);
});
