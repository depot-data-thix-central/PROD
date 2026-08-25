// lib/presentation/profile/public_profile_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/access_request_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/document_service.dart';

// ✅ Design System THIX v2
import 'package:thix_id/core/theme/thix_design_policy.dart';

// -----------------------------------------------------------------------------
// HELPERS & EXTRACTEURS DE DONNÉES
// -----------------------------------------------------------------------------
String _translateStatus(String? status) {
  if (status == null || status.trim().isEmpty) return 'Non renseigné';
  switch (status.toLowerCase()) {
    case 'pending': return 'En cours de vérification';
    case 'verified': return 'Vérifié avec succès';
    case 'rejected': return 'Rejeté / Invalide';
    case 'active': return 'Actif';
    case 'inactive': return 'Inactif';
    default: return status;
  }
}

Color _getStatusColor(String? status) {
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

/// Extracteur qui cherche la valeur parmi plusieurs clés possibles
String _get(dynamic map, List<String> keys) {
  if (map is! Map) return '';
  for (var k in keys) {
    if (map[k] != null && map[k].toString().trim().isNotEmpty) {
      return map[k].toString().trim();
    }
  }
  return '';
}

/// Récupère toutes les URLs de documents/preuves attachées
List<String> _extractDocs(dynamic e) {
  if (e is! Map) return [];
  Set<String> urls = {};

  final possibleKeys = ['proofUrl', 'document', 'documents', 'proofs', 'pieces', 'file', 'files', 'photos', 'url', 'urls', 'preuves', 'preuve'];

  for (var key in possibleKeys) {
    var val = e[key];
    if (val == null) continue;

    if (val is String && val.trim().isNotEmpty) {
      urls.add(val.trim());
    } else if (val is List) {
      for (var item in val) {
        if (item is String && item.trim().isNotEmpty) urls.add(item.trim());
        if (item is Map) {
          if (item['url'] != null) urls.add(item['url'].toString());
          if (item['download_url'] != null) urls.add(item['download_url'].toString());
          if (item['fileUrl'] != null) urls.add(item['fileUrl'].toString());
        }
      }
    } else if (val is Map) {
       if (val['url'] != null) urls.add(val['url'].toString());
       if (val['download_url'] != null) urls.add(val['download_url'].toString());
       if (val['fileUrl'] != null) urls.add(val['fileUrl'].toString());
    }
  }
  return urls.toList();
}

// -----------------------------------------------------------------------------
// CONTROLLER
// -----------------------------------------------------------------------------
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
    loading = true;
    error = null;
    notifyListeners();
    try {
      final p = await _profiles.fetchPublicProfileByThixId(thixId.toUpperCase());
      if (p == null) {
        error = 'THIX ID introuvable';
        loading = false;
        notifyListeners();
        return;
      }
      profile = p;
      _profileSub?.cancel();
      _profileSub = _profiles.streamMyProfile(p.userId).listen((live) {
        if (live != null) {
          profile = live;
          notifyListeners();
        }
      });
      _docSub?.cancel();
      _docSub = _docs.streamDocuments(p.userId).listen((d) {
        remoteDocs = d;
        notifyListeners();
      });
      if (viewerId != null && viewerId != p.userId) {
        _accessSub?.cancel();
        _accessSub = _access.streamState(requesterId: viewerId, targetUserId: p.userId).listen((s) {
          accessState = s;
          notifyListeners();
        });
      }
    } catch (e) {
      error = 'Erreur réseau';
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
    try {
      await _access.requestAccess(requesterId: reqId, targetUserId: profile!.userId, thixId: profile!.thixId);
      accessState = AccessRequestState(
        requestId: reqId, 
        status: AccessRequestStatus.pending,
        approvedUntil: DateTime.now().add(const Duration(days: 1))
      );
    } catch (e) {
      // Erreur silencieuse
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

// -----------------------------------------------------------------------------
// PAGE PRINCIPALE
// -----------------------------------------------------------------------------
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
    return ChangeNotifierProvider.value(
      value: ctrl,
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft, // Fond gris-bleuté clair premium
        body: Consumer<PublicProfileCtrl>(builder: (_, c, __) {
          if (c.loading) return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
          if (c.error != null) return Center(child: Text(c.error!, style: const TextStyle(color: ThixPolicy.textSecondary)));

          final p = c.profile!;
          final meId = context.read<AuthController>().currentUser?.id;
          final isOwner = meId == p.userId;
          final canSee = isOwner || c.canSeePrivate;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _RefHeader(p: p, onBack: () { HapticFeedback.lightImpact(); context.pop(); })),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _RefStats(p: p))),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              if (!canSee) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _GateCard(ctrl: c))),

              if (canSee)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: [

                      // 1. Identité Civile
                      _Cadre(
                        title: 'Identité civile',
                        icon: Icons.account_circle_rounded,
                        child: _MaskableContent(
                          canSee: canSee,
                          child: Column(children: [
                            _Row(label: 'Nom complet', value: p.fullName ?? p.displayName),
                            _Row(label: 'Date naissance', value: p.dateOfBirth ?? '—'),
                            _Row(label: 'Lieu naissance', value: p.placeOfBirth ?? '—'),
                            _Row(label: 'Nationalité', value: p.nationality ?? '—'),
                            _Row(label: 'État civil', value: p.maritalStatus ?? '—'),
                            _Row(label: 'Genre', value: p.gender ?? '—'),
                            _Row(label: 'Adresse', value: p.address ?? '—'),
                            _Row(label: 'Père', value: p.fatherName ?? '—'),
                            _Row(label: 'Mère', value: p.motherName ?? '—'),
                            _Row(label: 'Contact', value: p.contactPhone ?? '—'),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Origine
                      _Cadre(title: 'Origine', icon: Icons.map_rounded, child: _MaskableContent(canSee: canSee, child: Column(children: [_Row(label: 'Province origine', value: p.originProvince ?? '—'), _Row(label: 'Territoire', value: p.originTerritory ?? '—'), _Row(label: 'Secteur', value: p.originSector ?? '—')]))),
                      const SizedBox(height: 16),

                      // 3. Résidence actuelle
                      _Cadre(title: 'Résidence actuelle', icon: Icons.home_work_rounded, child: _MaskableContent(canSee: canSee, child: Column(children: [_Row(label: 'Pays', value: p.residenceCountry ?? '—'), _Row(label: 'Province', value: p.residenceProvince ?? '—'), _Row(label: 'Territoire', value: p.residenceTerritory ?? '—'), _Row(label: 'Ville', value: p.residenceCity ?? '—'), _Row(label: 'Commune', value: p.residenceCommune ?? '—'), _Row(label: 'Quartier', value: p.residenceQuarter ?? '—'), _Row(label: 'Avenue', value: p.residenceAvenue ?? '—'), _Row(label: 'Numéro', value: p.residenceNumber ?? '—')]))),
                      const SizedBox(height: 16),

                      // 4. Biographie
                      _Cadre(title: 'Biographie', icon: Icons.history_edu_rounded, child: _MaskableContent(canSee: canSee, child: _ExpandableTextBody(text: p.bio ?? 'Aucune biographie renseignée.'))),
                      const SizedBox(height: 16),

                      // 5. Profil Professionnel
                      _Cadre(title: 'Profil Professionnel', icon: Icons.work_outline_rounded, child: _MaskableContent(canSee: canSee, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Row(label: 'Profession', value: p.profession ?? p.occupation ?? '—'), _ExpandableRow(label: 'Compétence', value: p.competence ?? '—'), _Row(label: 'THIX CHAT', value: p.thixChat ?? '—')]))),
                      const SizedBox(height: 16),

                      // 6. Langues
                      _Cadre(
                        title: 'Langues', 
                        icon: Icons.language_rounded, 
                        child: _MaskableContent(
                          canSee: canSee, 
                          child: (p.languagesDetailed.isNotEmpty || p.languages.isNotEmpty)
                            ? Wrap(
                                spacing: 8, 
                                runSpacing: 8, 
                                children: (p.languagesDetailed.isNotEmpty ? p.languagesDetailed : p.languages.map((e) => {'name': e}).toList()).map((l) { 
                                  final name = (l['name'] ?? '').toString(); 
                                  final level = l['level'] != null && l['level'].toString().isNotEmpty ? ' - ${l['level']}' : ''; 
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: ThixPolicy.tint,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: ThixPolicy.primary.withOpacity(0.1)),
                                    ),
                                    child: Text('$name$level', style: const TextStyle(fontSize: 12, color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w700)),
                                  ); 
                                }).toList()
                              )
                            : const Text('Aucune langue renseignée', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)),
                        )
                      ),
                      const SizedBox(height: 16),

                      // 7. Contact urgence
                      _Cadre(title: 'Contact urgence', icon: Icons.contact_emergency_rounded, child: _MaskableContent(canSee: canSee, child: Column(children: [_Row(label: 'Nom', value: p.emergencyContactName ?? '—'), _Row(label: 'Téléphone', value: p.emergencyContactPhone ?? '—'), _Row(label: 'Lien', value: p.emergencyContactRelation ?? '—'), if (p.emergencyContacts.isNotEmpty) ...p.emergencyContacts.map((e) => ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text((e['name'] ?? '—').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain)), subtitle: Text('${e['relation'] ?? ''} - ${e['phone'] ?? ''}', style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary))))]))),
                      const SizedBox(height: 16),

                      // 8. Infos physiques
                      _Cadre(title: 'Infos physiques', icon: Icons.monitor_weight_rounded, child: _MaskableContent(canSee: canSee, child: Column(children: [_Row(label: 'Taille cm', value: p.height ?? '—'), _Row(label: 'Poids kg', value: p.weight ?? '—'), _Row(label: 'Groupe sanguin', value: p.bloodGroup ?? '—'), _Row(label: 'Handicap', value: (p.hasPhysicalDisability ?? false) ? 'Oui : ${p.physicalDisabilityDescription ?? ''}' : 'Non')]))),
                      const SizedBox(height: 16),

                      // 9. Identité nationale (Miniatures photos cliquables)
                      _Cadre(
                        title: 'Identité nationale',
                        icon: Icons.verified_user_rounded,
                        child: _MaskableContent(
                          canSee: canSee,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Row(label: 'Numéro', value: p.nationalIdNumber ?? '—'),
                              _Row(label: 'Type', value: p.idDocumentType ?? '—'),
                              _Row(label: 'Date émission', value: p.idDocumentIssueDate ?? '—'),
                              _Row(label: 'Date expiration', value: p.idDocumentExpiryDate ?? '—'),
                              _Row(label: 'Lieu émission', value: p.idDocumentIssuePlace ?? '—'),
                              // Affichage du statut avec couleur dynamique
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const SizedBox(width: 130, child: Text('Statut', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))),
                                  Expanded(child: Text(_translateStatus(p.idVerificationStatus), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _getStatusColor(p.idVerificationStatus)))),
                                ]),
                              ),

                              Builder(
                                builder: (context) {
                                  List<Map<String, String>> idDocs = [];
                                  for (var d in c.remoteDocs) {
                                    final type = (d['doc_type'] ?? '').toString().toLowerCase();
                                    if (type.contains('id') || type.contains('identit') || type.contains('recto') || type.contains('verso') || type.contains('selfie') || type.contains('carte') || type.contains('national')) {
                                      final url = d['download_url']?.toString() ?? d['fileUrl']?.toString() ?? d['url']?.toString() ?? '';
                                      if (url.isNotEmpty && !idDocs.any((doc) => doc['url'] == url)) {
                                         String label = 'Pièce';
                                         if(type.contains('recto')) label = 'Recto';
                                         else if(type.contains('verso')) label = 'Verso';
                                         else if(type.contains('selfie')) label = 'Selfie';
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
                                      children: idDocs.map((doc) {
                                        return _ThumbnailViewerButton(label: doc['label']!, documentUrl: doc['url']!);
                                      }).toList(),
                                    ),
                                  );
                                }
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 10. Parcours scolaire
                      _Cadre(
                        title: 'Cursus & Formations',
                        icon: Icons.account_balance_rounded,
                        child: _MaskableContent(
                          canSee: canSee,
                          child: p.education.isEmpty 
                            ? const Text('Aucun parcours scolaire enregistré', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)) 
                            : _LimitedList(
                                limit: 3,
                                children: p.education.map((e) {
                                  final institution = _get(e, ['institution', 'ecole', 'etablissement', 'school']);
                                  final degree = _get(e, ['degree', 'diplome', 'titre', 'certification']);
                                  final city = _get(e, ['city', 'ville', 'lieu']);
                                  final start = _get(e, ['startYear', 'debut', 'start_year']);
                                  final end = _get(e, ['endYear', 'fin', 'end_year']);
                                  final desc = _get(e, ['description', 'details']);

                                  String periodStr = '';
                                  if (start.isNotEmpty && end.isNotEmpty) periodStr = '$start - $end';
                                  else if (start.isNotEmpty) periodStr = start;
                                  else if (end.isNotEmpty) periodStr = end;
                                  else periodStr = _get(e, ['period', 'periode']);

                                  return _RecordCard(
                                    headerIcon: Icons.school_rounded,
                                    headerTitle: degree.isNotEmpty ? degree : 'Formation',
                                    fields: [
                                      if (institution.isNotEmpty) _RecordFieldRow(icon: Icons.account_balance_rounded, label: 'Établissement / École', value: institution),
                                      if (degree.isNotEmpty) _RecordFieldRow(icon: Icons.workspace_premium_rounded, label: 'Diplôme / Titre obtenu', value: degree),
                                      if (city.isNotEmpty) _RecordFieldRow(icon: Icons.location_city_rounded, label: 'Ville', value: city),
                                      if (periodStr.isNotEmpty) _RecordFieldRow(icon: Icons.calendar_month_rounded, label: 'Période', value: periodStr),
                                    ],
                                    descriptionLabel: 'Description',
                                    description: desc,
                                    documentUrls: _extractDocs(e),
                                  );
                                }).toList(),
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 11. Expériences Pro
                      _Cadre(
                        title: 'Expériences Pro',
                        icon: Icons.business_center_rounded,
                        child: _MaskableContent(
                          canSee: canSee,
                          child: p.experience.isEmpty 
                            ? const Text('Aucune expérience enregistrée', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)) 
                            : _LimitedList(
                                limit: 3,
                                children: p.experience.map((e) {
                                  final title = _get(e, ['title', 'poste', 'jobTitle']);
                                  final company = _get(e, ['company', 'entreprise', 'organisation', 'org', 'employeur']);
                                  final sector = _get(e, ['sector', 'secteur', 'domaine']);
                                  final city = _get(e, ['city', 'ville', 'lieu']);
                                  final period = _get(e, ['period', 'periode', 'dates', 'duree']);
                                  final missions = _get(e, ['missions', 'realisations', 'description', 'tasks', 'taches']);

                                  return _RecordCard(
                                    headerIcon: Icons.work_rounded,
                                    headerTitle: title.isNotEmpty ? title : 'Expérience',
                                    fields: [
                                      if (title.isNotEmpty) _RecordFieldRow(icon: Icons.badge_rounded, label: 'Titre du poste', value: title),
                                      if (company.isNotEmpty) _RecordFieldRow(icon: Icons.apartment_rounded, label: 'Entreprise / Organisation', value: company),
                                      if (sector.isNotEmpty) _RecordFieldRow(icon: Icons.category_rounded, label: 'Secteur', value: sector),
                                      if (city.isNotEmpty) _RecordFieldRow(icon: Icons.location_city_rounded, label: 'Ville', value: city),
                                      if (period.isNotEmpty) _RecordFieldRow(icon: Icons.calendar_month_rounded, label: 'Période', value: period),
                                    ],
                                    descriptionLabel: 'Missions et réalisations',
                                    description: missions,
                                    documentUrls: _extractDocs(e),
                                  );
                                }).toList(),
                              ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 12. THIX ID CARD (Refonte Enterprise)
                      _ThixIdCardWidget(profile: p),

                    ]),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ]
          );
        }),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPOSANTS UI (DESIGN PREMIUM LIGHT)
