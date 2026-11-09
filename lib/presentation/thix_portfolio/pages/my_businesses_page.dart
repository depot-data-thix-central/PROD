// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE « MES SITES »
//  Fichier  : lib/presentation/thix_portfolio/pages/my_businesses_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.2 — Novembre 2026 (CORRIGÉ CI v2)
// ════════════════════════════════════════════════════════════════════════════
//
//  Corrections CI v2 :
//    • import 'dart:ui' pour ImageFilter
//    • Remplacement de .animate() et .ms par animations natives
//    • Toutes les animations sont 100 % natives Flutter
// ════════════════════════════════════════════════════════════════════════════

import 'dart:ui'; // ✅ FIX CI v2 : pour ImageFilter

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../data/business_repository.dart';
import '../models/business_bundle.dart';

// ============================================================================
// ROUTES
// ============================================================================

const String _kRouteCreate = '/business/create';
String _kPublicRoute(String id) => '/b/$id';
String _kStudioRoute(String id) => '/business/edit/$id';

// ============================================================================
// PALETTE PRISM
// ============================================================================

class _Prism {
  _Prism._();
  static const Color bg = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE6E9F2);
  static const Color ink = Color(0xFF0B1220);
  static const Color inkSoft = Color(0xFF3E4C63);
  static const Color inkMuted = Color(0xFF8A94A6);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ThixPolicy.primary, Color(0xFF4338CA), Color(0xFF7C3AED)],
  );

  static List<BoxShadow> soft([double a = 0.05, double b = 14, double y = 6]) =>
      [
        BoxShadow(
          color: Colors.black.withValues(alpha: a),
          blurRadius: b,
          offset: Offset(0, y),
        ),
      ];
}

// ============================================================================
// LOGGING
// ============================================================================

class _MineLogger {
  static const _tag = 'BizMine';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// SANITIZER
// ============================================================================

class _Sanitizer {
  _Sanitizer._();
  static String text(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }
}

// ============================================================================
// FILTRES / TRI
// ============================================================================

enum _Filter { all, published, draft, suspended }
enum _Sort { newest, oldest, alpha }

// ============================================================================
// PAGE RACINE
// ============================================================================

class MyBusinessesPage extends ConsumerStatefulWidget {
  const MyBusinessesPage({super.key});
  @override
  ConsumerState<MyBusinessesPage> createState() => _MyBusinessesPageState();
}

class _MyBusinessesPageState extends ConsumerState<MyBusinessesPage> {
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.newest;

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    ref.invalidate(myBusinessesProvider);
    await ref.read(myBusinessesProvider.future);
  }

  List<Business> _apply(List<Business> list) {
    final filtered = list.where((b) {
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.published:
          return b.status == BusinessStatus.published;
        case _Filter.draft:
          return b.status == BusinessStatus.draft;
        case _Filter.suspended:
          return b.status == BusinessStatus.suspended;
      }
    }).toList();

    switch (_sort) {
      case _Sort.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.oldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _Sort.alpha:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return filtered;
  }

  void _onCreate() {
    HapticFeedback.mediumImpact();
    context.push(_kRouteCreate);
  }

  void _onOpen(Business b) {
    HapticFeedback.selectionClick();
    context.push(_kPublicRoute(b.thixId));
  }

  void _onStudio(Business b) {
    HapticFeedback.selectionClick();
    context.push(_kStudioRoute(b.id));
  }

