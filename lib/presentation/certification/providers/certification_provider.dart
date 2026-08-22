// lib/services/certification_service.dart

class CertificationService {
  final SupabaseClient supabase;

  CertificationService(this.supabase);

  // ... (vos méthodes existantes : getMyCertification, requestUpgrade, etc.) ...

  /// 🚨 Méthode ajoutée pour nettoyer une demande si le paiement échoue ou est annulé
  Future<void> cancelUpgradeRequest() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // ⚠️ IMPORTANT : Modifiez 'profiles' et 'certification_status' selon la structure réelle de votre base de données Supabase.
      
      // Si le statut de certification est stocké dans la table 'profiles' :
      await supabase
          .from('profiles')
          .update({'certification_status': CertificationStatus.none.name})
          .eq('id', user.id)
          .eq('certification_status', CertificationStatus.pending.name); 
          // Le .eq() final est une sécurité pour ne remettre à zéro que si c'était "En cours"

      /* 
      // Alternative : Si vos demandes sont dans une table séparée 'certification_requests'
      await supabase
          .from('certification_requests')
          .delete()
          .eq('user_id', user.id)
          .eq('status', 'pending');
      */

    } catch (e) {
      // On logue l'erreur mais on ne crashe pas, car c'est une méthode de repli
      print('Erreur dans cancelUpgradeRequest: $e');
    }
  }
}
