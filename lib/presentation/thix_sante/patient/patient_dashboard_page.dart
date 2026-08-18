// lib/presentation/thix_sante/patient/patient_dashboard_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class _Med {
  _Med._();

  static const Color primary = Color(0xFF0E7C86);
  static const Color primaryDark = Color(0xFF0B5F68);
  static const Color primaryDeep = Color(0xFF083E44);
  static const Color primarySoft = Color(0xFFE3F2F3);

  static const Color trustBlue = Color(0xFF2D6CDF);
  static const Color trustBlueSoft = Color(0xFFEAF1FC);

  static const Color sage = Color(0xFF3F9C6D);
  static const Color sageSoft = Color(0xFFE6F4EC);
  static const Color amber = Color(0xFFC98A1E);
  static const Color amberSoft = Color(0xFFFBF1E0);
  static const Color violet = Color(0xFF6D5BD0);
  static const Color violetSoft = Color(0xFFEEEBFB);
  static const Color rose = Color(0xFFC5455B);
  static const Color roseSoft = Color(0xFFFAEAED);
  static const Color emergency = Color(0xFFCC3333);
  static const Color emergencySoft = Color(0xFFFBEAEA);
  static const Color slate = Color(0xFF556270);

  static const Color bgApp = Color(0xFFF4F8F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE1EAEA);
  static const Color divider = Color(0xFFEDF3F3);

  static const Color textPrimary = Color(0xFF122325);
  static const Color textSecondary = Color(0xFF5E7477);
  static const Color textMuted = Color(0xFF93A6A8);

  static const LinearGradient statsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
  );

  static const LinearGradient aiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary],
  );
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

class ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Widget page;
  ServiceItem(this.title, this.subtitle, this.icon, this.color, this.bgColor, this.page);
}

class PatientDashboardPage extends ConsumerStatefulWidget {
  const PatientDashboardPage({super.key});
  @override
  ConsumerState<PatientDashboardPage> createState() => _PatientDashboardPageState();
}

class _PatientDashboardPageState extends ConsumerState<PatientDashboardPage> {
  late final List<ServiceItem> _dossierServices = [
    ServiceItem('Ordonnances', 'Prescriptions actives', Icons.receipt_long_rounded, _Med.primaryDark, _Med.primarySoft, const MesOrdonnancesPage()),
    ServiceItem('Résultats', 'Labo & imagerie', Icons.biotech_rounded, _Med.trustBlue, _Med.trustBlueSoft, const ResultatsExamensPage()),
    ServiceItem('Vaccins', 'Carnet à jour', Icons.vaccines_rounded, _Med.sage, _Med.sageSoft, const CarnetVaccinationPage()),
    ServiceItem('Historique', 'Dossier complet', Icons.folder_shared_rounded, _Med.slate, _Med.divider, const DossierMedicalPage()),
    ServiceItem('Assurance', 'Couverture santé', Icons.shield_rounded, _Med.trustBlue, _Med.trustBlueSoft, const AssuranceSantePage()),
    ServiceItem('Partage', 'Accès médecins', Icons.share_rounded, _Med.violet, _Med.violetSoft, const DossierPartagePage()),
  ];

  late final List<ServiceItem> _careServices = [
    ServiceItem('Médicaments', 'Disponibilité pharmacie', Icons.medication_rounded, _Med.primaryDark, _Med.primarySoft, const TrouverMedicamentPage()),
    ServiceItem('Second Avis', 'Experts médicaux', Icons.people_alt_rounded, _Med.violet, _Med.violetSoft, const SecondAvisPage()),
    ServiceItem('Don de sang', 'Centres proches', Icons.bloodtype_rounded, _Med.emergency, _Med.emergencySoft, const DonSangPage()),
    ServiceItem('Rendez-vous', 'Planification', Icons.medical_services_rounded, _Med.sage, _Med.sageSoft, const ConsulterMedecinPage()),
    ServiceItem('Épidémies', 'Alertes locales', Icons.coronavirus_rounded, _Med.amber, _Med.amberSoft, const EpidemiesPage()),
  ];

