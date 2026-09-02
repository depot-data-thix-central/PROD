/// ThixMediaAdminPage (Production Enterprise)
/// ✅ ThixPolicy + i18n 8 langues + Semantics + logs structurés
/// ✅ CachedNetworkImage + RepaintBoundary + throttling + mounted checks
/// ✅ Sanitization + HapticFeedback + error handling robuste
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';

import 'media_form_sheet.dart';
import '../providers/admin_media_provider.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kScrollThrottle = Duration(milliseconds: 300);
const double _kScrollThreshold = 300.0;
const int _kMaxSearchLength = 100;
const int _kGridCrossAxisCount = 2;
const double _kGridChildAspectRatio = 0.68;

// ============================================================================
// LOGGING
// ============================================================================

class _AdminLogger {
  static const _tag = 'AdminMedia';
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

class _AdminSanitizer {
  static String searchText(String? input) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > _kMaxSearchLength
        ? s.substring(0, _kMaxSearchLength)
        : s;
  }

  static String errorMessage(Object error) {
    final msg = error.toString();
    return msg.length > 200 ? '${msg.substring(0, 200)}...' : msg;
  }
}

// ============================================================================
// ADMIN PAGE
// ============================================================================

class ThixMediaAdminPage extends ConsumerStatefulWidget {
  const ThixMediaAdminPage({super.key});

  @override
  ConsumerState<ThixMediaAdminPage> createState() =>
      _ThixMediaAdminPageState();
}

