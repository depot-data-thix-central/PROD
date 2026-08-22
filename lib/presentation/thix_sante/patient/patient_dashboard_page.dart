// lib/presentation/thix_sante/patient/patient_dashboard_page.dart
import 'dart:async';
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
// PALETTE SANTÉ PRO (Fini l'arc-en-ciel, place au sérieux médical)
// ═══════════════════════════════════════════════════════════════════════════
class _HealthColors {
  _HealthColors._();
  static const Color primary = Color(0xFF0E7C86); // Teal médical
  static const Color primaryDeep = Color(0xFF083E44);
  static const Color primarySoft = Color(0xFFE6F3F4);
  static const Color emergency = Color(0xFFDC2626); // Rouge urgence strict
  static const Color emergencySoft = Color(0xFFFEF2F2);
  
  static const LinearGradient statsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
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

// Simplifié : on n'a plus besoin des couleurs pour chaque item
class ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
  ServiceItem(this.title, this.subtitle, this.icon, this.page);
}

class PatientDashboardPage extends ConsumerStatefulWidget {
  const PatientDashboardPage({super.key});
  @override
  ConsumerState<PatientDashboardPage> createState() => _PatientDashboardPageState();
}

class _PatientDashboardPageState extends ConsumerState<PatientDashboardPage> {
  late final List<ServiceItem> _dossierServices = [
    ServiceItem('Ordonnances', 'Prescriptions actives', Icons.receipt_long_rounded, const MesOrdonnancesPage()),
    ServiceItem('Résultats', 'Labo & imagerie', Icons.biotech_rounded, const ResultatsExamensPage()),
    ServiceItem('Vaccins', 'Carnet à jour', Icons.vaccines_rounded, const CarnetVaccinationPage()),
    ServiceItem('Historique', 'Dossier complet', Icons.folder_shared_rounded, const DossierMedicalPage()),
    ServiceItem('Assurance', 'Couverture santé', Icons.shield_rounded, const AssuranceSantePage()),
    ServiceItem('Partage', 'Accès médecins', Icons.share_rounded, const DossierPartagePage()),
  ];

  late final List<ServiceItem> _careServices = [
    ServiceItem('Médicaments', 'Disponibilité en pharmacie', Icons.medication_rounded, const TrouverMedicamentPage()),
    ServiceItem('Second Avis', 'Experts médicaux', Icons.people_alt_rounded, const SecondAvisPage()),
    ServiceItem('Don de sang', 'Centres de don proches', Icons.bloodtype_rounded, const DonSangPage()),
    ServiceItem('Rendez-vous', 'Planification des consultations', Icons.medical_services_rounded, const ConsulterMedecinPage()),
    ServiceItem('Épidémies', 'Alertes sanitaires locales', Icons.coronavirus_rounded, const EpidemiesPage()),
  ];

  late final List<ServiceItem> _familyServices = [
    ServiceItem('Profils', 'Gérer les membres de la famille', Icons.family_restroom_rounded, const DossierFamillePage()),
    ServiceItem('Maternité', 'Suivi de grossesse', Icons.pregnant_woman_rounded, const SuiviGrossessePage()),
    ServiceItem('Pédiatrie', 'Santé des enfants', Icons.child_care_rounded, const SanteEnfantsPage()),
    ServiceItem('Rappels', 'Prochains soins et vaccins', Icons.notifications_active_rounded, const RappelsVaccinPage()),
  ];