  late final List<ServiceItem> _familyServices = [
    ServiceItem('Profils', 'Gérer la famille', Icons.family_restroom_rounded, _Med.primaryDark, _Med.primarySoft, const DossierFamillePage()),
    ServiceItem('Maternité', 'Suivi grossesse', Icons.pregnant_woman_rounded, _Med.rose, _Med.roseSoft, const SuiviGrossessePage()),
    ServiceItem('Pédiatrie', 'Santé enfants', Icons.child_care_rounded, _Med.trustBlue, _Med.trustBlueSoft, const SanteEnfantsPage()),
    ServiceItem('Rappels', 'Prochains soins', Icons.notifications_active_rounded, _Med.amber, _Med.amberSoft, const RappelsVaccinPage()),
  ];

  late final List<ServiceItem> _wellbeingServices = [
    ServiceItem('Nutrition', 'Suivi alimentaire', Icons.restaurant_rounded, _Med.amber, _Med.amberSoft, const NutritionPage()),
    ServiceItem('Activité', 'Sport & fitness', Icons.directions_run_rounded, _Med.sage, _Med.sageSoft, const ActivitePhysiquePage()),
    ServiceItem('Psychologie', 'Santé mentale', Icons.psychology_rounded, _Med.violet, _Med.violetSoft, const BienEtreMentalPage()),
    ServiceItem('Relaxation', 'Gestion du stress', Icons.self_improvement_rounded, _Med.primaryDark, _Med.primarySoft, const GestionStressPage()),
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
      backgroundColor: _Med.bgApp,
      body: Stack(
        children: [
          RefreshIndicator(
            color: _Med.primary,
            backgroundColor: _Med.surface,
            onRefresh: () async {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(patientProfileProvider);
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildClinicalHeader(profile),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHealthSummaryCard(stats),
                      const SizedBox(height: 28),

                      _buildSectionTitle('Accès rapide'),
                      _buildQuickAccessRow(),
                      const SizedBox(height: 32),

                      _buildSectionTitle('Dossier médical'),
                      _buildServiceGrid(_dossierServices),
                      const SizedBox(height: 28),

                      _buildSectionTitle('Parcours de soins'),
                      _buildServiceGrid(_careServices),
                      const SizedBox(height: 28),

                      _buildSectionTitle('Famille & proches'),
                      _buildServiceGrid(_familyServices),
                      const SizedBox(height: 28),

                      _buildSectionTitle('Bien-être & prévention'),
                      _buildServiceGrid(_wellbeingServices),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          _buildClinicalBottomNav(),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. EN-TÊTE CLINIQUE
  // =========================================================================
  Widget _buildClinicalHeader(AsyncValue<PatientProfile> profileAsync) {
    final fullName = profileAsync.valueOrNull?.name ?? 'Patient';
    final firstName = fullName.split(' ').first;
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;

    return SliverAppBar(
      backgroundColor: _Med.bgApp,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      collapsedHeight: 88,
      expandedHeight: 88,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 44, width: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _Med.primarySoft,
                  border: Border.all(color: _Med.primary.withOpacity(0.18), width: 1.4),
                  image: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(Icons.person_outline_rounded, color: _Med.primary, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour, $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _Med.textPrimary, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 12, color: _Med.sage),
                        const SizedBox(width: 4),
                        const Text('Connexion chiffrée', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _Med.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _go(const UrgencesProchesPage()),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: _Med.emergency,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: _Med.emergency.withOpacity(0.28), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emergency_rounded, size: 15, color: Colors.white),
                      SizedBox(width: 5),
                      Text('SOS', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. CARTE DE SYNTHÈSE SANTÉ
  // =========================================================================
  Widget _buildHealthSummaryCard(AsyncValue<DashboardStats> statsAsync) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: _Med.statsGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _Med.primaryDeep.withOpacity(0.22), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Synthèse santé', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.1)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
                child: const Text('30 derniers jours', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          statsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Erreur de chargement', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            data: (d) => Row(
              children: [
                _statTile(Icons.medical_information_rounded, 'Consultations', d.consultations),
                _statDivider(),
                _statTile(Icons.biotech_rounded, 'Examens', d.examens),
                _statDivider(),
                _statTile(Icons.medication_liquid_rounded, 'Traitements', d.medicaments),
                _statDivider(),
                _statTile(Icons.event_available_rounded, 'RDV', d.rdvs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String label, int value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(height: 10),
          Text('$value', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.72))),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(height: 46, width: 1, color: Colors.white.withOpacity(0.14), margin: const EdgeInsets.symmetric(horizontal: 10));
  }

  // =========================================================================
  // 3. ACCÈS RAPIDE
  // =========================================================================
  Widget _buildQuickAccessRow() {
    return Row(
      children: [
        Expanded(
          child: _quickAccessCard(
            title: 'Pharmacies',
            subtitle: 'De garde à proximité',
            icon: Icons.local_pharmacy_rounded,
            iconColor: _Med.sage,
            iconBg: _Med.sageSoft,
            onTap: () => _go(const PharmaciesProchesPage()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickAccessCard(
            title: 'Hôpitaux',
            subtitle: 'Réseau de soins',
            icon: Icons.local_hospital_rounded,
            iconColor: _Med.trustBlue,
            iconBg: _Med.trustBlueSoft,
            onTap: () => _go(const TrouverHopitalPage()),
          ),
        ),
      ],
    );
  }

  Widget _quickAccessCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _Med.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Med.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _Med.textPrimary, letterSpacing: -0.2)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: _Med.textSecondary)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. TITRES DE SECTION
  // =========================================================================
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: _Med.primary, borderRadius: BorderRadius.circular(999))),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _Med.textPrimary, letterSpacing: -0.3)),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. GRILLE DE SERVICES — 3 colonnes, icône + titre + sous-titre + flèche
  //    (remplace la liste verticale, disposition inspirée de la capture)
  // =========================================================================
  Widget _buildServiceGrid(List<ServiceItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final it = items[index];
        return InkWell(
          onTap: () => _go(it.page),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _Med.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _Med.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: it.bgColor, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Icon(it.icon, color: it.color, size: 19),
                ),
                const SizedBox(height: 10),
                Text(
                  it.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _Med.textPrimary, height: 1.15, letterSpacing: -0.1),
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: Text(
                    it.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _Med.textSecondary, height: 1.2),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.arrow_forward_rounded, size: 15, color: it.color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // 6. NAVIGATION BASSE
  // =========================================================================
  Widget _buildClinicalBottomNav() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 18, right: 18),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: _Med.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _Med.border),
            boxShadow: [BoxShadow(color: _Med.primaryDeep.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(Icons.home_rounded, 'Accueil', true, () {}),
                  _navItem(Icons.folder_shared_rounded, 'Dossier', false, () => _go(const DossierMedicalPage())),
                  const SizedBox(width: 54),
                  _navItem(Icons.search_rounded, 'Soins', false, () => _go(const TrouverHopitalPage())),
                  _navItem(Icons.people_alt_rounded, 'Famille', false, () => _go(const DossierFamillePage())),
                ],
              ),
              Positioned(
                top: -18,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _go(const AssistantIAPage()),
                    child: Container(
                      height: 58, width: 58,
                      decoration: BoxDecoration(
                        gradient: _Med.aiGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: _Med.bgApp, width: 4),
                        boxShadow: [BoxShadow(color: _Med.primary.withOpacity(0.32), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 56,
        height: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: active ? _Med.primary : _Med.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? _Med.primary : _Med.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
