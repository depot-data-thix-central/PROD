import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/services/document_service.dart';

import '../../theme.dart';
import '../../nav.dart';
import 'dashboard_ui.dart';
import 'dashboard_editors.dart';

// ============================================================
// CONSTANTES DESIGN & CHARTE GRAPHIQUE
// ============================================================
const _blue = Color(0xFF0D2CC1);
const _blueDark = Color(0xFF0A1E8A);
const _bgLight = Color(0xFFF5F6FB);

String _truncate(String v, int max) {
  final s = v.trim();
  if (s.length <= max) return s;
  return '${s.substring(0, max).trim()}…';
}

bool _isPendingThixId(String? id) {
  if (id == null) return true;
  final v = id.trim().toUpperCase();
  return v.isEmpty ||
      v == 'THIX-PENDING' ||
      v == 'THIX-000000' ||
      v.startsWith('THIX-PENDING-');
}

// ============================================================
// COMPOSANTS UI RÉUTILISABLES POUR LES ONGLETS
// ============================================================
class _TabSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  const _TabSectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: _blue, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: _blueDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ============================================================
// TAB: PROFIL (IDENTITÉ & SCORE)
// ============================================================
class ProfileTab extends StatelessWidget {
  final dynamic authUser, profile;
  final int score;
  final dynamic profileService, userService;