// -----------------------------------------------------------------------------

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
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ThixPolicy.border, width: 1.2),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: ThixPolicy.primary)
          ), 
          const SizedBox(width: 12), 
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain, letterSpacing: -0.3))
        ]),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: ThixPolicy.border),
        ),
        child,
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ThixPolicy.textMain))),
      ]),
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
    final rawText = widget.text.trim();
    if (rawText.isEmpty || rawText == 'Aucune biographie renseignée.') {
      return Text(rawText, style: const TextStyle(fontSize: 13, color: ThixPolicy.textSecondary));
    }
    final isLong = rawText.length > 120;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(rawText, maxLines: _expanded ? null : 3, overflow: _expanded ? null : TextOverflow.fade, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.5, color: ThixPolicy.textMain)),
        if (isLong)
          Align(alignment: Alignment.centerRight, child: InkWell(onTap: () => setState(() => _expanded = !_expanded), child: Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(_expanded ? 'Voir moins' : 'Voir plus', style: const TextStyle(color: ThixPolicy.primary, fontSize: 12, fontWeight: FontWeight.w900))))),
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
    final text = widget.value.isEmpty ? '—' : widget.value;
    final isLong = text.length > 80;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(widget.label, style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ThixPolicy.textMain, height: 1.4), maxLines: _expanded ? null : 3, overflow: _expanded ? null : TextOverflow.ellipsis),
              if (isLong) InkWell(onTap: () => setState(() => _expanded = !_expanded), child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(_expanded ? 'Voir moins' : 'Voir plus', style: const TextStyle(color: ThixPolicy.primary, fontSize: 12, fontWeight: FontWeight.w900))))
            ],
          ),
        ),
      ]),
    );
  }
}

