// lib/presentation/profile/public_profile_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/access_request_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/document_service.dart';

const _blue = Color(0xFF0D2CC1);
const _blueDark = Color(0xFF0A1E8A);
const _red = Color(0xFFD32F2F);
const _fieldBg = Color(0xFFF7F8FC);
const _fieldBorder = Color(0xFFE7EAF3);

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
        backgroundColor: const Color(0xFFF5F6FB),
        body: Consumer<PublicProfileCtrl>(builder: (_, c, __) {
          if (c.loading) return const Center(child: CircularProgressIndicator(color: _blue));
          if (c.error != null) return Center(child: Text(c.error!));

          final p = c.profile!;
          final meId = context.read<AuthController>().currentUser?.id;
          final isOwner = meId == p.userId;
          final canSee = isOwner || c.canSeePrivate;

          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _RefHeader(p: p, onBack: () => context.go(AppRoutes.home))),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _RefStats(p: p))),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            if (!canSee) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _GateCard(ctrl: c))),

            if (canSee)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                                return Chip(
                                  label: Text('$name$level', style: const TextStyle(fontSize: 12, color: _blueDark, fontWeight: FontWeight.bold)), 
                                  backgroundColor: const Color(0xFFEFF4FF), 
                                  side: BorderSide.none,
                                ); 
                              }).toList()
                            )
                          : const Text('Aucune langue renseignée', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      )
                    ),
                    const SizedBox(height: 16),

                    // 7. Contact urgence
                    _Cadre(title: 'Contact urgence', icon: Icons.contact_emergency_rounded, child: _MaskableContent(canSee: canSee, child: Column(children: [_Row(label: 'Nom', value: p.emergencyContactName ?? '—'), _Row(label: 'Téléphone', value: p.emergencyContactPhone ?? '—'), _Row(label: 'Lien', value: p.emergencyContactRelation ?? '—'), if (p.emergencyContacts.isNotEmpty) ...p.emergencyContacts.map((e) => ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text((e['name'] ?? '—').toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), subtitle: Text('${e['relation'] ?? ''} - ${e['phone'] ?? ''}', style: const TextStyle(fontSize: 12))))]))),
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
                            _Row(label: 'Statut', value: _translateStatus(p.idVerificationStatus)),

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

                    // 10. Parcours scolaire (fiches détaillées + "Voir plus" si > 3)
                    _Cadre(
                      title: 'Cursus & Formations',
                      icon: Icons.account_balance_rounded,
                      child: _MaskableContent(
                        canSee: canSee,
                        child: p.education.isEmpty 
                          ? const Text('Aucun parcours scolaire enregistré', style: TextStyle(fontSize: 12, color: Colors.black54)) 
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
                                    if (institution.isNotEmpty) _RecordFieldRow(icon: Icons.account_balance, label: 'Établissement / École', value: institution),
                                    if (degree.isNotEmpty) _RecordFieldRow(icon: Icons.workspace_premium_rounded, label: 'Diplôme / Titre obtenu', value: degree),
                                    if (city.isNotEmpty) _RecordFieldRow(icon: Icons.location_city, label: 'Ville', value: city),
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

                    // 11. Expériences Pro (fiches détaillées + "Voir plus" si > 3)
                    _Cadre(
                      title: 'Expériences Pro',
                      icon: Icons.business_center_rounded,
                      child: _MaskableContent(
                        canSee: canSee,
                        child: p.experience.isEmpty 
                          ? const Text('Aucune expérience enregistrée', style: TextStyle(fontSize: 12, color: Colors.black54)) 
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
                                    if (city.isNotEmpty) _RecordFieldRow(icon: Icons.location_city, label: 'Ville', value: city),
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

                    // 12. THIX ID CARD
                    _ThixIdCardWidget(profile: p),

                  ]),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ]);
        }),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPOSANTS UI EXISTANTS
// -----------------------------------------------------------------------------

