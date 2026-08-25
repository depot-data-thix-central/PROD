// lib/presentation/thix_sante/patient/patient_dashboard_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; // ✅ NÉCESSAIRE POUR LE GLASSMORPHISM
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ POLICY THIX APPLIQUÉE
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'screens/mon_medecin_traitant_page.dart';
import 'screens/dossier_famille_page.dart';
import 'screens/second_avis_page.dart';
import 'screens/dossier_medical_page.dart';
import 'screens/resultats_examens_page.dart';
import 'screens/mes_ordonnances_page.dart';
import 'screens/consulter_medecin_page.dart';
import 'screens/trouver_hopital_page.dart';
import 'screens/trouver_medicament_page.dart';
import 'screens/pharmacies_proches_page.dart';
import 'screens/urgences_proches_page.dart';
import 'screens/prendre_rdv_page.dart';
import 'screens/teleconsultation_page.dart';
import 'screens/assistant_ia_page.dart';
import 'screens/dossier_partage_page.dart';
import 'screens/epidemies_page.dart';
import 'screens/don_sang_page.dart';
import 'screens/rappels_vaccin_page.dart';
import 'screens/certificat_medical_page.dart';
import 'screens/assurance_sante_page.dart';
import 'screens/sante_enfants_page.dart';
import 'screens/carnet_vaccination_page.dart';
import 'screens/suivi_grossesse_page.dart';
import 'screens/analyse_predictive_page.dart';
import 'screens/bien_etre_mental_page.dart';
import 'screens/nutrition_page.dart';
import 'screens/activite_physique_page.dart';
import 'screens/gestion_stress_page.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE SANTÉ PREMIUM
// ═══════════════════════════════════════════════════════════════════════════
class _HealthColors {
  _HealthColors._();
  static const Color primary = Color(0xFF0E7C86); // Teal médical
  static const Color primaryDeep = Color(0xFF063E44);
  static const Color primarySoft = Color(0xFFE6F3F4);
  static const Color emergency = Color(0xFFDC2626); // Rouge urgence strict
  static const Color info = Color(0xFF2563EB); // Bleu clinique
}

class DashboardStats {
  final int consultations, examens, medicaments, rdvs;
  const DashboardStats({
    this.consultations = 0,
    this.examens = 0,
    this.medicaments = 0,
    this.rdvs = 0,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return const DashboardStats();
  try {
    final c = await db.from('health_links').select('id').eq('patient_id', uid);
    final e = await db.from('health_records').select('id').eq('patient_id', uid);
    final p = await db.from('prescriptions').select('id').eq('patient_id', uid).neq('status', 'delivree');
    final r = await db.from('appointments').select('id').eq('patient_id', uid).gte('date_rdv', DateTime.now().toIso8601String());
    return DashboardStats(
      consultations: (c as List).length,
      examens: (e as List).length,
      medicaments: (p as List).length,
      rdvs: (r as List).length,
    );
  } catch (_) {
    return const DashboardStats();
  }
});

class PatientProfile {
  final String name;
  final String? avatarUrl;
  const PatientProfile({required this.name, this.avatarUrl});
}

final patientProfileProvider = FutureProvider<PatientProfile>((ref) async {
  final db = Supabase.instance.client;
  final user = db.auth.currentUser;
  if (user == null) return const PatientProfile(name: 'Patient');
  try {
    final res = await db.from('profiles').select('full_name, avatar_url').eq('id', user.id).maybeSingle();
    final name = (res?['full_name'] as String?)?.trim();
    final avatar = res?['avatar_url'] as String?;
    if (name != null && name.isNotEmpty) return PatientProfile(name: name, avatarUrl: avatar);
  } catch (_) {}
  final metaName = user.userMetadata?['full_name'] as String?;
  return PatientProfile(name: (metaName != null && metaName.isNotEmpty) ? metaName : 'Patient');
});

// Structure des services (titre ultra court pour la grille)
class ServiceItem {
  final String title;
  final IconData icon;
  final Widget page;
  ServiceItem(this.title, this.icon, this.page);
}

class PatientDashboardPage extends ConsumerStatefulWidget {
  const PatientDashboardPage({super.key});
  @override
  ConsumerState<PatientDashboardPage> createState() => _PatientDashboardPageState();
}

class _PatientDashboardPageState extends ConsumerState<PatientDashboardPage> {
  int _selectedNav = 0;

  late final List<ServiceItem> _dossierServices = [
    ServiceItem('Ordonnances', Icons.receipt_long_rounded, const MesOrdonnancesPage()),
    ServiceItem('Résultats', Icons.biotech_rounded, const ResultatsExamensPage()),
    ServiceItem('Vaccins', Icons.vaccines_rounded, const CarnetVaccinationPage()),
    ServiceItem('Historique', Icons.folder_shared_rounded, const DossierMedicalPage()),
    ServiceItem('Assurance', Icons.shield_rounded, const AssuranceSantePage()),
    ServiceItem('Partage', Icons.share_rounded, const DossierPartagePage()),
    ServiceItem('Certificats', Icons.description_rounded, const CertificatMedicalPage()),
    ServiceItem('Analyse IA', Icons.query_stats_rounded, const AnalysePredictivePage()),
  ];

