// lib/presentation/thix_sante/sante/screens/plus_services_page.dart
// =============================================================================
// Screen: PlusServicesPage - Catalogue complet des services sante
// Role: Afficher tous les services (rapides + sante + nouveaux)
// Charte: THIX SANTE - Design System Medical Premium
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/presentation/thix_sante/core/thix_sante_colors.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/consulter_medecin_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/trouver_hopital_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/trouver_medicament_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/pharmacies_proches_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/urgences_proches_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/prendre_rdv_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/teleconsultation_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/assistant_ia_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/dossier_partage_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/epidemies_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/don_sang_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/rappels_vaccin_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/certificat_medical_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/assurance_sante_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/sante_enfants_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/carnet_vaccination_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/suivi_grossesse_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/analyse_predictive_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/bien_etre_mental_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/gestion_stress_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/mon_medecin_traitant_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/dossier_famille_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/second_avis_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/dossier_medical_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/resultats_examens_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/mes_ordonnances_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/nutrition_page.dart';
import 'package:thix_id/presentation/thix_sante/patient/screens/activite_physique_page.dart';

class PlusServicesPage extends ConsumerWidget {
  const PlusServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(
        backgroundColor: ThixSanteColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Plus de services',
          style: TextStyle(
            color: ThixSanteColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: ThixSanteColors.ink),
            onPressed: () {},
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildCategory(context, title: '⚡ Services rapides', services: _servicesRapides)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(child: _buildCategory(context, title: '🏥 Services santé', services: _servicesSante)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(child: _buildCategory(context, title: '✨ Nouveautés', services: _nouveautes, isNewSection: true)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tous vos services santé',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_servicesRapides.length + _servicesSante.length + _nouveautes.length} services disponibles',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.apps_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(BuildContext context, {required String title, required List<Map<String, dynamic>> services, bool isNewSection = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ThixSanteColors.ink)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                child: Text('${services.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixSanteColors.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: services.length,
            itemBuilder: (c, i) {
              final s = services[i];
              return _serviceCard(context, service: s, highlightNew: isNewSection);
            },
          ),
        ),
      ],
    );
  }

  Widget _serviceCard(BuildContext context, {required Map<String, dynamic> service, required bool highlightNew}) {
    final bool isNew = service['isNew'] == true || highlightNew;
    return InkWell(
      onTap: () {
        final Widget? page = service['page'] as Widget?;
        if (page!= null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${service['label']} - Bientôt disponible')));
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isNew? ThixSanteColors.success.withOpacity(0.3) : ThixSanteColors.borderLight),
              boxShadow: [
                if (isNew)
                  BoxShadow(color: ThixSanteColors.success.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))
                else
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: service['color'] as Color, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(service['icon'] as String, style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    service['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2, color: ThixSanteColors.ink),
                  ),
                ),
              ],
            ),
          ),
          if (isNew)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: ThixSanteColors.success, borderRadius: BorderRadius.circular(8)),
                child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }

  // =============================================================================
  // DATA - 3 Categories
  // =============================================================================
  static final List<Map<String, dynamic>> _servicesRapides = [
  {'label':'Consulter\nmédecin','icon':'🩺','color':const Color(0xFFDBEAFE),'page':const ConsulterMedecinPage()},
  {'label':'Dossier\nmédical','icon':'📁','color':const Color(0xFFDBEAFE),'page':const DossierMedicalPage()},
  {'label':'Résultats\nexamens','icon':'🧪','color':const Color(0xFFD1FAE5),'page':const ResultatsExamensPage()},
  {'label':'Mes\nordonnances','icon':'📋','color':const Color(0xFFEDE9FE),'page':const MesOrdonnancesPage()},
  {'label':'Trouver\nhôpital','icon':'🏥','color':const Color(0xFFCFFAFE),'page':const TrouverHopitalPage()},
  {'label':'Trouver\nmédicament','icon':'💊','color':const Color(0xFFE0E7FF),'page':const TrouverMedicamentPage()},
  {'label':'Pharmacies\nproches','icon':'💊','color':const Color(0xFFDCFCE7),'page':const PharmaciesProchesPage()},
  {'label':'Urgences\nproches','icon':'🚑','color':const Color(0xFFFEE2E2),'page':const UrgencesProchesPage()},
];

  static final List<Map<String, dynamic>> _servicesSante = [
  {'label':'Santé\nenfants','icon':'👶','color':const Color(0xFFFFEDD5),'page':const SanteEnfantsPage()},
  {'label':'Carnet\nvaccination','icon':'💉','color':const Color(0xFFDBEAFE),'page':const CarnetVaccinationPage()},
  {'label':'Suivi\ngrossesse','icon':'🤰','color':const Color(0xFFFCE7F3),'page':const SuiviGrossessePage()},
  {'label':'Analyse\nprédictive','icon':'📈','color':const Color(0xFFE0E7FF),'page':const AnalysePredictivePage()},
  {'label':'Bien-être\nmental','icon':'🧠','color':const Color(0xFFEDE9FE),'page':const BienEtreMentalPage()},
  {'label':'Nutrition','icon':'🍏','color':const Color(0xFFDCFCE7),'page':const NutritionPage()},
  {'label':'Activité\nphysique','icon':'🏋️','color':const Color(0xFFFFEDD5),'page':const ActivitePhysiquePage()},
  {'label':'Gestion\nstress','icon':'🧘','color':const Color(0xFFDBEAFE),'page':const GestionStressPage()},
  {'label':'Assurance','icon':'🛡️','color':const Color(0xFFDBEAFE),'page':const AssuranceSantePage()},
];

  static final List<Map<String, dynamic>> _nouveautes = [
  {'label':'Mon Médecin\nTraitant','icon':'👨‍⚕️','color':const Color(0xFFD1FAE5),'isNew':true,'page':const MonMedecinTraitantPage()},
  {'label':'Dossier\nFamille','icon':'👨‍👩‍👧‍👦','color':const Color(0xFFFFEDD5),'isNew':true,'page':const DossierFamillePage()},
  {'label':'Second Avis\nMédical','icon':'🩻','color':const Color(0xFFE0E7FF),'isNew':true,'page':const SecondAvisPage()},
  {'label':'Téléconsultation','icon':'📹','color':const Color(0xFFEDE9FE),'page':const TeleconsultationPage()},
  {'label':'Assistant\nIA','icon':'🤖','color':const Color(0xFFDBEAFE),'page':const AssistantIAPage()},
  {'label':'Dossier\npartagé','icon':'🔗','color':const Color(0xFFF3E8FF),'page':const DossierPartagePage()},
  {'label':'Épidémies','icon':'🦠','color':const Color(0xFFFEE2E2),'page':const EpidemiesPage()},
  {'label':'Don de sang','icon':'🩸','color':const Color(0xFFFEE2E2),'page':const DonSangPage()},
  {'label':'Rappels\nvaccin','icon':'💉','color':const Color(0xFFE0F2FE),'page':const RappelsVaccinPage()},
  {'label':'Certificat\nmédical','icon':'📄','color':const Color(0xFFF3F4F6),'page':const CertificatMedicalPage()},
  {'label':'Prendre\nRDV','icon':'📅','color':const Color(0xFFEDE9FE),'page':const PrendreRdvPage()},
];
}