class _Cadre extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Cadre({required this.title, required this.icon, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 20, color: _blue), 
          const SizedBox(width: 8), 
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _blueDark))
        ]),
        const Divider(height: 24, color: Color(0xFFE0E0E0)),
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
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
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
      return Text(rawText, style: const TextStyle(fontSize: 13, color: Colors.black54));
    }
    final isLong = rawText.length > 120;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(rawText, maxLines: _expanded ? null : 3, overflow: _expanded ? null : TextOverflow.fade, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.5, color: Colors.black87)),
        if (isLong)
          Align(alignment: Alignment.centerRight, child: InkWell(onTap: () => setState(() => _expanded = !_expanded), child: Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(_expanded ? 'Voir moins' : 'Voir plus', style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w900))))),
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
        SizedBox(width: 130, child: Text(widget.label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600))),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.4), maxLines: _expanded ? null : 3, overflow: _expanded ? null : TextOverflow.ellipsis),
              if (isLong) InkWell(onTap: () => setState(() => _expanded = !_expanded), child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(_expanded ? 'Voir moins' : 'Voir plus', style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w800))))
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.lock_rounded, color: Colors.grey, size: 28),
          SizedBox(height: 8),
          Text("Informations masquées", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          SizedBox(height: 4),
          Text("Veuillez demander l'autorisation pour avoir accès à ces données.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
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
    return Stack(clipBehavior: Clip.none, children: [
      Container(height: 230, decoration: const BoxDecoration(gradient: LinearGradient(colors: [_blue, _blueDark]), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)))),
      SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        InkWell(onTap: onBack, child: const Icon(Icons.arrow_back, color: Colors.white)), 
        const Spacer(), 
        const Text('THIX ID Public', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        const Spacer(),
        const SizedBox(width: 24),
      ]))),
      Positioned(
        top: 110,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)]),
          child: Row(children: [
            CircleAvatar(radius: 38, backgroundColor: const Color(0xFFEFF4FF), backgroundImage: p.photoUrl != null && p.photoUrl!.isNotEmpty ? NetworkImage(p.photoUrl!) : null),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), 
              const SizedBox(height: 4),
              Text('THIX ID: ${p.thixId}', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
      ),
    ]);
  }
}

