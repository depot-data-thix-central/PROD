/// THIX — Parcours Form (Production Enterprise)
/// ✅ SÉCURISÉ : ThixPolicy, i18n, validation, mounted checks
/// ✅ ACCESSIBLE : Semantics, HapticFeedback, keyboard actions
/// ✅ ROBUSTE : Error handling, logs structurés, confirmation dialogs
///
/// Formulaire réutilisable pour :
/// - Personal Registration flow (step 2)
/// - "Mon Compte" editing flow
///
/// Sections :
/// - Compétences
/// - Biographie Professionnelle
/// - Cursus Académique (Education)
/// - Expériences & Carrière (Experience)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxYearLength = 4;
const int _kMinYear = 1950;
const int _kMaxYear = 2100;
const int _kMaxNameLength = 100;
const int _kMaxCityLength = 50;
const int _kMaxBioLength = 1000;
const int _kMaxCompetenceLength = 500;
const int _kMaxMissionsLength = 1000;
const int _kMaxDegreeLength = 150;
const int _kMaxSectorLength = 50;
const int _kMaxTitleLength = 100;

// ============================================================================
// VALIDATORS
// ============================================================================

class _ParcoursValidators {
  _ParcoursValidators._();

  /// Valide une année (format YYYY, entre 1950 et 2100)
  static bool isValidYear(String? year) {
    if (year == null || year.trim().isEmpty) return true; // Optionnel
    final cleaned = year.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleaned)) return false;
    final y = int.tryParse(cleaned);
    return y != null && y >= _kMinYear && y <= _kMaxYear;
  }

  /// Valide qu'une année de fin est >= année de début
  static bool isValidYearRange(String? start, String? end) {
    if (start == null || start.trim().isEmpty) return true;
    if (end == null || end.trim().isEmpty) return true;
    final s = int.tryParse(start.trim());
    final e = int.tryParse(end.trim());
    if (s == null || e == null) return true;
    return e >= s;
  }

  /// Sanitize un string (trim + truncate)
  static String sanitize(String? input, {int maxLength = 200}) {
    if (input == null) return '';
    final s = input.trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Normalise un niveau d'éducation
  static String normalizeEducationLevel(String? level) {
    if (level == null) return 'Supérieur';
    final t = level.trim().toLowerCase();
    if (t.startsWith('pri')) return 'Primaire';
    if (t.startsWith('sec')) return 'Secondaire';
    if (t.startsWith('for')) return 'Formation';
    if (t.startsWith('sup')) return 'Supérieur';
    return 'Supérieur';
  }
}

// ============================================================================
// EDUCATION ENTRY CONTROLLERS
// ============================================================================

/// Controllers pour une entrée d'éducation (cursus).
///
/// Clés alignées avec le flux d'inscription et les colonnes JSON Supabase `profiles` :
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

  /// Libère les resources des controllers
  void dispose() {
    levelC.dispose();
    institutionC.dispose();
    cityC.dispose();
    startYearC.dispose();
    endYearC.dispose();
    degreeC.dispose();
  }

  /// Convertit en Map pour sauvegarde
  Map<String, dynamic> toMap() => {
        'level': _ParcoursValidators.sanitize(levelC.text, maxLength: 50),
        'institution': _ParcoursValidators.sanitize(institutionC.text, maxLength: _kMaxNameLength),
        'city': _ParcoursValidators.sanitize(cityC.text, maxLength: _kMaxCityLength),
        'startYear': _ParcoursValidators.sanitize(startYearC.text, maxLength: _kMaxYearLength),
        'endYear': _ParcoursValidators.sanitize(endYearC.text, maxLength: _kMaxYearLength),
        'degree': _ParcoursValidators.sanitize(degreeC.text, maxLength: _kMaxDegreeLength),
      };

  /// Crée depuis une Map (backward-compat avec anciens formats)
  static EducationEntryControllers fromMap(Map<String, dynamic> raw) {
    try {
      final level = (raw['level'] ?? raw['degree'] ?? raw['title'] ?? 'Supérieur').toString();
      final institution = (raw['institution'] ?? raw['school'] ?? raw['org'] ?? '').toString();
      final city = (raw['city'] ?? '').toString();
      final startYear = (raw['startYear'] ?? '').toString();
      final endYear = (raw['endYear'] ?? '').toString();
      final degree = (raw['degree'] ?? '').toString();
      return EducationEntryControllers(
        level: level,
        institution: institution,
        city: city,
        startYear: startYear,
        endYear: endYear,
        degree: degree,
      );
    } catch (e) {
      debugPrint('[ParcoursForm] ⚠️ fromMap error: $e');
      return EducationEntryControllers();
    }
  }
}

