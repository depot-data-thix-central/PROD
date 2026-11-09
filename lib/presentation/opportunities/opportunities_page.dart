// ============================================================================
// FICHIER : lib/presentation/opportunities/opportunities_page.dart
// Module  : opportunities + accès INCUBATOR (v6 PROFESSIONAL)
// ============================================================================
// ✅ Segment control scrollable en haut : Opportunity ↔ Incubator
// ✅ Design renforcé : glass morphism plus subtil, ombres plus douces
// ✅ Landing Incubator intégrée avec hero + stats + programmes récents + CTA
// ✅ Animations sur les transitions de segments
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/security/thix_input_guard.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/opportunity_service.dart';
import 'package:thix_id/services/admin_rbac_service.dart';

// ============================================================================
// PALETTE PROFESSIONAL (bleu + blanc)
// ============================================================================
class _Opp {
  static const blue = Color(0xFF1259C3);
  static const blueDeep = Color(0xFF0B3B8C);
  static const blueDark = Color(0xFF082A66);
  static const blueSoft = Color(0xFFE8F0FE);
  static const sky = Color(0xFF4C8DFF);
  static const bg = Color(0xFFF4F7FC);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3E9F2);
  static const txt = Color(0xFF0E1B2E);
  static const sub = Color(0xFF5A6B84);
  static const mut = Color(0xFF93A1B5);
  static const green = Color(0xFF0F8A5F);
  static const red = Color(0xFFD64545);
  static const amber = Color(0xFFE08A00);

  // Palette INCUBATOR
  static const incBlueNight    = Color(0xFF061B4D);
  static const incBlueInst     = Color(0xFF092C78);
  static const incBlueElec     = Color(0xFF1455D9);
  static const incGold         = Color(0xFFFFC107);
  static const incGoldDeep     = Color(0xFFFF9800);
  static const incGreen        = Color(0xFF16A34A);

  static Color urgency(int d) {
    if (d <= 0) return mut;
    if (d <= 3) return red;
    if (d <= 7) return amber;
    return blue;
  }
}

const Duration _kHeroAutoPlay = Duration(seconds: 4);
const double _kGridCardHeight = 336;
const double _kHeroHeight = 300;
const double _kGridPhotoHeight = 150;

enum _View { opportunities, incubator }

class OpportunitiesPage extends ConsumerStatefulWidget {
  const OpportunitiesPage({super.key});
  @override
  ConsumerState<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends ConsumerState<OpportunitiesPage>
    with SingleTickerProviderStateMixin {
  final OpportunityService _service = OpportunityService();
  late Future<List<OpportunityItem>> _future;
  final TextEditingController _searchCtrl = TextEditingController();
  final PageController _heroCtrl = PageController(viewportFraction: 0.9);
  final ScrollController _segmentScrollCtrl = ScrollController();
  final Set<String> _saved = <String>{};

  // Animation du segment control
  late final AnimationController _segmentAnimCtrl;
  late Animation<double> _indicatorAnim;

  Timer? _heroTimer;
  int _heroIndex = 0;
  bool _heroReady = false;
  int _catIndex = 0;
  bool _savedOnly = false;
  int _deadlineFilter = 0;
  bool _withReward = false;
  int _sortMode = 0;

  bool _isAdmin = false;
  bool _adminChecked = false;

  _View _currentView = _View.opportunities;

  static const List<_Cat> _cats = [
    _Cat('Toutes', Icons.auto_awesome_rounded),
    _Cat('Bourses', Icons.school_rounded),
    _Cat('Emplois', Icons.work_rounded),
    _Cat('Subventions', Icons.payments_rounded),
    _Cat('Concours', Icons.emoji_events_rounded),
    _Cat('Formations', Icons.menu_book_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _future = _service.listOpportunities();
    _resolveIsAdmin();
    _segmentAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _indicatorAnim = CurvedAnimation(
      parent: _segmentAnimCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _searchCtrl.dispose();
    _heroCtrl.dispose();
    _segmentScrollCtrl.dispose();
    _segmentAnimCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════ DÉTECTION ADMIN ═══════════════════
  Future<void> _resolveIsAdmin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _adminChecked = true);
      return;
    }
    bool admin = false;
    try {
      if (user.appMetadata['role'] == 'admin' ||
          user.userMetadata?['role'] == 'admin' ||
          user.userMetadata?['is_admin'] == true) {
        admin = true;
      }
      if (!admin) {
        final role = await AdminRbacService().fetchMyRole();
        if (AdminRbacService.canAccess(role: role, minLevel: 5)) admin = true;
      }
      if (!admin) {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        if (res?['role'] == 'admin') admin = true;
      }
      if (!admin) {
        admin = user.email?.endsWith('@thix.info') ?? false;
      }
    } catch (e) {
      debugPrint('[Opportunities] ⚠️ admin check: $e');
    }
    if (mounted) {
      setState(() {
        _isAdmin = admin;
        _adminChecked = true;
      });
    }
  }

  String _tr(AppLocalizations l10n, String key, String fb) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fb : v;
  }

