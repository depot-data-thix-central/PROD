// lib/presentation/opportunities/opportunities_page.dart
// ============================================================================
// OPPORTUNITÉS — v4 PROFESSIONAL
//  • ✅ Grille 2 colonnes, grandes photos (style carte produit local) + barre
//  • ✅ Nouveautés en haut (tri created_at DESC + badge NOUVEAU)
//  • ✅ Bouton ADMIN (détection repo : RBAC + profiles + metadata + email)
//  • ✅ Recherche lisible : fond blanc, texte sombre, icône bleue
//  • ✅ Hero auto-scroll + glassmorphism bleu/blanc
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
  static const bg = Color(0xFFF4F7FC);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3E9F2);
  static const txt = Color(0xFF0E1B2E);
  static const sub = Color(0xFF5A6B84);
  static const mut = Color(0xFF93A1B5);
  static const green = Color(0xFF0F8A5F);
  static const red = Color(0xFFD64545);
}

const Duration _kHeroAutoPlay = Duration(seconds: 4);
const double _kGridCardHeight = 312;

class OpportunitiesPage extends ConsumerStatefulWidget {
  const OpportunitiesPage({super.key});
  @override
  ConsumerState<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends ConsumerState<OpportunitiesPage> {
  final OpportunityService _service = OpportunityService();
  late Future<List<OpportunityItem>> _future;
  final TextEditingController _searchCtrl = TextEditingController();
  final PageController _heroCtrl = PageController(viewportFraction: 0.92);
  final Set<String> _saved = <String>{};

  Timer? _heroTimer;
  int _heroIndex = 0;
  bool _heroReady = false;
  int _catIndex = 0;
  bool _savedOnly = false;
  int _deadlineFilter = 0;
  bool _withReward = false;
  int _sortMode = 0; // 0 = Nouveautés (created_at desc)

  bool _isAdmin = false;
  bool _adminChecked = false;

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
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _searchCtrl.dispose();
    _heroCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════ DÉTECTION ADMIN (logique du repo) ═══════════════════
  Future<void> _resolveIsAdmin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _adminChecked = true);
      return;
    }
    bool admin = false;
    try {
      // 1) Metadata JWT (instantané)
      if (user.appMetadata?['role'] == 'admin' ||
          user.userMetadata?['role'] == 'admin' ||
          user.userMetadata?['is_admin'] == true) {
        admin = true;
      }
      // 2) RBAC officiel : table thix_admin_memberships
      if (!admin) {
        final role = await AdminRbacService().fetchMyRole();
        if (AdminRbacService.canAccess(role: role, minLevel: 5)) admin = true;
      }
      // 3) profiles.role (AdminService)
      if (!admin) {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        if (res?['role'] == 'admin') admin = true;
      }
      // 4) Fallback dev (AdminService)
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

  bool _isNew(OpportunityItem o) =>
      DateTime.now().difference(o.createdAt).inDays <= 7;

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

  // ─── Filtres + tri (défaut : NOUVEAUTÉS en premier) ───
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
        // ✅ NOUVEAUTÉS EN HAUT
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  /// Hero = 6 plus récentes
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
        color: _Opp.blue,
        backgroundColor: _Opp.card,
        onRefresh: () async {
          setState(() => _future = _service.listOpportunities());
          await _future;
        },
        child: FutureBuilder<List<OpportunityItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [SliverToBoxAdapter(child: _skeletonAll(l10n))],
              );
            }
            if (snap.hasError) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _header(l10n)),
                  SliverToBoxAdapter(child: _errorState(l10n)),
                ],
              );
            }

            final all = snap.data ?? const <OpportunityItem>[];
            if (all.isEmpty) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _header(l10n)),
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
                      _header(l10n),
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
                  // ✅ GRILLE 2 COLONNES (grandes photos, style produit local)
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
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════ HEADER GLASS + BOUTON ADMIN ═══════════════════
  Widget _header(AppLocalizations l10n) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Opp.blueDark, _Opp.blueDeep, _Opp.blue],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 24),
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
                    width: 38,
                    height: 38,
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
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    Text(_tr(l10n, 'opp_subtitle', 'Bourses • Emplois • Subventions'),
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10.5, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              // ✅ BOUTON ADMIN (visible uniquement si compte admin du repo)
              if (_isAdmin) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/opportunities/admin');
                  },
                  child: _glassBox(
                    radius: 12,
                    tint: const Color(0x33FFFFFF),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.admin_panel_settings_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(_tr(l10n, 'opp_admin', 'Admin'),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ],
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
                    width: 38,
                    height: 38,
                    child: Icon(
                      _savedOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 16,
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
                    width: 38,
                    height: 38,
                    child: Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ RECHERCHE LISIBLE : fond blanc + texte sombre + icône bleue
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.9)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: _Opp.txt, fontSize: 13.5, fontWeight: FontWeight.w600),
              cursorColor: _Opp.blue,
              decoration: InputDecoration(
                hintText: _tr(l10n, 'opp_search', 'Rechercher une opportunité…'),
                hintStyle: const TextStyle(color: _Opp.mut, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _Opp.blue),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ HERO AUTO-SCROLL ═══════════════════
  Widget _heroBanner(List<OpportunityItem> feat, AppLocalizations l10n) {
    if (feat.isEmpty || _savedOnly) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 208,
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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(feat.length, (i) {
            final sel = i == _heroIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: sel ? 18 : 6,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: GestureDetector(
        onTap: () => context.push('/opportunities/${o.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: _Opp.blueDeep.withOpacity(0.16), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null)
                  CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, __, ___) => _heroFallback(o))
                else
                  _heroFallback(o),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _Opp.blueDark.withOpacity(0.25),
                        Colors.transparent,
                        _Opp.blueDark.withOpacity(0.90),
                      ],
                      stops: const [0.0, 0.40, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _glassBox(
                        radius: 8,
                        tint: const Color(0x29FFFFFF),
                        blur: 10,
                        borderColor: const Color(0x40FFFFFF),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          child: Text(o.category, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _toggleSave(o.id),
                        child: _glassBox(
                          radius: 8,
                          tint: const Color(0x29FFFFFF),
                          blur: 10,
                          borderColor: const Color(0x40FFFFFF),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 13, color: Colors.white),
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
                    radius: 14,
                    tint: const Color(0x24FFFFFF),
                    blur: 14,
                    borderColor: const Color(0x38FFFFFF),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ThixInputGuard.text(o.title, maxLength: 80),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.25)),
                          const SizedBox(height: 4),
                          Text(ThixInputGuard.text(o.organizer, maxLength: 45),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10.5, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _heroPill(
                                d <= 0
                                    ? _tr(l10n, 'opp_closed', 'Clôturé')
                                    : (d == 1 ? _tr(l10n, 'opp_last_day', 'Dernier jour') : 'J-$d'),
                                d <= 3 ? _Opp.red : null,
                              ),
                              if (reward.isNotEmpty && reward != '—') ...[
                                const SizedBox(width: 6),
                                _heroPill(reward, _Opp.green),
                              ],
                              const Spacer(),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 15),
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

  Widget _heroPill(String label, Color? accent) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (accent ?? Colors.white).withOpacity(accent == null ? 0.16 : 0.22),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _heroFallback(OpportunityItem o) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_Opp.blueDeep, _Opp.blue]),
      ),
      child: Center(
        child: Text(
          ThixInputGuard.text(o.organizer, maxLength: 1, fallback: 'T').toUpperCase(),
          style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.18)),
        ),
      ),
    );
  }

  // ═══════════════════ CATÉGORIES (pills) ═══════════════════
  Widget _catsRail(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: sel ? _Opp.blue : _Opp.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? _Opp.blue : _Opp.line),
                  boxShadow: sel
                      ? [BoxShadow(color: _Opp.blue.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))]
                      : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.icon, size: 14, color: sel ? Colors.white : _Opp.sub),
                    const SizedBox(width: 6),
                    Text(c.label,
                        style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? Colors.white : _Opp.sub)),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Container(width: 4, height: 16, decoration: BoxDecoration(color: _Opp.blue, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(_tr(l10n, 'opp_closing', 'Clôture imminente'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _Opp.txt, letterSpacing: -0.2)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() { _deadlineFilter = 1; _sortMode = 1; }),
                child: Text(_tr(l10n, 'opp_see_all', 'Voir tout'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Opp.blue)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: closing.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final o = closing[i];
              final d = _daysLeft(o);
              return GestureDetector(
                onTap: () => context.push('/opportunities/${o.id}'),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _Opp.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _Opp.line),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Ring(days: d, progress: _ratio(o), color: d <= 3 ? _Opp.red : _Opp.blue),
                          const Spacer(),
                          _miniLogo(o, 26),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(ThixInputGuard.text(o.title, maxLength: 44),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _Opp.txt, height: 1.25)),
                      const Spacer(),
                      Text(ThixInputGuard.text(o.organizer, maxLength: 22),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9.5, color: _Opp.mut, fontWeight: FontWeight.w500)),
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

  // ═══════════════════ GRILLE 2 COLONNES (style carte produit local) ═══════════════════
  Widget _listSectionHeader(int count, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: _Opp.blue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_savedOnly ? _tr(l10n, 'opp_favorites', 'Mes favoris') : _tr(l10n, 'opp_all', 'Toutes les opportunités'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _Opp.txt, letterSpacing: -0.2)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: _Opp.blueSoft, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _Opp.blue)),
          ),
        ],
      ),
    );
  }

  Widget _gridCard(OpportunityItem o, AppLocalizations l10n) {
    final d = _daysLeft(o);
    final isSaved = _saved.contains(o.id);
    final reward = _rewardOf(o);
    final url = ThixInputGuard.url(o.imageAssetPath);
    final closed = d <= 0;

    return GestureDetector(
      onTap: () => context.push('/opportunities/${o.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: _Opp.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _Opp.line),
          boxShadow: [BoxShadow(color: _Opp.blueDeep.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── GRANDE PHOTO ──
            SizedBox(
              height: 138,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url != null)
                    CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: _Opp.blueSoft),
                        errorWidget: (_, __, ___) => _letter(o, 138))
                  else
                    _letter(o, 138),
                  if (closed)
                    Container(color: Colors.black.withOpacity(0.35)),
                  // Chip catégorie (glass)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _glassBox(
                      radius: 8,
                      tint: const Color(0x29FFFFFF),
                      blur: 10,
                      borderColor: const Color(0x40FFFFFF),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Text(o.category, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  // Bookmark
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleSave(o.id),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isSaved ? _Opp.blue : Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 13, color: isSaved ? Colors.white : _Opp.sub),
                      ),
                    ),
                  ),
                  // Badge NOUVEAU (≤ 7 jours)
                  if (_isNew(o) && !closed)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: _Opp.blue, borderRadius: BorderRadius.circular(6)),
                        child: Text(_tr(l10n, 'opp_new', 'NOUVEAU'),
                            style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                      ),
                    ),
                  // Statut J-x / Clôturé
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: closed ? _Opp.mut : (d <= 3 ? _Opp.red : Colors.white),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        closed ? _tr(l10n, 'opp_closed', 'Clôturé') : 'J-$d',
                        style: TextStyle(color: closed ? Colors.white : (d <= 3 ? Colors.white : _Opp.blueDeep), fontSize: 8.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── INFOS ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ThixInputGuard.text(o.title, maxLength: 90),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _Opp.txt, height: 1.25)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.domain_rounded, size: 10, color: _Opp.mut),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(ThixInputGuard.text(o.organizer, maxLength: 40),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9.5, color: _Opp.mut, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    if (reward.isNotEmpty && reward != '—') ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                        decoration: BoxDecoration(color: _Opp.blueSoft, borderRadius: BorderRadius.circular(8)),
                        child: Text(reward,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _Opp.blueDeep)),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.event_rounded, size: 10, color: _Opp.mut),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(ThixInputGuard.text(o.deadlineLabel, maxLength: 20),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9, color: _Opp.sub, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // ── BARRE DE PROGRESSION ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: closed ? 1.0 : _ratio(o),
                        minHeight: 4,
                        backgroundColor: _Opp.line,
                        valueColor: AlwaysStoppedAnimation(closed ? _Opp.mut : _Opp.blue),
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
      borderRadius: BorderRadius.circular(8),
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
      color: _Opp.blueSoft,
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withOpacity(0.94),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: _Opp.line, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: _Opp.blueSoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.tune_rounded, size: 14, color: _Opp.blue)),
                      const SizedBox(width: 10),
                      Text(_tr(l10n, 'opp_filters', 'Filtres & tri'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _Opp.txt)),
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
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Opp.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      children: [
        _header(l10n),
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
            itemCount: 4,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(color: _Opp.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Opp.line)),
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
            Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(color: _Opp.blueSoft, shape: BoxShape.circle), child: const Icon(Icons.explore_rounded, size: 32, color: _Opp.blue)),
            const SizedBox(height: 14),
            Text(_tr(l10n, 'opp_empty_title', 'Aucune opportunité active'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _Opp.txt)),
            const SizedBox(height: 6),
            Text(_tr(l10n, 'opp_empty_sub', 'De nouvelles bourses, emplois et subventions arrivent bientôt.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _Opp.sub)),
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
            const Icon(Icons.search_off_rounded, size: 30, color: _Opp.mut),
            const SizedBox(height: 10),
            Text(_tr(l10n, 'opp_no_result', 'Aucun résultat'), style: const TextStyle(fontWeight: FontWeight.w800, color: _Opp.txt)),
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() { _catIndex = 0; _savedOnly = false; _deadlineFilter = 0; _withReward = false; _sortMode = 0; });
              },
              child: Text(_tr(l10n, 'opp_reset', 'Réinitialiser')),
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
            const Icon(Icons.wifi_off_rounded, size: 32, color: _Opp.mut),
            const SizedBox(height: 10),
            Text(_tr(l10n, 'opp_error', 'Connexion interrompue'), style: const TextStyle(fontWeight: FontWeight.w800, color: _Opp.txt)),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _Opp.blue, foregroundColor: Colors.white, elevation: 0),
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
      width: 44,
      height: 44,
      child: CustomPaint(
        painter: _RingPainter(progress: progress, color: color),
        child: Center(child: Text('$days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color))),
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