// ============================================================================
// EXPERIENCE ENTRY CONTROLLERS
// ============================================================================

/// Controllers pour une entrée d'expérience.
///
/// Clés alignées avec le flux d'inscription / Supabase :
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

  /// Libère les resources des controllers
  void dispose() {
    companyC.dispose();
    cityC.dispose();
    sectorC.dispose();
    titleC.dispose();
    missionsC.dispose();
  }

  /// Convertit en Map pour sauvegarde
  Map<String, dynamic> toMap() => {
        'company': _ParcoursValidators.sanitize(companyC.text, maxLength: _kMaxNameLength),
        'city': _ParcoursValidators.sanitize(cityC.text, maxLength: _kMaxCityLength),
        'sector': _ParcoursValidators.sanitize(sectorC.text, maxLength: _kMaxSectorLength),
        'title': _ParcoursValidators.sanitize(titleC.text, maxLength: _kMaxTitleLength),
        'missions': _ParcoursValidators.sanitize(missionsC.text, maxLength: _kMaxMissionsLength),
      };

  /// Crée depuis une Map (backward-compat avec anciens formats)
  static ExperienceEntryControllers fromMap(Map<String, dynamic> raw) {
    try {
      final company = (raw['company'] ?? raw['org'] ?? '').toString();
      final city = (raw['city'] ?? '').toString();
      final sector = (raw['sector'] ?? raw['industry'] ?? '').toString();
      final title = (raw['title'] ?? raw['role'] ?? '').toString();
      final missions = (raw['missions'] ?? raw['tasks'] ?? raw['description'] ?? '').toString();
      return ExperienceEntryControllers(
        company: company,
        city: city,
        sector: sector,
        title: title,
        missions: missions,
      );
    } catch (e) {
      debugPrint('[ParcoursForm] ⚠️ fromMap error: $e');
      return ExperienceEntryControllers();
    }
  }
}

// ============================================================================
// PARCOURS INPUT FIELD
// ============================================================================

/// Champ de saisie réutilisable pour le formulaire Parcours
class ParcoursInputField extends StatelessWidget {
  final String labelKey;
  final String hintKey;
  final IconData icon;
  final TextInputType type;
  final TextEditingController controller;
  final bool enabled;
  final int? maxLength;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onFieldSubmitted;

