// lib/presentation/thix_sante/patient/screens/suivi_grossesse_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; // Requis pour le Glassmorphism
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/thix_sante_colors.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart'; // ✅ Policy globale

import '../providers/grossesse_provider.dart';
import '../services/grossesse_advice_service.dart';
import '../models/grossesse_model.dart';

// ================= COULEURS SPÉCIFIQUES GROSSESSE =================
class _PregnancyColors {
  static const Color primary = Color(0xFF8B5CF6); // Violet doux
  static const Color secondary = Color(0xFFEC4899); // Rose doux
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
}

// ================= WIDGET COMPTE À REBOURS COMPACT (Glass) =================
class CountdownWidget extends StatefulWidget {
  final DateTime dpa;
  const CountdownWidget({super.key, required this.dpa});
  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = widget.dpa.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _remaining = widget.dpa.difference(DateTime.now()));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) {
      return const Text('🎉 Bébé est là !', style: TextStyle(color: _PregnancyColors.primary, fontWeight: FontWeight.w900, fontSize: 14));
    }
    final m = _remaining.inDays ~/ 30;
    final w = (_remaining.inDays % 30) ~/ 7;
    final d = (_remaining.inDays % 30) % 7;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _PregnancyColors.primary.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _PregnancyColors.primary.withOpacity(0.3))
      ),
      child: Text(
        '⏳ Reste : $m mois $w sem $d j', 
        style: const TextStyle(color: _PregnancyColors.primary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.2)
      ),
    );
  }
}

// ================= PAGE PRINCIPALE =================
class SuiviGrossessePage extends ConsumerStatefulWidget {
  final String? patientId;
  const SuiviGrossessePage({super.key, this.patientId});
  @override
  ConsumerState<SuiviGrossessePage> createState() => _SuiviGrossessePageState();
}

