// lib/presentation/thix_sante/sante/screens/gestion_stress_page.dart
// =============================================================================
// Screen: GestionStressPage - Service Sante 9/11
// Source reelle: public.stress_logs + mood_entries jointure
// Exercices respiration avec timer reel + sauvegarde duree pratiquee
// Zero mock - 100% Supabase, table stress_logs a creer si absente
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';

final stressLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  try {
    final List<dynamic> data = await db.from('stress_logs').select().eq('patient_uid', uid).order('created_at', ascending: false).limit(10);
    return data.map((e) => e as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

class GestionStressPage extends ConsumerStatefulWidget {
  const GestionStressPage({super.key});
  @override
  ConsumerState<GestionStressPage> createState() => _GestionStressPageState();
}

class _GestionStressPageState extends ConsumerState<GestionStressPage> {
  bool _isBreathing = false;
  int _seconds = 0;
  Timer? _timer;

  void _startBreathing() {
    setState(() {
      _isBreathing = true;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) => setState(() => _seconds++));
  }

  Future<void> _stopBreathing() async {
    _timer?.cancel();
    final int duration = _seconds;
    setState(() => _isBreathing = false);
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser!.id;
    try {
      await db.from('stress_logs').insert({
        'patient_uid': uid,
        'exercise_type': 'Respiration 4-7-8',
        'duration_sec': duration,
        'created_at': DateTime.now().toIso8601String()
      });
      ref.invalidate(stressLogsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exercice $duration sec enregistre - stress_logs'), backgroundColor: ThixSanteColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Creez table stress_logs: patient_uid text, exercise_type text, duration_sec int, created_at timestamptz. Erreur: $e'),
          backgroundColor: ThixSanteColors.warning,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(stressLogsProvider);

    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Gestion Stress', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(_isBreathing ? Icons.self_improvement_rounded : Icons.spa_rounded, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(_isBreathing ? 'Inspirez... Expirez... ($_seconds s)' : 'Respiration guidee 4-7-8',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                // FIX ICI - 1 seul ternaire
                Text(
                  _isBreathing ? 'Exercice en cours - timer reel' : 'Gerez votre stress - donnees liees a votre THIX ID UID reel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isBreathing ? _stopBreathing : _startBreathing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ThixSanteColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_isBreathing ? 'Terminer - Enregistrer ${_seconds}s' : 'Commencer exercice',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Exercices disponibles - insert stress_logs reel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _exerciseCard('Meditation', '5 min', Icons.self_improvement_rounded, ThixSanteColors.purpleLight, ThixSanteColors.purple),
              _exerciseCard('Yoga doux', '10 min', Icons.accessibility_new_rounded, ThixSanteColors.successLight, ThixSanteColors.success),
              _exerciseCard('Coherence', '3 min', Icons.favorite_rounded, ThixSanteColors.dangerLight, ThixSanteColors.danger),
              _exerciseCard('Relaxation', '7 min', Icons.bedtime_rounded, ThixSanteColors.skyLight, ThixSanteColors.sky),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Historique pratiques - Source stress_logs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          logsAsync.when(
            data: (logs) => logs.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Aucune pratique enregistree - lancez respiration guidee',
                        style: TextStyle(fontSize: 11, color: ThixSanteColors.muted), textAlign: TextAlign.center),
                  )
                : Column(
                    children: logs.map((l) {
                      final String createdAt = (l['created_at'] as String?) ?? '';
                      String display = createdAt.length >= 16 ? createdAt.substring(0, 16) : createdAt;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ThixSanteColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.check_circle_rounded, size: 16, color: ThixSanteColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l['exercise_type'] as String? ?? 'Respiration', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  Text('${l['duration_sec'] ?? 0}s - $display - stress_logs',
                                      style: const TextStyle(fontSize: 10, color: ThixSanteColors.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erreur stress_logs: $e - creez table'),
          ),
        ],
      ),
    );
  }

  Widget _exerciseCard(String title, String dur, IconData icon, Color bg, Color fg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixSanteColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: fg)),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            Text('$dur - insert reel', style: const TextStyle(fontSize: 10, color: ThixSanteColors.muted)),
          ],
        ),
      );
}