  int _daysLeft(OpportunityItem o) => o.deadline.difference(DateTime.now()).inDays;
  double _ratio(OpportunityItem o) => (_daysLeft(o).clamp(0, 30)) / 30.0;
  bool _isNew(OpportunityItem o) => DateTime.now().difference(o.createdAt).inDays <= 7;

  String _rewardOf(OpportunityItem o) =>
      ThixInputGuard.text(o.rewardLabel, maxLength: 60, fallback: '');

  void _startHeroAuto(int count) {
    if (_heroReady || count <= 1) return;
    _heroReady = true;
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(_kHeroAutoPlay, (_) {
      if (!mounted || !_heroCtrl.hasClients) return;
      _heroIndex = (_heroIndex + 1) % count;
      _heroCtrl.animateToPage(_heroIndex,
          duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic);
    });
  }

  List<OpportunityItem> _filter(List<OpportunityItem> all) {
    var list = List<OpportunityItem>.from(all);
    if (_savedOnly) list = list.where((o) => _saved.contains(o.id)).toList();
    if (_catIndex > 0) {
      final t = _cats[_catIndex].label.toLowerCase();
      list = list.where((o) => o.category.toLowerCase().contains(t)).toList();
    }
    final q = ThixInputGuard.text(_searchCtrl.text, maxLength: 60, fallback: '');
    if (q.isNotEmpty) {
      final ql = q.toLowerCase();
      list = list.where((o) =>
          o.title.toLowerCase().contains(ql) ||
          o.organizer.toLowerCase().contains(ql) ||
          o.category.toLowerCase().contains(ql)).toList();
    }
    if (_deadlineFilter == 1) {
      list = list.where((o) { final d = _daysLeft(o); return d >= 0 && d <= 7; }).toList();
    } else if (_deadlineFilter == 2) {
      list = list.where((o) { final d = _daysLeft(o); return d >= 0 && d <= 30; }).toList();
    }
    if (_withReward) {
      list = list.where((o) { final r = _rewardOf(o); return r.isNotEmpty && r != '—'; }).toList();
    }
    switch (_sortMode) {
      case 1:
        list.sort((a, b) => a.deadline.compareTo(b.deadline));
        break;
      case 2:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  List<OpportunityItem> _featured(List<OpportunityItem> all) {
    final sorted = List<OpportunityItem>.from(all)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(6).toList();
  }

  List<OpportunityItem> _closing(List<OpportunityItem> all) =>
      (List<OpportunityItem>.from(all)..sort((a, b) => a.deadline.compareTo(b.deadline)))
          .where((o) { final d = _daysLeft(o); return d >= 0 && d <= 14; })
          .take(8)
          .toList();

  void _toggleSave(String id) {
    HapticFeedback.selectionClick();
    setState(() => _saved.contains(id) ? _saved.remove(id) : _saved.add(id));
  }

  void _switchView(_View v) {
    if (_currentView == v) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentView = v;
      _segmentAnimCtrl.forward(from: 0);
    });
  }