  late final List<ServiceItem> _careServices = [
    ServiceItem('Pharmacies', Icons.local_pharmacy_rounded, const PharmaciesProchesPage()),
    ServiceItem('Hôpitaux', Icons.local_hospital_rounded, const TrouverHopitalPage()),
    ServiceItem('Médicaments', Icons.medication_rounded, const TrouverMedicamentPage()),
    ServiceItem('RDV', Icons.medical_services_rounded, const ConsulterMedecinPage()),
    ServiceItem('Don de sang', Icons.bloodtype_rounded, const DonSangPage()),
    ServiceItem('Avis Expert', Icons.people_alt_rounded, const SecondAvisPage()),
    ServiceItem('Épidémies', Icons.coronavirus_rounded, const EpidemiesPage()),
    ServiceItem('Téléconsult', Icons.video_call_rounded, const TeleconsultationPage()),
  ];

  late final List<ServiceItem> _familyServices = [
    ServiceItem('Profils', Icons.family_restroom_rounded, const DossierFamillePage()),
    ServiceItem('Maternité', Icons.pregnant_woman_rounded, const SuiviGrossessePage()),
    ServiceItem('Pédiatrie', Icons.child_care_rounded, const SanteEnfantsPage()),
    ServiceItem('Rappels', Icons.notifications_active_rounded, const RappelsVaccinPage()),
  ];

  late final List<ServiceItem> _wellbeingServices = [
    ServiceItem('Nutrition', Icons.restaurant_rounded, const NutritionPage()),
    ServiceItem('Activité', Icons.directions_run_rounded, const ActivitePhysiquePage()),
    ServiceItem('Mental', Icons.psychology_rounded, const BienEtreMentalPage()),
    ServiceItem('Relaxation', Icons.self_improvement_rounded, const GestionStressPage()),
  ];

  void _go(Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(patientProfileProvider);
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB), // Fond clinique premium
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // 🌟 ARRIÈRE-PLAN MÉDICAL ANIMÉ ET FLOUTÉ
          const Positioned.fill(
            child: _MedicalAmbientBackground(),
          ),

