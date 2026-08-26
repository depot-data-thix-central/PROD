// lib/presentation/thix_ia/pages/create_project_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/thix_design_policy.dart';
import '../core/constants/thix_ia_routes.dart';
import '../providers/thix_ia_provider.dart';

class CreateProjectPage extends ConsumerStatefulWidget {
  const CreateProjectPage({super.key});

  @override
  ConsumerState<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends ConsumerState<CreateProjectPage> {
  final _ideaController = TextEditingController();
  final _cityController = TextEditingController();
  final _customSectorController = TextEditingController();
  bool _isLoading = false;

  // ─── Secteurs élargis ───────────────────────────────────────────────────────
  static const List<String> _sectors = [
    'AgriTech',
    'Fintech',
    'HealthTech',
    'EdTech',
    'Logistique',
    'Énergie',
    'Commerce / Retail',
    'FoodTech',
    'Mobility / Transport',
    'PropTech / Immobilier',
    'CleanTech / Environnement',
    'Media & Divertissement',
    'Tourisme & Hospitality',
    'Manufacturing / Industrie',
    'Services aux entreprises',
    'Inclusion financière',
    'E-commerce',
    'SaaS / Software',
    'Autre',
  ];

  // ─── Tous les pays d’Afrique ────────────────────────────────────────────────
  static const List<String> africanCountries = [
    'Algérie',
    'Angola',
    'Bénin',
    'Botswana',
    'Burkina Faso',
    'Burundi',
    'Cameroun',
    'Cap-Vert',
    'République centrafricaine',
    'Tchad',
    'Comores',
    'Congo (Brazzaville)',
    'RDC',
    'Côte d\'Ivoire',
    'Djibouti',
    'Égypte',
    'Guinée équatoriale',
    'Érythrée',
    'Eswatini',
    'Éthiopie',
    'Gabon',
    'Gambie',
    'Ghana',
    'Guinée',
    'Guinée-Bissau',
    'Kenya',
    'Lesotho',
    'Liberia',
    'Libye',
    'Madagascar',
    'Malawi',
    'Mali',
    'Mauritanie',
    'Maurice',
    'Maroc',
    'Mozambique',
    'Namibie',
    'Niger',
    'Nigeria',
    'Rwanda',
    'Sao Tomé-et-Principe',
    'Sénégal',
    'Seychelles',
    'Sierra Leone',
    'Somalie',
    'Afrique du Sud',
    'Soudan du Sud',
    'Soudan',
    'Tanzanie',
    'Togo',
    'Tunisie',
    'Ouganda',
    'Zambie',
    'Zimbabwe',
  ];

  String _selectedSector = 'AgriTech';
  String _selectedCountry = 'RDC';

  @override
  void dispose() {
    _ideaController.dispose();
    _cityController.dispose();
    _customSectorController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_isLoading) return;

    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Décrivez votre idée')),
      );
      return;
    }

    // Gestion du secteur personnalisé
    String finalSector = _selectedSector;
    if (_selectedSector == 'Autre') {
      final custom = _customSectorController.text.trim();
      if (custom.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indiquez votre secteur personnalisé')),
        );
        return;
      }
      finalSector = custom;
    }

    setState(() => _isLoading = true);
    try {
      final project =
          await ref.read(projectsProvider.notifier).createFromIdea(idea);

      final city = _cityController.text.trim();

      await ref.read(projectRepositoryProvider).updateProject(
        project.projectCode,
        data: {
          'sector': finalSector,
          'country': _selectedCountry,
          if (city.isNotEmpty) 'city': city,
          'summary': idea,
          'name': idea.length > 60 ? '${idea.substring(0, 57)}...' : idea,
        },
      );

      if (!mounted) return;
      context.go(ThixIARoutes.projectDetailPath(project.projectCode));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Nouveau Projet', style: ThixPolicy.h3Style),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ThixPolicy.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Idée ──────────────────────────────────────────────────────
            Text('Décrivez votre idée', style: ThixPolicy.h2Style),
            const SizedBox(height: 8),
            Text(
              'THIX IA va analyser et structurer automatiquement votre projet.',
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textSecondary,
              ),
            ),
            const SizedBox(height: ThixPolicy.s16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: TextField(
                controller: _ideaController,
                maxLines: 6,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  hintText:
                      'Ex: Je veux créer une plateforme de livraison de produits agricoles à Kinshasa qui connecte les fermiers aux restaurants...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                style: ThixPolicy.bodyStyle,
              ),
            ),

            const SizedBox(height: ThixPolicy.s20),

            // ── Secteur ───────────────────────────────────────────────────
            Text('Secteur', style: ThixPolicy.labelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sectors.map((s) {
                final selected = s == _selectedSector;
                return ChoiceChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: _isLoading
                      ? null
                      : (_) => setState(() {
                            _selectedSector = s;
                            if (s != 'Autre') {
                              _customSectorController.clear();
                            }
                          }),
                  selectedColor: ThixPolicy.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: selected
                        ? ThixPolicy.primary
                        : ThixPolicy.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),

            // Champ libre quand "Autre" est sélectionné
            if (_selectedSector == 'Autre') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customSectorController,
                enabled: !_isLoading,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Secteur personnalisé',
                  hintText: 'Ex: Aquaculture, FashionTech, Mining...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  ),
                ),
              ),
            ],

            const SizedBox(height: ThixPolicy.s20),

            // ── Pays ──────────────────────────────────────────────────────
            Text('Pays', style: ThixPolicy.labelStyle),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCountry,
              isExpanded: true,
              items: africanCountries
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _isLoading
                  ? null
                  : (v) => setState(() => _selectedCountry = v ?? 'RDC'),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
            ),

            const SizedBox(height: ThixPolicy.s16),

            // ── Ville ─────────────────────────────────────────────────────
            Text('Ville (optionnel)', style: ThixPolicy.labelStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _cityController,
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Ex: Kinshasa, Lagos, Nairobi, Abidjan...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
            ),

            const SizedBox(height: ThixPolicy.s32),

            // ── Bouton ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  disabledBackgroundColor:
                      ThixPolicy.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Créer avec THIX IA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
