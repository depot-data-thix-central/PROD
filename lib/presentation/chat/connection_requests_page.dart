// lib/presentation/chat/connection_requests_page.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/chat/connection_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kPageSize = 20;
const int _kLoadMoreThresholdPx = 200;
const int _kLoadMoreThrottleMs = 500;
const int _kMaxNameLength = 80;
const int _kMaxMessageLength = 200;

// ============================================================================
// VALIDATORS
// ============================================================================
class _ReqValidators {
  _ReqValidators._();

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

  /// Retourne l'initiale sûre pour avatar fallback (jamais crash sur string vide)
  static String safeInitial(String? name) {
    final s = sanitize(name, maxLength: 10);
    if (s.isEmpty) return '?';
    return s[0].toUpperCase();
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _reqRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kRequestTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Requests] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Requests] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Requests] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// STATE
// ============================================================================
class ConnectionRequestsState {
  final List<ConnectionRequest> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;
  final Set<String> pendingActions; // IDs en cours d'action

  const ConnectionRequestsState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
    this.pendingActions = const {},
  });

  ConnectionRequestsState copyWith({
    List<ConnectionRequest>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    Set<String>? pendingActions,
  }) {
    return ConnectionRequestsState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      pendingActions: pendingActions ?? this.pendingActions,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================
class ConnectionRequestsNotifier extends StateNotifier<ConnectionRequestsState> {
  final ConnectionService _svc;

  ConnectionRequestsNotifier(this._svc) : super(const ConnectionRequestsState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    debugPrint('[Requests] 🚀 Loading initial data');
    state = state.copyWith(loading: true, error: null);

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      state = state.copyWith(loading: false);
      return;
    }

    try {
      final reqs = await _reqRetry(
        () => _svc.getPendingRequests(uid, limit: _kPageSize, offset: 0),
        label: 'loadInitial',
      );
      state = ConnectionRequestsState(
        items: reqs,
        loading: false,
        hasMore: reqs.length == _kPageSize,
      );
      debugPrint('[Requests] ✓ Loaded ${reqs.length} requests');
    } catch (e) {
      debugPrint('[Requests] ❌ Load initial error: $e');
      state = state.copyWith(loading: false, error: _ReqValidators.friendlyError(e));
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;

    state = state.copyWith(loadingMore: true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      state = state.copyWith(loadingMore: false);
      return;
    }

    try {
      final reqs = await _reqRetry(
        () => _svc.getPendingRequests(uid, limit: _kPageSize, offset: state.items.length),
        label: 'loadMore',
      );
      state = state.copyWith(
        items: [...state.items, ...reqs],
        hasMore: reqs.length == _kPageSize,
        loadingMore: false,
      );
      debugPrint('[Requests] ✓ Loaded ${reqs.length} more requests');
    } catch (e) {
      debugPrint('[Requests] ❌ Load more error: $e');
      state = state.copyWith(loadingMore: false);
    }
  }

  bool _isActionPending(String id) => state.pendingActions.contains(id);
  void _startAction(String id) {
    state = state.copyWith(pendingActions: {...state.pendingActions, id});
  }
  void _endAction(String id) {
    final s = Set<String>.from(state.pendingActions)..remove(id);
    state = state.copyWith(pendingActions: s);
  }

  /// Accepte une demande — retourne (success, errorMessage)
  Future<(bool, String?)> accept(String id) async {
    if (_isActionPending(id)) return (false, 'already_pending');
    _startAction(id);
    try {
      await _reqRetry(() => _svc.acceptRequest(id), label: 'accept[$id]');
      await loadInitial();
      debugPrint('[Requests] ✓ Accepted: $id');
      return (true, null);
    } catch (e) {
      debugPrint('[Requests] ❌ Accept error: $e');
      return (false, _ReqValidators.friendlyError(e));
    } finally {
      _endAction(id);
    }
  }

  /// Rejette une demande — retourne (success, errorMessage)
  Future<(bool, String?)> reject(String id) async {
    if (_isActionPending(id)) return (false, 'already_pending');
    _startAction(id);
    try {
      await _reqRetry(() => _svc.rejectRequest(id), label: 'reject[$id]');
      await loadInitial();
      debugPrint('[Requests] ✓ Rejected: $id');
      return (true, null);
    } catch (e) {
      debugPrint('[Requests] ❌ Reject error: $e');
      return (false, _ReqValidators.friendlyError(e));
    } finally {
      _endAction(id);
    }
  }

  bool isActionPending(String id) => _isActionPending(id);
}

final connectionRequestsProvider =
    StateNotifierProvider<ConnectionRequestsNotifier, ConnectionRequestsState>((ref) {
  return ConnectionRequestsNotifier(ConnectionService());
});

// ============================================================================
// PAGE
// ============================================================================
class ConnectionRequestsPage extends ConsumerStatefulWidget {
  const ConnectionRequestsPage({super.key});

  @override
  ConsumerState<ConnectionRequestsPage> createState() => _ConnectionRequestsPageState();
}

class _ConnectionRequestsPageState extends ConsumerState<ConnectionRequestsPage> {
  final _scroll = ScrollController();
  DateTime? _lastLoadMore;

  @override
  void initState() {
    super.initState();
    debugPrint('[Requests] 📄 Page opened');
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    debugPrint('[Requests] 👋 Page disposed');
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - _kLoadMoreThresholdPx) {
      final now = DateTime.now();
      if (_lastLoadMore != null && now.difference(_lastLoadMore!).inMilliseconds < _kLoadMoreThrottleMs) {
        return;
      }
      _lastLoadMore = now;
      ref.read(connectionRequestsProvider.notifier).loadMore();
    }
  }

  Future<void> _confirmReject(String id) async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.lightImpact();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ThixPolicy.border),
        ),
        title: Text(
          l10n.t('requests_reject_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          l10n.t('requests_reject_message'),
          style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx, false);
            },
            child: Text(
              l10n.t('common_cancel'),
              style: TextStyle(color: ThixPolicy.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx, true);
            },
            child: Text(
              l10n.t('requests_reject_confirm'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final (success, error) = await ref.read(connectionRequestsProvider.notifier).reject(id);
    if (mounted) {
      if (success) {
        _showSuccess(l10n.t('requests_rejected'));
      } else {
        _showError(error ?? l10n.t('requests_reject_error'));
      }
    }
  }

  Future<void> _accept(String id) async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    final (success, error) = await ref.read(connectionRequestsProvider.notifier).accept(id);
    if (mounted) {
      if (success) {
        _showSuccess(l10n.t('requests_accepted'));
      } else {
        _showError(error ?? l10n.t('requests_accept_error'));
      }
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(connectionRequestsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
        title: Text(
          l10n.t('requests_page_title'),
          style: ThixPolicy.titleStyle.copyWith(
            color: ThixPolicy.textMain,
            fontSize: 16,
            fontWeight: ThixPolicy.bold,
          ),
        ),
      ),
      body: state.loading
          ? Center(child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 2))
          : state.items.isEmpty
              ? _EmptyState(l10n: l10n, hasError: state.error != null, errorMessage: state.error)
              : RefreshIndicator(
                  color: ThixPolicy.primary,
                  backgroundColor: ThixPolicy.card,
                  onRefresh: () async {
                    HapticFeedback.selectionClick();
                    await ref.read(connectionRequestsProvider.notifier).loadInitial();
                  },
                  child: RepaintBoundary(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.items.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == state.items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 2),
                            ),
                          );
                        }

                        final req = state.items[i];
                        final isPending = state.pendingActions.contains(req.id);

                        return _RequestItem(
                          request: req,
                          isPending: isPending,
                          onAccept: () => _accept(req.id),
                          onReject: () => _confirmReject(req.id),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final bool hasError;
  final String? errorMessage;

  const _EmptyState({required this.l10n, this.hasError = false, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (hasError ? ThixPolicy.danger : ThixPolicy.primary).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasError ? Icons.error_outline_rounded : Icons.people_outline_rounded,
                color: hasError ? ThixPolicy.danger : ThixPolicy.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasError ? l10n.t('requests_error_title') : l10n.t('requests_empty_title'),
              style: ThixPolicy.titleStyle.copyWith(
                color: ThixPolicy.textMain,
                fontWeight: ThixPolicy.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasError ? (errorMessage ?? l10n.t('requests_error_generic')) : l10n.t('requests_empty_message'),
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REQUEST ITEM
// ============================================================================
class _RequestItem extends StatelessWidget {
  final ConnectionRequest request;
  final bool isPending;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestItem({
    required this.request,
    required this.isPending,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sender = request.sender ?? {};

    final name = _ReqValidators.sanitize(
      (sender['display_name'] ?? sender['username'])?.toString(),
      maxLength: _kMaxNameLength,
    );
    final message = _ReqValidators.sanitize(
      request.message ?? l10n.t('requests_wants_contact'),
      maxLength: _kMaxMessageLength,
    );
    final avatarUrl = _ReqValidators.sanitizeUrl(sender['avatar_url']?.toString());
    final initial = _ReqValidators.safeInitial(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: ThixPolicy.tint,
            backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    initial,
                    style: ThixPolicy.labelStyle.copyWith(
                      color: ThixPolicy.primary,
                      fontWeight: ThixPolicy.bold,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Name + message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? l10n.t('requests_unknown_user') : name,
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.textMain,
                    fontWeight: ThixPolicy.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  message.isEmpty ? '—' : message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Accept button
          Semantics(
            button: true,
            label: l10n.t('requests_accept_button'),
            enabled: !isPending,
            child: IconButton(
              icon: isPending
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: ThixPolicy.success,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.check_rounded, color: ThixPolicy.success, size: 20),
              onPressed: isPending ? null : onAccept,
              tooltip: l10n.t('requests_accept_button'),
            ),
          ),

          // Reject button
          Semantics(
            button: true,
            label: l10n.t('requests_reject_button'),
            enabled: !isPending,
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: ThixPolicy.textMuted, size: 20),
              onPressed: isPending ? null : onReject,
              tooltip: l10n.t('requests_reject_button'),
            ),
          ),
        ],
      ),
    );
  }
}