  Widget _glassBox({
    required Widget child,
    double radius = 14,
    Color tint = const Color(0x1FFFFFFF),
    double blur = 14,
    Color borderColor = const Color(0x33FFFFFF),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: _Opp.bg,
      body: RefreshIndicator(
        color: _currentView == _View.incubator ? _Opp.incBlueInst : _Opp.blue,
        backgroundColor: _Opp.card,
        onRefresh: () async {
          setState(() => _future = _service.listOpportunities());
          await _future;
        },
        child: FutureBuilder<List<OpportunityItem>>(
          future: _future,
          builder: (context, snap) {
            // ── Loading ──
            if (snap.connectionState != ConnectionState.done) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _header(l10n)),
                  SliverToBoxAdapter(child: _segmentControl(l10n)),
                  SliverToBoxAdapter(child: _skeletonAll(l10n)),
                ],
              );
            }

            // ── Erreur ──
            if (snap.hasError) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _header(l10n)),
                  SliverToBoxAdapter(child: _segmentControl(l10n)),
                  SliverToBoxAdapter(child: _errorState(l10n)),
                ],
              );
            }

            final all = snap.data ?? const <OpportunityItem>[];

            // ── Vue INCUBATOR (indépendante des données opportunities) ──
            if (_currentView == _View.incubator) {
              return _incubatorLanding(l10n);
            }

            // ── Vue OPPORTUNITIES vide ──
            if (all.isEmpty) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _header(l10n, all: all)),
                  SliverToBoxAdapter(child: _segmentControl(l10n)),
                  SliverToBoxAdapter(child: _emptyState(l10n)),
                ],
              );
            }

            final filteredList = _filter(all);
            final feat = _featured(all);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _startHeroAuto(feat.length);
            });

            return CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(l10n, all: all),
                      _segmentControl(l10n),
                      _heroBanner(feat, l10n),
                      _catsRail(l10n),
                      _closingSection(all, l10n),
                      _listSectionHeader(filteredList.length, l10n),
                    ],
                  ),
                ),
                if (filteredList.isEmpty)
                  SliverToBoxAdapter(child: _noResult(l10n))
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: _kGridCardHeight,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _gridCard(filteredList[i], l10n),
                        childCount: filteredList.length,
                      ),
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

  // ═══════════════════════════════════════════════════════════════════
  // SEGMENT CONTROL SCROLLABLE — Opportunity ↔ Incubator
  // ═══════════════════════════════════════════════════════════════════
  Widget _segmentControl(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _Opp.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Opp.line),
        boxShadow: [
          BoxShadow(
            color: _Opp.blueDeep.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (ctx, cons) {
          final segWidth = (cons.maxWidth - 8) / 2;
          return Stack(
            children: [
              // Indicateur animé
              AnimatedBuilder(
                animation: _indicatorAnim,
                builder: (context, _) {
                  final t = _currentView == _View.opportunities ? 0.0 : 1.0;
                  final animT = _segmentAnimCtrl.isAnimating
                      ? Tween<double>(
                          begin: _currentView == _View.opportunities ? 1.0 : 0.0,
                          end: t,
                        ).evaluate(_indicatorAnim)
                      : t;
                  return Positioned(
                    left: 4 + (segWidth * animT),
                    top: 4,
                    child: Container(
                      width: segWidth,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _currentView == _View.incubator
                            ? const LinearGradient(
                                colors: [_Opp.incBlueNight, _Opp.incBlueInst],
                              )
                            : const LinearGradient(
                                colors: [_Opp.blueDeep, _Opp.blue],
                              ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (_currentView == _View.incubator
                                    ? _Opp.incBlueInst
                                    : _Opp.blue)
                                .withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Segments
              Row(
                children: [
                  _SegmentButton(
                    label: _tr(l10n, 'seg_opportunities', 'Opportunités'),
                    icon: Icons.workspace_premium_rounded,
                    active: _currentView == _View.opportunities,
                    color: _Opp.blue,
                    onTap: () => _switchView(_View.opportunities),
                    width: segWidth,
                  ),
                  _SegmentButton(
                    label: _tr(l10n, 'seg_incubator', 'Incubator'),
                    icon: Icons.rocket_launch_rounded,
                    active: _currentView == _View.incubator,
                    color: _Opp.incGold,
                    onTap: () => _switchView(_View.incubator),
                    width: segWidth,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════ HEADER GLASS + STATS + BOUTON ADMIN ═══════════════════
  Widget _header(AppLocalizations l10n, {List<OpportunityItem>? all}) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Opp.blueDark, _Opp.blueDeep, _Opp.blue],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _Opp.sky.withOpacity(0.12)),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 10, 16, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.home),
                      child: _glassBox(
                        radius: 12,
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_tr(l10n, 'opp_title', 'Opportunités'),
                              style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                          const SizedBox(height: 1),
                          Text(_tr(l10n, 'opp_subtitle', 'Bourses • Emplois • Subventions'),
                              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    if (_isAdmin) ...[
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push('/opportunities/admin');
                        },
                        child: _glassBox(
                          radius: 12,
                          tint: const Color(0x33FFFFFF),
                          child: SizedBox(
                            height: 40,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.admin_panel_settings_rounded, size: 15, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text(_tr(l10n, 'opp_admin', 'Admin'),
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: () => setState(() => _savedOnly = !_savedOnly),
                      child: _glassBox(
                        radius: 12,
                        tint: _savedOnly ? const Color(0x40FFFFFF) : const Color(0x1FFFFFFF),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            _savedOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _openFilters,
                      child: _glassBox(
                        radius: 12,
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.tune_rounded, size: 17, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.9)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: _Opp.txt, fontSize: 13.5, fontWeight: FontWeight.w600),
                    cursorColor: _Opp.blue,
                    decoration: InputDecoration(
                      hintText: _tr(l10n, 'opp_search', 'Rechercher une opportunité…'),
                      hintStyle: const TextStyle(color: _Opp.mut, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, size: 19, color: _Opp.blue),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: _Opp.mut),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (all != null && all.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _headerStats(all, l10n),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStats(List<OpportunityItem> all, AppLocalizations l10n) {
    final total = all.length;
    final soon = all.where((o) { final d = _daysLeft(o); return d >= 0 && d <= 7; }).length;
    final fresh = all.where(_isNew).length;

    return Row(
      children: [
        Expanded(child: _statChip(Icons.layers_rounded, '$total', _tr(l10n, 'opp_stat_total', 'Actives'))),
        const SizedBox(width: 8),
        Expanded(child: _statChip(Icons.timer_rounded, '$soon', _tr(l10n, 'opp_stat_soon', 'Ferment ≤ 7 j'))),
        const SizedBox(width: 8),
        Expanded(child: _statChip(Icons.fiber_new_rounded, '$fresh', _tr(l10n, 'opp_stat_new', 'Nouvelles'))),
      ],
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return _glassBox(
      radius: 12,
      tint: const Color(0x1AFFFFFF),
      blur: 10,
      borderColor: const Color(0x30FFFFFF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white.withOpacity(0.9)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, height: 1.1)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 8.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // VUE INCUBATOR — LANDING INTÉGRÉE
  // ═══════════════════════════════════════════════════════════════════
  Widget _incubatorLanding(AppLocalizations l10n) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _incubatorHero(l10n),
              _incubatorStats(l10n),
              _incubatorFeatures(l10n),
              _incubatorFeaturedPrograms(l10n),
              _incubatorBottomCta(l10n),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ],
    );
  }

  Widget _incubatorHero(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Opp.incBlueNight, _Opp.incBlueInst, _Opp.incBlueElec],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _Opp.incBlueInst.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Pattern décoratif
          Positioned.fill(
            child: CustomPaint(painter: const _HeroPatternPainter()),
          ),
          // Glow or
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _Opp.incGold.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _Opp.incBlueElec.withOpacity(0.25),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _Opp.incGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _Opp.incGold.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _Opp.incGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SONATHIX GROUP',
                        style: TextStyle(
                          color: _Opp.incGold,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: _Opp.incGold,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _Opp.incGold.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.rocket_launch_rounded,
                          color: _Opp.incBlueNight, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INCUBATOR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Innover. Entreprendre. Grandir.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _tr(l10n, 'inc_hero_title',
                      'Transformez votre idée en startup d\'impact.'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tr(l10n, 'inc_hero_sub',
                      'Accédez aux programmes, mentors, formations et pitchs pour faire décoller votre projet.'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                // Double CTA
                Row(
                  children: [
                    Expanded(
                      child: _IncubatorPrimaryCta(
                        label: _tr(l10n, 'inc_cta_primary', 'Ouvrir l\'espace'),
                        icon: Icons.arrow_forward_rounded,
                        onTap: () => context.go(AppRoutes.incubator),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _IncubatorGhostCta(
                      label: _tr(l10n, 'inc_cta_secondary', 'Programmes'),
                      onTap: () => context.go(AppRoutes.incubatorExplore),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _incubatorStats(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _IncubatorStatCard(
              value: '12+',
              label: _tr(l10n, 'inc_stat_programs', 'Programmes'),
              icon: Icons.school_rounded,
              color: _Opp.incBlueInst,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _IncubatorStatCard(
              value: '45+',
              label: _tr(l10n, 'inc_stat_mentors', 'Mentors'),
              icon: Icons.groups_rounded,
              color: _Opp.incGold,
              textColor: _Opp.incBlueNight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _IncubatorStatCard(
              value: '200+',
              label: _tr(l10n, 'inc_stat_founders', 'Fondateurs'),
              icon: Icons.trending_up_rounded,
              color: _Opp.incGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _incubatorFeatures(AppLocalizations l10n) {
    final features = [
      (
        icon: Icons.emoji_events_rounded,
        title: _tr(l10n, 'inc_feat_programs', 'Programmes d\'incubation'),
        desc: _tr(l10n, 'inc_feat_programs_d',
            'Appels à projets, bourses et concours structurés.'),
        color: _Opp.incBlueInst,
      ),
      (
        icon: Icons.psychology_rounded,
        title: _tr(l10n, 'inc_feat_mentors', 'Mentorat 1-to-1'),
        desc: _tr(l10n, 'inc_feat_mentors_d',
            'Experts sectoriels pour accompagner votre croissance.'),
        color: _Opp.incBlueElec,
      ),
      (
        icon: Icons.mic_external_on_rounded,
        title: _tr(l10n, 'inc_feat_pitch', 'Pitch Room'),
        desc: _tr(l10n, 'inc_feat_pitch_d',
            'Préparez et présentez votre pitch devant des investisseurs.'),
        color: _Opp.incGold,
      ),
      (
        icon: Icons.workspace_premium_rounded,
        title: _tr(l10n, 'inc_feat_resources', 'Ressources premium'),
        desc: _tr(l10n, 'inc_feat_resources_d',
            'Formations, outils et communauté entrepreneuriale.'),
        color: _Opp.incGreen,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            _tr(l10n, 'inc_why_title', 'Pourquoi rejoindre INCUBATOR ?'),
          ),
          const SizedBox(height: 14),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _IncubatorFeatureCard(
                  icon: f.icon,
                  title: f.title,
                  description: f.desc,
                  color: f.color,
                ),
              )),
        ],
      ),
    );
  }

  Widget _incubatorFeaturedPrograms(AppLocalizations l10n) {
    // Programmes illustratifs (à remplacer par data réelle quand dispo)
    final programs = [
      (
        title: 'AgriTech Accelerator 2026',
        organizer: 'SONATHIX × AgriFund',
        duration: '12 semaines',
        seats: '15 places',
        tag: 'Ouvert',
        tagColor: _Opp.incGreen,
      ),
      (
        title: 'FinTech Bootcamp',
        organizer: 'Kinshasa Digital Hub',
        duration: '8 semaines',
        seats: '20 places',
        tag: 'Bientôt',
        tagColor: _Opp.incGold,
      ),
      (
        title: 'Green Energy Challenge',
        organizer: 'Congo Climate Fund',
        duration: '16 semaines',
        seats: '10 places',
        tag: 'Ouvert',
        tagColor: _Opp.incGreen,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  _tr(l10n, 'inc_featured', 'Programmes à la une'),
                  padding: EdgeInsets.zero,
                ),
              ),
              GestureDetector(
                onTap: () => context.go(AppRoutes.incubatorExplore),
                child: Row(
                  children: [
                    Text(
                      _tr(l10n, 'inc_see_all', 'Voir tout'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _Opp.incBlueInst,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: _Opp.incBlueInst),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: programs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = programs[i];
                return GestureDetector(
                  onTap: () => context.go(AppRoutes.incubator),
                  child: Container(
                    width: 230,
                    decoration: BoxDecoration(
                      color: _Opp.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _Opp.line),
                      boxShadow: [
                        BoxShadow(
                          color: _Opp.incBlueInst.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header coloré
                        Container(
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: i.isEven
                                  ? const [_Opp.incBlueNight, _Opp.incBlueInst]
                                  : const [_Opp.incBlueInst, _Opp.incBlueElec],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                    painter: const _HeroPatternPainter()),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: p.tagColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        p.tag,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.school_rounded,
                                        color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _Opp.txt,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.organizer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _Opp.sub,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _miniTag(Icons.schedule_rounded, p.duration),
                                  const SizedBox(width: 6),
                                  _miniTag(Icons.group_rounded, p.seats),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _Opp.blueSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _Opp.blue),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _Opp.blueDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _incubatorBottomCta(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_Opp.incGold, _Opp.incGoldDeep],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _Opp.incGold.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.handshake_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tr(l10n, 'inc_promo_title',
                        'Ensemble, construisons l\'entreprise de demain.'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _tr(l10n, 'inc_promo_sub',
                        'Rejoignez la communauté SONATHIX.'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ TITRE DE SECTION ═══════════════════
  Widget _sectionTitle(String title, {Widget? trailing, EdgeInsets? padding}) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_Opp.sky, _Opp.blue],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _Opp.txt, letterSpacing: -0.3)),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ═══════════════════ HERO XL AUTO-SCROLL ═══════════════════
  Widget _heroBanner(List<OpportunityItem> feat, AppLocalizations l10n) {
    if (feat.isEmpty || _savedOnly) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          _tr(l10n, 'opp_featured', 'À la une'),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: _Opp.blueSoft, borderRadius: BorderRadius.circular(10)),
            child: Text('${_heroIndex + 1}/${feat.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _Opp.blue)),
          ),
        ),
        SizedBox(
          height: _kHeroHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) {
                _heroTimer?.cancel();
                _heroReady = false;
              } else if (n is ScrollEndNotification) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) _startHeroAuto(feat.length);
                });
              }
              return false;
            },
            child: PageView.builder(
              controller: _heroCtrl,
              itemCount: feat.length,
              onPageChanged: (i) => setState(() => _heroIndex = i),
              itemBuilder: (_, i) => _heroItem(feat[i], l10n),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(feat.length, (i) {
            final sel = i == _heroIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: sel ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(color: sel ? _Opp.blue : _Opp.line, borderRadius: BorderRadius.circular(3)),
            );
          }),
        ),
      ],
    );
  }

  Widget _heroItem(OpportunityItem o, AppLocalizations l10n) {
    final d = _daysLeft(o);
    final url = ThixInputGuard.url(o.imageAssetPath);
    final reward = _rewardOf(o);
    final isSaved = _saved.contains(o.id);
    final closed = d <= 0;
    final accent = _Opp.urgency(d);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: GestureDetector(
        onTap: () => context.push('/opportunities/${o.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(color: _Opp.blueDeep.withOpacity(0.22), blurRadius: 22, offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null)
                  CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _heroFallback(o),
                    errorWidget: (_, __, ___) => _heroFallback(o),
                  )
                else
                  _heroFallback(o),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _Opp.blueDark.withOpacity(0.35),
                        Colors.transparent,
                        _Opp.blueDark.withOpacity(0.55),
                        _Opp.blueDark.withOpacity(0.95),
                      ],
                      stops: const [0.0, 0.30, 0.65, 1.0],
                    ),
                  ),
                ),
                if (closed) Container(color: Colors.black.withOpacity(0.25)),
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      _glassBox(
                        radius: 10,
                        tint: const Color(0x2EFFFFFF),
                        blur: 10,
                        borderColor: const Color(0x45FFFFFF),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          child: Text(o.category,
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      if (_isNew(o) && !closed) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(color: _Opp.blue, borderRadius: BorderRadius.circular(10)),
                          child: Text(_tr(l10n, 'opp_new', 'NOUVEAU'),
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _toggleSave(o.id),
                        child: _glassBox(
                          radius: 12,
                          tint: isSaved ? const Color(0x66FFFFFF) : const Color(0x2EFFFFFF),
                          blur: 10,
                          borderColor: const Color(0x45FFFFFF),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                size: 17, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _glassBox(
                    radius: 20,
                    tint: const Color(0x26FFFFFF),
                    blur: 16,
                    borderColor: const Color(0x3DFFFFFF),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ThixInputGuard.text(o.title, maxLength: 90),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.22, letterSpacing: -0.3)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.domain_rounded, size: 13, color: Colors.white.withOpacity(0.75)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(ThixInputGuard.text(o.organizer, maxLength: 50),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              _heroPill(
                                closed
                                    ? _tr(l10n, 'opp_closed', 'Clôturé')
                                    : (d == 1 ? _tr(l10n, 'opp_last_day', 'Dernier jour') : 'J-$d'),
                                closed ? null : (d <= 7 ? accent : null),
                                icon: Icons.schedule_rounded,
                              ),
                              if (reward.isNotEmpty && reward != '—') ...[
                                const SizedBox(width: 6),
                                _heroPill(reward, _Opp.green, icon: Icons.workspace_premium_rounded),
                              ],
                              const Spacer(),
                              const SizedBox(width: 8),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.arrow_outward_rounded, color: _Opp.blue, size: 19),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroPill(String label, Color? accent, {IconData? icon}) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: (accent ?? Colors.white).withOpacity(accent == null ? 0.18 : 0.38),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFallback(OpportunityItem o) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_Opp.blueDeep, _Opp.blue, _Opp.sky]),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
            ),
          ),
          Center(
            child: Text(
              ThixInputGuard.text(o.organizer, maxLength: 1, fallback: 'T').toUpperCase(),
              style: TextStyle(fontSize: 90, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.2)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ CATÉGORIES ═══════════════════
  Widget _catsRail(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final sel = _catIndex == i;
            final c = _cats[i];
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _catIndex = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: sel ? _Opp.blue : _Opp.card,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: sel ? _Opp.blue : _Opp.line),
                  boxShadow: sel
                      ? [BoxShadow(color: _Opp.blue.withOpacity(0.28), blurRadius: 12, offset: const Offset(0, 5))]
                      : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.icon, size: 15, color: sel ? Colors.white : _Opp.sub),
                    const SizedBox(width: 6),
                    Text(c.label,
                        style: TextStyle(fontSize: 12.5, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? Colors.white : _Opp.sub)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════ CLÔTURE IMMINENTE ═══════════════════
  Widget _closingSection(List<OpportunityItem> all, AppLocalizations l10n) {
    final closing = _closing(all);
    if (closing.isEmpty || _savedOnly) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          _tr(l10n, 'opp_closing', 'Clôture imminente'),
          trailing: GestureDetector(
            onTap: () => setState(() { _deadlineFilter = 1; _sortMode = 1; }),
            child: Row(
              children: [
                Text(_tr(l10n, 'opp_see_all', 'Voir tout'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Opp.blue)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 16, color: _Opp.blue),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: closing.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final o = closing[i];
              final d = _daysLeft(o);
              final col = _Opp.urgency(d);
              return GestureDetector(
                onTap: () => context.push('/opportunities/${o.id}'),
                child: Container(
                  width: 168,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _Opp.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _Opp.line),
                    boxShadow: [BoxShadow(color: _Opp.blueDeep.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Ring(days: d, progress: _ratio(o), color: col),
                          const Spacer(),
                          _miniLogo(o, 30),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(ThixInputGuard.text(o.title, maxLength: 50),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _Opp.txt, height: 1.25)),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.domain_rounded, size: 10, color: _Opp.mut),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(ThixInputGuard.text(o.organizer, maxLength: 24),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: _Opp.mut, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _listSectionHeader(int count, AppLocalizations l10n) {
    return _sectionTitle(
      _savedOnly ? _tr(l10n, 'opp_favorites', 'Mes favoris') : _tr(l10n, 'opp_all', 'Toutes les opportunités'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _Opp.blueSoft, borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _Opp.blue)),
      ),
    );
  }

  Widget _gridCard(OpportunityItem o, AppLocalizations l10n) {
    final d = _daysLeft(o);
    final isSaved = _saved.contains(o.id);
    final reward = _rewardOf(o);
    final url = ThixInputGuard.url(o.imageAssetPath);
    final closed = d <= 0;
    final col = _Opp.urgency(d);

    return GestureDetector(
      onTap: () => context.push('/opportunities/${o.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: _Opp.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _Opp.line),
          boxShadow: [BoxShadow(color: _Opp.blueDeep.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _kGridPhotoHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url != null)
                    CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: _Opp.blueSoft),
                        errorWidget: (_, __, ___) => _letter(o, _kGridPhotoHeight))
                  else
                    _letter(o, _kGridPhotoHeight),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.12), Colors.transparent, Colors.black.withOpacity(0.32)],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  if (closed) Container(color: Colors.black.withOpacity(0.35)),
                  Positioned(
                    top: 9,
                    left: 9,
                    right: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _glassBox(
                        radius: 9,
                        tint: const Color(0x33FFFFFF),
                        blur: 10,
                        borderColor: const Color(0x45FFFFFF),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                          child: Text(o.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleSave(o.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSaved ? _Opp.blue : Colors.white.withOpacity(0.95),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6)],
                        ),
                        child: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 14, color: isSaved ? Colors.white : _Opp.sub),
                      ),
                    ),
                  ),
                  if (_isNew(o) && !closed)
                    Positioned(
                      bottom: 9,
                      left: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _Opp.blue, borderRadius: BorderRadius.circular(7)),
                        child: Text(_tr(l10n, 'opp_new', 'NOUVEAU'),
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                    ),
                  Positioned(
                    bottom: 9,
                    right: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (closed || d <= 7) ? col : Colors.white,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        closed ? _tr(l10n, 'opp_closed', 'Clôturé') : 'J-$d',
                        style: TextStyle(
                            color: (closed || d <= 7) ? Colors.white : _Opp.blueDeep,
                            fontSize: 9,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ThixInputGuard.text(o.title, maxLength: 90),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _Opp.txt, height: 1.25)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.domain_rounded, size: 11, color: _Opp.mut),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(ThixInputGuard.text(o.organizer, maxLength: 40),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: _Opp.mut, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    if (reward.isNotEmpty && reward != '—') ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: _Opp.blueSoft, borderRadius: BorderRadius.circular(9)),
                        child: Row(
                          children: [
                            const Icon(Icons.workspace_premium_rounded, size: 11, color: _Opp.blue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(reward,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _Opp.blueDeep)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.event_rounded, size: 11, color: _Opp.mut),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(ThixInputGuard.text(o.deadlineLabel, maxLength: 20),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9.5, color: _Opp.sub, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: closed ? 1.0 : _ratio(o),
                        minHeight: 4.5,
                        backgroundColor: _Opp.line,
                        valueColor: AlwaysStoppedAnimation(closed ? _Opp.mut : col),
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

  Widget _miniLogo(OpportunityItem o, double size) {
    final url = ThixInputGuard.url(o.imageAssetPath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, __, ___) => _letter(o, size))
            : _letter(o, size),
      ),
    );
  }

  Widget _letter(OpportunityItem o, double size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_Opp.blueSoft, Color(0xFFD3E3FD)]),
      ),
      alignment: Alignment.center,
      child: Text(ThixInputGuard.text(o.organizer, maxLength: 1, fallback: 'T').toUpperCase(),
          style: TextStyle(fontSize: size * 0.35, fontWeight: FontWeight.w800, color: _Opp.blue)),
    );
  }

  // ═══════════════════ FILTRES ═══════════════════
  void _openFilters() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withOpacity(0.95),
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _Opp.line, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _Opp.blueSoft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.tune_rounded, size: 15, color: _Opp.blue)),
                      const SizedBox(width: 10),
                      Text(_tr(l10n, 'opp_filters', 'Filtres & tri'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _Opp.txt)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(_tr(l10n, 'opp_deadline', 'Échéance'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Opp.sub)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (int i = 0; i < 3; i++)
                        ChoiceChip(
                          selected: _deadlineFilter == i,
                          onSelected: (_) => setSt(() => _deadlineFilter = i),
                          label: Text([_tr(l10n, 'opp_f_all', 'Toutes'), '< 7 j', '< 30 j'][i]),
                          selectedColor: _Opp.blue,
                          backgroundColor: Colors.white,
                          showCheckmark: false,
                          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _deadlineFilter == i ? Colors.white : _Opp.sub),
                          side: BorderSide(color: _deadlineFilter == i ? _Opp.blue : _Opp.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_tr(l10n, 'opp_sort', 'Trier par'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Opp.sub)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (int i = 0; i < 3; i++)
                        ChoiceChip(
                          selected: _sortMode == i,
                          onSelected: (_) => setSt(() => _sortMode = i),
                          label: Text([
                            _tr(l10n, 'opp_sort_new', 'Nouveautés'),
                            _tr(l10n, 'opp_sort_deadline', 'Échéance'),
                            'A → Z',
                          ][i]),
                          selectedColor: _Opp.blueDeep,
                          backgroundColor: Colors.white,
                          showCheckmark: false,
                          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _sortMode == i ? Colors.white : _Opp.sub),
                          side: BorderSide(color: _sortMode == i ? _Opp.blueDeep : _Opp.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _withReward,
                    activeColor: _Opp.blue,
                    onChanged: (v) => setSt(() => _withReward = v),
                    title: Text(_tr(l10n, 'opp_with_reward', 'Avec récompense / financement'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Opp.txt)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Opp.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                      child: Text(_tr(l10n, 'opp_apply', 'Appliquer'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════ ÉTATS ═══════════════════
  Widget _skeletonAll(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
          child: Container(
            height: _kHeroHeight - 20,
            decoration: BoxDecoration(
              color: _Opp.card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _Opp.line),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: _kGridCardHeight,
            ),
            itemCount: 2,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(color: _Opp.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _Opp.line)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 32),
      child: Center(
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: _Opp.blueSoft, shape: BoxShape.circle), child: const Icon(Icons.explore_rounded, size: 34, color: _Opp.blue)),
            const SizedBox(height: 14),
            Text(_tr(l10n, 'opp_empty_title', 'Aucune opportunité active'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _Opp.txt)),
            const SizedBox(height: 6),
            Text(_tr(l10n, 'opp_empty_sub', 'De nouvelles bourses, emplois et subventions arrivent bientôt.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _Opp.sub)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              onPressed: () => _switchView(_View.incubator),
              style: ElevatedButton.styleFrom(
                backgroundColor: _Opp.incBlueInst,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              label: Text(_tr(l10n, 'inc_try_incubator', 'Essayer INCUBATOR')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noResult(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 32, color: _Opp.mut),
            const SizedBox(height: 10),
            Text(_tr(l10n, 'opp_no_result', 'Aucun résultat'), style: const TextStyle(fontWeight: FontWeight.w800, color: _Opp.txt)),
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() { _catIndex = 0; _savedOnly = false; _deadlineFilter = 0; _withReward = false; _sortMode = 0; });
              },
              child: Text(_tr(l10n, 'opp_reset', 'Réinitialiser'), style: const TextStyle(color: _Opp.blue, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 34, color: _Opp.mut),
            const SizedBox(height: 10),
            Text(_tr(l10n, 'opp_error', 'Connexion interrompue'), style: const TextStyle(fontWeight: FontWeight.w800, color: _Opp.txt)),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _Opp.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => setState(() => _future = _service.listOpportunities()),
              child: Text(_tr(l10n, 'opp_retry', 'Réessayer')),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SEGMENT BUTTON
// ============================================================================
class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
    required this.width,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : _Opp.sub,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? Colors.white : _Opp.sub,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS INCUBATOR
// ============================================================================
class _IncubatorStatCard extends StatelessWidget {
  const _IncubatorStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.textColor,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Opp.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Opp.line),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textColor ?? _Opp.txt,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: _Opp.sub,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncubatorFeatureCard extends StatelessWidget {
  const _IncubatorFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Opp.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Opp.line),
        boxShadow: [
          BoxShadow(
            color: _Opp.blueDeep.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _Opp.txt,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: _Opp.sub,
                    height: 1.4,
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

class _IncubatorPrimaryCta extends StatelessWidget {
  const _IncubatorPrimaryCta({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: _Opp.incGold,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _Opp.incGold.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _Opp.incBlueNight,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: _Opp.incBlueNight, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncubatorGhostCta extends StatelessWidget {
  const _IncubatorGhostCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 130,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ANNEAU COUNTDOWN
// ============================================================================
class _Ring extends StatelessWidget {
  final int days;
  final double progress;
  final Color color;
  const _Ring({required this.days, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: CustomPaint(
        painter: _RingPainter(progress: progress, color: color),
        child: Center(child: Text('$days', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: color))),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 5) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFFEDF1F6);
    canvas.drawCircle(center, radius, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}

// ============================================================================
// PATTERN PEINTER (hero Incubator)
// ============================================================================
class _HeroPatternPainter extends CustomPainter {
  const _HeroPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    for (int i = -20; i < size.width + 20; i += 24) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble() + 80, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Cat {
  final String label;
  final IconData icon;
  const _Cat(this.label, this.icon);
}

// ============================================================================
// COMPAT : widgets exportés utilisés ailleurs
// ============================================================================
class CountdownTimerWidget extends StatefulWidget {
  final DateTime targetDate;
  const CountdownTimerWidget({super.key, required this.targetDate});
  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  late Timer _timer;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final d = widget.targetDate.difference(DateTime.now());
    if (mounted) setState(() => _left = d.isNegative ? Duration.zero : d);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_left == Duration.zero) return _pill('Clôturé', const Color(0xFF93A1B5));
    final s = '${_left.inDays}j ${(_left.inHours % 24).toString().padLeft(2, '0')}:${(_left.inMinutes % 60).toString().padLeft(2, '0')}:${(_left.inSeconds % 60).toString().padLeft(2, '0')}';
    return _pill(s, _left.inDays <= 3 ? _Opp.red : _Opp.blue);
  }

  Widget _pill(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class FeaturedCountdownCarousel extends StatelessWidget {
  final List<OpportunityItem> opportunities;
  final ValueChanged<OpportunityItem> onOpen;
  const FeaturedCountdownCarousel({super.key, required this.opportunities, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (opportunities.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: opportunities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final o = opportunities[i];
          return GestureDetector(
            onTap: () => onOpen(o),
            child: Container(
              width: 230,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _Opp.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _Opp.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ThixInputGuard.text(o.title, maxLength: 60), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _Opp.txt)),
                const Spacer(),
                CountdownTimerWidget(targetDate: ThixInputGuard.safeDate(o.deadline)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