          RefreshIndicator(
            color: _HealthColors.primary,
            backgroundColor: Colors.white,
            onRefresh: () async {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(patientProfileProvider);
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildClinicalHeader(profile),

                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 16, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHealthSummaryCard(stats),
                      const SizedBox(height: 24),

                      _buildSectionTitle('Dossier Médical'),
                      _buildServiceGrid(_dossierServices),
                      const SizedBox(height: 24),

                      _buildSectionTitle('Parcours de Soins'),
                      _buildServiceGrid(_careServices),
                      const SizedBox(height: 24),

                      _buildSectionTitle('Famille & Proches'),
                      _buildServiceGrid(_familyServices),
                      const SizedBox(height: 24),

                      _buildSectionTitle('Bien-être & Prévention'),
                      _buildServiceGrid(_wellbeingServices),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // 🌟 BARRE DE NAVIGATION FLOTTANTE
          _buildClinicalBottomNav(),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. EN-TÊTE CLINIQUE GLASSMORPHISM
  // =========================================================================
  Widget _buildClinicalHeader(AsyncValue<PatientProfile> profileAsync) {
    final fullName = profileAsync.valueOrNull?.name ?? 'Patient';
    final firstName = fullName.split(' ').first;
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      collapsedHeight: 70,
      expandedHeight: 70,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.2)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 44, width: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.5),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        image: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? const Icon(Icons.person_rounded, color: _HealthColors.primaryDeep, size: 22)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Bonjour, $firstName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: const [
                              Icon(Icons.verified_user_rounded, size: 12, color: ThixPolicy.success),
                              SizedBox(width: 4),
                              Text('Espace chiffré', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Bouton SOS Urgence (Rouge)
                    InkWell(
                      onTap: () => _go(const UrgencesProchesPage()),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _HealthColors.emergency.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _HealthColors.emergency.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.emergency_rounded, size: 16, color: _HealthColors.emergency),
                            SizedBox(width: 6),
                            Text('SOS', style: TextStyle(color: _HealthColors.emergency, fontSize: 13, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. CARTE DE SYNTHÈSE SANTÉ (Glassmorphism)
  // =========================================================================
  Widget _buildHealthSummaryCard(AsyncValue<DashboardStats> statsAsync) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.monitor_heart_rounded, color: _HealthColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Synthèse Santé', style: TextStyle(color: ThixPolicy.textMain, fontSize: 15, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _HealthColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Mois en cours', style: TextStyle(color: _HealthColors.primaryDeep, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              statsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: _HealthColors.primary))),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Erreur de chargement', style: TextStyle(color: ThixPolicy.textSecondary)),
                ),
                data: (d) => Row(
                  children: [
                    _statTile(Icons.medical_information_rounded, 'Visites', d.consultations, _HealthColors.primary),
                    _statDivider(),
                    _statTile(Icons.biotech_rounded, 'Examens', d.examens, _HealthColors.info),
                    _statDivider(),
                    _statTile(Icons.medication_liquid_rounded, 'Ordon.', d.medicaments, ThixPolicy.gold),
                    _statDivider(),
                    _statTile(Icons.event_available_rounded, 'RDV', d.rdvs, _HealthColors.primaryDeep),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(IconData icon, String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text('$value', style: TextStyle(color: ThixPolicy.textMain, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(height: 40, width: 1, color: ThixPolicy.border, margin: const EdgeInsets.symmetric(horizontal: 4));
  }

  // =========================================================================
  // 3. TITRES DE SECTION
  // =========================================================================
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain, letterSpacing: -0.3)),
    );
  }

  // =========================================================================
  // 4. GRILLE DE SERVICES (Design "4 Colonnes" Premium)
  // =========================================================================
  Widget _buildServiceGrid(List<ServiceItem> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // 🌟 4 Colonnes pour un vrai dashboard
          crossAxisSpacing: 8,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8, // Ajustement pour laisser la place au texte
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final it = items[index];
          return GestureDetector(
            onTap: () => _go(it.page),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Icon(it.icon, color: _HealthColors.primaryDeep, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  it.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.textMain, height: 1.1),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 5. NAVIGATION BASSE FLOATING (Glassmorphism)
  // =========================================================================
  Widget _buildClinicalBottomNav() {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _navItem(Icons.home_rounded, 'Accueil', 0),
                          _navItem(Icons.folder_shared_rounded, 'Dossier', 1, page: const DossierMedicalPage()),
                          const SizedBox(width: 60), // Espace pour l'IA centrale
                          _navItem(Icons.search_rounded, 'Recherche', 3, page: const TrouverHopitalPage()),
                          _navItem(Icons.person_outline_rounded, 'Famille', 4, page: const DossierFamillePage()),
                        ],
                      ),
                      Positioned(
                        top: -20,
                        child: GestureDetector(
                          onTap: () => _go(const AssistantIAPage()),
                          child: Container(
                            width: 60, height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _HealthColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3.5),
                              boxShadow: [BoxShadow(color: _HealthColors.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, {Widget? page}) {
    final sel = _selectedNav == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (page != null) {
          _go(page);
        } else {
          setState(() => _selectedNav = index);
        }
      },
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: sel ? _HealthColors.primaryDeep : ThixPolicy.textSecondary.withValues(alpha: 0.8), size: 24),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, style: TextStyle(fontSize: 9.5, color: sel ? _HealthColors.primaryDeep : ThixPolicy.textSecondary.withValues(alpha: 0.8), fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// // ============================================================================
// WIDGET : BACKGROUND MÉDICAL ANIMÉ (OPTIMISÉ POUR HAUTES PERFORMANCES)
// ============================================================================
class _MedicalAmbientBackground extends StatefulWidget {
  const _MedicalAmbientBackground();

  @override
  State<_MedicalAmbientBackground> createState() => _MedicalAmbientBackgroundState();
}

class _MedicalAmbientBackgroundState extends State<_MedicalAmbientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Animation douce (15 secondes)
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🌟 HELPER HAUTE PERFORMANCE : Utilise un RadialGradient au lieu d'un Flou GPU
  Widget _buildPerformanceOrb(double x, double y, double size, Color color) {
    return Positioned(
      left: x - (size / 2),
      top: y - (size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color, 
              color.withOpacity(0.0) // Se fond de manière invisible dans le décor
            ],
            stops: const [0.1, 1.0], // Crée un effet de halo très doux
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: RepaintBoundary( // Empêche l'animation de recalculer l'UI entière
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;

            // Orb 1 (Rouge doux)
            final heartX = size.width * 0.5 + math.cos(t) * (size.width * 0.4);
            final heartY = size.height * 0.2 + math.sin(t * 1.5) * (size.height * 0.2);

            // Orb 2 (Teal)
            final crossX = size.width * 0.3 + math.sin(t * 1.2) * (size.width * 0.5);
            final crossY = size.height * 0.6 + math.cos(t) * (size.height * 0.15);

            // Orb 3 (Bleu)
            final shieldX = size.width * 0.7 + math.cos(t * 0.8) * 120.0;
            final shieldY = size.height * 0.5 + math.sin(t * 1.1) * 150.0;

            return Stack(
              children: [
                // Fond propre
                Positioned.fill(child: Container(color: const Color(0xFFF4F7FB))),
                
                // Orbes animés sans aucun flou GPU (Coût de performance = 0)
                _buildPerformanceOrb(heartX, heartY, 500, _HealthColors.emergency.withOpacity(0.12)),
                _buildPerformanceOrb(crossX, crossY, 550, _HealthColors.primary.withOpacity(0.15)),
                _buildPerformanceOrb(shieldX, shieldY, 600, _HealthColors.info.withOpacity(0.10)),
              ],
            );
          },
        ),
      ),
    );
  }
}