class _SuiviGrossessePageState extends ConsumerState<SuiviGrossessePage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  Timer? _cTimer;
  int _cSec = 0;
  DateTime? _lastC;
  
  // Listes locales pour les prénoms
  final List<String> _prenomsFilles = ['Mia', 'Emma'];
  final List<String> _prenomsGarcons = ['Léo', 'Noah'];

  String? get pid => widget.patientId;
  bool get isDoctor => pid != null;

  @override
  void initState() {
    _tab = TabController(length: 6, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tab.dispose();
    _cTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(grossesseProfileProvider(pid));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: Colors.white.withOpacity(0.7),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.2))),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain), 
          onPressed: () => Navigator.pop(context)
        ),
        title: Text(
          isDoctor ? 'Suivi Patiente' : 'Ma Grossesse', 
          style: const TextStyle(fontWeight: FontWeight.w900, color: ThixPolicy.textMain, fontSize: 18, letterSpacing: -0.5)
        ),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf_rounded, color: _PregnancyColors.primary), onPressed: _exportPdf)
        ],
      ),
      body: Stack(
        children: [
          // 🌟 FOND ANIMÉ OPTIMISÉ (Chaud & Maternité)
          const Positioned.fill(child: _PregnancyAmbientBackground()),

          profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _PregnancyColors.primary)),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (profile) {
              if (profile == null) return _createProfileWizard();
              
              final advice = GrossesseAdviceService.getWeekAdvice(profile.sa);
              final info = GrossesseAdviceService.getBabyInfo(profile.sa);
              
              return SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _riskAlerts(profile),
                    _dashboardCompact(profile, info), 
                    
                    // 🌟 BARRE D'ONGLETS GLASSMORPHISM
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: TabBar(
                            controller: _tab,
                            isScrollable: true,
                            indicatorColor: _PregnancyColors.primary,
                            indicatorWeight: 3,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelColor: _PregnancyColors.primary,
                            unselectedLabelColor: ThixPolicy.textSecondary.withOpacity(0.6),
                            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Nunito'),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Bébé'),
                              Tab(text: 'Maman'),
                              Tab(text: 'RDV & Docs'),
                              Tab(text: 'Journal'),
                              Tab(text: 'Prépa'),
                              Tab(text: 'Urgences')
                            ]
                          ),
                        ),
                      ),
                    ),
                    
                    Expanded(
                      child: TabBarView(
                        controller: _tab, 
                        children: [
                          _tabBebe(profile, advice, info),
                          _tabMaman(),
                          _tabDocs(),
                          _tabJournal(),
                          _tabPrepa(profile),
                          _tabUrgences(profile)
                        ]
                      )
                    ),
                  ]
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= DASHBOARD HERO RÉDUIT (Glassmorphism) =================
  Widget _dashboardCompact(PregnancyProfile p, BabyWeekInfo info) {
    final isLabor = p.sa >= 37;
    final recordsAsync = ref.watch(grossesseRecordsProvider(pid));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isLabor ? _PregnancyColors.danger.withOpacity(0.5) : Colors.white.withOpacity(0.9), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${p.sa} SA + ${p.daysRemain}j', style: TextStyle(color: isLabor ? _PregnancyColors.danger : ThixPolicy.textMain, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                      decoration: BoxDecoration(color: _PregnancyColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), 
                      child: Text(p.trimester().toUpperCase(), style: const TextStyle(color: _PregnancyColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5))
                    ),
                  ]
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Container(
                      width: 50, height: 50, 
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]), 
                      child: Center(child: Text(info.fruit, style: const TextStyle(fontSize: 26)))
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Taille estimée', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
                          Text('📏 ${info.size}  •  ⚖️ ${info.weight}', style: const TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 13))
                        ],
                      ),
                    ),
                    CountdownWidget(dpa: p.dpa),
                  ]
                ),
                const SizedBox(height: 20),
                
                ClipRRect(
                  borderRadius: BorderRadius.circular(10), 
                  child: LinearProgressIndicator(
                    value: p.progress, 
                    backgroundColor: _PregnancyColors.primary.withOpacity(0.1), 
                    valueColor: AlwaysStoppedAnimation(isLabor ? _PregnancyColors.danger : _PregnancyColors.primary), 
                    minHeight: 8
                  )
                ),
                
                recordsAsync.when(
                  data: (records) {
                    if (records.isEmpty) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(children: [
                        Icon(Icons.event_available_rounded, color: ThixPolicy.textSecondary.withOpacity(0.8), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Prochain RDV : ${records.first.title}', style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis))
                      ]),
                    );
                  },
                  loading: () => const SizedBox(), error: (_, __) => const SizedBox()
                )
              ]
            )
          ),
        ),
      ),
    );
  }

  // ================= HELPER GLASS CARD =================
  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, Color? colorHint}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorHint ?? Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: child,
        ),
      ),
    );
  }

  // ================= ONGLETS =================

  Widget _tabBebe(PregnancyProfile p, WeekAdvice advice, BabyWeekInfo info) {
    return ListView(
      padding: const EdgeInsets.all(16), 
      physics: const BouncingScrollPhysics(),
      children: [
        Text(advice.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: advice.babyDevelopment.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10), 
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('✨ ', style: TextStyle(fontSize: 14)), 
                Expanded(child: Text(e, style: const TextStyle(fontSize: 14, height: 1.5, color: ThixPolicy.textMain, fontWeight: FontWeight.w600)))
              ])
            )).toList()
          )
        ),
        const SizedBox(height: 24),
        
        const Text('👶 Idées de Prénoms', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        _buildGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPrenomList('Filles 🌸', _prenomsFilles, _PregnancyColors.secondary.withOpacity(0.1), _PregnancyColors.secondary)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPrenomList('Garçons 💙', _prenomsGarcons, Colors.blue.withOpacity(0.1), Colors.blue.shade700)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton.icon(
                  onPressed: _showAddPrenomDialog, 
                  icon: const Icon(Icons.add_rounded, size: 20), 
                  label: const Text('Ajouter une idée', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: TextButton.styleFrom(
                    foregroundColor: _PregnancyColors.primary,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  )
                ),
              )
            ],
          )
        ),
        const SizedBox(height: 24),
        
        const Text('Panneau d\'Activité', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        _kickCounter(),
        const SizedBox(height: 40),
      ]
    );
  }

  Widget _buildPrenomList(String title, List<String> list, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 14)),
          const SizedBox(height: 12),
          if (list.isEmpty) Text('Aucun', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13, fontStyle: FontStyle.italic)),
          ...list.map((name) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [Icon(Icons.favorite_rounded, size: 12, color: textColor.withOpacity(0.6)), const SizedBox(width: 8), Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textColor.withOpacity(0.9)))]),
          ))
        ],
      ),
    );
  }

  Widget _tabPrepa(PregnancyProfile p) {
    final checks = ref.watch(checklistProvider(pid));
    final contractions = ref.watch(contractionsProvider(pid));
    
    return ListView(
      padding: const EdgeInsets.all(16), 
      physics: const BouncingScrollPhysics(),
      children: [
        const Text('📚 Plan & Éducation', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildGlassAction(Icons.assignment_turned_in_rounded, 'Plan Naissance', Colors.blue, _showPlanNaissance)),
          const SizedBox(width: 12),
          Expanded(child: _buildGlassAction(Icons.auto_stories_rounded, 'Conseils Pratiques', _PregnancyColors.secondary, _showConseils)),
        ]),
        const SizedBox(height: 24),

        const Text('⏱️ Chronomètre Contractions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: Column(children: [
            Text('$_cSec s', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: _PregnancyColors.primary)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                  onPressed: isDoctor ? null : _toggleContraction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cTimer == null ? _PregnancyColors.primary : _PregnancyColors.danger, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0
                  ),
                  child: Text(_cTimer == null ? 'DÉMARRER' : 'ARRÊTER', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)))
            ),
            const SizedBox(height: 20),
            contractions.when(
                data: (List<PregnancyContraction> list) {
                  if (list.isEmpty) return const Text('Aucune contraction enregistrée', style: TextStyle(fontSize: 13, color: ThixPolicy.textSecondary));
                  return Column(children: [
                    const Align(alignment: Alignment.centerLeft, child: Text('Dernières contractions :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain))),
                    const SizedBox(height: 8),
                    ...list.take(3).map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: _PregnancyColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Durée : ${c.durationSec}s', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                          Text('${(c.intervalSec / 60).toStringAsFixed(1)} min', style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 13, fontWeight: FontWeight.w700))
                        ],
                      ),
                    ))
                  ]);
                },
                loading: () => const CircularProgressIndicator(), error: (_, __) => const Text('Erreur')),
          ])
        ),
        
        const SizedBox(height: 24),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('🎒 Ma Valise & Achats', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.3)),
            IconButton(icon: const Icon(Icons.add_circle_rounded, color: _PregnancyColors.primary, size: 28), onPressed: _showAddValiseItemDialog)
          ],
        ),
        const SizedBox(height: 12),
        _buildGlassCard(
          padding: EdgeInsets.zero,
          child: checks.when(
              data: (List<ChecklistItem> list) {
                if(list.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text('Votre liste est vide.', style: TextStyle(fontWeight: FontWeight.w600)));
                return Column(
                  children: list.map((c) => CheckboxListTile(
                          value: c.done,
                          activeColor: _PregnancyColors.primary,
                          checkColor: Colors.white,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(c.item, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.done ? ThixPolicy.textSecondary : ThixPolicy.textMain, decoration: c.done ? TextDecoration.lineThrough : null)),
                          onChanged: (v) async {
                            HapticFeedback.lightImpact();
                            await ref.read(grossesseServiceProvider).toggleChecklist(c.id, v!);
                            ref.invalidate(checklistProvider(pid));
                          }))
                     .toList()
                );
              },
              loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const Text('Erreur')),
        ),
        const SizedBox(height: 60),
      ]
    );
  }

  Widget _buildGlassAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8), 
            decoration: BoxDecoration(
              color: color.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(20), 
              border: Border.all(color: color.withOpacity(0.3), width: 1.5)
            ), 
            child: Column(
              children: [
                Icon(icon, color: color, size: 32), 
                const SizedBox(height: 10), 
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color))
              ]
            )
          ),
        ),
      ),
    );
  }

  // ================= MODALES PRÉPA =================
  void _showPlanNaissance() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withOpacity(0.85),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assignment_turned_in_rounded, color: Colors.blue, size: 32),
                      SizedBox(width: 12),
                      Text('Mon Plan de Naissance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Sélectionnez vos préférences pour le jour J. Ce document pourra être partagé avec votre équipe médicale.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, height: 1.4, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  _buildPrefItem(Icons.vaccines_rounded, 'Gestion de la douleur', 'Péridurale, Bain chaud, Hypnose...'),
                  _buildPrefItem(Icons.nightlight_round, 'Ambiance souhaitée', 'Lumière tamisée, Musique douce...'),
                  _buildPrefItem(Icons.group_rounded, 'Accompagnant(s)', 'Conjoint, Doula, Mère...'),
                  _buildPrefItem(Icons.child_care_rounded, 'Accueil du bébé', 'Peau à peau immédiat, Allaitement...'),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Valider mes préférences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))
                    )
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  void _showConseils() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withOpacity(0.85),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_stories_rounded, color: _PregnancyColors.secondary, size: 32),
                      SizedBox(width: 12),
                      Text('Conseils Pratiques', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero, 
                    leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _PregnancyColors.secondary.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.shopping_bag_rounded, color: _PregnancyColors.secondary)),
                    title: const Text('Quand préparer sa valise ?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), 
                    subtitle: const Padding(padding: EdgeInsets.only(top: 6), child: Text('Idéalement autour de 32 SA pour être sereine en cas de départ précipité.', style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600))),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero, 
                    leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _PregnancyColors.secondary.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.directions_walk_rounded, color: _PregnancyColors.secondary)),
                    title: const Text('Activité physique', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), 
                    subtitle: const Padding(padding: EdgeInsets.only(top: 6), child: Text('La marche, la natation ou le yoga prénatal sont fortement recommandés.', style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600))),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildPrefItem(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.blue)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.edit_outlined, size: 20, color: ThixPolicy.textSecondary),
        onTap: () {},
      ),
    );
  }

  // ================= AUTRES ONGLETS =================

  Widget _kickCounter() {
    final kicksAsync = ref.watch(kicksProvider(pid));
    return kicksAsync.when(
        data: (List<PregnancyKick> list) {
          final today = list.where((k) => k.createdAt.day == DateTime.now().day).length;
          return _buildGlassCard(
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(children: [Icon(Icons.pan_tool_rounded, color: _PregnancyColors.primary, size: 24), SizedBox(width: 10), Text('Mouvements (Auj.)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))]),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _PregnancyColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('$today / 10', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _PregnancyColors.primary)))
                    ]),
                const SizedBox(height: 20),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: (today / 10).clamp(0, 1).toDouble(), minHeight: 10, backgroundColor: Colors.black.withOpacity(0.05), valueColor: const AlwaysStoppedAnimation(_PregnancyColors.primary))),
                if (!isDoctor)
                  Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: _PregnancyColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                              onPressed: () async { HapticFeedback.mediumImpact(); await ref.read(grossesseServiceProvider).addKick(pid); ref.invalidate(kicksProvider(pid)); },
                              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                              label: const Text('Enregistrer un coup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))))),
              ]));
        },
        loading: () => const CircularProgressIndicator(), error: (_, __) => const Text('Erreur'));
  }

  Widget _tabMaman() {
    final vitals = ref.watch(vitalsProvider(pid));
    return ListView(
      padding: const EdgeInsets.all(16), 
      physics: const BouncingScrollPhysics(),
      children: [
        const Text('📈 Suivi du Poids', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        _buildGlassCard(
            child: SizedBox(
              height: 220,
              child: vitals.when(
                  data: (List<PregnancyVital> list) {
                    final poids = list.where((v) => v.type == 'poids').toList().reversed.take(7).toList().reversed.toList();
                    if (poids.isEmpty) return const Center(child: Text('Aucune donnée de poids pour le moment', style: TextStyle(fontSize: 13, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)));
                    final spots = <FlSpot>[];
                    for (int i = 0; i < poids.length; i++) { spots.add(FlSpot(i.toDouble(), double.tryParse(poids[i].value) ?? 0)); }
                    return LineChart(LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.black.withOpacity(0.05), strokeWidth: 1)),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(show: false),
                      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: _PregnancyColors.primary, barWidth: 4, belowBarData: BarAreaData(show: true, color: _PregnancyColors.primary.withOpacity(0.1)), dotData: const FlDotData(show: true))]
                    ));
                  },
                  loading: () => const Center(child: CircularProgressIndicator()), error: (_, __) => const Text('Erreur')),
            )),
        const SizedBox(height: 32),
        const Text('Saisie Rapide', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildActionBtn('⚖️ Poids', () => _addVital('poids'))),
          const SizedBox(width: 10),
          Expanded(child: _buildActionBtn('🩸 Tension', () => _addVital('tension'))),
          const SizedBox(width: 10),
          Expanded(child: _buildActionBtn('💧 Glycémie', () => _addVital('glycemie'))),
        ]),
      ]
    );
  }
  
  Widget _buildActionBtn(String title, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.8), 
        foregroundColor: _PregnancyColors.primary, 
        elevation: 0, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.5)), 
        padding: const EdgeInsets.symmetric(vertical: 16)
      ),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: -0.2)),
    );
  }

  Widget _tabDocs() {
    final records = ref.watch(grossesseRecordsProvider(pid));
    return ListView(
      padding: const EdgeInsets.all(16), 
      physics: const BouncingScrollPhysics(),
      children: [
        Row(children: [
          if (isDoctor) Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _PregnancyColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)), icon: const Icon(Icons.add, size: 20), label: const Text('Consultation', style: TextStyle(fontWeight: FontWeight.w900)), onPressed: _addConsultation)),
          if (isDoctor) const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: _PregnancyColors.primary, backgroundColor: Colors.white.withOpacity(0.5), side: const BorderSide(color: _PregnancyColors.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)), icon: const Icon(Icons.upload_file_rounded, size: 20), label: const Text('Ajouter Doc', style: TextStyle(fontWeight: FontWeight.w900)), onPressed: _pickDoc)),
        ]),
        const SizedBox(height: 32),
        const Text('Dossier Médical', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        records.when(
            data: (list) {
              if (list.isEmpty) return _buildGlassCard(child: const Center(child: Padding(padding: EdgeInsets.all(10), child: Text("Aucun document.", style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)))));
              return Column(children: list.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))]),
                child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _PregnancyColors.primary.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.description_rounded, color: _PregnancyColors.primary, size: 24)),
                    title: Text(r.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
                    subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.description ?? 'Aucune note', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textSecondary))
              )).toList());
            },
            loading: () => const CircularProgressIndicator(), error: (e, _) => Text('Erreur $e')),
      ]
    );
  }

  Widget _tabJournal() {
    final journals = ref.watch(journalProvider(pid));
    return Stack(children: [
      journals.when(
          data: (List<PregnancyJournal> list) {
            final monthEntries = list.where((j) => j.createdAt.month == DateTime.now().month).length;
            return ListView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildGlassCard(
                  colorHint: const Color(0xFFFFF7ED).withOpacity(0.8),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEA580C), size: 36),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Résumé du mois', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF9A3412))),
                      const SizedBox(height: 4),
                      Text('$monthEntries souvenir(s) enregistré(s)', style: const TextStyle(fontSize: 13, color: Color(0xFFC2410C), fontWeight: FontWeight.w700)),
                    ])
                  ]),
                ),
                const SizedBox(height: 24),
                ...list.map((j) => Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4))]),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (j.photoUrl != null)
                            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), child: Image.network(j.photoUrl!, height: 220, width: double.infinity, fit: BoxFit.cover)),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(j.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3)),
                                const SizedBox(height: 8),
                                Text(j.content, style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, height: 1.5, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                Text(j.createdAt.toString().substring(0, 10), style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          )
                        ])))
              ]
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()), error: (_, __) => const Text('Erreur')),
      if (!isDoctor)
        Positioned(bottom: 24, right: 16, child: FloatingActionButton.extended(onPressed: _addJournalPhoto, backgroundColor: _PregnancyColors.primary, icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white), label: const Text('Nouveau Souvenir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)), elevation: 4))
    ]);
  }

  Widget _tabUrgences(PregnancyProfile p) => ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            const Text('Maternité & Urgences', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: ThixPolicy.textMain, letterSpacing: -0.5)),
            const SizedBox(height: 16),
            _buildGlassCard(
                colorHint: _PregnancyColors.danger.withOpacity(0.05),
                padding: const EdgeInsets.all(24),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _UrgenceItem('Saignements', 'Similaires à des règles.'),
                    _UrgenceItem('Perte de liquide', 'Rupture de la poche des eaux (même sans contraction).'),
                    _UrgenceItem('Fièvre > 38°C', 'Risque d\'infection pour le bébé.'),
                    _UrgenceItem('Baisse des mouvements', 'Si le bébé bouge moins de 10 fois par jour.'),
                    _UrgenceItem('Contractions intenses', 'Toutes les 5 minutes depuis plus de 2 heures.'),
                  ],
                )),
            const SizedBox(height: 32),
            SizedBox(
              height: 70,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _PregnancyColors.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 4),
                onPressed: (){}, 
                icon: const Icon(Icons.phone_in_talk_rounded, size: 36), 
                label: Text('APPELER LA MATERNITÉ\nDPA: ${p.dpa.day}/${p.dpa.month}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))
              ),
            )
          ]);

  // ================= AUTRES MÉTHODES CONSERVÉES À L'IDENTIQUE =================
  Widget _createProfileWizard() {
    // ... [Même code que précédemment, encapsulé dans un GlassCard si souhaité, mais fonctionnel]
    final ctrl = TextEditingController();
    PregnancyType selectedType = PregnancyType.singleton;
    
    return StatefulBuilder(
      builder: (context, setLocal) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildGlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  const Text('🤰', style: TextStyle(fontSize: 60)), 
                  const SizedBox(height: 16),
                  const Text('Bienvenue !', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: ThixPolicy.textMain)),
                  const SizedBox(height: 8),
                  const Text('Configurons votre suivi de grossesse.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 32),
                  
                  DropdownButtonFormField<PregnancyType>(
                    value: selectedType, 
                    decoration: InputDecoration(
                      labelText: 'Type de grossesse',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      prefixIcon: const Icon(Icons.people_alt_rounded)
                    ),
                    items: PregnancyType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)))).toList(), 
                    onChanged: (v) { if (v != null) setLocal(() => selectedType = v); }
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: ctrl, 
                    readOnly: true, 
                    decoration: InputDecoration(
                      labelText: 'Date des Dernières Règles (DDR)', 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      prefixIcon: const Icon(Icons.calendar_month_rounded, color: _PregnancyColors.primary)
                    ), 
                    onTap: () async { 
                      final d = await showDatePicker(
                        context: context, 
                        initialDate: DateTime.now().subtract(const Duration(days: 60)), 
                        firstDate: DateTime.now().subtract(const Duration(days: 300)), 
                        lastDate: DateTime.now()
                      ); 
                      if (d != null) setLocal(() => ctrl.text = d.toIso8601String().substring(0, 10)); 
                    }
                  ),
                  
                  const SizedBox(height: 32), 
                  
                  SizedBox(
                    width: double.infinity, 
                    height: 56, 
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _PregnancyColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      onPressed: () async { 
                        if (ctrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer la DDR')));
                          return;
                        }
                        await ref.read(grossesseServiceProvider).createProfile(pid, DateTime.parse(ctrl.text), selectedType); 
                        ref.invalidate(grossesseProfileProvider(pid)); 
                      }, 
                      child: const Text('DÉMARRER MON SUIVI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))
                    )
                  ),
                ]
              )
            )
          )
        );
      }
    );
  }

  Widget _riskAlerts(PregnancyProfile profile) {
    final vitals = ref.watch(vitalsProvider(pid)).value ?? [];
    final kicks = ref.watch(kicksProvider(pid)).value ?? [];
    final contractions = ref.watch(contractionsProvider(pid)).value ?? [];
    final risks = ref.read(grossesseServiceProvider).calculateRisks(sa: profile.sa, vitals: vitals, kicks: kicks, contractions: contractions);
    
    if (risks.isEmpty) {
      return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.green.shade50.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade200, width: 1.5)),
          child: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
            SizedBox(width: 12),
            Expanded(child: Text("Grossesse normale - Pensez à vos vitamines", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF166534))))
          ]));
    }
    return Column(
        children: risks.map((r) => Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200, width: 1.5)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C))))
                ]))).toList());
  }

  // --- Les fonctions _addVital, _showAddValiseItemDialog, _addJournalPhoto, etc., restent inchangées en logique, juste les styles boutons mis à jour si besoin.
  // [Le reste des fonctions utilitaires (_addVital, _pickDoc, _addConsultation, _exportPdf) reste le même que ton code original]

  void _addVital(String type) async {
    final c = TextEditingController();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text('Ajouter : $type', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))), hintText: 'Valeur')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.bold))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _PregnancyColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        await ref.read(grossesseServiceProvider).addVital(pid, type, c.text);
                        ref.invalidate(vitalsProvider(pid));
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Valider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                ]));
  }

  void _showAddValiseItemDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ajouter à la valise', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Ex: Biberons, Couches...', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _PregnancyColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if(ctrl.text.trim().isNotEmpty) {
                final uid = pid ?? Supabase.instance.client.auth.currentUser!.id;
                await Supabase.instance.client.from('pregnancy_checklist').insert({
                  'user_id': uid, 'item': ctrl.text.trim(), 'category': 'achat', 'done': false
                });
                ref.invalidate(checklistProvider(pid));
              }
              if(mounted) Navigator.pop(context);
            }, 
            child: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold))
          )
        ],
      )
    );
  }

  void _addJournalPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final path = 'journal/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await Supabase.instance.client.storage.from('pregnancy_photos').uploadBinary(path, bytes);
    final url = Supabase.instance.client.storage.from('pregnancy_photos').getPublicUrl(path);
    await ref.read(grossesseServiceProvider).addJournal(pid, 'Souvenir S${ref.read(grossesseProfileProvider(pid)).value?.sa ?? ''}', 'Mon évolution', photoUrl: url);
    ref.invalidate(journalProvider(pid));
  }

  void _pickDoc() async {
    final res = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'png']);
    if (res == null) return;
    final f = res.files.first;
    if (f.bytes == null) return;

    final bytes = f.bytes!;
    final uid = pid ?? Supabase.instance.client.auth.currentUser!.id;
    final path = 'docs/$uid/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
    await Supabase.instance.client.storage.from('pregnancy_photos').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f.name} ajouté', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
  }

  void _addConsultation() async {
    final t = TextEditingController();
    final d = TextEditingController();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Nouvelle Consultation', style: TextStyle(fontWeight: FontWeight.w900)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: t, decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))))),
                  const SizedBox(height: 12),
                  TextField(controller: d, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))))
                ]),
                actions: [
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _PregnancyColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        await ref.read(grossesseServiceProvider).addConsultation(pid, t.text, d.text);
                        ref.invalidate(grossesseRecordsProvider(pid));
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                ]));
  }

  void _toggleContraction() async {
    if (_cTimer == null) {
      _cSec = 0;
      _cTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _cSec++);
      });
    } else {
      _cTimer?.cancel();
      _cTimer = null;
      final inter = _lastC == null ? 0 : DateTime.now().difference(_lastC!).inSeconds;
      final sec = _cSec;
      setState(() => _cSec = 0);
      _lastC = DateTime.now();
      await ref.read(grossesseServiceProvider).addContraction(pid, sec, inter);
      ref.invalidate(contractionsProvider(pid));
    }
  }

  Future<void> _exportPdf() async {
    final profile = ref.read(grossesseProfileProvider(pid)).value;
    if (profile == null) return;
    final vitals = ref.read(vitalsProvider(pid)).value ?? [];
    final doc = pw.Document();
    doc.addPage(pw.Page(
        build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Dossier de Grossesse', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('DPA : ${profile.dpa.toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 16)),
              pw.Divider(),
              ...vitals.map((v) => pw.Text('${v.createdAt.toString().substring(0, 10)} - ${v.type.toUpperCase()}: ${v.value}'))
            ])));
    await Printing.layoutPdf(onLayout: (f) => doc.save(), name: 'Grossesse.pdf');
  }
}

