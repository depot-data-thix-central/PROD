// lib/presentation/opportunities/opportunities_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/security/thix_input_guard.dart';
import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/opportunity_service.dart';

// ============================================================================
// OPPORTUNITÉS HUB — design "marketplace pro" (réf. LinkedIn Jobs / Indeed /
// ReliefWeb / Scholly / Jobberman). Fond clair, cartes blanches logo-first,
// métadonnées structurées, badges d'échéance, favoris, filtres.
// ============================================================================
class OpportunitiesPage extends ConsumerStatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  ConsumerState<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends ConsumerState<OpportunitiesPage> {
  final OpportunityService _service = OpportunityService();
  late Future<List<OpportunityItem>> _future;

  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _saved = <String>{};

  int _catIndex = 0;
  bool _savedOnly = false;
  int _deadlineFilter = 0; // 0=tous, 1=<7j, 2=<30j
  bool _withReward = false;
  int _sortMode = 0; // 0=échéance, 1=récent, 2=A→Z

  static const List<_Cat> _cats = [
    _Cat('Toutes', Icons.grid_view_rounded),
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
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _catColor(String c) {
    final l = c.toLowerCase();
    if (l.contains('bourse') || l.contains('formation')) return const Color(0xFF2563EB);
    if (l.contains('emploi')) return const Color(0xFF059669);
    if (l.contains('subvention')) return const Color(0xFFD97706);
    if (l.contains('concours')) return const Color(0xFFDB2777);
    return ThixPolicy.primaryDeep;
  }

  int _daysLeft(OpportunityItem o) =>
      o.deadline.difference(DateTime.now()).inDays;

  // ─── Pipeline de filtres ───
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
          ThixInputGuard.text(o.title, maxLength: 200).toLowerCase().contains(ql) ||
          ThixInputGuard.text(o.organizer, maxLength: 200).toLowerCase().contains(ql) ||
          o.category.toLowerCase().contains(ql)).toList();
    }

    if (_deadlineFilter == 1) {
      list = list.where((o) { final d = _daysLeft(o); return d >= 0 && d <= 7; }).toList();
    } else if (_deadlineFilter == 2) {
      list = list.where((o) { final d = _daysLeft(o); return d >= 0 && d <= 30; }).toList();
    }

    if (_withReward) {
      list = list.where((o) {
        final r = ThixInputGuard.text(o.rewardLabel, maxLength: 60, fallback: '');
        return r.isNotEmpty && r != '—';
      }).toList();
    }

    switch (_sortMode) {
      case 1:
        list.sort((a, b) => b.deadline.compareTo(a.deadline));
        break;
      case 2:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      default:
        list.sort((a, b) => a.deadline.compareTo(b.deadline));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAdmin = user?.appMetadata?['role'] == 'admin' ||
        user?.userMetadata?['is_admin'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/opportunities/admin'),
              backgroundColor: ThixPolicy.primaryDeep,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Publier une offre',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            )
          : null,
      body: RefreshIndicator(
        color: ThixPolicy.primaryDeep,
        onRefresh: () async {
          setState(() => _future = _service.listOpportunities());
          await _future;
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _appBar(),
            SliverToBoxAdapter(child: _searchAndChips()),
            SliverToBoxAdapter(
              child: FutureBuilder<List<OpportunityItem>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return _skeleton();
                  if (snap.hasError) return _errorState();
                  final all = snap.data ?? const <OpportunityItem>[];
                  if (all.isEmpty) return _emptyState();

                  final closing = (List<OpportunityItem>.from(all)
                        ..sort((a, b) => a.deadline.compareTo(b.deadline)))
                      .where((o) { final d = _daysLeft(o); return d >= 0 && d <= 14; })
                      .take(8)
                      .toList();

                  final list = _filter(all);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (closing.isNotEmpty && !_savedOnly) ...[
                        _sectionHeader('🔥 Clôture imminente', 'Voir tout', () {
                          setState(() { _deadlineFilter = 1; _sortMode = 0; });
                        }),
                        _closingRail(closing),
                        const SizedBox(height: 8),
                      ],
                      _sectionHeader(
                        _savedOnly ? 'Mes favoris' : 'Recommandées pour vous',
                        '${list.length} offres',
                        null,
                      ),
                      if (list.isEmpty)
                        _noResult()
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: list
                                .map((o) => _jobCard(o))
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 110),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ APP BAR claire ═══════════════
  Widget _appBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFFF7F9FC),
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: ThixPolicy.inkDeep, size: 18),
        onPressed: () => context.go(AppRoutes.home),
      ),
      title: const Text('Opportunités',
          style: TextStyle(
              color: ThixPolicy.inkDeep,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.3)),
      centerTitle: false,
      actions: [
        IconButton(
          tooltip: 'Mes favoris',
          icon: Icon(
            _savedOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: _savedOnly ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary,
          ),
          onPressed: () => setState(() => _savedOnly = !_savedOnly),
        ),
        IconButton(
          tooltip: 'Filtres & tri',
          icon: const Icon(Icons.tune_rounded, color: ThixPolicy.textSecondary),
          onPressed: _openFilters,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ═══════════════ RECHERCHE + CHIPS ═══════════════
  Widget _searchAndChips() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain),
              decoration: const InputDecoration(
                hintText: 'Rechercher une bourse, un emploi, une subvention…',
                hintStyle: TextStyle(fontSize: 13.5, color: ThixPolicy.textMuted),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final sel = _catIndex == i;
              final c = _cats[i];
              return ChoiceChip(
                selected: sel,
                onSelected: (_) { HapticFeedback.selectionClick(); setState(() => _catIndex = i); },
                avatar: Icon(c.icon, size: 15, color: sel ? Colors.white : ThixPolicy.textSecondary),
                label: Text(c.label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : ThixPolicy.textSecondary)),
                selectedColor: ThixPolicy.primaryDeep,
                backgroundColor: Colors.white,
                side: BorderSide(color: sel ? ThixPolicy.primaryDeep : const Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionHeader(String title, String right, VoidCallback? onRight) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
          if (onRight != null)
            GestureDetector(
              onTap: onRight,
              child: Text(right,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ThixPolicy.primaryDeep)),
            )
          else
            Text(right,
                style: const TextStyle(fontSize: 12, color: ThixPolicy.textMuted)),
        ],
      ),
    );
  }

  // ═══════════════ RAIL "CLÔTURE IMMINENTE" ═══════════════
  Widget _closingRail(List<OpportunityItem> items) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final o = items[i];
          final color = _catColor(o.category);
          final d = _daysLeft(o);
          return GestureDetector(
            onTap: () => context.push('/opportunities/${o.id}'),
            child: Container(
              width: 210,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _logo(o, 34),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(ThixInputGuard.text(o.organizer, maxLength: 40),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(ThixInputGuard.text(o.title, maxLength: 70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThixPolicy.inkDeep, height: 1.25)),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (d <= 3 ? ThixPolicy.danger : const Color(0xFFD97706)).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(d <= 0 ? 'Clôturé' : (d == 1 ? 'Dernier jour' : '$d j restants'),
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: d <= 3 ? ThixPolicy.danger : const Color(0xFFB45309))),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, size: 16, color: color),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════ CARTE TYPE "LINKEDIN / INDEED" ═══════════════
  Widget _jobCard(OpportunityItem o) {
    final color = _catColor(o.category);
    final d = _daysLeft(o);
    final isSaved = _saved.contains(o.id);
    final reward = ThixInputGuard.text(o.rewardLabel, maxLength: 60, fallback: '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/opportunities/${o.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _logo(o, 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ThixInputGuard.text(o.title, maxLength: 110),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ThixPolicy.inkDeep, height: 1.3)),
                      const SizedBox(height: 3),
                      Text(ThixInputGuard.text(o.organizer, maxLength: 60),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: ThixPolicy.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 20, color: isSaved ? ThixPolicy.primaryDeep : Colors.grey.shade400),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => isSaved ? _saved.remove(o.id) : _saved.add(o.id));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isSaved ? 'Retiré des favoris' : 'Ajouté aux favoris'),
                        duration: const Duration(seconds: 1)));
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _tag(o.category, color),
                _tag(d <= 0 ? 'Clôturé' : (d <= 7 ? 'Clôture proche' : 'Ouvert'),
                    d <= 0 ? Colors.grey : (d <= 7 ? ThixPolicy.danger : const Color(0xFF059669))),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                if (reward.isNotEmpty && reward != '—') ...[
                  const Icon(Icons.payments_outlined, size: 15, color: Color(0xFF059669)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(reward,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                  ),
                ] else
                  const Spacer(),
                const Icon(Icons.schedule_rounded, size: 14, color: ThixPolicy.textMuted),
                const SizedBox(width: 4),
                Text(ThixInputGuard.text(o.deadlineLabel, maxLength: 30),
                    style: const TextStyle(fontSize: 11.5, color: ThixPolicy.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(ThixInputGuard.text(label, maxLength: 24),
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _logo(OpportunityItem o, double size) {
    final url = ThixInputGuard.url(o.imageAssetPath);
    final letter = ThixInputGuard.text(o.organizer, maxLength: 1, fallback: 'T');
    final color = _catColor(o.category);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _letterLogo(letter, color, size),
              )
            : _letterLogo(letter, color, size),
      ),
    );
  }

  Widget _letterLogo(String letter, Color color, double size) {
    return Container(
      color: color.withOpacity(0.12),
      alignment: Alignment.center,
      child: Text(letter.toUpperCase(),
          style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: color)),
    );
  }

  // ═══════════════ FILTRES (bottom sheet) ═══════════════
  void _openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtres & tri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
              const SizedBox(height: 16),
              const Text('Échéance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (int i = 0; i < 3; i++)
                    ChoiceChip(
                      selected: _deadlineFilter == i,
                      onSelected: (_) => setSt(() => _deadlineFilter = i),
                      label: Text(['Toutes', '< 7 jours', '< 30 jours'][i]),
                      selectedColor: ThixPolicy.tint,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Trier par', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (int i = 0; i < 3; i++)
                    ChoiceChip(
                      selected: _sortMode == i,
                      onSelected: (_) => setSt(() => _sortMode = i),
                      label: Text(['Échéance', 'Récentes', 'A → Z'][i]),
                      selectedColor: ThixPolicy.tint,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _withReward,
                onChanged: (v) => setSt(() => _withReward = v),
                title: const Text('Avec récompense / financement', style: TextStyle(fontSize: 13.5)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primaryDeep, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════ ÉTATS ═══════════════
  Widget _skeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (int i = 0; i < 4; i++) ...[
            Container(
              height: 120,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 46, height: 46, color: const Color(0xFFEEF2F7)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 12, color: const Color(0xFFEEF2F7)),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 120, color: const Color(0xFFEEF2F7)),
                  ])),
                ]),
                const Spacer(),
                Container(height: 10, width: 160, color: const Color(0xFFEEF2F7)),
              ]),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.work_outline_rounded, size: 44, color: Colors.grey),
            const SizedBox(height: 14),
            const Text('Aucune opportunité active', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ThixPolicy.inkDeep)),
            const SizedBox(height: 6),
            const Text('De nouvelles bourses, emplois et subventions arrivent bientôt.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThixPolicy.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _noResult() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 34, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('Aucun résultat', style: TextStyle(fontWeight: FontWeight.w700, color: ThixPolicy.inkDeep)),
            TextButton(onPressed: () { _searchCtrl.clear(); setState(() { _catIndex = 0; _savedOnly = false; _deadlineFilter = 0; _withReward = false; }); }, child: const Text('Réinitialiser')),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 36, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('Connexion interrompue', style: TextStyle(fontWeight: FontWeight.w700, color: ThixPolicy.inkDeep)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => setState(() => _future = _service.listOpportunities()), child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _Cat {
  final String label;
  final IconData icon;
  const _Cat(this.label, this.icon);
}

// ============================================================================
// COMPAT : widgets exportés utilisés ailleurs (même signature, nouveau style)
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
  void initState() { super.initState(); _tick(); _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick()); }
  void _tick() { final d = widget.targetDate.difference(DateTime.now()); if (mounted) setState(() => _left = d.isNegative ? Duration.zero : d); }
  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_left == Duration.zero) {
      return _pill('Clôturé', Colors.grey);
    }
    final s = '${_left.inDays}j ${(_left.inHours % 24).toString().padLeft(2, '0')}:${(_left.inMinutes % 60).toString().padLeft(2, '0')}:${(_left.inSeconds % 60).toString().padLeft(2, '0')}';
    return _pill(s, _left.inDays <= 3 ? ThixPolicy.danger : const Color(0xFFD97706));
  }

  Widget _pill(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ThixInputGuard.text(o.title, maxLength: 60), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: ThixPolicy.inkDeep)),
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
