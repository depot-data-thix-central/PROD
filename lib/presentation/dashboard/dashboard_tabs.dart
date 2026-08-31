// lib/presentation/home/dashboard_tabs.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/models/app_user.dart';
import 'dashboard_ui.dart';
import 'dashboard_editors.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxBioLength = 500;
const int _kMaxNameLength = 80;
const int _kMaxTitleLength = 60;
const int _kMaxDocPreview = 10;
const int _kMaxPaymentPreview = 15;
const int _kMaxSecurityPreview = 5;

// ============================================================================
// VALIDATORS
// ============================================================================
class _DashValidators {
  _DashValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String truncate(String input, int max) {
    final s = input.trim();
    if (s.length <= max) return s;
    return '${s.substring(0, max).trim()}…';
  }

  static bool isPendingThixId(String? id) {
    if (id == null) return true;
    final v = id.trim().toUpperCase();
    return v.isEmpty ||
        v == 'THIX-PENDING' ||
        v == 'THIX-000000' ||
        v.startsWith('THIX-PENDING-');
  }

  static DateTime? safeParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String formatDate(DateTime? dt, String locale) {
    if (dt == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy', locale).format(dt);
    } catch (_) {
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
  }

  static String formatDateTime(DateTime? dt, String locale) {
    if (dt == null) return '—';
    try {
      return DateFormat('dd/MM HH:mm', locale).format(dt);
    } catch (_) {
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  static String formatIsoDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static String formatAmount(double amount, String currency, String locale) {
    try {
      final isUSD = currency.toUpperCase() == 'USD';
      if (isUSD) {
        return NumberFormat.decimalPatternDigits(
          locale: locale,
          decimalDigits: 2,
        ).format(amount);
      }
      return NumberFormat.decimalPattern(locale).format(amount.toInt());
    } catch (_) {
      return amount.toStringAsFixed(2);
    }
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _dashRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Dashboard] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Dashboard] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Dashboard] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// REUSABLE COMPONENTS
// ============================================================================

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
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
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
                  color: ThixPolicy.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: ThixPolicy.primary, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 13.5,
                        color: ThixPolicy.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.textMuted,
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
          Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
          const SizedBox(height: 12),
          child,
        ],
      ),
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
          style: ThixPolicy.captionStyle.copyWith(
            fontSize: 10.5,
            color: ThixPolicy.textMuted,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        const SizedBox(width: 4),
        Semantics(
          toggled: value,
          label: '$label: ${value ? "on" : "off"}',
          child: SizedBox(
            height: 28,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: ThixPolicy.success,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _ExpandableTextRow extends StatefulWidget {
  final String label;
  final String text;

  const _ExpandableTextRow({required this.label, required this.text});

  @override
  State<_ExpandableTextRow> createState() => _ExpandableTextRowState();
}

class _ExpandableTextRowState extends State<_ExpandableTextRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final raw = widget.text.trim();
    final safeText = _DashValidators.sanitize(raw, maxLength: _kMaxBioLength);
    final displayText = safeText.isEmpty ? '—' : safeText;
    final maxLines = _expanded ? 99 : 3;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: ThixPolicy.captionStyle.copyWith(
                fontSize: 11,
                color: ThixPolicy.textMuted,
                fontWeight: ThixPolicy.bold,
              ),
            ),
            if (safeText.length > 50)
              Semantics(
                button: true,
                label: _expanded ? l10n.t('common_show_less') : l10n.t('common_show_more'),
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _expanded = !_expanded);
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _expanded ? l10n.t('common_show_less') : l10n.t('common_show_more'),
                    style: ThixPolicy.captionStyle.copyWith(
                      fontSize: 10.5,
                      color: ThixPolicy.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          displayText,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: ThixPolicy.bodySmallStyle.copyWith(
            fontWeight: ThixPolicy.semiBold,
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
    final l10n = AppLocalizations.of(context);
    final list = languages
        .map((e) => _DashValidators.sanitize(e, maxLength: 40))
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.t('profile_languages'),
          style: ThixPolicy.captionStyle.copyWith(
            fontSize: 11,
            color: ThixPolicy.textMuted,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        const SizedBox(height: 6),
        if (list.isEmpty)
          Text(
            '—',
            style: ThixPolicy.bodySmallStyle.copyWith(
              fontWeight: ThixPolicy.semiBold,
              fontSize: 12.5,
            ),
          )
        else
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: list
                .map(
                  (l) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ThixPolicy.surfaceSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                    ),
                    child: Text(
                      l,
                      style: ThixPolicy.captionStyle.copyWith(
                        fontSize: 10.5,
                        fontWeight: ThixPolicy.bold,
                        color: ThixPolicy.textMain,
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

class _SkeletonRows extends StatelessWidget {
  final int count;
  const _SkeletonRows({this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 12,
                color: Colors.grey.shade200,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 12,
                  color: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocStatusChip {
  final String label;
  final Color bg;
  final Color fg;

  const _DocStatusChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  factory _DocStatusChip.from(String raw, AppLocalizations l10n) {
    final v = raw.trim().toLowerCase();
    if (v == 'verified') {
      return _DocStatusChip(
        label: l10n.t('status_verified'),
        bg: ThixPolicy.success.withOpacity(0.15),
        fg: ThixPolicy.success,
      );
    }
    if (v == 'rejected') {
      return _DocStatusChip(
        label: l10n.t('status_rejected'),
        bg: ThixPolicy.danger.withOpacity(0.1),
        fg: ThixPolicy.danger,
      );
    }
    return _DocStatusChip(
      label: l10n.t('status_pending'),
      bg: ThixPolicy.warning.withOpacity(0.15),
      fg: ThixPolicy.warning,
    );
  }
}

// ============================================================================
// PROFILE TAB
// ============================================================================
class ProfileTab extends StatelessWidget {
  final dynamic authUser;
  final ThixProfile profile;
  final int score;
  final dynamic profileService;
  final dynamic userService;

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
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.of(context).size.width >= 960;
    final user = profile;

    final safeThixId = _DashValidators.sanitize(user.thixId, maxLength: 50);
    final safeEmail = _DashValidators.sanitize(authUser.email, maxLength: 80);
    final safePhone = _DashValidators.sanitize(authUser.phone, maxLength: 30);
    final safeContact = _DashValidators.sanitize(authUser.contactPhone, maxLength: 30);
    final safeOccupation = _DashValidators.sanitize(user.occupation, maxLength: 80);
    final safeCountry = _DashValidators.sanitize(user.countryOrOrigin, maxLength: 60);
    final safeDob = _DashValidators.sanitize(authUser.dateOfBirth, maxLength: 30);
    final safePob = _DashValidators.sanitize(authUser.placeOfBirth, maxLength: 60);
    final safeNationality = _DashValidators.sanitize(authUser.nationality, maxLength: 40);
    final safeMarital = _DashValidators.sanitize(authUser.maritalStatus, maxLength: 30);
    final safeAddress = _DashValidators.sanitize(authUser.address, maxLength: 120);
    final safeFather = _DashValidators.sanitize(authUser.fatherName, maxLength: _kMaxNameLength);
    final safeMother = _DashValidators.sanitize(authUser.motherName, maxLength: _kMaxNameLength);

    final left = <Widget>[
      _TabSectionCard(
        icon: Icons.badge_rounded,
        title: l10n.t('profile_professional'),
        subtitle: l10n.t('profile_thix_linked'),
        child: Column(
          children: [
            DashboardInfoRow(label: 'THIX ID', value: safeThixId),
            DashboardInfoRow(
              label: l10n.t('profile_email'),
              value: safeEmail.isEmpty ? '—' : safeEmail,
            ),
            DashboardInfoRow(
              label: l10n.t('profile_phone'),
              value: safePhone.isEmpty ? '—' : safePhone,
            ),
            DashboardInfoRow(
              label: l10n.t('profile_contact'),
              value: safeContact.isEmpty ? '—' : safeContact,
            ),
            DashboardInfoRow(
              label: l10n.t('profile_occupation'),
              value: safeOccupation.isEmpty ? '—' : safeOccupation,
            ),
            DashboardInfoRow(
              label: l10n.t('profile_location'),
              value: safeCountry.isEmpty ? '—' : safeCountry,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _ExpandableTextRow(
                    label: l10n.t('profile_bio'),
                    text: user.bio ?? '—',
                  ),
                ),
                const SizedBox(width: 6),
                _VisibilityToggle(
                  label: l10n.t('common_public'),
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
                _VisibilityToggle(
                  label: l10n.t('common_public'),
                  value: true,
                  onChanged: null,
                  tooltip: l10n.t('profile_languages_always_public'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _TabSectionCard(
        icon: Icons.account_circle_rounded,
        title: l10n.t('profile_civil_identity'),
        subtitle: l10n.t('profile_sensitive_protected'),
        child: Column(
          children: [
            DashboardInfoRow(label: l10n.t('profile_dob'), value: safeDob.isEmpty ? '—' : safeDob),
            DashboardInfoRow(label: l10n.t('profile_pob'), value: safePob.isEmpty ? '—' : safePob),
            DashboardInfoRow(label: l10n.t('profile_nationality'), value: safeNationality.isEmpty ? '—' : safeNationality),
            DashboardInfoRow(label: l10n.t('profile_marital'), value: safeMarital.isEmpty ? '—' : safeMarital),
            DashboardInfoRow(label: l10n.t('profile_address'), value: safeAddress.isEmpty ? '—' : safeAddress),
            DashboardInfoRow(label: l10n.t('profile_father'), value: safeFather.isEmpty ? '—' : safeFather),
            DashboardInfoRow(label: l10n.t('profile_mother'), value: safeMother.isEmpty ? '—' : safeMother),
          ],
        ),
      ),
    ];

    final right = <Widget>[
      _TabSectionCard(
        icon: Icons.school_rounded,
        title: l10n.t('profile_education'),
        subtitle: '${user.education.length} ${l10n.t('profile_entries')}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (user.education.isEmpty)
              Text(
                l10n.t('profile_no_education'),
                style: ThixPolicy.captionStyle.copyWith(
                  fontSize: 11.5,
                  color: ThixPolicy.textMuted,
                ),
              )
            else
              ...user.education.take(3).map((e) {
                final inst = _DashValidators.sanitize(
                  (e['institution'] as String?) ?? (e['school'] as String?),
                  maxLength: _kMaxNameLength,
                );
                final degree = _DashValidators.sanitize(e['degree'] as String?, maxLength: 60);
                final city = _DashValidators.sanitize(e['city'] as String?, maxLength: 40);
                final start = (e['startYear'] as String?) ?? '';
                final end = (e['endYear'] as String?) ?? '';
                final period = [start, end].where((v) => v.trim().isNotEmpty).join('–');
                final meta = [degree, city, period]
                    .where((v) => v.trim().isNotEmpty)
                    .join(' • ');

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(Icons.school_rounded, color: ThixPolicy.textMuted, size: 18),
                  title: Text(
                    inst.isEmpty ? '—' : inst,
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  subtitle: meta.isEmpty
                      ? null
                      : Text(
                          meta,
                          style: ThixPolicy.captionStyle.copyWith(
                            fontSize: 10.5,
                            color: ThixPolicy.textMuted,
                          ),
                        ),
                );
              }),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l10n.t('common_manage'),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        EducationEditorSheet.show(
                          context,
                          profile: user,
                          profileService: profileService,
                        );
                      },
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: Text(l10n.t('common_manage'), style: const TextStyle(fontSize: 11.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ThixPolicy.primaryDeep,
                        side: BorderSide(color: ThixPolicy.primary.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _VisibilityToggle(
                  label: l10n.t('common_public'),
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
        title: l10n.t('profile_trust_index'),
        subtitle: l10n.t('profile_score_compliance'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.t('profile_thix_score')}:',
                  style: ThixPolicy.captionStyle.copyWith(
                    fontWeight: ThixPolicy.semiBold,
                    fontSize: 12.5,
                    color: ThixPolicy.textMuted,
                  ),
                ),
                Text(
                  '$score/100',
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                    color: ThixPolicy.primaryDeep,
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
                valueColor: AlwaysStoppedAnimation(ThixPolicy.success),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t('profile_score_hint'),
              style: ThixPolicy.captionStyle.copyWith(
                fontSize: 10.5,
                color: ThixPolicy.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ];

    if (!isWide) {
      return TabScaffold(children: [...left, const SizedBox(height: 8), ...right]);
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

// ============================================================================
// DOCUMENTS TAB
// ============================================================================
class DocumentsTab extends StatefulWidget {
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

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  static const _filters = [
    'all', 'CIN', 'Passeport', 'Permis', 'Diplôme', 'PreuveAdresse', 'other',
  ];

  Future<List<Map<String, dynamic>>>? _docsFuture;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  void _loadDocs() {
    _docsFuture = _dashRetry(
      () => widget.docs.fetchDocuments(widget.uid, limit: 50),
      label: 'fetchDocuments',
    );
  }

  String _filterLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'all': return l10n.t('filter_all');
      case 'other': return l10n.t('filter_other');
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TabScaffold(
      children: [
        _TabSectionCard(
          icon: Icons.folder_special_rounded,
          title: l10n.t('docs_secure_title'),
          subtitle: l10n.t('docs_secure_subtitle'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _filters.map((f) {
                  final selected = widget.filter == f;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: _filterLabel(f, l10n),
                    child: ChoiceChip(
                      label: Text(
                        _filterLabel(f, l10n),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: selected,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        widget.onChangeFilter(f);
                      },
                      selectedColor: ThixPolicy.primary.withOpacity(0.1),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: selected ? ThixPolicy.primary : ThixPolicy.textMain,
                      ),
                      side: BorderSide(
                        color: selected ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _docsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: _SkeletonRows(count: 4),
                    );
                  }

                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              _DashValidators.friendlyError(snap.error),
                              style: ThixPolicy.captionStyle.copyWith(
                                color: ThixPolicy.textMuted,
                                fontSize: 11.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _loadDocs());
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 14),
                              label: Text(l10n.t('common_retry')),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final all = snap.data ?? [];
                  final filtered = all.where((d) {
                    if (widget.filter == 'all') return true;
                    if (widget.filter == 'other') {
                      final t = (d['doc_type'] as String?) ?? (d['docType'] as String?) ?? 'other';
                      return t == 'other' || t == 'Autre';
                    }
                    final t = (d['doc_type'] as String?) ?? (d['docType'] as String?) ?? 'other';
                    return t == widget.filter;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(Icons.folder_off_rounded, color: ThixPolicy.textMuted, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            l10n.t('docs_empty'),
                            style: ThixPolicy.captionStyle.copyWith(
                              color: ThixPolicy.textMuted,
                              fontSize: 11.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: filtered.take(_kMaxDocPreview).map((data) {
                      final title = _DashValidators.sanitize(
                        (data['title'] as String?) ?? (data['doc_id'] as String?),
                        maxLength: _kMaxTitleLength,
                      );
                      final docId = _DashValidators.sanitize(data['doc_id'] as String?, maxLength: 40);
                      final status = (data['status'] as String?) ?? 'pending';
                      final expiresAt = _DashValidators.safeParseDate(data['expires_at']);
                      final dateStr = _DashValidators.formatDate(expiresAt, Localizations.localeOf(context).languageCode);
                      final chip = _DocStatusChip.from(status, l10n);

                      return DocRow(
                        name: title.isEmpty ? l10n.t('docs_document') : title,
                        date: docId.isEmpty
                            ? '${l10n.t('docs_expires')}: $dateStr'
                            : '$docId • ${l10n.t('docs_exp')}: $dateStr',
                        status: chip.label,
                        statusBg: chip.bg,
                        statusText: chip.fg,
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: l10n.t('docs_new'),
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      context.push(AppRoutes.vault);
                    },
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: Text(
                      l10n.t('docs_new'),
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
}

// ============================================================================
// EXPERIENCE & SKILLS TAB
// ============================================================================
class ExperienceSkillsTab extends StatelessWidget {
  final ThixProfile profile;
  final dynamic profileService;

  const ExperienceSkillsTab({
    super.key,
    required this.profile,
    required this.profileService,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = profile;

    return TabScaffold(
      children: [
        _TabSectionCard(
          icon: Icons.business_center_rounded,
          title: l10n.t('exp_title'),
          subtitle: '${user.experience.length} ${l10n.t('exp_entries')}',
          child: Column(
            children: [
              if (user.experience.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(Icons.work_off_rounded, color: ThixPolicy.textMuted, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        l10n.t('exp_empty'),
                        style: ThixPolicy.captionStyle.copyWith(
                          fontSize: 11.5,
                          color: ThixPolicy.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...user.experience.map((e) {
                  final title = _DashValidators.sanitize(e['title'] as String?, maxLength: _kMaxTitleLength);
                  final org = _DashValidators.sanitize(
                    (e['org'] as String?) ?? (e['company'] as String?),
                    maxLength: _kMaxNameLength,
                  );
                  final date = _DashValidators.sanitize(e['date'] as String?, maxLength: 40);
                  final tasks = _DashValidators.sanitize(e['tasks'] as String?, maxLength: 300);
                  final meta = [org, date].where((v) => v.trim().isNotEmpty).join(' • ');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.work_outline_rounded, color: ThixPolicy.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? '—' : title,
                                style: ThixPolicy.labelStyle.copyWith(
                                  fontWeight: ThixPolicy.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (meta.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  meta,
                                  style: ThixPolicy.captionStyle.copyWith(
                                    fontSize: 10.5,
                                    color: ThixPolicy.textMuted,
                                    fontWeight: ThixPolicy.semiBold,
                                  ),
                                ),
                              ],
                              if (tasks.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  _DashValidators.truncate(tasks, 120),
                                  style: ThixPolicy.captionStyle.copyWith(
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
              Semantics(
                button: true,
                label: l10n.t('common_manage'),
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ExperienceEditorSheet.show(
                      context,
                      profile: user,
                      profileService: profileService,
                    );
                  },
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: Text(l10n.t('common_manage'), style: const TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThixPolicy.primaryDeep,
                    side: BorderSide(color: ThixPolicy.primary.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PAYMENTS TAB
// ============================================================================
class PaymentsTab extends StatefulWidget {
  final String uid;
  final dynamic userService;
  final ThixProfile user;

  const PaymentsTab({
    super.key,
    required this.uid,
    required this.userService,
    required this.user,
  });

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  Future<List<Map<String, dynamic>>>? _paymentsFuture;
  final Set<String> _downloadingIds = {};

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    _paymentsFuture = _dashRetry(
      () => widget.userService.fetchPayments(widget.uid),
      label: 'fetchPayments',
    );
  }

  Future<void> _downloadReceipt(Map<String, dynamic> tx) async {
    final txId = tx['tx_ref']?.toString() ?? tx.hashCode.toString();
    if (_downloadingIds.contains(txId)) return;

    if (!mounted) return;
    setState(() => _downloadingIds.add(txId));
    HapticFeedback.mediumImpact();

    try {
      final bytes = await _ReceiptPdf.build(user: widget.user, tx: tx);
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => bytes);
      debugPrint('[Dashboard] ✓ Receipt generated');
    } catch (e) {
      debugPrint('[Dashboard] ❌ Receipt error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_DashValidators.friendlyError(e)),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingIds.remove(txId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TabScaffold(
      children: [
        _TabSectionCard(
          icon: Icons.payments_rounded,
          title: l10n.t('payments_title'),
          subtitle: l10n.t('payments_subtitle'),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _paymentsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: _SkeletonRows(count: 4),
                );
              }

              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _DashValidators.friendlyError(snap.error),
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.textMuted,
                            fontSize: 11.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => setState(() => _loadPayments()),
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: Text(l10n.t('common_retry')),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final list = snap.data ?? [];
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, color: ThixPolicy.textMuted, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        l10n.t('payments_empty'),
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: list.take(_kMaxPaymentPreview).map((data) {
                  final title = _DashValidators.sanitize(
                    (data['title'] as String?) ?? (data['tx_ref'] as String?),
                    maxLength: _kMaxTitleLength,
                  );
                  final amount = _DashValidators.safeDouble(data['amount']);
                  final currency = ((data['currency'] as String?) ?? 'USD').toUpperCase();
                  final method = _DashValidators.sanitize(data['method'] as String?, maxLength: 40);
                  final status = (data['status'] as String?) ?? 'paid';
                  final dt = _DashValidators.safeParseDate(data['created_at']);
                  final dateStr = _DashValidators.formatDate(expiresAt, Localizations.localeOf(context).languageCode);
                  final amountStr = _DashValidators.formatAmount(amount, currency, l10n.localeName);
                  final symbol = currency == 'USD' ? '\$' : currency;
                  final txId = data['tx_ref']?.toString() ?? data.hashCode.toString();
                  final isDownloading = _downloadingIds.contains(txId);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          status == 'paid' ? Icons.check_circle_rounded : Icons.pending_rounded,
                          color: status == 'paid' ? ThixPolicy.success : ThixPolicy.warning,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? l10n.t('payments_transaction') : title,
                                style: ThixPolicy.labelStyle.copyWith(
                                  fontWeight: ThixPolicy.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$dateStr • ${method.isEmpty ? '—' : method}',
                                style: ThixPolicy.captionStyle.copyWith(
                                  fontSize: 10.5,
                                  color: ThixPolicy.textMuted,
                                ),
                              ),
                            ], 
                          ),
                        ),
                        Text(
                          '$amountStr $symbol',
                          style: ThixPolicy.labelStyle.copyWith(
                            fontWeight: ThixPolicy.bold,
                            fontSize: 13,
                            color: ThixPolicy.primaryDeep,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l10n.t('payments_download'),
                          enabled: !isDownloading,
                          child: IconButton(
                            tooltip: l10n.t('payments_download'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: isDownloading ? null : () => _downloadReceipt(data),
                            icon: isDownloading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(Icons.download_rounded, color: ThixPolicy.primary, size: 18),
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
}

class _ReceiptPdf {
  static Future<Uint8List> build({
    required ThixProfile user,
    required Map<String, dynamic> tx,
  }) async {
    final title = _DashValidators.sanitize(tx['title'] as String?, maxLength: _kMaxTitleLength);
    final amount = _DashValidators.safeDouble(tx['amount']);
    final currency = ((tx['currency'] as String?) ?? 'USD').toUpperCase();
    final method = _DashValidators.sanitize(tx['method'] as String?, maxLength: 40);
    final status = _DashValidators.sanitize(tx['status'] as String?, maxLength: 20);
    final dt = _DashValidators.safeParseDate(tx['created_at']);
    final dateStr = _DashValidators.formatIsoDate(dt);
    final amountStr = amount.toStringAsFixed(2);
    final safeDisplayName = _DashValidators.sanitize(user.displayName, maxLength: _kMaxNameLength);
    final safeThixId = _DashValidators.sanitize(user.thixId, maxLength: 50);

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
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Utilisateur: ${safeDisplayName.isEmpty ? '—' : safeDisplayName}'),
              pw.Text('THIX ID: ${safeThixId.isEmpty ? '—' : safeThixId}'),
              pw.SizedBox(height: 12),
              pw.Text(
                'Opération: ${title.isEmpty ? 'Transaction' : title}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Montant: $amountStr $currency'),
              pw.Text('Méthode: ${method.isEmpty ? '—' : method}'),
              pw.Text('Statut: ${status.isEmpty ? 'paid' : status}'),
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

// ============================================================================
// SECURITY TAB
// ============================================================================
class SecurityTab extends StatefulWidget {
  final String uid;
  final ThixProfile user;
  final dynamic userService;

  const SecurityTab({
    super.key,
    required this.uid,
    required this.user,
    required this.userService,
  });

  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  Future<List<Map<String, dynamic>>>? _eventsFuture;
  bool _togglingBio = false;
  bool _toggling2FA = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    _eventsFuture = _dashRetry(
      () => widget.userService.fetchSecurityEvents(widget.uid),
      label: 'fetchSecurityEvents',
    );
  }

  Future<void> _toggleBiometrics(bool v) async {
    if (_togglingBio) return;
    setState(() => _togglingBio = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.userService.updateProfile(uid: widget.uid, biometricsEnabled: v);
      unawaited(
        widget.userService.logSecurityEvent(
          uid: widget.uid,
          type: 'security_change',
          label: 'Biométrie ${v ? 'activée' : 'désactivée'}',
        ),
      );
      debugPrint('[Dashboard] ✓ Biometrics: $v');
    } catch (e) {
      debugPrint('[Dashboard] ❌ Biometrics error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_DashValidators.friendlyError(e)),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingBio = false);
    }
  }

  Future<void> _toggle2FA(bool v) async {
    if (_toggling2FA) return;
    setState(() => _toggling2FA = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.userService.updateProfile(uid: widget.uid, twoFaEnabled: v);
      unawaited(
        widget.userService.logSecurityEvent(
          uid: widget.uid,
          type: 'security_change',
          label: '2FA ${v ? 'activée' : 'désactivée'}',
        ),
      );
      debugPrint('[Dashboard] ✓ 2FA: $v');
    } catch (e) {
      debugPrint('[Dashboard] ❌ 2FA error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_DashValidators.friendlyError(e)),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling2FA = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TabScaffold(
      children: [
        _TabSectionCard(
          icon: Icons.shield_rounded,
          title: l10n.t('security_title'),
          subtitle: l10n.t('security_subtitle'),
          child: Column(
            children: [
              _SecurityToggleRow(
                icon: Icons.fingerprint_rounded,
                title: l10n.t('security_biometrics'),
                value: widget.user.biometricsEnabled ?? false,
                isLoading: _togglingBio,
                onChanged: _toggleBiometrics,
              ),
              const SizedBox(height: 10),
              _SecurityToggleRow(
                icon: Icons.vpn_key_rounded,
                title: l10n.t('security_2fa'),
                value: widget.user.twoFaEnabled ?? false,
                isLoading: _toggling2FA,
                onChanged: _toggle2FA,
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.t('security_logins'),
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 13,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.t('security_more'),
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.push(AppRoutes.settings);
                      },
                      child: Text(
                        l10n.t('security_more'),
                        style: TextStyle(color: ThixPolicy.primary, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _eventsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _SkeletonRows(count: 3);
                  }

                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.t('security_no_events'),
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: list.take(_kMaxSecurityPreview).map((data) {
                      final label = _DashValidators.sanitize(
                        (data['label'] as String?) ?? (data['type'] as String?),
                        maxLength: 60,
                      );
                      final dt = _DashValidators.safeParseDate(data['created_at']);
                      final dateStr = _DashValidators.formatDate(expiresAt, Localizations.localeOf(context).languageCode);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, color: ThixPolicy.textMuted, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label.isEmpty ? '—' : label,
                                    style: ThixPolicy.labelStyle.copyWith(
                                      fontWeight: ThixPolicy.semiBold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: ThixPolicy.captionStyle.copyWith(
                                      color: ThixPolicy.textMuted,
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
}

class _SecurityToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  const _SecurityToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ThixPolicy.textMuted, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: ThixPolicy.labelStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              fontSize: 13,
            ),
          ),
        ),
        Semantics(
          toggled: value,
          label: title,
          child: SizedBox(
            height: 28,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: value,
                    onChanged: onChanged,
                    activeColor: ThixPolicy.success,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SHEETS
// ============================================================================

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
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
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
                    style: ThixPolicy.titleStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 16,
                      color: ThixPolicy.primaryDeep,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Close',
                  child: IconButton(
                    onPressed: () => context.pop(false),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: ThixPolicy.bodyStyle.copyWith(
                color: ThixPolicy.textMuted,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: amountLabel,
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    context.pop(true);
                  },
                  icon: const Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                  label: Text(
                    amountLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.pop(false);
              },
              child: const Text('Annuler', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
      builder: (_) => _SkillsEditorBody(profile: profile, profileService: profileService),
    );
  }
}

class _SkillsEditorBody extends StatefulWidget {
  final ThixProfile profile;
  final dynamic profileService;

  const _SkillsEditorBody({required this.profile, required this.profileService});

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

  static const _levels = ['Débutant', 'Intermédiaire', 'Avancé', 'Expert'];

  @override
  void initState() {
    super.initState();
    _localSkills = List<Map<String, dynamic>>.from(widget.profile.skills);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _detailsC.dispose();
    _saving.dispose();
    super.dispose();
  }

  void _load(int index, Map<String, dynamic> entry) {
    HapticFeedback.selectionClick();
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
    final name = _DashValidators.sanitize(_nameC.text, maxLength: _kMaxNameLength);
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nom de la compétence est requis.'),
          backgroundColor: ThixPolicy.warning,
        ),
      );
      return;
    }

    if (_saving.value) return;
    _saving.value = true;
    HapticFeedback.mediumImpact();

    try {
      final patch = {
        'name': name,
        'level': _level,
        if (_detailsC.text.trim().isNotEmpty)
          'details': _DashValidators.sanitize(_detailsC.text, maxLength: 300),
      };

      if (_editingIndex != null) {
        _localSkills[_editingIndex!] = patch;
      } else {
        _localSkills.insert(0, patch);
      }

      await _dashRetry(
        () => widget.profileService.updateProfile(
          userId: widget.profile.userId,
          skills: _localSkills,
        ),
        label: 'updateSkills',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Compétence mise à jour.'),
          backgroundColor: ThixPolicy.success,
        ),
      );
      _reset();
    } catch (e) {
      debugPrint('[Dashboard] ❌ Save skill error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_DashValidators.friendlyError(e)),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  Future<void> _delete(int index) async {
    if (_saving.value) return;
    _saving.value = true;
    HapticFeedback.lightImpact();

    try {
      _localSkills.removeAt(index);
      await _dashRetry(
        () => widget.profileService.updateProfile(
          userId: widget.profile.userId,
          skills: _localSkills,
        ),
        label: 'deleteSkill',
      );
      if (_editingIndex == index) _reset();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[Dashboard] ❌ Delete skill error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_DashValidators.friendlyError(e)),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Compétences',
                    style: ThixPolicy.titleStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 16,
                      color: ThixPolicy.primaryDeep,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _saving,
                    builder: (ctx, isSaving, _) => Semantics(
                      button: true,
                      label: 'Close',
                      enabled: !isSaving,
                      child: IconButton(
                        onPressed: isSaving ? null : () => context.pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
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
                      Text(
                        'Vos compétences enregistrées',
                        style: ThixPolicy.labelStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...List.generate(_localSkills.length, (i) {
                        final e = _localSkills[i];
                        final isEditing = _editingIndex == i;
                        final safeName = _DashValidators.sanitize(e['name'] as String?, maxLength: _kMaxNameLength);
                        final safeLevel = _DashValidators.sanitize(e['level'] as String?, maxLength: 30);

                        return Card(
                          elevation: 0,
                          color: isEditing
                              ? ThixPolicy.primary.withOpacity(0.05)
                              : ThixPolicy.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isEditing ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.6),
                            ),
                          ),
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              safeName.isEmpty ? '—' : safeName,
                              style: ThixPolicy.labelStyle.copyWith(
                                fontWeight: ThixPolicy.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              safeLevel.isEmpty ? '—' : safeLevel,
                              style: ThixPolicy.captionStyle.copyWith(fontSize: 11.5),
                            ),
                            trailing: Semantics(
                              button: true,
                              label: 'Delete',
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                onPressed: () => _delete(i),
                              ),
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
                        color: ThixPolicy.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editingIndex == null
                                ? 'Ajouter une compétence'
                                : 'Modifier la compétence',
                            style: ThixPolicy.titleStyle.copyWith(
                              fontWeight: ThixPolicy.bold,
                              fontSize: 14,
                              color: ThixPolicy.primaryDeep,
                            ),
                          ),
                          const Divider(height: 20),
                          TextField(
                            controller: _nameC,
                            maxLength: _kMaxNameLength,
                            style: const TextStyle(fontSize: 13.5),
                            decoration: InputDecoration(
                              counterText: '',
                              labelText: 'Compétence',
                              labelStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.psychology_rounded, color: Colors.black54, size: 20),
                              filled: true,
                              fillColor: ThixPolicy.surfaceSoft,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _levels.contains(_level) ? _level : 'Intermédiaire',
                            style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                            items: _levels
                                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                                .toList(),
                            onChanged: (v) => setState(() => _level = v ?? 'Intermédiaire'),
                            decoration: InputDecoration(
                              labelText: 'Niveau',
                              labelStyle: const TextStyle(fontSize: 13),
                              filled: true,
                              fillColor: ThixPolicy.surfaceSoft,
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
                            maxLength: 300,
                            style: const TextStyle(fontSize: 13.5),
                            decoration: InputDecoration(
                              counterText: '',
                              labelText: 'Explication / Détails',
                              labelStyle: const TextStyle(fontSize: 13),
                              filled: true,
                              fillColor: ThixPolicy.surfaceSoft,
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
              color: ThixPolicy.card,
              child: Row(
                children: [
                  if (_editingIndex != null) ...[
                    OutlinedButton(
                      onPressed: _reset,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      ),
                      child: const Text('ANNULER', style: TextStyle(fontSize: 12.5)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _saving,
                      builder: (ctx, isSaving, _) => Semantics(
                        button: true,
                        enabled: !isSaving,
                        label: _editingIndex == null ? 'Ajouter' : 'Mettre à jour',
                        child: SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: isSaving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: ThixPolicy.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    _editingIndex == null ? 'AJOUTER' : 'METTRE À JOUR',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
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