// ================= WIDGET UTILITAIRE URGENCES =================
class _UrgenceItem extends StatelessWidget {
  final String title;
  final String desc;
  const _UrgenceItem(this.title, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 10, color: _PregnancyColors.danger)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _PregnancyColors.danger)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, height: 1.4, fontWeight: FontWeight.w600)),
            ],
          ))
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET : BACKGROUND GROSSESSE ANIMÉ & OPTIMISÉ 100% (Zéro Flou GPU)
// ============================================================================
class _PregnancyAmbientBackground extends StatefulWidget {
  const _PregnancyAmbientBackground();

  @override
  State<_PregnancyAmbientBackground> createState() => _PregnancyAmbientBackgroundState();
}

class _PregnancyAmbientBackgroundState extends State<_PregnancyAmbientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Cycle fluide et lent (20s) pour un effet doux et rassurant
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🌟 HELPER HAUTE PERFORMANCE : Utilise un RadialGradient elliptique au lieu d'un Flou GPU
  Widget _buildPerformanceOrb(double left, double top, double width, double height, Color color, double angle) {
    return Positioned(
      left: left - (width / 2),
      top: top - (height / 2),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(width, height)),
            gradient: RadialGradient(
              colors: [
                color,
                color.withOpacity(0.0), // Fondu doux et naturel
              ],
              stops: const [0.1, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;

            // Orb 1 : Violet doux (Maternité)
            final p1X = size.width * 0.3 + math.cos(t * 0.8) * 150.0;
            final p1Y = size.height * 0.2 + math.sin(t * 1.1) * 120.0;

            // Orb 2 : Rose doux (Bébé)
            final p2X = size.width * 0.8 + math.sin(t * 1.3) * 130.0;
            final p2Y = size.height * 0.6 + math.cos(t * 0.9) * 180.0;

            // Orb 3 : Bleu très clair clinique (Santé)
            final p3X = size.width * 0.5 + math.cos(t * 1.5) * 100.0;
            final p3Y = size.height * 0.85 + math.sin(t * 0.7) * 100.0;

            return Stack(
              children: [
                // Orbes dessinés via RadialGradient (Coût GPU = 0)
                _buildPerformanceOrb(p1X, p1Y, 700, 600, _PregnancyColors.primary.withOpacity(0.12), t * 0.3),
                _buildPerformanceOrb(p2X, p2Y, 600, 500, _PregnancyColors.secondary.withOpacity(0.12), -t * 0.4),
                _buildPerformanceOrb(p3X, p3Y, 650, 450, Colors.blue.withOpacity(0.08), t * 0.5),

                // Voile clair très subtil par-dessus
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
