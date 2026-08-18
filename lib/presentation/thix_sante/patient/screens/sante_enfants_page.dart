// lib/presentation/thix_sante/patient/screens/sante_enfants_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/thix_sante_colors.dart';
import '../providers/famille_provider.dart';

final enfantGrowthProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, thixId) async {
  final db = Supabase.instance.client;
  try {
    final data = await db.from('health_records').select('title, description, created_at').eq('patient_thix_id', thixId).ilike('title', '%poids%').order('created_at', ascending: false).limit(1).maybeSingle();
    return data?? {};
  } catch (_) {
    return {};
  }
});

class SanteEnfantsPage extends ConsumerWidget {
  const SanteEnfantsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(familleMembersNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)), onPressed: () => Navigator.pop(context)),
        title: const Text('Santé Enfants', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (all) {
          final enfants = all.where((m) => (m['lien']?? '')!= 'Vous').toList();
          if (enfants.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0xFFFEF9C3), shape: BoxShape.circle), child: const Icon(Icons.child_care_rounded, size: 40, color: Color(0xFFCA8A04))),
                  const SizedBox(height: 16),
                  const Text('Aucun enfant lié', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Ajoutez vos enfants dans Dossier Famille. Leur dossier santé apparaîtra ici automatiquement.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ]),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.info_rounded, size: 18, color: Color(0xFFCA8A04)), const SizedBox(width: 8), Expanded(child: Text('${enfants.length} dossiers enfants • Source: family_members', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))])),
              const SizedBox(height: 12),
             ...enfants.map((e) => _card(context, ref, e)),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Map<String, dynamic> enfant) {
    final fullName = '${enfant['prenom']?? ''} ${enfant['nom']?? ''}'.trim();
    final thixId = (enfant['thix_id']?? '').toString();
    final avatarUrl = enfant['avatar_url'] as String?;
    final lien = (enfant['lien']?? 'Enfant').toString();
    final groupe = (enfant['groupe_sanguin']?? 'O+').toString();
    final growthAsync = ref.watch(enfantGrowthProvider(thixId));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 22, backgroundColor: const Color(0xFFEFF6FF), backgroundImage: avatarUrl!= null? NetworkImage(avatarUrl) : null, child: avatarUrl == null? Text(fullName.isNotEmpty? fullName[0].toUpperCase() : 'E', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800)) : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fullName.isNotEmpty? fullName : 'Enfant', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), Text(thixId, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF94A3B8))), Text('$lien • $groupe', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ]),
        const SizedBox(height: 12),
        growthAsync.when(
          data: (g) => Row(children: [
            Expanded(child: _metric(icon: Icons.monitor_weight_rounded, label: 'Poids', value: g['description']?.toString()?? '${enfant['poids']?? '--'} kg', color: const Color(0xFF2563EB))),
            const SizedBox(width: 8),
            Expanded(child: _metric(icon: Icons.vaccines_rounded, label: 'Vaccins', value: 'Voir carnet', color: const Color(0xFF16A34A), isAction: true)),
          ]),
          loading: () => const SizedBox(height: 40, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
          error: (_, __) => const Text('Erreur', style: TextStyle(fontSize: 10)),
        ),
      ]),
    );
  }

  Widget _metric({required IconData icon, required String label, required String value, required Color color, bool isAction = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: isAction? Border.all(color: color.withOpacity(0.3)) : null),
      child: Column(children: [Icon(icon, size: 18, color: color), const SizedBox(height: 4), Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: isAction? color : const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis), Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))]),
    );
  }
}