  const ProfileTab({
    super.key,
    required this.authUser,
    required this.profile,
    required this.score,
    required this.profileService,
    required this.userService,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 960;
    final user = profile;

    final left = <Widget>[
      // ❌ Callout paiement retiré — inscription gratuite
      _TabSectionCard(
        icon: Icons.badge_rounded,
        title: 'Profil Professionnel',
        subtitle: 'Données liées à votre THIX ID',
        child: Column(
          children: [
            DashboardInfoRow(label: 'THIX ID', value: user.thixId),
            // ❌ UID retiré
            DashboardInfoRow(
              label: 'Email',
              value: authUser.email.isEmpty ? '—' : authUser.email,
            ),
            DashboardInfoRow(
              label: 'Téléphone',
              value: authUser.phone ?? '—',
            ),
            DashboardInfoRow(
              label: 'Contact',
              value: authUser.contactPhone ?? '—',
            ),
            DashboardInfoRow(
              label: 'Profession / Poste',
              value: user.occupation?.trim().isEmpty ?? true
                  ? '—'
                  : user.occupation!.trim(),
            ),
            DashboardInfoRow(
              label: 'Localisation',
              value: user.countryOrOrigin?.trim().isEmpty ?? true
                  ? '—'
                  : user.countryOrOrigin!.trim(),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _ExpandableTextRow(
                    label: 'Bio',
                    text: user.bio ?? '—',
                  ),
                ),
                const SizedBox(width: 6),
                _VisibilityToggle(
                  label: 'Public',
                  value: user.visibility.bio,
                  onChanged: (v) => profileService.updateVisibility(
                    userId: user.userId,
                    visibility: user.visibility.copyWith(bio: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _LanguagesRow(languages: user.languages)),
                const SizedBox(width: 6),
                const _VisibilityToggle(
                  label: 'Public',
                  value: true,
                  onChanged: null,
                  tooltip: 'Les langues sont toujours publiques.',
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _TabSectionCard(
        icon: Icons.account_circle_rounded,
        title: 'Identité civile',
        subtitle: 'Informations sensibles protégées',
        child: Column(
          children: [
            DashboardInfoRow(
              label: 'Date de naissance',
              value: authUser.dateOfBirth ?? '—',
            ),
            DashboardInfoRow(
              label: 'Lieu de naissance',
              value: authUser.placeOfBirth ?? '—',
            ),
            DashboardInfoRow(
              label: 'Nationalité',
              value: authUser.nationality ?? '—',
            ),
            DashboardInfoRow(
              label: 'État civil',
              value: authUser.maritalStatus ?? '—',
            ),
            DashboardInfoRow(
              label: 'Adresse',
              value: authUser.address ?? '—',
            ),
            DashboardInfoRow(
              label: 'Père',
              value: authUser.fatherName ?? '—',
            ),
            DashboardInfoRow(
              label: 'Mère',
              value: authUser.motherName ?? '—',
            ),
          ],
        ),
      ),
    ];

    final right = <Widget>[
      _TabSectionCard(
        icon: Icons.school_rounded,
        title: 'Cursus scolaire',
        subtitle: '${user.education.length} entrée(s)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (user.education.isEmpty)
              const Text(
                'Aucune formation enregistrée.',
                style: TextStyle(fontSize: 11.5, color: Colors.black54),
              )
            else
              ...user.education.take(3).map((e) {
                final inst = (e['institution'] as String?) ??
                    (e['school'] as String?) ??
                    '—';
                final degree = (e['degree'] as String?) ?? '';
                final city = (e['city'] as String?) ?? '';
                final start = (e['startYear'] as String?) ?? '';
                final end = (e['endYear'] as String?) ?? '';
                final period =
                    [start, end].where((v) => v.trim().isNotEmpty).join('–');
                final meta = [degree, city, period]
                    .where((v) => v.trim().isNotEmpty)
                    .join(' • ');

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(
                    Icons.school_rounded,
                    color: Colors.grey,
                    size: 18,
                  ),
                  title: Text(
                    inst,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  subtitle: meta.isEmpty
                      ? null
                      : Text(
                          meta,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.black54,
                          ),
                        ),
                );
              }),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => EducationEditorSheet.show(
                      context,
                      profile: user,
                      profileService: profileService,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Gérer', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blueDark,
                      side: BorderSide(color: _blue.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _VisibilityToggle(
                  label: 'Public',
                  value: user.visibility.education,
                  onChanged: (v) => profileService.updateVisibility(
                    userId: user.userId,
                    visibility: user.visibility.copyWith(education: v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _TabSectionCard(
        icon: Icons.insights_rounded,
        title: 'Indice de confiance',
        subtitle: 'THIX Score + conformité',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'THIX Score:',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  '$score/100',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: _blueDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: LinearProgressIndicator(
                value: (score.clamp(0, 100)) / 100.0,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Colors.green),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Complétez votre Bio, Compétences, Formations et Documents pour atteindre 100.',
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ];

    if (!isWide) {
      return TabScaffold(
        children: [...left, const SizedBox(height: 8), ...right],
      );
    }

    return TabScaffold(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: left)),
            const SizedBox(width: 14),
            Expanded(child: Column(children: right)),
          ],
        ),
      ],
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? tooltip;

  const _VisibilityToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: Colors.black54,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 28,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _ExpandableTextRow extends StatefulWidget {
  final String label, text;
  const _ExpandableTextRow({required this.label, required this.text});
  @override
  State<_ExpandableTextRow> createState() => _ExpandableTextRowState();
}

class _ExpandableTextRowState extends State<_ExpandableTextRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final raw = widget.text.trim();
    final text = raw.isEmpty ? '—' : raw;
    final maxLines = _expanded ? 99 : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (raw.length > 50)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _expanded ? 'Moins' : 'Plus',
                  style: const TextStyle(fontSize: 10.5, color: _blue),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _LanguagesRow extends StatelessWidget {
  final List<String> languages;
  const _LanguagesRow({required this.languages});

  @override
  Widget build(BuildContext context) {
    final list =
        languages.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Langues',
          style: TextStyle(
            fontSize: 11,
            color: Colors.black54,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (list.isEmpty)
          const Text(
            '—',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          )
        else
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: list
                .map(
                  (l) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _bgLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      l,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _blueDark,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

// ============================================================
// TAB: DOCUMENTS (SANS STREAM)
// ============================================================
class DocumentsTab extends StatelessWidget {
  final String uid;
  final DocumentService docs;
  final dynamic userService;
  final String filter;
  final ValueChanged<String> onChangeFilter;

  const DocumentsTab({
    super.key,
    required this.uid,
    required this.docs,
    required this.userService,
    required this.filter,
    required this.onChangeFilter,
  });

  static const _filters = [
    'Tous',
    'CIN',
    'Passeport',
    'Permis',
    'Diplôme',
    'PreuveAdresse',
    'Autre',
  ];

  @override
  Widget build(BuildContext context) => TabScaffold(
        children: [
          _TabSectionCard(
            icon: Icons.folder_special_rounded,
            title: 'Documents Sécurisés',
            subtitle: 'Votre portefeuille numérique certifié',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _filters
                      .map(
                        (f) => ChoiceChip(
                          label: Text(f, style: const TextStyle(fontSize: 11.5)),
                          selected: filter == f,
                          onSelected: (_) => onChangeFilter(f),
                          selectedColor: _blue.withOpacity(0.1),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: filter == f ? _blue : Colors.black87,
                          ),
                          side: BorderSide(
                            color: filter == f ? _blue : Colors.black12,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: docs.fetchDocuments(uid, limit: 50),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      );
                    }

                    final all = snap.data ?? [];
                    final filtered = all.where((d) {
                      if (filter == 'Tous') return true;
                      final t = (d['doc_type'] as String?) ??
                          (d['docType'] as String?) ??
                          'Autre';
                      return t == filter;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Aucun document trouvé pour ce filtre.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: filtered.take(10).map((data) {
                        final title = (data['title'] as String?) ??
                            (data['doc_id'] as String?) ??
                            'Document';
                        final docId = (data['doc_id'] as String?) ?? '';
                        final status = (data['status'] as String?) ?? 'pending';
                        final exp = data['expires_at'];
                        final expiresAt = exp is DateTime
                            ? exp
                            : (exp is String ? DateTime.tryParse(exp) : null);
                        
                        // CORRECTION : Utilisation de la syntaxe ${...} correcte
                        final dateStr = expiresAt == null
                            ? '—'
                            : '${expiresAt.day.toString().padLeft(2, '0')}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.year}';
                            
                        final chip = _DocStatusChip.from(status);

                        return DocRow(
                          name: title,
                          date: docId.isEmpty
                              ? 'Expiration: $dateStr'
                              : '$docId • Exp: $dateStr',
                          status: chip.label,
                          statusBg: chip.bg,
                          statusText: chip.fg,
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () {
                      // Upload libre — plus de frais
                      context.push(AppRoutes.vault);
                    },
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: const Text(
                      'Nouveau document',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _DocStatusChip {
  final String label;
  final Color bg, fg;

  const _DocStatusChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  factory _DocStatusChip.from(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'verified') {
      return const _DocStatusChip(
        label: 'Vérifié',
        bg: Color(0xFFE6FFFA),
        fg: Colors.green,
      );
    }
    if (v == 'rejected') {
      return _DocStatusChip(
        label: 'Rejeté',
        bg: Colors.red.shade50,
        fg: Colors.red.shade700,
      );
    }
    return _DocStatusChip(
      label: 'En attente',
      bg: Colors.orange.withOpacity(0.15),
      fg: Colors.orange.shade800,
    );
  }
}

// ============================================================
// TAB: EXPÉRIENCES & COMPÉTENCES
// ============================================================
class ExperienceSkillsTab extends StatelessWidget {
  final dynamic profile, profileService;

  const ExperienceSkillsTab({
    super.key,
    required this.profile,
    required this.profileService,
  });

  @override
  Widget build(BuildContext context) {
    final user = profile;
    return TabScaffold(
      children: [
        _TabSectionCard(
          icon: Icons.business_center_rounded,
          title: 'Expériences professionnelles',
          subtitle: '${user.experience.length} expérience(s)',
          child: Column(
            children: [
              if (user.experience.isEmpty)
                const Text(
                  'Aucune expérience. Ajoutez votre parcours.',
                  style: TextStyle(fontSize: 11.5, color: Colors.black54),
                )
              else
                ...user.experience.map((e) {
                  final title = (e['title'] as String?) ?? '—';
                  final org = (e['org'] as String?) ??
                      (e['company'] as String?) ??
                      '';
                  final date = (e['date'] as String?) ?? '';
                  final tasks = (e['tasks'] as String?) ?? '';
                  final meta = [org, date]
                      .where((v) => v.trim().isNotEmpty)
                      .join(' • ');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.work_outline_rounded,
                          color: Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              if (meta.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  meta,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (tasks.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  _truncate(tasks, 120),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ExperienceEditorSheet.show(
                        context,
                        profile: user,
                        profileService: profileService,
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text(
                        'Gérer',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blueDark,
                        side: BorderSide(color: _blue.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TAB: PAIEMENTS (SANS STREAM)
// ============================================================
class PaymentsTab extends StatelessWidget {
  final String uid;
  final dynamic userService, user;

  const PaymentsTab({
    super.key,
    required this.uid,
    required this.userService,
    required this.user,
  });

  @override
  Widget build(BuildContext context) => TabScaffold(
        children: [
          _TabSectionCard(
            icon: Icons.payments_rounded,
            title: 'Historique des Paiements',
            subtitle: 'Transactions liées à votre THIX ID',
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: userService.fetchPayments(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  );
                }

                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Text(
                    'Aucune transaction enregistrée.',
                    style: TextStyle(fontSize: 11.5, color: Colors.black54),
                  );
                }

                return Column(
                  children: list.take(15).map((data) {
                    final title = (data['title'] as String?) ??
                        (data['tx_ref'] as String?) ??
                        'Transaction';
                    final amount = data['amount'];
                    final currency = (data['currency'] as String?) ?? 'USD';
                    final method = (data['method'] as String?) ?? '—';
                    final status = (data['status'] as String?) ?? 'paid';
                    final created = data['created_at'];
                    final dt = created is DateTime
                        ? created
                        : (created is String
                            ? DateTime.tryParse(created)
                            : null);
                            
                    // CORRECTION : Utilisation de la syntaxe ${...} correcte
                    final dateStr = dt == null
                        ? '—'
                        : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                        
                    final amountStr =
                        '${(amount is num ? amount.toStringAsFixed(2) : amount?.toString() ?? '0.00')} $currency';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            status == 'paid'
                                ? Icons.check_circle_rounded
                                : Icons.pending_rounded,
                            color: status == 'paid'
                                ? Colors.green
                                : Colors.orange,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$dateStr • $method',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            amountStr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: _blueDark,
                            ),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            tooltip: 'Télécharger le reçu',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              try {
                                final bytes = await _ReceiptPdf.build(
                                  user: user,
                                  tx: data,
                                );
                                if (!context.mounted) return;
                                await Printing.layoutPdf(
                                  onLayout: (_) async => bytes,
                                );
                              } catch (e) {
                                debugPrint('Receipt failed $e');
                              }
                            },
                            icon: const Icon(
                              Icons.download_rounded,
                              color: _blue,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      );
}

class _ReceiptPdf {
  static Future<Uint8List> build({
    required dynamic user,
    required Map<String, dynamic> tx,
  }) async {
    final title = (tx['title'] as String?) ?? 'Transaction';
    final amount = tx['amount'];
    final currency = (tx['currency'] as String?) ?? 'USD';
    final method = (tx['method'] as String?) ?? '—';
    final status = (tx['status'] as String?) ?? 'paid';
    final created = tx['created_at'];
    final dt = created is DateTime
        ? created
        : (created is String ? DateTime.tryParse(created) : null);
        
    // CORRECTION : Utilisation de la syntaxe ${...} correcte
    final dateStr = dt == null
        ? '—'
        : '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        
    final amountStr =
        '${(amount is num ? amount.toStringAsFixed(2) : amount?.toString() ?? '0.00')} $currency';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (_) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'THIX ID — Reçu de Paiement',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Utilisateur: ${user.displayName}'),
              pw.Text('THIX ID: ${user.thixId}'),
              pw.SizedBox(height: 12),
              pw.Text(
                'Opération: $title',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Montant: $amountStr'),
              pw.Text('Méthode: $method'),
              pw.Text('Statut: $status'),
              pw.Text('Date: $dateStr'),
              pw.SizedBox(height: 18),
              pw.Text(
                'Ce reçu est généré automatiquement.',
                style: const pw.TextStyle(color: PdfColors.grey),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }
}

// ============================================================
// TAB: SÉCURITÉ
// ============================================================
class SecurityTab extends StatelessWidget {
  final String uid;
  final dynamic user, userService;

  const SecurityTab({
    super.key,
    required this.uid,
    required this.user,
    required this.userService,
  });

  @override
  Widget build(BuildContext context) => TabScaffold(
        children: [
          _TabSectionCard(
            icon: Icons.shield_rounded,
            title: 'Sécurité du Compte',
            subtitle: 'Paramètres et journalisation',
            child: Column(
              children: [
                _SecurityToggleRow(
                  icon: Icons.fingerprint_rounded,
                  title: 'Connexion Biométrique',
                  value: user.biometricsEnabled ?? false,
                  onChanged: (v) async {
                    try {
                      await userService.updateProfile(
                        uid: uid,
                        biometricsEnabled: v,
                      );
                      unawaited(
                        userService.logSecurityEvent(
                          uid: uid,
                          type: 'security_change',
                          label: 'Biométrie ${v ? 'activée' : 'désactivée'}',
                        ),
                      );
                    } catch (e) {
                      debugPrint('Sec toggle failed $e');
                    }
                  },
                ),
                const SizedBox(height: 10),
                _SecurityToggleRow(
                  icon: Icons.vpn_key_rounded,
                  title: 'Double Authentification (2FA)',
                  value: user.twoFaEnabled ?? false,
                  onChanged: (v) async {
                    try {
                      await userService.updateProfile(
                        uid: uid,
                        twoFaEnabled: v,
                      );
                      unawaited(
                        userService.logSecurityEvent(
                          uid: uid,
                          type: 'security_change',
                          label: '2FA ${v ? 'activée' : 'désactivée'}',
                        ),
                      );
                    } catch (e) {
                      debugPrint('2fa toggle failed $e');
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Journal des connexions',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.settings),
                      child: const Text(
                        'Plus de détails',
                        style: TextStyle(color: _blue, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: userService.fetchSecurityEvents(uid),
                  builder: (context, snap) {
                    final list = snap.data ?? [];
                    if (list.isEmpty) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Aucun événement récent.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 11.5,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: list.take(5).map((data) {
                        final label = (data['label'] as String?) ??
                            (data['type'] as String?) ??
                            'Événement de sécurité';
                        final created = data['created_at'];
                        final dt = created is DateTime
                            ? created
                            : (created is String
                                ? DateTime.tryParse(created)
                                : null);
                                
                        // CORRECTION : Utilisation de la syntaxe ${...} correcte
                        final dateStr = dt == null
                            ? '—'
                            : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history_rounded,
                                color: Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      );
}

class _SecurityToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SecurityToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: Colors.black54, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            height: 28,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      );
}

// ============================================================
// COMPOSANTS : ConfirmFeeSheet & SkillsEditorSheet
// ============================================================

class ConfirmFeeSheet {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String description,
    required String amountLabel,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF0A1E8A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(false),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => context.pop(true),
                icon: const Icon(
                  Icons.payments_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  amountLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2CC1),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(false),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class SkillsEditorSheet {
  static Future<void> show(
    BuildContext context, {
    required ThixProfile profile,
    required dynamic profileService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkillsEditorBody(
        profile: profile,
        profileService: profileService,
      ),
    );
  }
}

class _SkillsEditorBody extends StatefulWidget {
  final ThixProfile profile;
  final dynamic profileService;
  const _SkillsEditorBody({
    required this.profile,
    required this.profileService,
  });
  @override
  State<_SkillsEditorBody> createState() => _SkillsEditorBodyState();
}

class _SkillsEditorBodyState extends State<_SkillsEditorBody> {
  final ValueNotifier<bool> _saving = ValueNotifier(false);
  final _nameC = TextEditingController();
  final _detailsC = TextEditingController();
  String _level = 'Intermédiaire';
  int? _editingIndex;
  late List<Map<String, dynamic>> _localSkills;

  @override
  void initState() {
    super.initState();
    _localSkills = List<Map<String, dynamic>>.from(widget.profile.skills);
  }

  void _load(int index, Map<String, dynamic> entry) {
    setState(() {
      _editingIndex = index;
      _nameC.text = (entry['name'] as String?) ?? '';
      _level = (entry['level'] as String?) ?? 'Intermédiaire';
      _detailsC.text = (entry['details'] as String?) ?? '';
    });
  }

  void _reset() {
    setState(() {
      _editingIndex = null;
      _nameC.clear();
      _detailsC.clear();
      _level = 'Intermédiaire';
    });
  }

  Future<void> _save() async {
    if (_nameC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom de la compétence est requis.')),
      );
      return;
    }

    _saving.value = true;
    try {
      final patch = {
        'name': _nameC.text.trim(),
        'level': _level,
        if (_detailsC.text.trim().isNotEmpty) 'details': _detailsC.text.trim(),
      };

      if (_editingIndex != null) {
        _localSkills[_editingIndex!] = patch;
      } else {
        _localSkills.insert(0, patch);
      }

      await widget.profileService.updateProfile(
        userId: widget.profile.userId,
        skills: _localSkills,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compétence mise à jour.')),
      );
      _reset();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      _saving.value = false;
    }
  }

  Future<void> _delete(int index) async {
    _saving.value = true;
    try {
      _localSkills.removeAt(index);
      await widget.profileService.updateProfile(
        userId: widget.profile.userId,
        skills: _localSkills,
      );
      if (_editingIndex == index) _reset();
      setState(() {});
    } finally {
      _saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6FB),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Compétences',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF0A1E8A),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _saving,
                    builder: (ctx, isSaving, _) => IconButton(
                      onPressed: isSaving ? null : () => context.pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_localSkills.isNotEmpty) ...[
                      const Text(
                        'Vos compétences enregistrées',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...List.generate(_localSkills.length, (i) {
                        final e = _localSkills[i];
                        final isEditing = _editingIndex == i;
                        return Card(
                          elevation: 0,
                          color: isEditing
                              ? const Color(0xFF0D2CC1).withOpacity(0.05)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isEditing
                                  ? const Color(0xFF0D2CC1)
                                  : Colors.black12,
                            ),
                          ),
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              e['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              e['level'] ?? '',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 18,
                              ),
                              onPressed: () => _delete(i),
                            ),
                            onTap: () => _load(i, e),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editingIndex == null
                                ? 'Ajouter une compétence'
                                : 'Modifier la compétence',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Color(0xFF0A1E8A),
                            ),
                          ),
                          const Divider(height: 20),
                          TextField(
                            controller: _nameC,
                            style: const TextStyle(fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Compétence',
                              labelStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(
                                Icons.psychology_rounded,
                                color: Colors.black54,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _level,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Colors.black87,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Débutant',
                                child: Text('Débutant'),
                              ),
                              DropdownMenuItem(
                                value: 'Intermédiaire',
                                child: Text('Intermédiaire'),
                              ),
                              DropdownMenuItem(
                                value: 'Avancé',
                                child: Text('Avancé'),
                              ),
                              DropdownMenuItem(
                                value: 'Expert',
                                child: Text('Expert'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _level = v ?? 'Intermédiaire'),
                            decoration: InputDecoration(
                              labelText: 'Niveau',
                              labelStyle: const TextStyle(fontSize: 13),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _detailsC,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Explication / Détails',
                              labelStyle: const TextStyle(fontSize: 13),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: Row(
                children: [
                  if (_editingIndex != null) ...[
                    OutlinedButton(
                      onPressed: _reset,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                      ),
                      child: const Text('ANNULER', style: TextStyle(fontSize: 12.5)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _saving,
                      builder: (ctx, isSaving, _) => SizedBox(
                        height: 46,
                        child: FilledButton(
                          onPressed: isSaving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0D2CC1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _editingIndex == null
                                      ? 'AJOUTER'
                                      : 'METTRE À JOUR',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
