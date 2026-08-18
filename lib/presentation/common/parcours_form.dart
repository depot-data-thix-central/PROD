import 'package:flutter/material.dart';

import 'package:thix_id/theme.dart';

/// Controllers for one education entry (cursus).
///
/// Keys are aligned with the registration flow and the Supabase `profiles` JSON
/// columns:
/// - level, institution, city, startYear, endYear, degree
class EducationEntryControllers {
  final TextEditingController levelC;
  final TextEditingController institutionC;
  final TextEditingController cityC;
  final TextEditingController startYearC;
  final TextEditingController endYearC;
  final TextEditingController degreeC;

  EducationEntryControllers({
    String level = 'Supérieur',
    String institution = '',
    String city = '',
    String startYear = '',
    String endYear = '',
    String degree = '',
  })  : levelC = TextEditingController(text: level),
        institutionC = TextEditingController(text: institution),
        cityC = TextEditingController(text: city),
        startYearC = TextEditingController(text: startYear),
        endYearC = TextEditingController(text: endYear),
        degreeC = TextEditingController(text: degree);

  void dispose() {
    levelC.dispose();
    institutionC.dispose();
    cityC.dispose();
    startYearC.dispose();
    endYearC.dispose();
    degreeC.dispose();
  }

  Map<String, dynamic> toMap() => {
        'level': levelC.text.trim(),
        'institution': institutionC.text.trim(),
        'city': cityC.text.trim(),
        'startYear': startYearC.text.trim(),
        'endYear': endYearC.text.trim(),
        'degree': degreeC.text.trim(),
      };

  static EducationEntryControllers fromMap(Map<String, dynamic> raw) {
    // Backward-compat: accept older keys used in some older editors.
    final level = (raw['level'] ?? raw['degree'] ?? raw['title'] ?? 'Supérieur').toString();
    final institution = (raw['institution'] ?? raw['school'] ?? raw['org'] ?? '').toString();
    final city = (raw['city'] ?? '').toString();
    final startYear = (raw['startYear'] ?? '').toString();
    final endYear = (raw['endYear'] ?? '').toString();
    final degree = (raw['degree'] ?? '').toString();
    return EducationEntryControllers(level: level, institution: institution, city: city, startYear: startYear, endYear: endYear, degree: degree);
  }
}

/// Controllers for one experience entry.
///
/// Keys aligned with registration flow / Supabase:
/// - company, city, sector, title, missions
class ExperienceEntryControllers {
  final TextEditingController companyC;
  final TextEditingController cityC;
  final TextEditingController sectorC;
  final TextEditingController titleC;
  final TextEditingController missionsC;

  ExperienceEntryControllers({
    String company = '',
    String city = '',
    String sector = '',
    String title = '',
    String missions = '',
  })  : companyC = TextEditingController(text: company),
        cityC = TextEditingController(text: city),
        sectorC = TextEditingController(text: sector),
        titleC = TextEditingController(text: title),
        missionsC = TextEditingController(text: missions);

  void dispose() {
    companyC.dispose();
    cityC.dispose();
    sectorC.dispose();
    titleC.dispose();
    missionsC.dispose();
  }

  Map<String, dynamic> toMap() => {
        'company': companyC.text.trim(),
        'city': cityC.text.trim(),
        'sector': sectorC.text.trim(),
        'title': titleC.text.trim(),
        'missions': missionsC.text.trim(),
      };

  static ExperienceEntryControllers fromMap(Map<String, dynamic> raw) {
    // Backward-compat: accept older keys used in some older editors.
    final company = (raw['company'] ?? raw['org'] ?? '').toString();
    final city = (raw['city'] ?? '').toString();
    final sector = (raw['sector'] ?? raw['industry'] ?? '').toString();
    final title = (raw['title'] ?? raw['role'] ?? '').toString();
    final missions = (raw['missions'] ?? raw['tasks'] ?? raw['description'] ?? '').toString();
    return ExperienceEntryControllers(company: company, city: city, sector: sector, title: title, missions: missions);
  }
}

