// lib/presentation/thix_sante/patient/screens/suivi_grossesse_page.dart
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/thix_sante_colors.dart';
import '../providers/grossesse_provider.dart';
import '../services/grossesse_advice_service.dart';
import '../models/grossesse_model.dart';

// ================= WIDGET COMPTE À REBOURS COMPACT =================
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
      return const Text('🎉 Bébé est là !', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14));
    }
    final m = _remaining.inDays ~/ 30;
    final w = (_remaining.inDays % 30) ~/ 7;
    final d = (_remaining.inDays % 30) % 7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: Text('⏳ Reste : $m mois $w sem $d j', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
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
  
  // Listes locales pour les prénoms (Idéalement à sauvegarder en BDD plus tard)
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
      backgroundColor: const Color(0xFFF8FAFC), // Fond gris très clair moderne
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Text(isDoctor ? 'Suivi Patiente' : 'Ma Grossesse', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 18, letterSpacing: -0.5)),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: ThixSanteColors.primary), onPressed: _exportPdf)
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur $e')),
        data: (profile) {
          if (profile == null) return _createProfileWizard();
          
          final advice = GrossesseAdviceService.getWeekAdvice(profile.sa);
          final info = GrossesseAdviceService.getBabyInfo(profile.sa);
          
          return Column(children: [
            _riskAlerts(profile),
            _dashboardCompact(profile, info), // <-- Nouvelle bande Hero réduite
            Container(
              color: Colors.white,
              child: TabBar(
                  controller: _tab,
                  isScrollable: true,
                  indicatorColor: ThixSanteColors.primary,
                  indicatorWeight: 3,
                  labelColor: ThixSanteColors.primary,
                  unselectedLabelColor: Colors.grey.shade400,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Bébé'),
                    Tab(text: 'Maman'),
                    Tab(text: 'RDV & Docs'),
                    Tab(text: 'Journal'),
                    Tab(text: 'Prépa'),
                    Tab(text: 'Urgences')
                  ]),
            ),
            Expanded(
                child: TabBarView(controller: _tab, children: [
              _tabBebe(profile, advice, info),
              _tabMaman(),
              _tabDocs(),
              _tabJournal(),
              _tabPrepa(profile),
              _tabUrgences(profile)
            ])),
          ]);
        },
      ),
    );
  }

  // ================= DASHBOARD HERO RÉDUIT =================
  Widget _dashboardCompact(PregnancyProfile p, BabyWeekInfo info) {
    final isLabor = p.sa >= 37;
    final recordsAsync = ref.watch(grossesseRecordsProvider(pid));

    return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLabor ? [Colors.red.shade700, const Color(0xFFB91C1C)] : [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)], 
              begin: Alignment.topLeft, end: Alignment.bottomRight
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: (isLabor ? Colors.red : const Color(0xFF6D28D9)).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))]
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Semaines et Trimester
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${p.sa} SA + ${p.daysRemain}j', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text(p.trimester().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
                  ]),
              const SizedBox(height: 12),
              
              // Ligne 2 : Info Bébé et Countdown
              Row(
                children: [
                  Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(info.fruit, style: const TextStyle(fontSize: 24)))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Taille : ${info.fruit}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('📏 ${info.size}  •  ⚖️ ${info.weight}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12))
                      ],
                    ),
                  ),
                  CountdownWidget(dpa: p.dpa),
                ]
              ),
              const SizedBox(height: 12),
              
              // Ligne 3 : Barre de progression + Prochain RDV
              ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: p.progress, backgroundColor: Colors.white.withOpacity(0.2), valueColor: const AlwaysStoppedAnimation(Colors.white), minHeight: 6)),
              recordsAsync.when(
                data: (records) {
                  if (records.isEmpty) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(children: [
                      const Icon(Icons.event_available, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Text('RDV : ${records.first.title}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis))
                    ]),
                  );
                },
                loading: () => const SizedBox(), error: (_, __) => const SizedBox()
              )
            ]));
  }

  // ================= ONGLETS =================

  Widget _tabBebe(PregnancyProfile p, WeekAdvice advice, BabyWeekInfo info) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(advice.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: advice.babyDevelopment.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('✨ ', style: TextStyle(fontSize: 12)), Expanded(child: Text(e, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155))))]))).toList()
        )
      ),
      const SizedBox(height: 16),
      
      // Nouvelle section : Idées de prénoms
      const Text('👶 Idées de Prénoms', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
      const SizedBox(height: 8),
      _buildCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPrenomList('Filles 🌸', _prenomsFilles, Colors.pink.shade50, Colors.pink)),
                const SizedBox(width: 12),
                Expanded(child: _buildPrenomList('Garçons 💙', _prenomsGarcons, Colors.blue.shade50, Colors.blue)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _showAddPrenomDialog, 
                icon: const Icon(Icons.add, size: 18), 
                label: const Text('Ajouter une idée'),
                style: TextButton.styleFrom(foregroundColor: ThixSanteColors.primary)
              ),
            )
          ],
        )
      ),
      const SizedBox(height: 16),
      _kickCounter()
    ]);
  }

  Widget _buildPrenomList(String title, List<String> list, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: textColor, fontSize: 13)),
          const SizedBox(height: 8),
          if (list.isEmpty) Text('Aucun', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic)),
          ...list.map((name) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [const Icon(Icons.favorite, size: 10, color: Colors.black26), const SizedBox(width: 6), Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]),
          ))
        ],
      ),
    );
  }

  void _showAddPrenomDialog() {
    final ctrl = TextEditingController();
    bool isFille = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateLocal) => AlertDialog(
          title: const Text('Nouveau prénom', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Ex: Léo, Mia...', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ChoiceChip(label: const Text('Fille 🌸'), selected: isFille, onSelected: (v) => setStateLocal(() => isFille = true))),
                  const SizedBox(width: 8),
                  Expanded(child: ChoiceChip(label: const Text('Garçon 💙'), selected: !isFille, onSelected: (v) => setStateLocal(() => isFille = false))),
                ],
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                if(ctrl.text.trim().isNotEmpty) {
                  setState(() {
                    if (isFille) _prenomsFilles.add(ctrl.text.trim());
                    else _prenomsGarcons.add(ctrl.text.trim());
                  });
                }
                Navigator.pop(context);
              }, 
              child: const Text('Ajouter')
            )
          ],
        )
      )
    );
  }

  Widget _tabPrepa(PregnancyProfile p) {
    final checks = ref.watch(checklistProvider(pid));
    final contractions = ref.watch(contractionsProvider(pid));
    
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Section Plan de Naissance & Education (FONCTIONNELLE)
      const Text('📚 Plan & Éducation', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: InkWell(
          onTap: _showPlanNaissance,
          child: Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade100)), child: const Column(children: [Icon(Icons.assignment_turned_in, color: Colors.blue, size: 28), SizedBox(height: 8), Text('Plan Naissance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent))]))
        )),
        const SizedBox(width: 12),
        Expanded(child: InkWell(
          onTap: _showConseils,
          child: Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.purple.shade100)), child: const Column(children: [Icon(Icons.auto_stories, color: Colors.purple, size: 28), SizedBox(height: 8), Text('Conseils', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent))]))
        )),
      ]),
      const SizedBox(height: 24),

      // Suivi des Contractions Intelligent
      const Text('⏱️ Chronomètre Contractions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      _buildCard(
        child: Column(children: [
          Text('$_cSec s', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: ThixSanteColors.primary)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
                onPressed: isDoctor ? null : _toggleContraction,
                style: ElevatedButton.styleFrom(backgroundColor: _cTimer == null ? const Color(0xFF10B981) : const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(_cTimer == null ? 'DÉMARRER' : 'ARRÊTER', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)))
          ),
          const SizedBox(height: 16),
          contractions.when(
              data: (List<PregnancyContraction> list) {
                if (list.isEmpty) return const Text('Aucune contraction enregistrée', style: TextStyle(fontSize: 12, color: Colors.grey));
                return Column(children: [
                  const Align(alignment: Alignment.centerLeft, child: Text('Dernières contractions :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ...list.take(3).map((c) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.timer_outlined, color: Colors.grey, size: 18), title: Text('Durée : ${c.durationSec}s', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), trailing: Text('Intervalle : ${(c.intervalSec / 60).toStringAsFixed(1)} min', style: const TextStyle(color: Colors.grey, fontSize: 12))))
                ]);
              },
              loading: () => const CircularProgressIndicator(), error: (_, __) => const Text('Erreur')),
        ])
      ),
      
      const SizedBox(height: 24),
      
      // Valise avec Planification Achats
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('🎒 Ma Valise & Achats', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
          IconButton(icon: const Icon(Icons.add_circle, color: ThixSanteColors.primary), onPressed: _showAddValiseItemDialog)
        ],
      ),
      const SizedBox(height: 8),
      _buildCard(
        padding: EdgeInsets.zero,
        child: checks.when(
            data: (List<ChecklistItem> list) {
              if(list.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Votre liste est vide.'));
              return Column(
                children: list.map((c) => CheckboxListTile(
                        value: c.done,
                        activeColor: ThixSanteColors.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(c.item, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.done ? Colors.grey : Colors.black87, decoration: c.done ? TextDecoration.lineThrough : null)),
                        onChanged: (v) async {
                          await ref.read(grossesseServiceProvider).toggleChecklist(c.id, v!);
                          ref.invalidate(checklistProvider(pid));
                        }))
                   .toList()
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const Text('Erreur')),
      ),
      const SizedBox(height: 40),
    ]);
  }

  // ================= MODALES PRÉPA (PLAN & CONSEILS) =================
  
  void _showPlanNaissance() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in, color: Colors.blue, size: 28),
                  SizedBox(width: 12),
                  Text('Mon Plan de Naissance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Sélectionnez vos préférences pour le jour J. Ce document pourra être partagé avec votre équipe médicale pour respecter vos choix.', style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
              const SizedBox(height: 20),
              _buildPrefItem(Icons.vaccines, 'Gestion de la douleur', 'Péridurale, Bain chaud, Hypnose...'),
              _buildPrefItem(Icons.nightlight_round, 'Ambiance souhaitée', 'Lumière tamisée, Musique douce...'),
              _buildPrefItem(Icons.group, 'Accompagnant(s)', 'Conjoint, Doula, Mère...'),
              _buildPrefItem(Icons.child_care, 'Accueil du bébé', 'Peau à peau immédiat, Allaitement...'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Valider mes préférences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))
                )
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      }
    );
  }

  void _showConseils() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_stories, color: Colors.purple, size: 28),
                  SizedBox(width: 12),
                  Text('Conseils Pratiques', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle), child: const Icon(Icons.shopping_bag, color: Colors.purple)),
                title: const Text('Quand préparer sa valise ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), subtitle: const Padding(padding: EdgeInsets.only(top: 4), child: Text('Idéalement autour de 32 SA pour être sereine en cas de départ précipité.', style: TextStyle(fontSize: 12, height: 1.4))),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero, leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle), child: const Icon(Icons.directions_walk, color: Colors.purple)),
                title: const Text('Activité physique', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), subtitle: const Padding(padding: EdgeInsets.only(top: 4), child: Text('La marche, la natation ou le yoga prénatal sont fortement recommandés.', style: TextStyle(fontSize: 12, height: 1.4))),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      }
    );
  }

  Widget _buildPrefItem(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
        onTap: () {}, // Action future
      ),
    );
  }

  void _showAddValiseItemDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter à la valise', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Ex: Biberons, Couches...', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, foregroundColor: Colors.white),
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
            child: const Text('Ajouter')
          )
        ],
      )
    );
  }

  // ================= UTILITAIRES & AUTRES ONGLETS =================
  
  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))]),
      child: child,
    );
  }

  Widget _kickCounter() {
    final kicksAsync = ref.watch(kicksProvider(pid));
    return kicksAsync.when(
        data: (List<PregnancyKick> list) {
          final today = list.where((k) => k.createdAt.day == DateTime.now().day).length;
          return _buildCard(
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(children: [Icon(Icons.pan_tool_rounded, color: ThixSanteColors.primary, size: 20), SizedBox(width: 8), Text('Mouvements (Aujourd\'hui)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))]),
                      Text('$today / 10', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixSanteColors.primary))
                    ]),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (today / 10).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: Colors.grey.shade100, valueColor: const AlwaysStoppedAnimation(ThixSanteColors.primary))),
                if (!isDoctor)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                              onPressed: () async { await ref.read(grossesseServiceProvider).addKick(pid); ref.invalidate(kicksProvider(pid)); },
                              icon: const Icon(Icons.add, color: Colors.white, size: 18),
                              label: const Text('Enregistrer un coup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
              ]));
        },
        loading: () => const CircularProgressIndicator(), error: (_, __) => const Text('Erreur'));
  }

  Widget _tabMaman() {
    final vitals = ref.watch(vitalsProvider(pid));
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('📈 Suivi du Poids', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      _buildCard(
          child: SizedBox(
            height: 200,
            child: vitals.when(
                data: (List<PregnancyVital> list) {
                  final poids = list.where((v) => v.type == 'poids').toList().reversed.take(7).toList().reversed.toList();
                  if (poids.isEmpty) return const Center(child: Text('Aucune donnée de poids pour le moment', style: TextStyle(fontSize: 12, color: Colors.grey)));
                  final spots = <FlSpot>[];
                  for (int i = 0; i < poids.length; i++) { spots.add(FlSpot(i.toDouble(), double.tryParse(poids[i].value) ?? 0)); }
                  return LineChart(LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: ThixSanteColors.primary, barWidth: 4, belowBarData: BarAreaData(show: true, color: ThixSanteColors.primary.withOpacity(0.1)), dotData: const FlDotData(show: true))]
                  ));
                },
                loading: () => const Center(child: CircularProgressIndicator()), error: (_, __) => const Text('Erreur')),
          )),
      const SizedBox(height: 24),
      const Text('Saisie Rapide', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _buildActionBtn('⚖️ Poids', () => _addVital('poids'))),
        const SizedBox(width: 8),
        Expanded(child: _buildActionBtn('🩸 Tension', () => _addVital('tension'))),
        const SizedBox(width: 8),
        Expanded(child: _buildActionBtn('💧 Glycémie', () => _addVital('glycemie'))),
      ]),
    ]);
  }
  
  Widget _buildActionBtn(String title, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ThixSanteColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)), padding: const EdgeInsets.symmetric(vertical: 12)),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }

  Widget _tabDocs() {
    final records = ref.watch(grossesseRecordsProvider(pid));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        if (isDoctor) Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.add, size: 18), label: const Text('Consultation', style: TextStyle(fontWeight: FontWeight.bold)), onPressed: _addConsultation)),
        if (isDoctor) const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: ThixSanteColors.primary, side: const BorderSide(color: ThixSanteColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.upload_file, size: 18), label: const Text('Ajouter Doc', style: TextStyle(fontWeight: FontWeight.bold)), onPressed: _pickDoc)),
      ]),
      const SizedBox(height: 24),
      const Text('Dossier Médical', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      records.when(
          data: (list) {
            if (list.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Aucun document.", style: TextStyle(color: Colors.grey))));
            return Column(children: list.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: ListTile(
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ThixSanteColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.description, color: ThixSanteColors.primary, size: 20)),
                  title: Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  subtitle: Text(r.description ?? 'Aucune note', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey))
            )).toList());
          },
          loading: () => const CircularProgressIndicator(), error: (e, _) => Text('Erreur $e')),
    ]);
  }

  Widget _tabJournal() {
    final journals = ref.watch(journalProvider(pid));
    return Stack(children: [
      journals.when(
          data: (List<PregnancyJournal> list) {
            final monthEntries = list.where((j) => j.createdAt.month == DateTime.now().month).length;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFEDD5))),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFEA580C), size: 28),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Résumé de votre mois', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF9A3412))),
                      const SizedBox(height: 2),
                      Text('$monthEntries souvenir(s) enregistré(s)', style: const TextStyle(fontSize: 12, color: Color(0xFFC2410C), fontWeight: FontWeight.w600)),
                    ])
                  ]),
                ),
                const SizedBox(height: 20),
                ...list.map((j) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)]),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (j.photoUrl != null)
                            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: Image.network(j.photoUrl!, height: 200, width: double.infinity, fit: BoxFit.cover)),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(j.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                const SizedBox(height: 6),
                                Text(j.content, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
                                const SizedBox(height: 12),
                                Text(j.createdAt.toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        ])))
              ]
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()), error: (_, __) => const Text('Erreur')),
      if (!isDoctor)
        Positioned(bottom: 16, right: 16, child: FloatingActionButton.extended(onPressed: _addJournalPhoto, backgroundColor: ThixSanteColors.primary, icon: const Icon(Icons.add_a_photo, color: Colors.white), label: const Text('Nouveau Souvenir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
    ]);
  }

  Widget _tabUrgences(PregnancyProfile p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Quand se rendre à la Maternité ?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade100)),
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
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
              onPressed: (){}, 
              icon: const Icon(Icons.phone_in_talk, size: 32), 
              label: Text('APPELER LA MATERNITÉ\nDPA: ${p.dpa.day}/${p.dpa.month}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))
            )
          ]);

  Widget _createProfileWizard() {
    final ctrl = TextEditingController();
    PregnancyType selectedType = PregnancyType.singleton;
    
    return StatefulBuilder(
      builder: (context, setLocal) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                const Text('🤰', style: TextStyle(fontSize: 60)), 
                const SizedBox(height: 16),
                const Text('Bienvenue !', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF1E293B))),
                const SizedBox(height: 8),
                const Text('Configurons votre suivi de grossesse.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 32),
                
                DropdownButtonFormField<PregnancyType>(
                  value: selectedType, 
                  decoration: InputDecoration(
                    labelText: 'Type de grossesse',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.people_alt_outlined)
                  ),
                  items: PregnancyType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(), 
                  onChanged: (v) { if (v != null) setLocal(() => selectedType = v); }
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: ctrl, 
                  readOnly: true, 
                  decoration: InputDecoration(
                    labelText: 'Date des Dernières Règles (DDR)', 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.calendar_month, color: ThixSanteColors.primary)
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
                  height: 55, 
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixSanteColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4
                    ),
                    onPressed: () async { 
                      if (ctrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer la DDR')));
                        return;
                      }
                      // Enregistrement dans Supabase
                      await ref.read(grossesseServiceProvider).createProfile(pid, DateTime.parse(ctrl.text), selectedType); 
                      // Rafraîchissement de la page
                      ref.invalidate(grossesseProfileProvider(pid)); 
                    }, 
                    child: const Text('DÉMARRER MON SUIVI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))
                  )
                ),
              ]
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
          child: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text("Grossesse normale - Pensez à vos vitamines", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534))))
          ]));
    }
    return Column(
        children: risks.map((r) => Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCA5A5))),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))))
                ]))).toList());
  }

  
  // ================= MÉTHODES (Ajout, Upload, etc.) =================
  
  void _addVital(String type) async {
    final c = TextEditingController();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
                title: Text('Ajouter : $type', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))), hintText: 'Valeur')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () async {
                        await ref.read(grossesseServiceProvider).addVital(pid, type, c.text);
                        ref.invalidate(vitalsProvider(pid));
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Valider', style: TextStyle(color: Colors.white)))
                ]));
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
                title: const Text('Nouvelle Consultation', style: TextStyle(fontWeight: FontWeight.w800)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: t, decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: d, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()))
                ]),
                actions: [
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary),
                      onPressed: () async {
                        await ref.read(grossesseServiceProvider).addConsultation(pid, t.text, d.text);
                        ref.invalidate(grossesseRecordsProvider(pid));
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Enregistrer', style: TextStyle(color: Colors.white)))
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
          const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 8, color: Colors.red)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.red)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)),
            ],
          ))
        ],
      ),
    );
  }
}
