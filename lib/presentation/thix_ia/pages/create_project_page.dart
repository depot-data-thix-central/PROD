// lib/presentation/thix_ia/pages/create_project_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/thix_ia_provider.dart';

class CreateProjectPage extends ConsumerStatefulWidget {
  const CreateProjectPage({super.key});
  @override
  ConsumerState<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends ConsumerState<CreateProjectPage> {
  final _ideaController = TextEditingController();
  bool _isLoading = false;

  final _sectors = ['AgriTech', 'Fintech', 'HealthTech', 'EdTech', 'Logistique', 'Energie', 'Commerce', 'Autre'];
  String _selectedSector = 'AgriTech';
  String _selectedCountry = 'RDC';
  String? _selectedCity;

  @override
  void dispose() {
    _ideaController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Décrivez votre idée')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final project = await ref.read(projectsProvider.notifier).createFromIdea(idea);
      if (mounted) {
        // Update sector/country si sélectionné
        await ref.read(projectRepositoryProvider).updateProject(project.projectCode, data: {
          'sector': _selectedSector,
          'country': _selectedCountry,
          'city': _selectedCity,
          'summary': idea,
        });
        if (mounted) context.go('/thix-ia/project/${project.projectCode}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Nouveau Projet', style: ThixPolicy.h3Style)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ThixPolicy.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Décrivez votre idée', style: ThixPolicy.h2Style),
            const SizedBox(height: 8),
            Text('THIX IA va analyser et structurer automatiquement votre projet.', style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
            const SizedBox(height: ThixPolicy.s20),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border)),
              child: TextField(
                controller: _ideaController,
                maxLines: 6,
                decoration: InputDecoration(hintText: 'Ex: Je veux créer une plateforme de livraison de produits agricoles à Kinshasa qui connecte les fermiers aux restaurants...', border: InputBorder.none, contentPadding: EdgeInsets.all(16)),
                style: ThixPolicy.bodyStyle,
              ),
            ),
            const SizedBox(height: ThixPolicy.s20),
            Text('Secteur', style: ThixPolicy.labelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _sectors.map((s) {
                final selected = s == _selectedSector;
                return ChoiceChip(label: Text(s), selected: selected, onSelected: (_) => setState(() => _selectedSector = s), selectedColor: ThixPolicy.primary.withOpacity(0.15), labelStyle: TextStyle(color: selected? ThixPolicy.primary : ThixPolicy.textSecondary));
              }).toList(),
            ),
            const SizedBox(height: ThixPolicy.s16),
            Text('Pays', style: ThixPolicy.labelStyle),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCountry,
              items: ['RDC', 'RW', 'KE', 'UG', 'TZ', 'CM', 'CI'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCountry = v?? 'RDC'),
              decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
            ),
            const SizedBox(height: ThixPolicy.s32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading? null : _create,
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
                child: _isLoading? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18), SizedBox(width: 8), Text('Créer avec THIX IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
