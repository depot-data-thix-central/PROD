// lib/presentation/profile/public_profile_page.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/access_request_service.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/profile_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxNameLength = 80;
const int _kMaxFieldLength = 120;
const int _kMaxBioLength = 1000;
const int _kMaxDescriptionLength = 500;
const int _kMaxThixIdLength = 50;
const int _kDefaultListLimit = 3;

// ============================================================================
// VALIDATORS
// ============================================================================
class _PubValidators {
  _PubValidators._();

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

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    return 'Une erreur est survenue. Réessayez.';
  }

  static String translateStatus(String? status, AppLocalizations l10n) {
    if (status == null || status.trim().isEmpty) return l10n.t('status_unknown');
    switch (status.toLowerCase()) {
      case 'pending': return l10n.t('status_pending_long');
      case 'verified': return l10n.t('status_verified_long');
      case 'rejected': return l10n.t('status_rejected_long');
      case 'active': return l10n.t('status_active');
      case 'inactive': return l10n.t('status_inactive');
      default: return status;
    }
  }

  static Color getStatusColor(String? status) {
    if (status == null || status.trim().isEmpty) return ThixPolicy.textSecondary;
    switch (status.toLowerCase()) {
      case 'pending': return ThixPolicy.warning;
      case 'verified': return ThixPolicy.success;
      case 'rejected': return ThixPolicy.danger;
      case 'active': return ThixPolicy.success;
      case 'inactive': return ThixPolicy.textSecondary;
      default: return ThixPolicy.textSecondary;
    }
  }

  static String getFromMap(dynamic map, List<String> keys) {
    if (map is! Map) return '';
    for (var k in keys) {
      if (map[k] != null && map[k].toString().trim().isNotEmpty) {
        return sanitize(map[k].toString(), maxLength: _kMaxFieldLength);
      }
    }
    return '';
  }

  static List<String> extractDocUrls(dynamic e) {
    if (e is! Map) return [];
    final urls = <String>{};
    const possibleKeys = [
      'proofUrl', 'document', 'documents', 'proofs', 'pieces', 'file', 'files',
      'photos', 'url', 'urls', 'preuves', 'preuve',
    ];

    for (var key in possibleKeys) {
      final val = e[key];
      if (val == null) continue;

      if (val is String && val.trim().isNotEmpty) {
        final sanitized = sanitizeUrl(val);
        if (sanitized != null) urls.add(sanitized);
      } else if (val is List) {
        for (var item in val) {
          if (item is String && item.trim().isNotEmpty) {
            final sanitized = sanitizeUrl(item);
            if (sanitized != null) urls.add(sanitized);
          }
          if (item is Map) {
            _addUrlFromMap(item, urls);
          }
        }
      } else if (val is Map) {
        _addUrlFromMap(val, urls);
      }
    }
    return urls.toList();
  }

  static void _addUrlFromMap(Map map, Set<String> urls) {
    for (final key in ['url', 'download_url', 'fileUrl']) {
      if (map[key] != null) {
        final sanitized = sanitizeUrl(map[key].toString());
        if (sanitized != null) urls.add(sanitized);
      }
    }
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _pubRetry<T>(
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
        debugPrint('[PublicProfile] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[PublicProfile] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[PublicProfile] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// CONTROLLER
// ============================================================================
class PublicProfileCtrl extends ChangeNotifier {
  final _profiles = ProfileService();
  final _docs = DocumentService();
  final _access = AccessRequestService();

  ThixProfile? profile;
  bool loading = true;
  bool isRequestingAccess = false;
  String? error;
  AccessRequestState? accessState;
  List<Map<String, dynamic>> remoteDocs = [];

  StreamSubscription? _profileSub;
  StreamSubscription? _accessSub;
  StreamSubscription? _docSub;

  Future<void> init(String thixId, String? viewerId) async {
    debugPrint('[PublicProfile] 🚀 Initializing for THIX ID: $thixId');

    loading = true;
    error = null;
    notifyListeners();

    try {
      final p = await _pubRetry(
        () => _profiles.fetchPublicProfileByThixId(thixId.toUpperCase()),
        label: 'fetchProfile',
      );

      if (p == null) {
        error = 'THIX ID introuvable';
        loading = false;
        notifyListeners();
        debugPrint('[PublicProfile] ⚠️ Profile not found');
        return;
      }

      profile = p;
      debugPrint('[PublicProfile] ✓ Profile loaded: ${p.displayName}');

      // Stream profil live
      _profileSub?.cancel();
      _profileSub = _profiles.streamMyProfile(p.userId).listen(
        (live) {
          if (live != null) {
            profile = live;
            notifyListeners();
          }
        },
        onError: (e) => debugPrint('[PublicProfile] ⚠️ Profile stream error: $e'),
      );

      // Stream documents
      _docSub?.cancel();
      _docSub = _docs.streamDocuments(p.userId).listen(
        (d) {
          remoteDocs = d;
          notifyListeners();
        },
        onError: (e) => debugPrint('[PublicProfile] ⚠️ Docs stream error: $e'),
      );

      // Stream access state (si viewer différent)
      if (viewerId != null && viewerId != p.userId) {
        _accessSub?.cancel();
        _accessSub = _access.streamState(requesterId: viewerId, targetUserId: p.userId).listen(
          (s) {
            accessState = s;
            notifyListeners();
          },
          onError: (e) => debugPrint('[PublicProfile] ⚠️ Access stream error: $e'),
        );
      }
    } catch (e) {
      debugPrint('[PublicProfile] ❌ Init error: $e');
      error = _PubValidators.friendlyError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool get canSeePrivate => accessState?.isActiveAt(DateTime.now().toUtc()) ?? false;

  Future<void> requestAccess(String reqId) async {
    if (profile == null) return;

    isRequestingAccess = true;
    notifyListeners();
    debugPrint('[PublicProfile] 🔐 Requesting access...');

    try {
      await _pubRetry(
        () => _access.requestAccess(
          requesterId: reqId,
          targetUserId: profile!.userId,
          thixId: profile!.thixId,
        ),
        label: 'requestAccess',
      );

      accessState = AccessRequestState(
        requestId: reqId,
        status: AccessRequestStatus.pending,
        approvedUntil: DateTime.now().add(const Duration(days: 1)),
      );

      debugPrint('[PublicProfile] ✓ Access requested');
    } catch (e) {
      debugPrint('[PublicProfile] ❌ Request access error: $e');
    } finally {
      isRequestingAccess = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _accessSub?.cancel();
    _docSub?.cancel();
    super.dispose();
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class PublicProfilePage extends StatefulWidget {
  final String? initialThixId;

  const PublicProfilePage({super.key, this.initialThixId});

  @override
  State<PublicProfilePage> createState() => _PState();
}

class _PState extends State<PublicProfilePage> {
  late final ctrl = PublicProfileCtrl();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = context.read<AuthController>().currentUser;
      if (widget.initialThixId != null) {
        ctrl.init(widget.initialThixId!, me?.id);
      }
    });
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ChangeNotifierProvider.value(
      value: ctrl,
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        body: Consumer<PublicProfileCtrl>(
          builder: (_, c, __) {
            if (c.loading) {
              return Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
            }

            if (c.error != null) {
              return _ErrorState(message: c.error!);
            }

            final p = c.profile!;
            final meId = context.read<AuthController>().currentUser?.id;
            final isOwner = meId == p.userId;
            final canSee = isOwner || c.canSeePrivate;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _RefHeader(
                    p: p,
                    onBack: () {
                      HapticFeedback.lightImpact();
                      context.pop();
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _RefStats(p: p),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                if (!canSee)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _GateCard(ctrl: c),
                    ),
                  ),

                if (canSee)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _ProfileContent(p: p, ctrl: c, canSee: canSee),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================
class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('public_error_title'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PROFILE CONTENT (Extrait pour lisibilité)
// ============================================================================
class _ProfileContent extends StatelessWidget {
  final ThixProfile p;
  final PublicProfileCtrl ctrl;
  final bool canSee;

  const _ProfileContent({required this.p, required this.ctrl, required this.canSee});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // 1. Identité Civile
        _Cadre(
          title: l10n.t('public_civil_identity'),
          icon: Icons.account_circle_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: Column(
              children: [
                _Row(label: l10n.t('public_full_name'), value: p.fullName ?? p.displayName),
                _Row(label: l10n.t('public_dob'), value: p.dateOfBirth ?? '—'),
                _Row(label: l10n.t('public_pob'), value: p.placeOfBirth ?? '—'),
                _Row(label: l10n.t('public_nationality'), value: p.nationality ?? '—'),
                _Row(label: l10n.t('public_marital'), value: p.maritalStatus ?? '—'),
                _Row(label: l10n.t('public_gender'), value: p.gender ?? '—'),
                _Row(label: l10n.t('public_address'), value: p.address ?? '—'),
                _Row(label: l10n.t('public_father'), value: p.fatherName ?? '—'),
                _Row(label: l10n.t('public_mother'), value: p.motherName ?? '—'),
                _Row(label: l10n.t('public_contact'), value: p.contactPhone ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Origine
        _Cadre(
          title: l10n.t('public_origin'),
          icon: Icons.map_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: Column(
              children: [
                _Row(label: l10n.t('public_origin_province'), value: p.originProvince ?? '—'),
                _Row(label: l10n.t('public_territory'), value: p.originTerritory ?? '—'),
                _Row(label: l10n.t('public_sector'), value: p.originSector ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Résidence actuelle
        _Cadre(
          title: l10n.t('public_residence'),
          icon: Icons.home_work_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: Column(
              children: [
                _Row(label: l10n.t('public_country'), value: p.residenceCountry ?? '—'),
                _Row(label: l10n.t('public_province'), value: p.residenceProvince ?? '—'),
                _Row(label: l10n.t('public_territory'), value: p.residenceTerritory ?? '—'),
                _Row(label: l10n.t('public_city'), value: p.residenceCity ?? '—'),
                _Row(label: l10n.t('public_commune'), value: p.residenceCommune ?? '—'),
                _Row(label: l10n.t('public_quarter'), value: p.residenceQuarter ?? '—'),
                _Row(label: l10n.t('public_avenue'), value: p.residenceAvenue ?? '—'),
                _Row(label: l10n.t('public_number'), value: p.residenceNumber ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Biographie
        _Cadre(
          title: l10n.t('public_biography'),
          icon: Icons.history_edu_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: _ExpandableTextBody(text: p.bio ?? l10n.t('public_no_bio')),
          ),
        ),
        const SizedBox(height: 16),

        // 5. Profil Professionnel
        _Cadre(
          title: l10n.t('public_professional'),
          icon: Icons.work_outline_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row(label: l10n.t('public_profession'), value: p.profession ?? p.occupation ?? '—'),
                _ExpandableRow(label: l10n.t('public_competence'), value: p.competence ?? '—'),
                _Row(label: 'THIX CHAT', value: p.thixChat ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 6. Langues
        _Cadre(
          title: l10n.t('public_languages'),
          icon: Icons.language_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: (p.languagesDetailed.isNotEmpty || p.languages.isNotEmpty)
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (p.languagesDetailed.isNotEmpty
                            ? p.languagesDetailed
                            : p.languages.map((e) => {'name': e}).toList())
                        .map((l) {
                      final name = _PubValidators.sanitize((l['name'] ?? '').toString(), maxLength: 40);
                      final level = l['level'] != null && l['level'].toString().isNotEmpty
                          ? ' - ${_PubValidators.sanitize(l['level'].toString(), maxLength: 20)}'
                          : '';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: ThixPolicy.tint,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ThixPolicy.primary.withOpacity(0.1)),
                        ),
                        child: Text(
                          '$name$level',
                          style: ThixPolicy.captionStyle.copyWith(
                            fontSize: 12,
                            color: ThixPolicy.primaryDeep,
                            fontWeight: ThixPolicy.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : Text(
                    l10n.t('public_no_languages'),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // 7. Contact urgence
        _Cadre(
          title: l10n.t('public_emergency'),
          icon: Icons.contact_emergency_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: Column(
              children: [
                _Row(label: l10n.t('public_name'), value: p.emergencyContactName ?? '—'),
                _Row(label: l10n.t('public_phone'), value: p.emergencyContactPhone ?? '—'),
                _Row(label: l10n.t('public_relation'), value: p.emergencyContactRelation ?? '—'),
                if (p.emergencyContacts.isNotEmpty)
                  ...p.emergencyContacts.map(
                    (e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _PubValidators.sanitize((e['name'] ?? '—').toString(), maxLength: _kMaxNameLength),
                        style: ThixPolicy.labelStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          fontSize: 13,
                          color: ThixPolicy.textMain,
                        ),
                      ),
                      subtitle: Text(
                        '${_PubValidators.sanitize((e['relation'] ?? '').toString(), maxLength: 40)} - '
                        '${_PubValidators.sanitize((e['phone'] ?? '').toString(), maxLength: 30)}',
                        style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 8. Infos physiques
        _Cadre(
          title: l10n.t('public_physical'),
          icon: Icons.monitor_weight_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: Column(
              children: [
                _Row(label: l10n.t('public_height'), value: p.height ?? '—'),
                _Row(label: l10n.t('public_weight'), value: p.weight ?? '—'),
                _Row(label: l10n.t('public_blood_group'), value: p.bloodGroup ?? '—'),
                _Row(
                  label: l10n.t('public_disability'),
                  value: (p.hasPhysicalDisability ?? false)
                      ? '${l10n.t('common_yes')}: ${_PubValidators.sanitize(p.physicalDisabilityDescription ?? '', maxLength: 100)}'
                      : l10n.t('common_no'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 9. Identité nationale
        _Cadre(
          title: l10n.t('public_national_id'),
          icon: Icons.verified_user_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row(label: l10n.t('public_id_number'), value: p.nationalIdNumber ?? '—'),
                _Row(label: l10n.t('public_id_type'), value: p.idDocumentType ?? '—'),
                _Row(label: l10n.t('public_id_issue'), value: p.idDocumentIssueDate ?? '—'),
                _Row(label: l10n.t('public_id_expiry'), value: p.idDocumentExpiryDate ?? '—'),
                _Row(label: l10n.t('public_id_place'), value: p.idDocumentIssuePlace ?? '—'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          l10n.t('public_status'),
                          style: ThixPolicy.captionStyle.copyWith(
                            fontSize: 12,
                            color: ThixPolicy.textSecondary,
                            fontWeight: ThixPolicy.semiBold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _PubValidators.translateStatus(p.idVerificationStatus, l10n),
                          style: ThixPolicy.labelStyle.copyWith(
                            fontSize: 13,
                            fontWeight: ThixPolicy.bold,
                            color: _PubValidators.getStatusColor(p.idVerificationStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) {
                    final idDocs = <Map<String, String>>[];
                    for (var d in ctrl.remoteDocs) {
                      final type = (d['doc_type'] ?? '').toString().toLowerCase();
                      if (type.contains('id') ||
                          type.contains('identit') ||
                          type.contains('recto') ||
                          type.contains('verso') ||
                          type.contains('selfie') ||
                          type.contains('carte') ||
                          type.contains('national')) {
                        final url = _PubValidators.sanitizeUrl(
                          d['download_url']?.toString() ?? d['fileUrl']?.toString() ?? d['url']?.toString(),
                        );
                        if (url != null && !idDocs.any((doc) => doc['url'] == url)) {
                          String label = l10n.t('public_document');
                          if (type.contains('recto')) {
                            label = l10n.t('public_recto');
                          } else if (type.contains('verso')) {
                            label = l10n.t('public_verso');
                          } else if (type.contains('selfie')) {
                            label = l10n.t('public_selfie');
                          }
                          idDocs.add({'url': url, 'label': label});
                        }
                      }
                    }

                    if (idDocs.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: idDocs
                            .map((doc) => _ThumbnailViewerButton(
                                  label: doc['label']!,
                                  documentUrl: doc['url']!,
                                ))
                            .toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 10. Parcours scolaire
        _Cadre(
          title: l10n.t('public_education'),
          icon: Icons.account_balance_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: p.education.isEmpty
                ? Text(
                    l10n.t('public_no_education'),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary),
                  )
                : _LimitedList(
                    limit: _kDefaultListLimit,
                    children: p.education.map((e) {
                      final institution = _PubValidators.getFromMap(
                        e,
                        ['institution', 'ecole', 'etablissement', 'school'],
                      );
                      final degree = _PubValidators.getFromMap(e, ['degree', 'diplome', 'titre', 'certification']);
                      final city = _PubValidators.getFromMap(e, ['city', 'ville', 'lieu']);
                      final start = _PubValidators.getFromMap(e, ['startYear', 'debut', 'start_year']);
                      final end = _PubValidators.getFromMap(e, ['endYear', 'fin', 'end_year']);
                      final desc = _PubValidators.getFromMap(e, ['description', 'details']);

                      String periodStr = '';
                      if (start.isNotEmpty && end.isNotEmpty) {
                        periodStr = '$start - $end';
                      } else if (start.isNotEmpty) {
                        periodStr = start;
                      } else if (end.isNotEmpty) {
                        periodStr = end;
                      } else {
                        periodStr = _PubValidators.getFromMap(e, ['period', 'periode']);
                      }

                      return _RecordCard(
                        headerIcon: Icons.school_rounded,
                        headerTitle: degree.isNotEmpty ? degree : l10n.t('public_formation'),
                        fields: [
                          if (institution.isNotEmpty)
                            _RecordFieldRow(
                              icon: Icons.account_balance_rounded,
                              label: l10n.t('public_institution'),
                              value: institution,
                            ),
                          if (degree.isNotEmpty)
                            _RecordFieldRow(
                              icon: Icons.workspace_premium_rounded,
                              label: l10n.t('public_degree'),
                              value: degree,
                            ),
                          if (city.isNotEmpty)
                            _RecordFieldRow(icon: Icons.location_city_rounded, label: l10n.t('public_city'), value: city),
                          if (periodStr.isNotEmpty)
                            _RecordFieldRow(
                              icon: Icons.calendar_month_rounded,
                              label: l10n.t('public_period'),
                              value: periodStr,
                            ),
                        ],
                        descriptionLabel: l10n.t('public_description'),
                        description: desc,
                        documentUrls: _PubValidators.extractDocUrls(e),
                      );
                    }).toList(),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // 11. Expériences Pro
        _Cadre(
          title: l10n.t('public_experiences'),
          icon: Icons.business_center_rounded,
          child: _MaskableContent(
            canSee: canSee,
            child: p.experience.isEmpty
                ? Text(
                    l10n.t('public_no_experiences'),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary),
                  )
                : _LimitedList(
                    limit: _kDefaultListLimit,
                    children: p.experience.map((e) {
                      final title = _PubValidators.getFromMap(e, ['title', 'poste', 'jobTitle']);
                      final company = _PubValidators.getFromMap(
                        e,
                        ['company', 'entreprise', 'organisation', 'org', 'employeur'],
                      );
                      final sector = _PubValidators.getFromMap(e, ['sector', 'secteur', 'domaine']);
                      final city = _PubValidators.getFromMap(e, ['city', 'ville', 'lieu']);
                      final period = _PubValidators.getFromMap(e, ['period', 'periode', 'dates', 'duree']);
                      final missions = _PubValidators.getFromMap(
                        e,
                        ['missions', 'realisations', 'description', 'tasks', 'taches'],
                      );

                      return _RecordCard(
                        headerIcon: Icons.work_rounded,
                        headerTitle: title.isNotEmpty ? title : l10n.t('public_experience'),
                        fields: [
                          if (title.isNotEmpty)
                            _RecordFieldRow(icon: Icons.badge_rounded, label: l10n.t('public_position'), value: title),
                          if (company.isNotEmpty)
                            _RecordFieldRow(
                              icon: Icons.apartment_rounded,
                              label: l10n.t('public_company'),
                              value: company,
                            ),
                          if (sector.isNotEmpty)
                            _RecordFieldRow(icon: Icons.category_rounded, label: l10n.t('public_sector'), value: sector),
                          if (city.isNotEmpty)
                            _RecordFieldRow(icon: Icons.location_city_rounded, label: l10n.t('public_city'), value: city),
                          if (period.isNotEmpty)
                            _RecordFieldRow(
                              icon: Icons.calendar_month_rounded,
                              label: l10n.t('public_period'),
                              value: period,
                            ),
                        ],
                        descriptionLabel: l10n.t('public_missions'),
                        description: missions,
                        documentUrls: _PubValidators.extractDocUrls(e),
                      );
                    }).toList(),
                  ),
          ),
        ),
        const SizedBox(height: 32),

        // 12. THIX ID CARD
        _ThixIdCardWidget(profile: p),
      ],
    );
  }
}

// ============================================================================
// UI COMPONENTS
// ============================================================================

class _Cadre extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Cadre({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ThixPolicy.border, width: 1.2),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: ThixPolicy.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                    color: ThixPolicy.textMain,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: ThixPolicy.border),
          ),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final safeValue = _PubValidators.sanitize(value, maxLength: _kMaxFieldLength);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: ThixPolicy.captionStyle.copyWith(
                fontSize: 12,
                color: ThixPolicy.textSecondary,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              safeValue.isEmpty ? '—' : safeValue,
              style: ThixPolicy.labelStyle.copyWith(
                fontSize: 13,
                fontWeight: ThixPolicy.bold,
                color: ThixPolicy.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableTextBody extends StatefulWidget {
  final String text;

  const _ExpandableTextBody({required this.text});

  @override
  State<_ExpandableTextBody> createState() => _ExpandableTextBodyState();
}

class _ExpandableTextBodyState extends State<_ExpandableTextBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rawText = _PubValidators.sanitize(widget.text, maxLength: _kMaxBioLength);

    if (rawText.isEmpty || rawText == l10n.t('public_no_bio')) {
      return Text(
        rawText,
        style: ThixPolicy.captionStyle.copyWith(fontSize: 13, color: ThixPolicy.textSecondary),
      );
    }

    final isLong = rawText.length > 120;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          rawText,
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? null : TextOverflow.fade,
          style: ThixPolicy.bodySmallStyle.copyWith(
            fontSize: 13,
            fontWeight: ThixPolicy.semiBold,
            height: 1.5,
            color: ThixPolicy.textMain,
          ),
        ),
        if (isLong)
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: _expanded ? l10n.t('common_show_less') : l10n.t('common_show_more'),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _expanded = !_expanded);
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    _expanded ? l10n.t('common_show_less') : l10n.t('common_show_more'),
                    style: ThixPolicy.captionStyle.copyWith(
                      color: ThixPolicy.primary,
                      fontSize: 12,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExpandableRow extends StatefulWidget {
  final String label;
  final String value;

  const _ExpandableRow({required this.label, required this.value});

  @override
  State<_ExpandableRow> createState() => _ExpandableRowState();
}

class _ExpandableRowState extends State<_ExpandableRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = _PubValidators.sanitize(widget.value, maxLength: _kMaxDescriptionLength);
    final displayText = text.isEmpty ? '—' : text;
    final isLong = text.length > 80;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              widget.label,
              style: ThixPolicy.captionStyle.copyWith(
                fontSize: 12,
                color: ThixPolicy.textSecondary,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayText,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontSize: 13,
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.textMain,
                    height: 1.4,
                  ),
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
                if (isLong)
                  Semantics(
                    button: true,
                    label: _expanded ? l10n.t('common_show_less') : l10n.t('common_show_more'),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _expanded = !_expanded);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _expanded ? l10n.t('common_show_less') : l10n.t('common_show_more'),
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.primary,
                            fontSize: 12,
                            fontWeight: ThixPolicy.bold,
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
    );
  }
}

class _MaskableContent extends StatelessWidget {
  final bool canSee;
  final Widget child;

  const _MaskableContent({required this.canSee, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (canSee) return child;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThixPolicy.border),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              shape: BoxShape.circle,
              boxShadow: ThixPolicy.shadowSoft(),
            ),
            child: const Icon(Icons.lock_rounded, color: ThixPolicy.textSecondary, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('public_masked_title'),
            style: ThixPolicy.labelStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              color: ThixPolicy.textMain,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t('public_masked_subtitle'),
            textAlign: TextAlign.center,
            style: ThixPolicy.captionStyle.copyWith(
              color: ThixPolicy.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefHeader extends StatelessWidget {
  final ThixProfile p;
  final VoidCallback onBack;

  const _RefHeader({required this.p, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeName = _PubValidators.sanitize(p.displayName, maxLength: _kMaxNameLength);
    final safeThixId = _PubValidators.sanitize(p.thixId, maxLength: _kMaxThixIdLength);
    final safePhotoUrl = _PubValidators.sanitizeUrl(p.photoUrl);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 16,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        border: const Border(bottom: BorderSide(color: ThixPolicy.border)),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                button: true,
                label: l10n.t('common_back'),
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              Text(
                l10n.t('public_header_title'),
                style: ThixPolicy.captionStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.primary.withOpacity(0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: ThixPolicy.tint,
                  backgroundImage: safePhotoUrl != null ? CachedNetworkImageProvider(safePhotoUrl) : null,
                  child: safePhotoUrl == null
                      ? const Icon(Icons.person_rounded, size: 36, color: ThixPolicy.primary)
                      : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeName.isEmpty ? l10n.t('public_user_default') : safeName,
                      style: ThixPolicy.h2Style.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 24,
                        color: ThixPolicy.textMain,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThixPolicy.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: Text(
                        'THIX ID: ${safeThixId.isEmpty ? '—' : safeThixId}',
                        style: ThixPolicy.captionStyle.copyWith(
                          fontSize: 11,
                          color: ThixPolicy.textMain,
                          fontWeight: ThixPolicy.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefStats extends StatelessWidget {
  final ThixProfile p;

  const _RefStats({required this.p});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ThixPolicy.border, width: 1.2),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle),
                  child: const Icon(Icons.school_rounded, color: ThixPolicy.primary, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  '${p.education.length}',
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 18,
                    color: ThixPolicy.textMain,
                  ),
                ),
                Text(
                  l10n.t('public_diplomas'),
                  style: ThixPolicy.captionStyle.copyWith(
                    fontSize: 11,
                    color: ThixPolicy.textSecondary,
                    fontWeight: ThixPolicy.semiBold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle),
                  child: const Icon(Icons.business_center_rounded, color: ThixPolicy.primary, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  '${p.experience.length}',
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 18,
                    color: ThixPolicy.textMain,
                  ),
                ),
                Text(
                  l10n.t('public_experiences'),
                  style: ThixPolicy.captionStyle.copyWith(
                    fontSize: 11,
                    color: ThixPolicy.textSecondary,
                    fontWeight: ThixPolicy.semiBold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle),
                  child: const Icon(Icons.psychology_rounded, color: ThixPolicy.primary, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  '${p.skills.length}',
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 18,
                    color: ThixPolicy.textMain,
                  ),
                ),
                Text(
                  l10n.t('public_skills'),
                  style: ThixPolicy.captionStyle.copyWith(
                    fontSize: 11,
                    color: ThixPolicy.textSecondary,
                    fontWeight: ThixPolicy.semiBold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GateCard extends StatelessWidget {
  final PublicProfileCtrl ctrl;

  const _GateCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ctrl.accessState;
    final rawStatus = s?.status?.name;

    String label = l10n.t('public_request_access');
    bool isPending = rawStatus == 'pending' || rawStatus == 'En attente';

    if (isPending) label = l10n.t('public_request_pending');
    if (rawStatus == 'rejected') label = l10n.t('public_request_rejected');

    final btnColor = isPending
        ? ThixPolicy.textSecondary
        : (rawStatus == 'rejected' ? ThixPolicy.danger : ThixPolicy.primary);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ThixPolicy.border, width: 1.2),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.lock_person_rounded, color: ThixPolicy.primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('public_secure_profile'),
            style: ThixPolicy.labelStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              fontSize: 16,
              color: ThixPolicy.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('public_access_hint'),
            style: ThixPolicy.captionStyle.copyWith(
              fontSize: 12,
              color: ThixPolicy.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Semantics(
            button: true,
            label: label,
            enabled: !(isPending || ctrl.isRequestingAccess),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (isPending || ctrl.isRequestingAccess)
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        final me = context.read<AuthController>().currentUser;
                        if (me == null) {
                          context.go(AppRoutes.login);
                          return;
                        }
                        await ctrl.requestAccess(me.id);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: ctrl.isRequestingAccess
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        label,
                        style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitedList extends StatefulWidget {
  final List<Widget> children;
  final int limit;

  const _LimitedList({required this.children, this.limit = 3});

  @override
  State<_LimitedList> createState() => _LimitedListState();
}

class _LimitedListState extends State<_LimitedList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (widget.children.length <= widget.limit) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children);
    }

    final visibleChildren = _expanded ? widget.children : widget.children.sublist(0, widget.limit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...visibleChildren,
        Semantics(
          button: true,
          label: _expanded ? l10n.t('common_show_less') : l10n.t('public_show_more', args: ['${widget.children.length - widget.limit}']),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _expanded = !_expanded);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  _expanded ? l10n.t('common_show_less') : l10n.t('public_show_more', args: ['${widget.children.length - widget.limit}']),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.primary,
                    fontWeight: ThixPolicy.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordFieldRow {
  final IconData icon;
  final String label;
  final String value;

  const _RecordFieldRow({required this.icon, required this.label, required this.value});
}

class _RecordCard extends StatelessWidget {
  final IconData headerIcon;
  final String headerTitle;
  final List<_RecordFieldRow> fields;
  final String? descriptionLabel;
  final String? description;
  final List<String> documentUrls;

  const _RecordCard({
    required this.headerIcon,
    required this.headerTitle,
    required this.fields,
    this.descriptionLabel,
    this.description,
    this.documentUrls = const [],
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeTitle = _PubValidators.sanitize(headerTitle, maxLength: _kMaxFieldLength);
    final hasDescription = description != null && description!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(10)),
                child: Icon(headerIcon, color: ThixPolicy.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  safeTitle.isEmpty ? '—' : safeTitle,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 15,
                    color: ThixPolicy.textMain,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...fields.map((f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _fieldTile(f))),
          if (hasDescription) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notes_rounded, size: 16, color: ThixPolicy.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        descriptionLabel ?? l10n.t('public_description'),
                        style: ThixPolicy.captionStyle.copyWith(
                          fontSize: 12,
                          fontWeight: ThixPolicy.bold,
                          color: ThixPolicy.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ExpandableTextBody(text: description!),
                ],
              ),
            ),
          ],
          if (documentUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.attach_file_rounded, size: 16, color: ThixPolicy.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '${l10n.t('public_documents')} (${documentUrls.length})',
                  style: ThixPolicy.captionStyle.copyWith(
                    fontSize: 12,
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: documentUrls
                  .map((url) => _ThumbnailViewerButton(label: l10n.t('public_proof'), documentUrl: url))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldTile(_RecordFieldRow f) {
    final safeLabel = _PubValidators.sanitize(f.label, maxLength: 40);
    final safeValue = _PubValidators.sanitize(f.value, maxLength: _kMaxFieldLength);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(f.icon, size: 18, color: ThixPolicy.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeLabel,
                  style: ThixPolicy.captionStyle.copyWith(
                    fontSize: 11,
                    color: ThixPolicy.textSecondary,
                    fontWeight: ThixPolicy.semiBold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  safeValue.isEmpty ? '—' : safeValue,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontSize: 13,
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.textMain,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailViewerButton extends StatelessWidget {
  final String label;
  final String documentUrl;

  const _ThumbnailViewerButton({required this.label, required this.documentUrl});

  void _showDocument(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CachedNetworkImage(
                  imageUrl: documentUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Container(
                    color: ThixPolicy.card,
                    padding: const EdgeInsets.all(24),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: ThixPolicy.card,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.t('public_doc_unsupported'),
                      textAlign: TextAlign.center,
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.textMain,
                        fontWeight: ThixPolicy.semiBold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Semantics(
                button: true,
                label: l10n.t('common_close'),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeLabel = _PubValidators.sanitize(label, maxLength: 20);

    return Semantics(
      button: true,
      label: '${AppLocalizations.of(context).t('public_view')} $safeLabel',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _showDocument(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 90,
          decoration: BoxDecoration(
            color: ThixPolicy.tint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 70,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: CachedNetworkImage(
                    imageUrl: documentUrl,
                    fit: BoxFit.cover,
                    errorWidget: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.description_rounded, color: ThixPolicy.primary, size: 28),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.zoom_in_rounded, size: 12, color: ThixPolicy.textMain),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        safeLabel.isEmpty ? '—' : safeLabel,
                        style: ThixPolicy.captionStyle.copyWith(
                          fontSize: 10,
                          color: ThixPolicy.textMain,
                          fontWeight: ThixPolicy.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThixIdCardWidget extends StatelessWidget {
  final ThixProfile profile;

  const _ThixIdCardWidget({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeName = _PubValidators.sanitize(profile.fullName ?? profile.displayName, maxLength: _kMaxNameLength);
    final safeProfession = _PubValidators.sanitize(profile.profession ?? profile.occupation ?? '—', maxLength: _kMaxFieldLength);
    final safeDob = _PubValidators.sanitize(profile.dateOfBirth ?? '—', maxLength: 20);
    final safeNationality = _PubValidators.sanitize(profile.nationality ?? 'CONGOLAISE', maxLength: 40);
    final safeThixId = _PubValidators.sanitize(profile.thixId, maxLength: _kMaxThixIdLength);
    final safePhotoUrl = _PubValidators.sanitizeUrl(profile.photoUrl);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.58,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ThixPolicy.primaryDeep, Color(0xFF0F172A)],
              ),
              boxShadow: [
                BoxShadow(color: ThixPolicy.primaryDeep.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -40,
                  top: -40,
                  child: Icon(Icons.fingerprint_rounded, size: 200, color: Colors.white.withOpacity(0.03)),
                ),
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.05), width: 20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'THIX ID',
                                style: ThixPolicy.titleStyle.copyWith(
                                  color: Colors.white,
                                  fontWeight: ThixPolicy.bold,
                                  fontSize: 18,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'DIGITAL IDENTITY',
                                style: ThixPolicy.captionStyle.copyWith(
                                  color: Colors.white.withOpacity(0.6),
                                  fontWeight: ThixPolicy.semiBold,
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Text(
                              'RDC',
                              style: ThixPolicy.captionStyle.copyWith(
                                color: Colors.white,
                                fontWeight: ThixPolicy.bold,
                                fontSize: 11,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 80,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                              image: safePhotoUrl != null
                                  ? DecorationImage(image: CachedNetworkImageProvider(safePhotoUrl), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: safePhotoUrl == null
                                ? const Icon(Icons.person_rounded, color: Colors.white54, size: 40)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          const SizedBox(width: 16), // Correction : "const" avec un "c" minuscule
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      _CardLabelValue(l10n.t('public_full_name').toUpperCase(), safeName),
      const SizedBox(height: 6),
      _CardLabelValue(l10n.t('public_profession').toUpperCase(), safeProfession),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(child: _CardLabelValue(l10n.t('public_dob').toUpperCase(), safeDob)),
          // J'ai ajouté un child générique pour fermer ton Expanded manquant.
          // Si c'est le lieu de naissance (POB), tu peux mettre safePob à la place.
          Expanded(child: _CardLabelValue('INFO', '—')), 
        ],
      ), // Fermeture du Row
    ],
  ), // Fermeture du Column
), // Fermeture du Expanded