class _RefStats extends StatelessWidget {
  final ThixProfile p;
  const _RefStats({required this.p});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 52),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(children: [
        Expanded(child: Column(children: [const Icon(Icons.school, color: _blue, size: 24), const SizedBox(height: 6), Text('${p.education.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const Text('Diplômes', style: TextStyle(fontSize: 11, color: Colors.black54))])),
        Expanded(child: Column(children: [const Icon(Icons.business_center, color: _blue, size: 24), const SizedBox(height: 6), Text('${p.experience.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const Text('Expériences', style: TextStyle(fontSize: 11, color: Colors.black54))])),
        Expanded(child: Column(children: [const Icon(Icons.psychology, color: _blue, size: 24), const SizedBox(height: 6), Text('${p.skills.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const Text('Compétences', style: TextStyle(fontSize: 11, color: Colors.black54))])),
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

    String label = "Demander l'accès";
    bool isPending = rawStatus == 'pending' || rawStatus == 'En attente';

    if (isPending) label = 'Demande envoyée (En attente)';
    if (rawStatus == 'rejected') label = 'Refusé - Redemander';

    final btnColor = isPending ? Colors.grey : _red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _blue.withOpacity(0.15))),
      child: Column(children: [
        const Icon(Icons.lock_rounded, color: _blue, size: 32),
        const SizedBox(height: 12),
        const Text('Profil privé - accès 10 min après approbation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (isPending || ctrl.isRequestingAccess) ? null : () async {
              final me = context.read<AuthController>().currentUser;
              if (me == null) {
                context.go(AppRoutes.login);
                return;
              }
              await ctrl.requestAccess(me.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: btnColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: ctrl.isRequestingAccess
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}

// -----------------------------------------------------------------------------
// LISTE LIMITÉE
// -----------------------------------------------------------------------------

/// Limite l'affichage à X éléments, et ajoute un bouton "Voir plus" / "Voir moins"
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
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                _expanded ? 'Voir moins' : 'Voir plus (${widget.children.length - widget.limit})',
                style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
        )
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// FICHE DÉTAILLÉE — Cursus & Expériences (miroir du formulaire d'ajout)
// -----------------------------------------------------------------------------

/// Une ligne de champ affichée dans une fiche : icône + label + valeur,
/// dans un encadré gris clair — même esprit que les champs du formulaire.
class _RecordFieldRow {
  final IconData icon;
  final String label;
  final String value;
  const _RecordFieldRow({required this.icon, required this.label, required this.value});
}

/// Fiche complète (Formation ou Expérience) : en-tête + champs + description
/// + galerie de preuves (documents/photos) cliquables.
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(headerIcon, color: _blue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(headerTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: _blueDark)),
            ),
          ]),
          const SizedBox(height: 12),
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _fieldTile(f),
              )),
          if (hasDescription) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _fieldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _fieldBorder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.notes_rounded, size: 15, color: Colors.black45),
                    const SizedBox(width: 6),
                    Text(descriptionLabel ?? 'Description', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                  ]),
                  const SizedBox(height: 6),
                  _ExpandableTextBody(text: description!),
                ],
              ),
            ),
          ],
          if (documentUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.attach_file_rounded, size: 15, color: Colors.black45),
              const SizedBox(width: 6),
              Text('Documents & Photos (${documentUrls.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: _fieldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _fieldBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Icon(f.icon, size: 17, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.label, style: const TextStyle(fontSize: 10.5, color: Colors.black45, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(f.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Affiche une vraie miniature carrée (photo) cliquable
class _ThumbnailViewerButton extends StatelessWidget {
  final String label;
  final String documentUrl;

  const _ThumbnailViewerButton({required this.label, required this.documentUrl});

  void _showDocument(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  documentUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: const Text('Le format du document n\'est pas supporté pour l\'aperçu.', textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 84,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _blue.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Miniature de l'image (Aperçu)
            SizedBox(
              height: 64,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Image.network(
                  documentUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.description_rounded, color: _blue, size: 28),
                  ),
                ),
              ),
            ),
            // Petit texte sous la miniature (ex: "Recto", "Preuve")
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                border: Border(top: BorderSide(color: _blue.withOpacity(0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.zoom_in_rounded, size: 11, color: _blueDark),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 10, color: _blueDark, fontWeight: FontWeight.bold),
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
// 12. THIX ID CARD WIDGET
// -----------------------------------------------------------------------------
class _ThixIdCardWidget extends StatelessWidget {
  final ThixProfile profile;
  const _ThixIdCardWidget({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.58, // Format standard carte ID
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE5C158), Color(0xFFF9E8A2), Color(0xFFD4AF37), Color(0xFFF9E8A2), Color(0xFFB59325)],
                stops: [0.0, 0.3, 0.5, 0.8, 1.0],
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: Icon(Icons.fingerprint, size: 180, color: Colors.white.withOpacity(0.25)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF8B0000), borderRadius: BorderRadius.circular(6)),
                            child: const Text('THIX ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('DIGITAL IDENTITY CARD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5, shadows: [Shadow(color: Colors.black45, blurRadius: 2)])),
                              Text('ID NAT : ${profile.nationalIdNumber ?? 'NON RENSEIGNÉ'}', style: const TextStyle(color: Color(0xFF5A4000), fontWeight: FontWeight.bold, fontSize: 10)),
                              const Text('VILLE / PAYS D\'EMISSION : KINSHASA / RDC', style: TextStyle(color: Color(0xFF5A4000), fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 85,
                            height: 110,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white, width: 2),
                              image: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                                  ? DecorationImage(image: NetworkImage(profile.photoUrl!), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                                ? const Icon(Icons.person, color: Colors.grey, size: 50) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _CardLabelValue('Name / Nom', profile.fullName ?? profile.displayName),
                                _CardLabelValue('Place / Lieu', profile.placeOfBirth ?? '—'),
                                _CardLabelValue('Address / Adresse', '${profile.residenceCity ?? ''} ${profile.residenceCommune ?? ''}'.trim()),
                                _CardLabelValue('Profession / Occupation', profile.profession ?? profile.occupation ?? '—'),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('DIGITAL ID', style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w900, fontSize: 12)),
                              Text(profile.thixId, style: const TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold, fontSize: 10)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(2),
                                color: Colors.white,
                                child: const Icon(Icons.qr_code_2, size: 55, color: Color(0xFF8B0000)), // Faux QR
                              ),
                              const SizedBox(height: 4),
                              const Text('CONGOLAIS', style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w900, fontSize: 11)),
                              const Text('NATIONALITY / NATIONALITÉ', style: TextStyle(color: Color(0xFF5A4000), fontSize: 7, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(profile.dateOfBirth ?? '—', style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w900, fontSize: 12)),
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12.0, left: 8, right: 8),
          child: Text(
            "Cette pièce n'est pas une pièce d'identité officielle d'un gouvernement. Elle est générée automatiquement par THIX ID à titre strictement informatif.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.bold),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF5A4000), fontSize: 8, fontWeight: FontWeight.w700)),
          Text(value.isEmpty ? '—' : value.toUpperCase(), style: const TextStyle(color: Color(0xFF222222), fontSize: 11, fontWeight: FontWeight.w900, height: 1.1)),
        ],
      ),
    );
  }
}