class _MaskableContent extends StatelessWidget {
  final bool canSee;
  final Widget child;
  const _MaskableContent({required this.canSee, required this.child});
  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: ThixPolicy.shadowSoft()),
            child: const Icon(Icons.lock_rounded, color: ThixPolicy.textSecondary, size: 24)
          ),
          const SizedBox(height: 16),
          const Text("Informations masquées", style: TextStyle(fontWeight: FontWeight.w900, color: ThixPolicy.textMain, fontSize: 15)),
          const SizedBox(height: 6),
          const Text("Veuillez demander l'autorisation pour avoir accès à ces données personnelles.", textAlign: TextAlign.center, style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 12, height: 1.4)),
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
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 16, bottom: 24, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        border: const Border(bottom: BorderSide(color: ThixPolicy.border)),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const Text('THIX ID PUBLIC', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
              const SizedBox(width: 20), // Spacer pour équilibrer
            ]
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.primary.withOpacity(0.2), width: 2)),
                child: CircleAvatar(
                  radius: 40, 
                  backgroundColor: ThixPolicy.tint, 
                  backgroundImage: p.photoUrl != null && p.photoUrl!.isNotEmpty ? NetworkImage(p.photoUrl!) : null,
                  child: (p.photoUrl == null || p.photoUrl!.isEmpty) ? const Icon(Icons.person_rounded, size: 36, color: ThixPolicy.primary) : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: ThixPolicy.textMain, letterSpacing: -0.5, height: 1.1)), 
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: ThixPolicy.border)),
                      child: Text('THIX ID: ${p.thixId}', style: const TextStyle(fontSize: 11, color: ThixPolicy.textMain, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                  ]
                )
              ),
            ]
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
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: ThixPolicy.border, width: 1.2), boxShadow: ThixPolicy.shadowSoft()),
      child: Row(children: [
        Expanded(child: Column(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle), child: const Icon(Icons.school_rounded, color: ThixPolicy.primary, size: 20)), const SizedBox(height: 10), Text('${p.education.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain)), const Text('Diplômes', style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))])),
        Expanded(child: Column(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle), child: const Icon(Icons.business_center_rounded, color: ThixPolicy.primary, size: 20)), const SizedBox(height: 10), Text('${p.experience.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain)), const Text('Expériences', style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))])),
        Expanded(child: Column(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle), child: const Icon(Icons.psychology_rounded, color: ThixPolicy.primary, size: 20)), const SizedBox(height: 10), Text('${p.skills.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.textMain)), const Text('Compétences', style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))])),
      ]),
    );
  }
}