class ParcoursInputField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType type;
  final TextEditingController controller;

  const ParcoursInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.type = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: context.textStyles.labelMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: theme.dividerColor),
              color: theme.colorScheme.surface,
            ),
            clipBehavior: Clip.antiAlias,
            child: TextField(
              controller: controller,
              keyboardType: type,
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(icon, color: LightModeColors.hint),
                border: InputBorder.none,
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ParcoursPremiumCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const ParcoursPremiumCard({super.key, required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: LightModeColors.accent, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: LightModeColors.accent, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// A reusable “Parcours” form (Compétences + Bio + Education + Experience).
///
/// This widget is used both in:
/// - the Personal Registration flow (step 2)
/// - the “Mon Compte” editing flow
class ParcoursForm extends StatelessWidget {
  final Widget header;
  final TextEditingController bioC;
  final TextEditingController competenceC;
  final List<EducationEntryControllers> education;
  final List<ExperienceEntryControllers> experience;
  final VoidCallback onAddEducation;
  final void Function(int index) onRemoveEducation;
  final VoidCallback onAddExperience;
  final void Function(int index) onRemoveExperience;
  final bool enabled;

  const ParcoursForm({
    super.key,
    required this.header,
    required this.bioC,
    required this.competenceC,
    required this.education,
    required this.experience,
    required this.onAddEducation,
    required this.onRemoveEducation,
    required this.onAddExperience,
    required this.onRemoveExperience,
    this.enabled = true,
  });

  String _normalizeEducationLevel(String v) {
    final t = v.trim().toLowerCase();
    if (t.startsWith('pri')) return 'Primaire';
    if (t.startsWith('sec')) return 'Secondaire';
    if (t.startsWith('for')) return 'Formation';
    return 'Supérieur';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: theme.dividerColor, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 4))],
          ),
          child: TextField(
            controller: competenceC,
            enabled: enabled,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Ex: Flutter, Gestion de projet, Design UI…',
              prefixIcon: const Icon(Icons.auto_awesome_rounded, color: LightModeColors.accent),
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: theme.dividerColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: theme.dividerColor)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Divider(color: theme.dividerColor, thickness: 1),
        const SizedBox(height: AppSpacing.xl),
        Text('Biographie Professionnelle', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.xs),
        Text('Valorisez votre profil auprès des institutions.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: theme.dividerColor, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 4))],
          ),
          child: TextField(
            controller: bioC,
            enabled: enabled,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Partagez vos compétences clés, vos années d'expérience et vos ambitions...",
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: theme.dividerColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: theme.dividerColor)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Divider(color: theme.dividerColor, thickness: 1),
        const SizedBox(height: AppSpacing.xl),
        Text('Cursus Académique', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.xs),
        Text('Historique de vos diplômes et formations.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(
          education.length,
          (i) => ParcoursPremiumCard(
            icon: Icons.school_rounded,
            title: '${education[i].levelC.text.trim().isEmpty ? 'Études' : education[i].levelC.text.trim()} #${i + 1}',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _normalizeEducationLevel(education[i].levelC.text),
                  items: const [
                    DropdownMenuItem(value: 'Primaire', child: Text('Primaire')),
                    DropdownMenuItem(value: 'Secondaire', child: Text('Secondaire')),
                    DropdownMenuItem(value: 'Supérieur', child: Text('Supérieur / Université')),
                    DropdownMenuItem(value: 'Formation', child: Text('Formation / Certificat')),
                  ],
                  onChanged: !enabled ? null : (v) => education[i].levelC.text = (v ?? 'Supérieur'),
                  decoration: InputDecoration(
                    labelText: 'Niveau',
                    prefixIcon: const Icon(Icons.layers_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ParcoursInputField(label: 'Établissement', hint: 'Ex: Institut X / Université Y', icon: Icons.apartment_rounded, controller: education[i].institutionC),
                ParcoursInputField(label: 'Ville (où était situé)', hint: 'Ex: Kinshasa', icon: Icons.location_city_rounded, controller: education[i].cityC),
                Row(
                  children: [
                    Expanded(child: ParcoursInputField(label: 'Année Début', hint: '2018', icon: Icons.event_note_rounded, type: TextInputType.number, controller: education[i].startYearC)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: ParcoursInputField(label: 'Année Fin', hint: '2023', icon: Icons.event_available_rounded, type: TextInputType.number, controller: education[i].endYearC)),
                  ],
                ),
                ParcoursInputField(label: 'Diplôme Obtenu', hint: 'Licence en Économie', icon: Icons.workspace_premium_rounded, controller: education[i].degreeC),
                if (education.length > 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: !enabled ? null : () => onRemoveEducation(i),
                      icon: const Icon(Icons.delete_outline_rounded, color: LightModeColors.error),
                      label: const Text('Supprimer', style: TextStyle(color: LightModeColors.error)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: !enabled ? null : onAddEducation,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter un diplôme'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.centerLeft,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Divider(color: theme.dividerColor, thickness: 1),
        const SizedBox(height: AppSpacing.xl),
        Text('Expériences & Carrière', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.xs),
        Text('Détaillez votre parcours professionnel.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(
          experience.length,
          (i) => ParcoursPremiumCard(
            icon: Icons.business_center_rounded,
            title: 'Poste de Travail #${i + 1}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ParcoursInputField(label: 'Entreprise', hint: 'Ex: Rawbank', icon: Icons.business_rounded, controller: experience[i].companyC),
                ParcoursInputField(label: 'Ville (où était situé)', hint: 'Ex: Lubumbashi', icon: Icons.location_city_rounded, controller: experience[i].cityC),
                Row(
                  children: [
                    Expanded(child: ParcoursInputField(label: 'Secteur', hint: 'Banque', icon: Icons.category_rounded, controller: experience[i].sectorC)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: ParcoursInputField(label: 'Titre', hint: 'Analyste Senior', icon: Icons.badge_rounded, controller: experience[i].titleC)),
                  ],
                ),
                Text('Missions principales', style: context.textStyles.labelMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: experience[i].missionsC,
                  enabled: enabled,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Décrivez vos responsabilités...',
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: theme.dividerColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: theme.dividerColor)),
                  ),
                ),
                if (experience.length > 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: !enabled ? null : () => onRemoveExperience(i),
                      icon: const Icon(Icons.delete_outline_rounded, color: LightModeColors.error),
                      label: const Text('Supprimer', style: TextStyle(color: LightModeColors.error)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: !enabled ? null : onAddExperience,
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Ajouter une expérience'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.centerLeft,
          ),
        ),
      ],
    );
  }
}