  late final List<ServiceItem> _wellbeingServices = [
    ServiceItem('Nutrition', 'Suivi alimentaire', Icons.restaurant_rounded, const NutritionPage()),
    ServiceItem('Activité', 'Sport et fitness', Icons.directions_run_rounded, const ActivitePhysiquePage()),
    ServiceItem('Psychologie', 'Santé mentale', Icons.psychology_rounded, const BienEtreMentalPage()),
    ServiceItem('Relaxation', 'Gestion du stress', Icons.self_improvement_rounded, const GestionStressPage()),
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
      backgroundColor: ThixPolicy.surfaceSoft, // Fond d'appli très propre
      body: Stack(
        children: [
          RefreshIndicator(
            color: _HealthColors.primary,
            backgroundColor: ThixPolicy.card,
            onRefresh: () async {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(patientProfileProvider);
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildClinicalHeader(profile),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s4, ThixPolicy.s20, 130),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHealthSummaryCard(stats),
                      const SizedBox(height: ThixPolicy.s28),

                      _buildSectionTitle('Accès rapide'),
                      _buildQuickAccessRow(),
                      const SizedBox(height: ThixPolicy.s28),

                      _buildSectionTitle('Dossier médical'),
                      _buildGroupedList(_dossierServices),
                      const SizedBox(height: ThixPolicy.s28),

                      _buildSectionTitle('Parcours de soins'),
                      _buildGroupedList(_careServices),
                      const SizedBox(height: ThixPolicy.s28),

                      _buildSectionTitle('Famille & proches'),
                      _buildGroupedList(_familyServices),
                      const SizedBox(height: ThixPolicy.s28),

                      _buildSectionTitle('Bien-être & prévention'),
                      _buildGroupedList(_wellbeingServices),
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
  // 1. EN-TÊTE CLINIQUE ÉPURÉ
  // =========================================================================
  Widget _buildClinicalHeader(AsyncValue<PatientProfile> profileAsync) {
    final fullName = profileAsync.valueOrNull?.name ?? 'Patient';
    final firstName = fullName.split(' ').first;
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;

    return SliverAppBar(
      backgroundColor: ThixPolicy.surfaceSoft,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      collapsedHeight: 88,
      expandedHeight: 88,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s10, ThixPolicy.s20, ThixPolicy.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 44, width: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _HealthColors.primarySoft,
                  border: Border.all(color: _HealthColors.primary.withOpacity(0.2), width: 1.5),
                  image: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(Icons.person_rounded, color: _HealthColors.primary, size: 22)
                    : null,
              ),
              const SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Bonjour, $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 12, color: ThixPolicy.success),
                        const SizedBox(width: 4),
                        Text('Connexion chiffrée', style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ThixPolicy.s10),
              InkWell(
                onTap: () => _go(const UrgencesProchesPage()),
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _HealthColors.emergencySoft,
                    borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                    border: Border.all(color: _HealthColors.emergency.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emergency_rounded, size: 16, color: _HealthColors.emergency),
                      const SizedBox(width: 6),
                      Text('SOS', style: ThixPolicy.labelStyle.copyWith(color: _HealthColors.emergency, fontWeight: ThixPolicy.bold, letterSpacing: 0.4)),
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
        gradient: _HealthColors.statsGradient,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: ThixPolicy.s8),
                  Text('Synthèse santé', style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                child: Text('30 derniers jours', style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.semiBold)),
              ),
            ],
          ),
          const SizedBox(height: ThixPolicy.s20),
          statsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Erreur de chargement', style: ThixPolicy.captionStyle.copyWith(color: Colors.white70)),
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
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(ThixPolicy.rXs)),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(height: 10),
          Text('$value', style: ThixPolicy.h2Style.copyWith(color: Colors.white, height: 1)),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.microStyle.copyWith(color: Colors.white.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(height: 46, width: 1, color: Colors.white.withOpacity(0.14), margin: const EdgeInsets.symmetric(horizontal: 10));
  }

  // =========================================================================
  // 3. ACCÈS RAPIDE (Cartes professionnelles horizontales)
  // =========================================================================
  Widget _buildQuickAccessRow() {
    return Row(
      children: [
        Expanded(
          child: _quickAccessCard(
            title: 'Pharmacies',
            subtitle: 'De garde à proximité',
            icon: Icons.local_pharmacy_rounded,
            onTap: () => _go(const PharmaciesProchesPage()),
          ),
        ),
        const SizedBox(width: ThixPolicy.s12),
        Expanded(
          child: _quickAccessCard(
            title: 'Hôpitaux',
            subtitle: 'Réseau de soins',
            icon: Icons.local_hospital_rounded,
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      child: Container(
        padding: const EdgeInsets.all(ThixPolicy.s16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.02),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _HealthColors.primarySoft, borderRadius: BorderRadius.circular(ThixPolicy.rXs)),
              child: Icon(icon, color: _HealthColors.primary, size: 20),
            ),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.microStyle),
                ],
              ),
            ),
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
      padding: const EdgeInsets.only(bottom: ThixPolicy.s12),
      child: Row(
        children: [
          Text(title, style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. LISTES GROUPÉES D'ENTREPRISE (Type Apple Health / Paramètres)
  // =========================================================================
  Widget _buildGroupedList(List<ServiceItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.02),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 56), // Ligne séparatrice
        itemBuilder: (context, index) {
          final it = items[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _go(it.page),
              borderRadius: BorderRadius.circular(
                index == 0 ? ThixPolicy.rMd : (index == items.length - 1 ? ThixPolicy.rMd : 0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _HealthColors.primarySoft,
                        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                      ),
                      child: Icon(it.icon, color: _HealthColors.primary, size: 20),
                    ),
                    const SizedBox(width: ThixPolicy.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.title, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                          const SizedBox(height: 2),
                          Text(it.subtitle, style: ThixPolicy.captionStyle),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: ThixPolicy.textMuted),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 6. NAVIGATION BASSE
  // =========================================================================
  Widget _buildClinicalBottomNav() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rXl),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowCard(),
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
                top: -20,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _go(const AssistantIAPage()),
                    child: Container(
                      height: 56, width: 56,
                      decoration: BoxDecoration(
                        color: _HealthColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.surfaceSoft, width: 4),
                        boxShadow: [BoxShadow(color: _HealthColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
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
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: active ? _HealthColors.primary : ThixPolicy.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: ThixPolicy.microStyle.copyWith(
                fontWeight: active ? ThixPolicy.bold : ThixPolicy.semiBold,
                color: active ? _HealthColors.primary : ThixPolicy.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