  const ParcoursInputField({
    super.key,
    required this.labelKey,
    required this.hintKey,
    required this.icon,
    required this.controller,
    this.enabled = true,
    this.type = TextInputType.text,
    this.maxLength,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.sentences,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: l10n.t(labelKey),
            child: Text(
              l10n.t(labelKey),
              style: TextStyle(
                color: ThixPolicy.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: ThixPolicy.s8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: ThixPolicy.border),
              color: ThixPolicy.card,
            ),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              textField: true,
              label: l10n.t(labelKey),
              hint: l10n.t(hintKey),
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: type,
                maxLength: maxLength,
                textInputAction: textInputAction,
                textCapitalization: textCapitalization,
                onSubmitted: onFieldSubmitted,
                style: TextStyle(color: ThixPolicy.textMain),
                decoration: InputDecoration(
                  hintText: l10n.t(hintKey),
                  hintStyle: TextStyle(color: ThixPolicy.textMuted),
                  counterText: '', // Cache le compteur
                  prefixIcon: Icon(icon, color: ThixPolicy.primary, size: 20),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: ThixPolicy.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: ThixPolicy.s16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PARCOURS PREMIUM CARD
// ============================================================================

/// Carte premium pour afficher une section du parcours
class ParcoursPremiumCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const ParcoursPremiumCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: ThixPolicy.s24),
        padding: const EdgeInsets.all(ThixPolicy.s16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(color: ThixPolicy.primary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(icon, color: ThixPolicy.primary, size: 18),
                  const SizedBox(width: ThixPolicy.s8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: ThixPolicy.textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ThixPolicy.s16),
            child,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PARCOURS FORM
// ============================================================================

/// Formulaire réutilisable "Parcours" (Compétences + Bio + Education + Experience)
///
/// Utilisé dans :
/// - Personal Registration flow (step 2)
/// - "Mon Compte" editing flow
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,

        // ─── COMPÉTENCES ──────────────────────────────────────────
        _buildCompetencesSection(context, l10n),

        const SizedBox(height: ThixPolicy.s32),
        Divider(color: ThixPolicy.border, thickness: 1),
        const SizedBox(height: ThixPolicy.s32),

        // ─── BIOGRAPHIE ───────────────────────────────────────────
        _buildBiographySection(context, l10n),

        const SizedBox(height: ThixPolicy.s32),
        Divider(color: ThixPolicy.border, thickness: 1),
        const SizedBox(height: ThixPolicy.s32),

        // ─── CURSUS ACADÉMIQUE ────────────────────────────────────
        _buildEducationSection(context, l10n),

        const SizedBox(height: ThixPolicy.s32),
        Divider(color: ThixPolicy.border, thickness: 1),
        const SizedBox(height: ThixPolicy.s32),

        // ─── EXPÉRIENCES ──────────────────────────────────────────
        _buildExperienceSection(context, l10n),
      ],
    );
  }

  // ========================================================================
  // COMPÉTENCES SECTION
  // ========================================================================

  Widget _buildCompetencesSection(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Semantics(
        textField: true,
        label: l10n.t('parcours_competences'),
        hint: l10n.t('parcours_competences_hint'),
        child: TextField(
          controller: competenceC,
          enabled: enabled,
          maxLines: 2,
          maxLength: _kMaxCompetenceLength,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: ThixPolicy.textMain),
          decoration: InputDecoration(
            hintText: l10n.t('parcours_competences_hint'),
            hintStyle: TextStyle(color: ThixPolicy.textMuted),
            counterText: '',
            prefixIcon: Icon(Icons.auto_awesome_rounded, color: ThixPolicy.primary),
            filled: true,
            fillColor: ThixPolicy.surfaceSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide(color: ThixPolicy.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: BorderSide(color: ThixPolicy.border),
            ),
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // BIOGRAPHY SECTION
  // ========================================================================

  Widget _buildBiographySection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.t('parcours_biography_title'),
            style: TextStyle(
              color: ThixPolicy.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: ThixPolicy.s4),
        Text(
          l10n.t('parcours_biography_subtitle'),
          style: TextStyle(color: ThixPolicy.textMuted, fontSize: 14),
        ),
        const SizedBox(height: ThixPolicy.s12),
        Container(
          padding: const EdgeInsets.all(ThixPolicy.s16),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(color: ThixPolicy.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Semantics(
            textField: true,
            label: l10n.t('parcours_biography_title'),
            hint: l10n.t('parcours_biography_hint'),
            child: TextField(
              controller: bioC,
              enabled: enabled,
              maxLines: 4,
              maxLength: _kMaxBioLength,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: ThixPolicy.textMain),
              decoration: InputDecoration(
                hintText: l10n.t('parcours_biography_hint'),
                hintStyle: TextStyle(color: ThixPolicy.textMuted),
                counterText: '',
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // EDUCATION SECTION
  // ========================================================================

  Widget _buildEducationSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.t('parcours_education_title'),
            style: TextStyle(
              color: ThixPolicy.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: ThixPolicy.s4),
        Text(
          l10n.t('parcours_education_subtitle'),
          style: TextStyle(color: ThixPolicy.textMuted, fontSize: 14),
        ),
        const SizedBox(height: ThixPolicy.s16),
        ...List.generate(
          education.length,
          (i) => KeyedSubtree(
            key: ValueKey('education_$i'),
            child: _buildEducationCard(context, l10n, i),
          ),
        ),
        Semantics(
          button: true,
          label: l10n.t('parcours_add_education'),
          child: OutlinedButton.icon(
            onPressed: !enabled
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onAddEducation();
                  },
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.t('parcours_add_education')),
            style: OutlinedButton.styleFrom(
              foregroundColor: ThixPolicy.primary,
              side: BorderSide(color: ThixPolicy.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEducationCard(BuildContext context, AppLocalizations l10n, int index) {
    final levelText = education[index].levelC.text.trim();
    final title = levelText.isEmpty
        ? l10n.t('parcours_education_item', args: ['${index + 1}'])
        : '$levelText #${index + 1}';

    return ParcoursPremiumCard(
      icon: Icons.school_rounded,
      title: title,
      child: Column(
        children: [
          // Niveau (Dropdown)
          Semantics(
            label: l10n.t('parcours_education_level'),
            child: DropdownButtonFormField<String>(
              value: _ParcoursValidators.normalizeEducationLevel(
                education[index].levelC.text,
              ),
              items: [
                DropdownMenuItem(
                  value: 'Primaire',
                  child: Text(l10n.t('parcours_level_primary')),
                ),
                DropdownMenuItem(
                  value: 'Secondaire',
                  child: Text(l10n.t('parcours_level_secondary')),
                ),
                DropdownMenuItem(
                  value: 'Supérieur',
                  child: Text(l10n.t('parcours_level_higher')),
                ),
                DropdownMenuItem(
                  value: 'Formation',
                  child: Text(l10n.t('parcours_level_training')),
                ),
              ],
              onChanged: !enabled
                  ? null
                  : (v) {
                      HapticFeedback.selectionClick();
                      education[index].levelC.text = v ?? 'Supérieur';
                    },
              decoration: InputDecoration(
                labelText: l10n.t('parcours_education_level'),
                labelStyle: TextStyle(color: ThixPolicy.textMuted),
                prefixIcon: Icon(Icons.layers_rounded, color: ThixPolicy.primary),
                filled: true,
                fillColor: ThixPolicy.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
              ),
              dropdownColor: ThixPolicy.card,
            ),
          ),
          const SizedBox(height: ThixPolicy.s16),

          // Établissement
          ParcoursInputField(
            labelKey: 'parcours_institution',
            hintKey: 'parcours_institution_hint',
            icon: Icons.apartment_rounded,
            controller: education[index].institutionC,
            enabled: enabled,
            maxLength: _kMaxNameLength,
            textCapitalization: TextCapitalization.words,
          ),

          // Ville
          ParcoursInputField(
            labelKey: 'parcours_city',
            hintKey: 'parcours_city_hint',
            icon: Icons.location_city_rounded,
            controller: education[index].cityC,
            enabled: enabled,
            maxLength: _kMaxCityLength,
            textCapitalization: TextCapitalization.words,
          ),

          // Années
          Row(
            children: [
              Expanded(
                child: ParcoursInputField(
                  labelKey: 'parcours_start_year',
                  hintKey: 'parcours_year_hint',
                  icon: Icons.event_note_rounded,
                  type: TextInputType.number,
                  controller: education[index].startYearC,
                  enabled: enabled,
                  maxLength: _kMaxYearLength,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: ThixPolicy.s16),
              Expanded(
                child: ParcoursInputField(
                  labelKey: 'parcours_end_year',
                  hintKey: 'parcours_year_hint',
                  icon: Icons.event_available_rounded,
                  type: TextInputType.number,
                  controller: education[index].endYearC,
                  enabled: enabled,
                  maxLength: _kMaxYearLength,
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),

          // Diplôme
          ParcoursInputField(
            labelKey: 'parcours_degree',
            hintKey: 'parcours_degree_hint',
            icon: Icons.workspace_premium_rounded,
            controller: education[index].degreeC,
            enabled: enabled,
            maxLength: _kMaxDegreeLength,
            textCapitalization: TextCapitalization.words,
          ),

          // Bouton supprimer
          if (education.length > 1)
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: l10n.t('parcours_delete'),
                child: TextButton.icon(
                  onPressed: !enabled
                      ? null
                      : () => _confirmDeleteEducation(context, l10n, index),
                  icon: Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger),
                  label: Text(
                    l10n.t('parcours_delete'),
                    style: TextStyle(color: ThixPolicy.danger),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========================================================================
  // EXPERIENCE SECTION
  // ========================================================================

  Widget _buildExperienceSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.t('parcours_experience_title'),
            style: TextStyle(
              color: ThixPolicy.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: ThixPolicy.s4),
        Text(
          l10n.t('parcours_experience_subtitle'),
          style: TextStyle(color: ThixPolicy.textMuted, fontSize: 14),
        ),
        const SizedBox(height: ThixPolicy.s16),
        ...List.generate(
          experience.length,
          (i) => KeyedSubtree(
            key: ValueKey('experience_$i'),
            child: _buildExperienceCard(context, l10n, i),
          ),
        ),
        Semantics(
          button: true,
          label: l10n.t('parcours_add_experience'),
          child: OutlinedButton.icon(
            onPressed: !enabled
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onAddExperience();
                  },
            icon: const Icon(Icons.add_business_rounded),
            label: Text(l10n.t('parcours_add_experience')),
            style: OutlinedButton.styleFrom(
              foregroundColor: ThixPolicy.primary,
              side: BorderSide(color: ThixPolicy.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceCard(BuildContext context, AppLocalizations l10n, int index) {
    return ParcoursPremiumCard(
      icon: Icons.business_center_rounded,
      title: l10n.t('parcours_experience_item', args: ['${index + 1}']),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Entreprise
          ParcoursInputField(
            labelKey: 'parcours_company',
            hintKey: 'parcours_company_hint',
            icon: Icons.business_rounded,
            controller: experience[index].companyC,
            enabled: enabled,
            maxLength: _kMaxNameLength,
            textCapitalization: TextCapitalization.words,
          ),

          // Ville
          ParcoursInputField(
            labelKey: 'parcours_city',
            hintKey: 'parcours_city_hint',
            icon: Icons.location_city_rounded,
            controller: experience[index].cityC,
            enabled: enabled,
            maxLength: _kMaxCityLength,
            textCapitalization: TextCapitalization.words,
          ),

          // Secteur + Titre
          Row(
            children: [
              Expanded(
                child: ParcoursInputField(
                  labelKey: 'parcours_sector',
                  hintKey: 'parcours_sector_hint',
                  icon: Icons.category_rounded,
                  controller: experience[index].sectorC,
                  enabled: enabled,
                  maxLength: _kMaxSectorLength,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: ThixPolicy.s16),
              Expanded(
                child: ParcoursInputField(
                  labelKey: 'parcours_title',
                  hintKey: 'parcours_title_hint',
                  icon: Icons.badge_rounded,
                  controller: experience[index].titleC,
                  enabled: enabled,
                  maxLength: _kMaxTitleLength,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),

          // Missions
          Semantics(
            label: l10n.t('parcours_missions'),
            child: Text(
              l10n.t('parcours_missions'),
              style: TextStyle(
                color: ThixPolicy.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: ThixPolicy.s8),
          Semantics(
            textField: true,
            label: l10n.t('parcours_missions'),
            hint: l10n.t('parcours_missions_hint'),
            child: TextField(
              controller: experience[index].missionsC,
              enabled: enabled,
              maxLines: 3,
              maxLength: _kMaxMissionsLength,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: ThixPolicy.textMain),
              decoration: InputDecoration(
                hintText: l10n.t('parcours_missions_hint'),
                hintStyle: TextStyle(color: ThixPolicy.textMuted),
                counterText: '',
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
              ),
            ),
          ),

          // Bouton supprimer
          if (experience.length > 1)
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: l10n.t('parcours_delete'),
                child: TextButton.icon(
                  onPressed: !enabled
                      ? null
                      : () => _confirmDeleteExperience(context, l10n, index),
                  icon: Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger),
                  label: Text(
                    l10n.t('parcours_delete'),
                    style: TextStyle(color: ThixPolicy.danger),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========================================================================
  // CONFIRMATION DIALOGS
  // ========================================================================

  Future<void> _confirmDeleteEducation(
    BuildContext context,
    AppLocalizations l10n,
    int index,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        title: Text(
          l10n.t('parcours_delete_confirm_title'),
          style: TextStyle(color: ThixPolicy.textMain),
        ),
        content: Text(
          l10n.t('parcours_delete_confirm_message'),
          style: TextStyle(color: ThixPolicy.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.t('common_cancel'),
              style: TextStyle(color: ThixPolicy.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.t('parcours_delete'),
              style: TextStyle(color: ThixPolicy.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      debugPrint('[ParcoursForm] 🗑️ Removing education #$index');
      onRemoveEducation(index);
    }
  }

  Future<void> _confirmDeleteExperience(
    BuildContext context,
    AppLocalizations l10n,
    int index,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        title: Text(
          l10n.t('parcours_delete_confirm_title'),
          style: TextStyle(color: ThixPolicy.textMain),
        ),
        content: Text(
          l10n.t('parcours_delete_confirm_message'),
          style: TextStyle(color: ThixPolicy.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.t('common_cancel'),
              style: TextStyle(color: ThixPolicy.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.t('parcours_delete'),
              style: TextStyle(color: ThixPolicy.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      debugPrint('[ParcoursForm] 🗑️ Removing experience #$index');
      onRemoveExperience(index);
    }
  }
}
