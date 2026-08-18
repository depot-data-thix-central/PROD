// lib/presentation/thix_sante/patient/providers/famille_provider.dart
import 'dart:typed_data'; // Indispensable pour utiliser Uint8List
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/famille_service.dart';

final familleServiceProvider = Provider((ref) => FamilleService());
final familleMembersNotifierProvider = StateNotifierProvider<FamilleNotifier, AsyncValue<List<Map<String,dynamic>>>>((ref) => FamilleNotifier(ref));

class FamilleNotifier extends StateNotifier<AsyncValue<List<Map<String,dynamic>>>> {
  final Ref ref;
  
  FamilleNotifier(this.ref): super(const AsyncValue.loading()) { 
    load(); 
  }
  
  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await ref.read(familleServiceProvider).getMembers();
      state = AsyncValue.data(data);
    } catch (e, st) { 
      state = AsyncValue.error(e, st); 
    }
  }
  
  Future<void> add({
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
    Uint8List? avatarBytes // Remplacement de String? localAvatarPath par Uint8List? avatarBytes
  }) async {
    final svc = ref.read(familleServiceProvider);
    String? avatarUrl;
    
    // On vérifie les octets au lieu du chemin de fichier
    if (avatarBytes != null) { 
      avatarUrl = await svc.uploadAvatar(avatarBytes, thixId);
    }
    
    await svc.addMember(
      thixId: thixId, 
      nom: nom, 
      postnom: postnom, 
      prenom: prenom, 
      dob: dob, 
      sexe: sexe, 
      lien: lien, 
      groupe: groupe, 
      poids: poids, 
      taille: taille, 
      avatarUrl: avatarUrl
    );
    
    await load();
  }
  
  Future<void> remove(String id) async {
    await ref.read(familleServiceProvider).deleteMember(id);
    await load();
  }
}
