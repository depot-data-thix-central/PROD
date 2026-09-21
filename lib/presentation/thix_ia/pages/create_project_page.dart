// lib/presentation/thix_ia/pages/create_project_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _quotaReached = false;
  bool _checkingQuota = true;
  DateTime? _nextAvailableDate;

  static const List<String> _sectors = [
    'AgriTech', 'Fintech', 'HealthTech', 'EdTech', 'Logistique', 'Énergie',
    'Commerce / Retail', 'FoodTech', 'Mobility / Transport', 'PropTech / Immobilier',
    'CleanTech / Environnement', 'Media & Divertissement', 'Tourisme & Hospitality',
    'Manufacturing / Industrie', 'Services aux entreprises', 'Inclusion financière',
    'E-commerce', 'SaaS / Software', 'Autre',
  ];

  static const List<String> africanCountries = [
    'Algérie', 'Angola', 'Bénin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cameroun',
    'Cap-Vert', 'République centrafricaine', 'Tchad', 'Comores', 'Congo (Brazzaville)',
    'RDC', 'Côte d\'Ivoire', 'Djibouti', 'Égypte', 'Guinée équatoriale', 'Érythrée',
    'Eswatini', 'Éthiopie', 'Gabon', 'Gambie', 'Ghana', 'Guinée', 'Guinée-Bissau',
    'Kenya', 'Lesotho', 'Liberia', 'Libye', 'Madagascar', 'Malawi', 'Mali',
    'Mauritanie', 'Maurice', 'Maroc', 'Mozambique', 'Namibie', 'Niger', 'Nigeria',
    'Rwanda', 'Sao Tomé-et-Principe', 'Sénégal', 'Seychelles', 'Sierra Leone',
    'Somalie', 'Afrique du Sud', 'Soudan du Sud', 'Soudan', 'Tanzanie', 'Togo',
    'Tunisie', 'Ouganda', 'Zambie', 'Zimbabwe',
  ];

  String _selectedSector = 'AgriTech';
  String _selectedCountry = 'RDC';

  @override
  void initState() {
    super.initState();
    _checkQuota();
  }

  Future<void> _checkQuota() async {
    setState(() => _checkingQuota = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _checkingQuota = false;
          _quotaReached = false;
        });
        return;
      }

      final since = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();

      final response = await Supabase.instance.client
          .from('projects')
          .select('created_at')
          .eq('user_id', user.id) // ← adapte le nom de colonne
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final lastCreated = DateTime.parse(response.first['created_at'] as String);
        final nextDate = lastCreated.add(const Duration(days: 7));
        setState(() {
          _quotaReached = true;
          _nextAvailableDate = nextDate;
          _checkingQuota = false;
        });
      } else {
        setState(() {
          _quotaReached = false;
          _checkingQuota = false;
        });
      }
    } catch (_) {
      // En cas d'erreur on laisse passer (le backend bloquera de toute façon)
      setState(() {
        _quotaReached = false;
        _checkingQuota = false;
      });
    }
  }

  @override
  void dispose() {
    _ideaController.dispose();
    _cityController.dispose();
    _customSectorController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_isLoading || _quotaReached) return;

    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Décrivez votre idée')),
      );
      return;
    }

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
      if (!mounted) return;

      final msg = e.toString();
      final isQuota = msg.contains('QUOTA_EXCEEDED') ||
          msg.contains('un seul projet par semaine') ||
          (e is PostgrestException && e.code == 'P0001');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isQuota
                ? 'Quota atteint : vous ne pouvez créer qu’un seul projet par semaine.'
                : 'Erreur: $e',
          ),
          backgroundColor: isQuota ? Colors.orange.shade800 : Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      // Rafraîchir le statut quota
      if (isQuota) await _checkQuota();
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
      body: _checkingQuota
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(ThixPolicy.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Bannière Quota ──────────────────────────────────────
                  if (_quotaReached) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock_clock_rounded,
                                  color: Colors.orange.shade800, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Quota atteint',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.orange.shade900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vous avez déjà créé un projet cette semaine.\n'
                            'Prochaine création possible le ${_formatDate(_nextAvailableDate)}.',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Idée ────────────────────────────────────────────────
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
                      enabled: !_isLoading && !_quotaReached,
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

                  // ── Secteur ─────────────────────────────────────────────
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
                        onSelected: (_isLoading || _quotaReached)
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

                  if (_selectedSector == 'Autre') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customSectorController,
                      enabled: !_isLoading && !_quotaReached,
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

                  // ── Pays ────────────────────────────────────────────────
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
                    onChanged: (_isLoading || _quotaReached)
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

                  // ── Ville ───────────────────────────────────────────────
                  Text('Ville (optionnel)', style: ThixPolicy.labelStyle),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cityController,
                    enabled: !_isLoading && !_quotaReached,
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

                  // ── Bouton ──────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _quotaReached) ? null : _create,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.primary,
                        disabledBackgroundColor:
                            ThixPolicy.primary.withOpacity(0.4),
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _quotaReached
                                      ? Icons.lock_rounded
                                      : Icons.auto_awesome_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _quotaReached
                                      ? 'Quota atteint'
                                      : 'Créer avec THIX IA',
                                  style: const TextStyle(
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

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