class _ThixMediaAdminPageState extends ConsumerState<ThixMediaAdminPage> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  DateTime? _lastScroll;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _AdminLogger.info('Admin page initialized');
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _AdminLogger.info('Admin page disposed');
    super.dispose();
  }

  void _onScroll() {
    final now = DateTime.now();
    if (_lastScroll != null &&
        now.difference(_lastScroll!) < _kScrollThrottle) {
      return;
    }
    _lastScroll = now;

    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - _kScrollThreshold) {
      ref.read(adminMediaProvider.notifier).loadMore();
      _AdminLogger.info('Load more triggered', {
        'position': _scrollCtrl.position.pixels.toStringAsFixed(0),
        'maxExtent': _scrollCtrl.position.maxScrollExtent.toStringAsFixed(0),
      });
    }
  }

  void _openForm({MediaContent? item}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MediaFormSheet(
        existing: item,
        onSaved: () {
          if (mounted) {
            ref.read(adminMediaProvider.notifier).refreshList();
            _AdminLogger.info('Media saved, refreshing');
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(MediaContent item) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

    HapticFeedback.heavyImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        title: Text(
          // ✅ FIX : forcer type Map explicite pour dart2js
          l10n.t('admin_confirm_delete_title',
              args: <String, String>{'title': item.title}),
          style: TextStyle(color: ThixPolicy.textMain),
        ),
        content: Text(
          l10n.t('admin_confirm_delete_message'),
          style: TextStyle(color: ThixPolicy.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.t('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.t('admin_delete'),
              style: const TextStyle(color: ThixPolicy.danger),
            ),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      await ref.read(adminMediaProvider.notifier).delete(item);
      _AdminLogger.info('Media deleted', {'id': item.id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncAll = ref.watch(adminMediaProvider);
    final filtered = ref.watch(filteredAdminProvider);
    final all = asyncAll.valueOrNull ?? [];
    final filter = ref.watch(adminFilterProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.primary,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 18),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.play_circle_fill_rounded,
                  size: 16, color: ThixPolicy.warning),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.t('admin_title'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              button: true,
              label: l10n.t('admin_add_media'),
              child: ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: Text(
                  l10n.t('admin_add'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.warning,
                  foregroundColor: ThixPolicy.inkDeep,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: asyncAll.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ThixPolicy.primary),
        ),
        error: (e, st) => _buildErrorState(context, l10n, e),
        data: (_) => RefreshIndicator(
          onRefresh: () {
            HapticFeedback.mediumImpact();
            return ref.read(adminMediaProvider.notifier).refreshList();
          },
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _stats(all, l10n)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _search(l10n)),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(child: _filters(filter, l10n)),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: filtered.isEmpty
                    ? _buildEmptyState(context, l10n, filter)
                    : _buildGrid(filtered),
              ),
              SliverToBoxAdapter(
                child: Consumer(
                  builder: (c, ref, _) {
                    final hasMore =
                        ref.read(adminMediaProvider.notifier).hasMore;
                    return hasMore
                        ? const _LoadingIndicator()
                        : const SizedBox(height: 40);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    Object error,
  ) {
    final errorMessage = _AdminSanitizer.errorMessage(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          header: true,
          label: l10n.t('admin_load_error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: ThixPolicy.danger,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('admin_load_error'),
                style: ThixPolicy.h3Style.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: ThixPolicy.captionStyle.copyWith(
                  color: ThixPolicy.textMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: l10n.t('common_retry'),
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(adminMediaProvider.notifier).refreshList();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.t('common_retry')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    String filter,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Semantics(
            header: true,
            // ✅ FIX : forcer type Map explicite pour dart2js
            label: l10n.t('admin_empty_filter',
                args: <String, String>{'filter': filter}),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: ThixPolicy.textMuted.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  // ✅ FIX : forcer type Map explicite pour dart2js
                  l10n.t('admin_empty_filter',
                      args: <String, String>{'filter': filter}),
                  style: ThixPolicy.bodyStyle.copyWith(
                    color: ThixPolicy.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<MediaContent> filtered) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (c, i) {
          final item = filtered[i];
          return RepaintBoundary(
            child: _card(item),
          );
        },
        childCount: filtered.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kGridCrossAxisCount,
        childAspectRatio: _kGridChildAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
    );
  }

  Widget _search(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        textField: true,
        label: l10n.t('admin_search'),
        child: TextField(
          controller: _searchCtrl,
          maxLength: _kMaxSearchLength,
          onChanged: (v) {
            final sanitized = _AdminSanitizer.searchText(v);
            ref.read(adminSearchProvider.notifier).state = sanitized;
          },
          decoration: InputDecoration(
            counterText: '',
            hintText: l10n.t('admin_search_hint'),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            filled: true,
            fillColor: ThixPolicy.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ThixPolicy.border),
            ),
          ),
          style: TextStyle(color: ThixPolicy.textMain),
        ),
      ),
    );
  }

  Widget _stats(List<MediaContent> all, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: [
          BoxShadow(
            color: ThixPolicy.inkDeep.withValues(alpha: 0.04),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('${all.length}', l10n.t('admin_stat_total')),
          _stat(
            '${all.where((e) => e.isPublished).length}',
            l10n.t('admin_stat_published'),
          ),
          _stat(
            '${all.where((e) => e.isNewRelease).length}',
            l10n.t('admin_stat_new'),
          ),
          _stat(
            '${(all.fold<int>(0, (s, e) => s + e.viewCount) / 1000).toStringAsFixed(1)}k',
            l10n.t('admin_stat_views'),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: ThixPolicy.textMain,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: ThixPolicy.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _filters(String current, AppLocalizations l10n) {
    final filters = [
      l10n.t('admin_filter_all'),
      l10n.t('admin_filter_published'),
      l10n.t('admin_filter_drafts'),
      l10n.t('admin_filter_films'),
      l10n.t('admin_filter_series'),
      l10n.t('admin_filter_videos'),
      l10n.t('admin_filter_music'),
    ];

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: filters
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  button: true,
                  selected: current == f,
                  label: f,
                  child: ChoiceChip(
                    label: Text(
                      f,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: current == f,
                    selectedColor: ThixPolicy.primary,
                    backgroundColor: ThixPolicy.card,
                    side: BorderSide(color: ThixPolicy.border),
                    labelStyle: TextStyle(
                      color: current == f ? Colors.white : ThixPolicy.textMain,
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      ref.read(adminFilterProvider.notifier).state = f;
                      _AdminLogger.info('Filter changed', {'filter': f});
                    },
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _card(MediaContent item) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: [
          BoxShadow(
            color: ThixPolicy.inkDeep.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: CachedNetworkImage(
                  imageUrl: item.coverUrl,
                  height: 110,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 110,
                    color: ThixPolicy.surfaceSoft,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 110,
                    color: ThixPolicy.surfaceSoft,
                    child: Icon(
                      Icons.image_rounded,
                      color: ThixPolicy.textMuted,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.isPublished
                        ? ThixPolicy.success
                        : ThixPolicy.warning,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.isPublished
                        ? l10n.t('admin_status_published')
                        : l10n.t('admin_status_draft'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (item.rankPosition != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#${item.rankPosition}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: ThixPolicy.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.type} • ${item.year ?? ''} • ${item.viewCount} ${l10n.t("admin_views")}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: ThixPolicy.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Semantics(
                        button: true,
                        label: l10n.t('admin_edit'),
                        child: InkWell(
                          onTap: () => _openForm(item: item),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ThixPolicy.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: ThixPolicy.primary,
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: l10n.t('admin_delete'),
                        child: InkWell(
                          onTap: () => _confirmDelete(item),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ThixPolicy.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_rounded,
                              size: 16,
                              color: ThixPolicy.danger,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LOADING INDICATOR
// ============================================================================

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ThixPolicy.primary,
          ),
        ),
      ),
    );
  }
}