class _GateCard extends StatelessWidget {
  final PublicProfileCtrl ctrl;
  const _GateCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final s = ctrl.accessState;
    final rawStatus = s?.status?.name;

    String label = "Demander l'accès complet";
    bool isPending = rawStatus == 'pending' || rawStatus == 'En attente';

    if (isPending) label = 'Demande en attente...';
    if (rawStatus == 'rejected') label = 'Refusé - Redemander';

    final btnColor = isPending ? ThixPolicy.textSecondary : (rawStatus == 'rejected' ? ThixPolicy.danger : ThixPolicy.primary);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: ThixPolicy.border, width: 1.2), boxShadow: ThixPolicy.shadowSoft()),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.lock_person_rounded, color: ThixPolicy.primary, size: 28)
        ),
        const SizedBox(height: 16),
        const Text('Profil sécurisé', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain)),
        const SizedBox(height: 8),
        const Text('Accès aux données complètes disponible uniquement après approbation (délai de 10 min).', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, height: 1.4), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: (isPending || ctrl.isRequestingAccess) ? null : () async {
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
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          ),
        ),
      ]),
    );
  }
}

// -----------------------------------------------------------------------------
// LISTE LIMITÉE
// -----------------------------------------------------------------------------
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
    if (widget.children.length <= widget.limit) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children);
    }

    final visibleChildren = _expanded ? widget.children : widget.children.sublist(0, widget.limit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...visibleChildren,
        InkWell(
          onTap: () { HapticFeedback.lightImpact(); setState(() => _expanded = !_expanded); },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                _expanded ? 'Voir moins' : 'Voir plus (${widget.children.length - widget.limit})',
                style: const TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
        )
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// FICHE DÉTAILLÉE — Cursus & Expériences
// -----------------------------------------------------------------------------
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
    final hasDescription = description != null && description!.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(10)),
              child: Icon(headerIcon, color: ThixPolicy.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(headerTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain, letterSpacing: -0.3)),
            ),
          ]),
          const SizedBox(height: 16),
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _fieldTile(f),
              )),
          if (hasDescription) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixPolicy.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.notes_rounded, size: 16, color: ThixPolicy.textSecondary),
                    const SizedBox(width: 8),
                    Text(descriptionLabel ?? 'Description', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ThixPolicy.textSecondary)),
                  ]),
                  const SizedBox(height: 8),
                  _ExpandableTextBody(text: description!),
                ],
              ),
            ),
          ],
          if (documentUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.attach_file_rounded, size: 16, color: ThixPolicy.textSecondary),
              const SizedBox(width: 8),
              Text('Documents & Photos (${documentUrls.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ThixPolicy.textSecondary)),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: documentUrls
                  .map((url) => _ThumbnailViewerButton(label: 'Preuve', documentUrl: url))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldTile(_RecordFieldRow f) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixPolicy.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Icon(f.icon, size: 18, color: ThixPolicy.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.label, style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(f.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ThumbnailViewerButton extends StatelessWidget {
  final String label;
  final String documentUrl;

  const _ThumbnailViewerButton({required this.label, required this.documentUrl});

  void _showDocument(BuildContext context) {
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
                child: Image.network(
                  documentUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(24),
                    child: const Text('Le format du document n\'est pas supporté pour l\'aperçu.', textAlign: TextAlign.center, style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)
                ),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDocument(context),
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
                child: Image.network(
                  documentUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
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
                      label,
                      style: const TextStyle(fontSize: 10, color: ThixPolicy.textMain, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 12. THIX ID CARD WIDGET (Refonte Premium "Digital Wallet")
// -----------------------------------------------------------------------------
class _ThixIdCardWidget extends StatelessWidget {
  final ThixProfile profile;
  const _ThixIdCardWidget({required this.profile});

  @override
  Widget build(BuildContext context) {
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
                colors: [ThixPolicy.primaryDeep, Color(0xFF0F172A)], // Indigo sombre et élégant
              ),
              boxShadow: [BoxShadow(color: ThixPolicy.primaryDeep.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Stack(
              children: [
                // Filigrane abstrait moderne (pas une grosse empreinte)
                Positioned(
                  right: -40,
                  top: -40,
                  child: Icon(Icons.fingerprint_rounded, size: 200, color: Colors.white.withOpacity(0.03)),
                ),
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.05), width: 20))),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Header de la carte
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('THIX ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2.0)),
                              const SizedBox(height: 2),
                              Text('DIGITAL IDENTITY', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700, fontSize: 8, letterSpacing: 1.5)),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withOpacity(0.2))),
                            child: const Text('RDC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.0)),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Corps de la carte
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Photo
                          Container(
                            width: 80,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                              image: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                                  ? DecorationImage(image: NetworkImage(profile.photoUrl!), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                                ? const Icon(Icons.person_rounded, color: Colors.white54, size: 40) : null,
                          ),
                          const SizedBox(width: 16),
                          
                          // Infos
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _CardLabelValue('NOM COMPLET', profile.fullName ?? profile.displayName),
                                const SizedBox(height: 6),
                                _CardLabelValue('PROFESSION', profile.profession ?? profile.occupation ?? '—'),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(child: _CardLabelValue('NAISSANCE', profile.dateOfBirth ?? '—')),
                                    Expanded(child: _CardLabelValue('NATIONALITÉ', profile.nationality ?? 'CONGOLAISE')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Footer de la carte
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(profile.thixId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Courier', letterSpacing: 3.0)),
                            const Icon(Icons.qr_code_2_rounded, size: 20, color: Colors.white70),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 16.0, left: 16, right: 16),
          child: Text(
            "Ceci est une identité numérique générée par THIX. Elle ne remplace pas une pièce d'identité gouvernementale officielle.",
            textAlign: TextAlign.center,
            style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _CardLabelValue extends StatelessWidget {
  final String label;
  final String value;
  const _CardLabelValue(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value.isEmpty ? '—' : value.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: 0.2)),
      ],
    );
  }
}