  void _onQr(BuildContext ctx, Business b) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _Prism.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(_Sanitizer.text(b.name, maxLength: 40),
            style: const TextStyle(
                fontWeight: FontWeight.w900, color: _Prism.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _Prism.border),
              ),
              child: QrImageView(
                data: b.thixId,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(b.thixId,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: ThixPolicy.primary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx).t('common_close'),
                style: const TextStyle(color: _Prism.inkSoft)),
          ),
        ],
      ),
    );
  }

  void _onShare(Business b) {
    final url = 'https://thixid.com/b/${b.thixId}';
    final name = _Sanitizer.text(b.name, maxLength: 40);
    Share.share(
      'Découvrez $name sur THIX Portfolio 🚀\n$url\nID : ${b.thixId}',
      subject: 'Site THIX — $name',
    );
    HapticFeedback.lightImpact();
  }

  Future<void> _onTogglePublish(BuildContext ctx, Business b) async {
    final l10n = AppLocalizations.of(ctx);
    final repo = ref.read(businessRepositoryProvider);

    if (b.isPublished) {
      try {
        await repo.unpublish(b.id);
        _MineLogger.info('Unpublished', {'id': b.id});
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        ref.invalidate(myBusinessesProvider);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(l10n.t('biz_mine_unpublished',
              args: [_Sanitizer.text(b.name, maxLength: 40)])),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
        ));
      } catch (e) {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(l10n.t('biz_mine_error_generic',
              args: [_Sanitizer.text('$e', maxLength: 100)])),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    final issues = <String>[];
    if (b.name.trim().isEmpty) issues.add(l10n.t('biz_mine_check_name'));
    if ((b.description ?? '').trim().isEmpty) {
      issues.add(l10n.t('biz_mine_check_description'));
    }
    if (b.logoUrl == null || b.logoUrl!.isEmpty) {
      issues.add(l10n.t('biz_mine_check_logo'));
    }
    if (b.coverUrl == null || b.coverUrl!.isEmpty) {
      issues.add(l10n.t('biz_mine_check_cover'));
    }

    if (issues.isNotEmpty) {
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      await showDialog<void>(
        context: ctx,
        builder: (_) => AlertDialog(
          backgroundColor: _Prism.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(l10n.t('biz_mine_checklist_title'),
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: _Prism.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.t('biz_mine_checklist_hint'),
                  style: const TextStyle(color: _Prism.inkSoft)),
              const SizedBox(height: 12),
              for (final i in issues)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_box_outline_blank,
                          color: ThixPolicy.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(i,
                              style: const TextStyle(color: _Prism.ink))),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.t('common_close')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _onStudio(b);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(l10n.t('biz_mine_open_studio')),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await repo.publish(b.id);
      _MineLogger.info('Published', {'id': b.id, 'thix': b.thixId});
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ref.invalidate(myBusinessesProvider);
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(l10n.t('biz_mine_published',
            args: [_Sanitizer.text(b.name, maxLength: 40)])),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(l10n.t('biz_mine_error_generic',
            args: [_Sanitizer.text('$e', maxLength: 100)])),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _onDelete(BuildContext ctx, Business b) async {
    final l10n = AppLocalizations.of(ctx);
    final name = _Sanitizer.text(b.name, maxLength: 40);
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _Prism.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.warning_amber_rounded,
            color: ThixPolicy.danger, size: 36),
        title: Text(l10n.t('biz_mine_delete_title'),
            style: const TextStyle(fontWeight: FontWeight.w900, color: _Prism.ink)),
        content: Text(l10n.t('biz_mine_delete_confirm', args: [name]),
            style: const TextStyle(color: _Prism.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.t('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(l10n.t('common_delete')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await ref.read(businessRepositoryProvider).updateBusiness(
          businessId: b.id,
          business: b.copyWith(status: BusinessStatus.deleted));
      _MineLogger.info('Deleted (soft)', {'id': b.id});
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref.invalidate(myBusinessesProvider);
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(l10n.t('biz_mine_deleted', args: [name])),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(l10n.t('biz_mine_error_generic',
            args: [_Sanitizer.text('$e', maxLength: 100)])),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final listAsync = ref.watch(myBusinessesProvider);

    return Scaffold(
      backgroundColor: _Prism.bg,
      body: Stack(
        children: [
          Positioned(
              top: -100,
              right: -60,
              child: _halo(240, ThixPolicy.primary.withValues(alpha: 0.12))),
          Positioned(
              bottom: -80,
              left: -80,
              child: _halo(260, const Color(0xFF7C3AED).withValues(alpha: 0.09))),

          SafeArea(
            bottom: false,
            child: listAsync.when(
              loading: () => const _LoadingView(),
              error: (e, _) => _ErrorView(
                message: l10n.t('biz_mine_error_generic',
                    args: [_Sanitizer.text('$e', maxLength: 120)]),
                onRetry: _refresh,
              ),
              data: (list) {
                final filtered = _apply(list);
                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: ThixPolicy.primary,
                  backgroundColor: _Prism.surface,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(child: _Header(
                        onCreate: _onCreate,
                        count: list.length,
                      )),
                      SliverToBoxAdapter(child: _Filters(
                        filter: _filter,
                        sort: _sort,
                        onFilter: (f) => setState(() => _filter = f),
                        onSort: (s) => setState(() => _sort = s),
                      )),
                      if (filtered.isEmpty)
                        SliverToBoxAdapter(
                          child: _EmptyState(
                            hasAny: list.isNotEmpty,
                            onCreate: _onCreate,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                // ✅ FIX CI v2 : animation NATIVE (pas de .animate())
                                child: _StaggeredFadeIn(
                                  delay: Duration(milliseconds: i * 60),
                                  child: _BusinessCard(
                                    business: filtered[i],
                                    onOpen: () => _onOpen(filtered[i]),
                                    onStudio: () => _onStudio(filtered[i]),
                                    onQr: () => _onQr(context, filtered[i]),
                                    onShare: () => _onShare(filtered[i]),
                                    onTogglePublish: () =>
                                        _onTogglePublish(context, filtered[i]),
                                    onDelete: () =>
                                        _onDelete(context, filtered[i]),
                                  ),
                                ),
                              ),
                              childCount: filtered.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: listAsync.whenOrNull(
        data: (list) => list.isEmpty
            ? null
            : _CreateFab(onTap: _onCreate),
      ) ?? const SizedBox.shrink(),
    );
  }

  Widget _halo(double s, Color c) {
    return RepaintBoundary(
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          children: [
            Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
            BackdropFilter(
              // ✅ FIX CI v2 : ImageFilter nécessite import 'dart:ui'
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Animation native staggered fade-in + slide
// ============================================================================

class _StaggeredFadeIn extends StatefulWidget {
  const _StaggeredFadeIn({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted && !_started) {
        _started = true;
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// LOADING VIEW
// ============================================================================

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        const SizedBox(height: 8),
        Container(
            height: 32,
            width: 220,
            decoration: BoxDecoration(
                color: _Prism.border, borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 8),
        Container(
            height: 14,
            width: 160,
            decoration: BoxDecoration(
                color: _Prism.border, borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 24),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: _Prism.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _Prism.border),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 40, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 16),
            Text(l10n.t('biz_mine_error_title'),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _Prism.ink)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _Prism.inkSoft)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.t('common_retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================

class _Header extends StatelessWidget {
  const _Header({required this.onCreate, required this.count});
  final VoidCallback onCreate;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l10n.t('biz_mine_title'),
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: _Prism.ink,
                            letterSpacing: -0.4)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: ThixPolicy.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(l10n.t('biz_mine_subtitle'),
                    style: const TextStyle(
                        fontSize: 13,
                        color: _Prism.inkSoft,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (count == 0)
            _CreateFab.small(onTap: onCreate),
        ],
      ),
    );
  }
}

// ============================================================================
// FILTRES + TRI
// ============================================================================

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.sort,
    required this.onFilter,
    required this.onSort,
  });
  final _Filter filter;
  final _Sort sort;
  final ValueChanged<_Filter> onFilter;
  final ValueChanged<_Sort> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = [
      (_Filter.all, l10n.t('biz_mine_filter_all')),
      (_Filter.published, l10n.t('biz_mine_filter_published')),
      (_Filter.draft, l10n.t('biz_mine_filter_draft')),
      (_Filter.suspended, l10n.t('biz_mine_filter_suspended')),
    ];
    final sorts = [
      (_Sort.newest, l10n.t('biz_mine_sort_newest')),
      (_Sort.oldest, l10n.t('biz_mine_sort_oldest')),
      (_Sort.alpha, l10n.t('biz_mine_sort_alpha')),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (f, label) = filters[i];
                final selected = filter == f;
                return Semantics(
                  button: true,
                  selected: selected,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onFilter(f);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? ThixPolicy.primary : _Prism.surface,
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(
                            color: selected
                                ? ThixPolicy.primary
                                : _Prism.border),
                        boxShadow:
                            selected ? null : _Prism.soft(0.03, 6, 2),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  selected ? Colors.white : _Prism.ink)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.sort_rounded,
                  size: 15, color: _Prism.inkMuted),
              const SizedBox(width: 6),
              Text(l10n.t('biz_mine_sort_by'),
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _Prism.inkMuted,
                      letterSpacing: 0.4)),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sorts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final (s, label) = sorts[i];
                      final selected = sort == s;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSort(s);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? _Prism.ink.withValues(alpha: 0.06)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? _Prism.ink
                                      : _Prism.inkMuted)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ============================================================================
// ÉTAT VIDE
// ============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny, required this.onCreate});
  final bool hasAny;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _Prism.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _Prism.border),
          boxShadow: _Prism.soft(0.04, 14, 6),
        ),
        child: Column(
          children: [
            // ✅ FIX CI v2 : animation NATIVE (pas de .animate())
            _PulseWrapper(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: _Prism.brand,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: ThixPolicy.primary.withValues(alpha: 0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.storefront_rounded,
                    size: 44, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
                hasAny
                    ? l10n.t('biz_mine_empty_filter_title')
                    : l10n.t('biz_mine_empty_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _Prism.ink,
                    letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(
                hasAny
                    ? l10n.t('biz_mine_empty_filter_hint')
                    : l10n.t('biz_mine_empty_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    color: _Prism.inkSoft,
                    fontWeight: FontWeight.w500,
                    height: 1.5)),
            const SizedBox(height: 22),
            if (!hasAny)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_business_rounded, size: 18),
                  label: Text(l10n.t('biz_mine_create_first'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pulse animation native
class _PulseWrapper extends StatefulWidget {
  const _PulseWrapper({required this.child});
  final Widget child;

  @override
  State<_PulseWrapper> createState() => _PulseWrapperState();
}

class _PulseWrapperState extends State<_PulseWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.08);
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// CARTE BUSINESS
// ============================================================================

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.business,
    required this.onOpen,
    required this.onStudio,
    required this.onQr,
    required this.onShare,
    required this.onTogglePublish,
    required this.onDelete,
  });

  final Business business;
  final VoidCallback onOpen;
  final VoidCallback onStudio;
  final VoidCallback onQr;
  final VoidCallback onShare;
  final VoidCallback onTogglePublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _Sanitizer.text(business.name, maxLength: 40);
    final sector = _Sanitizer.text(business.sector, maxLength: 30);
    final city = _Sanitizer.text(business.city, maxLength: 30);
    final fmt = DateFormat.yMMMd('fr_FR');

    return Container(
      decoration: BoxDecoration(
        color: _Prism.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Prism.border),
        boxShadow: _Prism.soft(0.05, 16, 6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(
                  height: 88,
                  width: double.infinity,
                  child: (business.coverUrl != null &&
                          business.coverUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: business.coverUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _GradientFallback(),
                        )
                      : _GradientFallback(),
                ),
              ),
              Positioned(
                left: 14,
                top: 48,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _Prism.surface,
                    boxShadow: _Prism.soft(0.10, 10, 4),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: _Prism.border,
                    backgroundImage: (business.logoUrl != null &&
                            business.logoUrl!.isNotEmpty)
                        ? NetworkImage(business.logoUrl!)
                        : null,
                    child: (business.logoUrl == null ||
                            business.logoUrl!.isEmpty)
                        ? Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: _Prism.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 20),
                          )
                        : null,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: _StatusChip(status: business.status),
              ),
              if (business.verified)
                Positioned(
                  right: 12,
                  top: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            size: 11, color: Colors.white),
                        SizedBox(width: 4),
                        Text('VERIFIED',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 48, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: _Prism.ink,
                              letterSpacing: -0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                          [sector, city]
                              .where((s) => s.isNotEmpty)
                              .join(' • '),
                          style: const TextStyle(
                              fontSize: 12,
                              color: _Prism.inkSoft,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _Prism.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _Prism.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded,
                          size: 16, color: ThixPolicy.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(business.thixId,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: _Prism.ink,
                                letterSpacing: 0.3),
                            maxLines: 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: _Prism.inkMuted),
                    const SizedBox(width: 5),
                    Text(
                        '${l10n.t('biz_mine_created_on')} '
                        '${fmt.format(business.createdAt)}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: _Prism.inkMuted,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: l10n.t('biz_mine_action_open'),
                        icon: Icons.open_in_new_rounded,
                        primary: business.isPublished,
                        onTap: onOpen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: l10n.t('biz_mine_action_studio'),
                        icon: Icons.edit_rounded,
                        onTap: onStudio,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconChip(
                        icon: Icons.qr_code_2_rounded, onTap: onQr),
                    const SizedBox(width: 8),
                    _IconChip(
                        icon: Icons.share_rounded, onTap: onShare),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onTogglePublish,
                        icon: Icon(
                          business.isPublished
                              ? Icons.visibility_off_rounded
                              : Icons.publish_rounded,
                          size: 16,
                        ),
                        label: Text(
                            business.isPublished
                                ? l10n.t('biz_mine_action_unpublish')
                                : l10n.t('biz_mine_action_publish'),
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: business.isPublished
                              ? ThixPolicy.danger
                              : ThixPolicy.success,
                          side: BorderSide(
                              color: business.isPublished
                                  ? ThixPolicy.danger
                                  : ThixPolicy.success),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconChip(
                        icon: Icons.delete_outline_rounded,
                        tint: ThixPolicy.danger,
                        onTap: onDelete),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _GradientFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: _Prism.brand),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final BusinessStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case BusinessStatus.published:
        bg = ThixPolicy.success.withValues(alpha: 0.14);
        fg = ThixPolicy.success;
        label = 'Publié';
      case BusinessStatus.draft:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.14);
        fg = const Color(0xFFB45309);
        label = 'Brouillon';
      case BusinessStatus.suspended:
        bg = ThixPolicy.danger.withValues(alpha: 0.14);
        fg = ThixPolicy.danger;
        label = 'Suspendu';
      case BusinessStatus.deleted:
        bg = _Prism.inkMuted.withValues(alpha: 0.14);
        fg = _Prism.inkMuted;
        label = 'Supprimé';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.3)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: primary ? ThixPolicy.primary : _Prism.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary ? ThixPolicy.primary : _Prism.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: primary ? Colors.white : _Prism.ink),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: primary ? Colors.white : _Prism.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.onTap, this.tint});
  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = tint ?? _Prism.ink;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _Prism.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _Prism.border),
          ),
          child: Icon(icon, size: 17, color: c),
        ),
      ),
    );
  }
}

// ============================================================================
// FAB CRÉER
// ============================================================================

class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.onTap});
  final VoidCallback onTap;

  factory _CreateFab.small({required VoidCallback onTap}) =>
      _CreateFab(onTap: onTap);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.t('biz_mine_create_first'),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: _Prism.brand,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: ThixPolicy.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: const Icon(Icons.add_rounded,
              size: 26, color: Colors.white),
        ),
      ),
    );
  }
}
