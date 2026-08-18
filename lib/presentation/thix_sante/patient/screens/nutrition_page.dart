// lib/presentation/thix_sante/sante/screens/nutrition_page.dart
// =============================================================================
// Screen: NutritionPage - Service Sante 7/11
// Source reelle: public.nutrition_logs (patient_uid, calories, water_ml, meal_type)
// + public.health_records exam_date pour IMC reel si poids/taille renseignes
// Calcul IMC reel depuis dernier poids/taille health_records
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';

final nutritionTodayProvider = FutureProvider<Map<String,dynamic>>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  final today = DateTime.now().toIso8601String().substring(0,10);
  try {
    final List<dynamic> logs = await db.from('nutrition_logs').select('calories, water_ml').eq('patient_uid', uid).gte('created_at', '${today}T00:00:00');
    final int totalCal = logs.fold<int>(0, (sum, e) => sum + (e['calories'] as int? ?? 0));
    final int totalWater = logs.fold<int>(0, (sum, e) => sum + (e['water_ml'] as int? ?? 0));
    return {'calories': totalCal, 'water': totalWater, 'count': logs.length};
  } catch (_) {
    return {'calories': 0, 'water': 0, 'count': 0, 'error': 'Table nutrition_logs manquante - creez table'};
  }
});

final imcProvider = FutureProvider<double?>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  // Cherche dernier poids et taille dans health_records
  final weightRec = await db.from('health_records').select('description').eq('patient_uid', uid).ilike('title', '%poids%').order('created_at', ascending: false).limit(1).maybeSingle();
  final heightRec = await db.from('health_records').select('description').eq('patient_uid', uid).ilike('title', '%taille%').order('created_at', ascending: false).limit(1).maybeSingle();
  if (weightRec==null || heightRec==null) return null;
  final double? poids = double.tryParse(RegExp(r'(\d+(\.\d+)?)').firstMatch(weightRec['description'] as String? ?? '')?.group(1)?? '');
  final double? tailleCm = double.tryParse(RegExp(r'(\d+(\.\d+)?)').firstMatch(heightRec['description'] as String? ?? '')?.group(1)?? '');
  if (poids==null || tailleCm==null || tailleCm==0) return null;
  final double tailleM = tailleCm/100;
  return poids/(tailleM*tailleM);
});

class NutritionPage extends ConsumerWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(nutritionTodayProvider);
    final imcAsync = ref.watch(imcProvider);

    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Nutrition', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          todayAsync.when(
            data: (d) => Row(children: [
              Expanded(child: _kpiCard(icon: '🔥', label: 'Calories aujourd hui', value: '${d['calories']} kcal', sub: '${d['count']} repas logs - nutrition_logs')),
              const SizedBox(width: 10),
              Expanded(child: _kpiCard(icon: '💧', label: 'Eau', value: '${d['water']} ml', sub: 'Objectif 2000 ml/j')),
            ]),
            loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            error: (e,_) => Text('Erreur nutrition_logs: $e'),
          ),
          const SizedBox(height: 12),
          imcAsync.when(
            data: (imc) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.borderLight)), child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ThixSanteColors.successLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.monitor_weight_rounded, color: ThixSanteColors.success)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('IMC calcule reel depuis health_records', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(imc!=null? 'IMC: ${imc.toStringAsFixed(1)} - ${imc<18.5? 'Insuffisance': imc<25? 'Normal': imc<30? 'Surpoids':'Obesite'}':'Ajoutez poids/taille dans Dossier Medical type consultation pour calcul IMC reel', style: TextStyle(fontSize: 11, color: imc!=null? ThixSanteColors.ink: ThixSanteColors.muted)),
              ])),
            ])),
            loading: () => const SizedBox.shrink(),
            error: (_,__) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          const Text('Journal alimentaire reel - insert nutrition_logs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          _mealButton(context, ref, 'Petit dejeuner', 350, Icons.free_breakfast_rounded),
          _mealButton(context, ref, 'Dejeuner', 650, Icons.lunch_dining_rounded),
          _mealButton(context, ref, 'Diner', 550, Icons.dinner_dining_rounded),
          _mealButton(context, ref, 'Eau 250ml', 0, Icons.water_drop_rounded, isWater: true),
        ],
      ),
    );
  }

  Widget _kpiCard({required String icon, required String label, required String value, required String sub}) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixSanteColors.borderLight)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(icon, style: const TextStyle(fontSize: 20)), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), Text(sub, style: const TextStyle(fontSize: 9, color: ThixSanteColors.mutedLight))]));
  
  Widget _mealButton(BuildContext context, WidgetRef ref, String meal, int cal, IconData icon, {bool isWater=false}) {
    return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixSanteColors.borderLight)), child: ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: ThixSanteColors.primary)), title: Text(meal, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), subtitle: Text(isWater? 'Ajoute 250ml eau - insert nutrition_logs':'~$cal kcal - insert nutrition_logs', style: const TextStyle(fontSize: 11, color: ThixSanteColors.muted)), trailing: IconButton(icon: const Icon(Icons.add_circle_rounded, color: ThixSanteColors.primary), onPressed: () async {
      final db = Supabase.instance.client;
      final uid = db.auth.currentUser!.id;
      try {
        await db.from('nutrition_logs').insert({'patient_uid': uid, 'meal_type': meal, 'calories': cal, 'water_ml': isWater? 250:0, 'created_at': DateTime.now().toIso8601String()});
        ref.invalidate(nutritionTodayProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$meal enregistre - nutrition_logs'), backgroundColor: ThixSanteColors.success));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Creez table nutrition_logs: patient_uid text, meal_type text, calories int, water_ml int, created_at timestamptz. Erreur: $e'), backgroundColor: ThixSanteColors.warning));
      }
    })));
  }
}
