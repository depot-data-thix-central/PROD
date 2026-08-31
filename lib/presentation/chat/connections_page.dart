// lib/presentation/chat/connections_page.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/services/chat/connection_service.dart';

import 'call/call_page.dart';
import 'call/providers/call_provider.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kPageSize = 20;
const int _kLoadMoreThresholdPx = 300;
const int _kLoadMoreThrottleMs = 500;
const int _kMaxNameLength = 80;
const int _kMaxRoleLength = 60;
const int _kMaxMessageLength = 500;

// ============================================================================
// VALIDATORS
// ============================================================================
class _ConnValidators {
  _ConnValidators._();

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
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _connRetry<T>(
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
        debugPrint('[Connections] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Connections] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Connections] ❌ $label error: $e');
      rethrow;
    }
  }
}

/// Extrait les infos de certification d'une map user
class _CertificationInfo {
  final CertificationTier? tier;
  final CertificationStatus? status;
  final bool isCertified;
  final bool isLegacyVerified;

  const _CertificationInfo({
    required this.tier,
    required this.status,
    required this.isCertified,
    required this.isLegacyVerified,
  });

  factory _CertificationInfo.fromMap(Map<String, dynamic> user) {
    CertificationTier? tier;
    CertificationStatus? status;
    bool isCertified = false;
    final isLegacyVerified = user['is_verified'] == true;

    if (user.containsKey('certification_tier') && user['certification_tier'] != null) {
      tier = CertificationTierX.parse(user['certification_tier']);
      status = CertificationStatusX.parse(user['certification_status']);
      isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
    }

    return _CertificationInfo(
      tier: tier,
      status: status,
      isCertified: isCertified,
      isLegacyVerified: isLegacyVerified,
    );
  }
}

// ============================================================================
// STATE
// ============================================================================
class ConnectionsState {
  final List<ConnectionRequest> received;
  final List<ConnectionRequest> sent;
  final List<dynamic> connections;
  final bool loading;
  final bool loadingMore;
  final bool hasMoreConnections;
  final String? error;
  final Set<String> pendingActions; // IDs en cours d'action (protection double-tap)

  const ConnectionsState({
    this.received = const [],
    this.sent = const [],
    this.connections = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMoreConnections = true,
    this.error,
    this.pendingActions = const {},
  });

  ConnectionsState copyWith({
    List<ConnectionRequest>? received,
    List<ConnectionRequest>? sent,
    List<dynamic>? connections,
    bool? loading,
    bool? loadingMore,
    bool? hasMoreConnections,
    String? error,
    Set<String>? pendingActions,
  }) {
    return ConnectionsState(
      received: received ?? this.received,
      sent: sent ?? this.sent,
      connections: connections ?? this.connections,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMoreConnections: hasMoreConnections ?? this.hasMoreConnections,
      error: error,
      pendingActions: pendingActions ?? this.pendingActions,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================
class ConnectionsNotifier extends StateNotifier<ConnectionsState> {
  final ConnectionService _svc;

  ConnectionsNotifier(this._svc) : super(const ConnectionsState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    debugPrint('[Connections] 🚀 Loading initial data');
    state = state.copyWith(loading: true, error: null);

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      state = state.copyWith(loading: false);
      return;
    }

    try {
      await _connRetry(
        () => _svc.loadData(uid, limit: _kPageSize, offset: 0),
        label: 'loadInitial',
      );
      state = ConnectionsState(
        received: _svc.receivedRequests,
        sent: _svc.sentRequests,
        connections: _svc.connections,
        loading: false,
        hasMoreConnections: _svc.connections.length == _kPageSize,
      );
      debugPrint('[Connections] ✓ Loaded: ${_svc.receivedRequests.length} received, '
          '${_svc.sentRequests.length} sent, ${_svc.connections.length} connections');
    } catch (e) {
      debugPrint('[Connections] ❌ Load initial error: $e');
      state = state.copyWith(loading: false, error: _ConnValidators.friendlyError(e));
    }
  }

  Future<void> loadMoreConnections() async {
    if (state.loadingMore || !state.hasMoreConnections) return;

    state = state.copyWith(loadingMore: true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      state = state.copyWith(loadingMore: false);
      return;
    }

    try {
      final more = await _connRetry(
        () => _svc.loadMoreConnections(uid, offset: state.connections.length, limit: _kPageSize),
        label: 'loadMore',
      );
      state = state.copyWith(
        connections: [...state.connections, ...more],
        hasMoreConnections: more.length == _kPageSize,
        loadingMore: false,
      );
      debugPrint('[Connections] ✓ Loaded ${more.length} more connections');
    } catch (e) {
      debugPrint('[Connections] ❌ Load more error: $e');
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

  Future<bool> accept(String id) async {
    if (_isActionPending(id)) return false;
    _startAction(id);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return false;
      final ok = await _connRetry(() => _svc.acceptRequest(id, uid), label: 'accept[$id]');
      if (ok) await loadInitial();
      return ok;
    } catch (e) {
      debugPrint('[Connections] ❌ Accept error: $e');
      return false;
    } finally {
      _endAction(id);
    }
  }

  Future<bool> reject(String id) async {
    if (_isActionPending(id)) return false;
    _startAction(id);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return false;
      final ok = await _connRetry(() => _svc.rejectRequest(id, uid), label: 'reject[$id]');
      if (ok) await loadInitial();
      return ok;
    } catch (e) {
      debugPrint('[Connections] ❌ Reject error: $e');
      return false;
    } finally {
      _endAction(id);
    }
  }

  Future<bool> cancel(String id) async {
    if (_isActionPending(id)) return false;
    _startAction(id);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return false;
      final ok = await _connRetry(() => _svc.cancelRequest(id, uid), label: 'cancel[$id]');
      if (ok) await loadInitial();
      return ok;
    } catch (e) {
      debugPrint('[Connections] ❌ Cancel error: $e');
      return false;
    } finally {
      _endAction(id);
    }
  }

  Future<bool> removeConnection(String otherUserId) async {
    if (_isActionPending(otherUserId)) return false;
    _startAction(otherUserId);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return false;
      final ok = await _connRetry(
        () => _svc.removeConnection(uid, otherUserId),
        label: 'remove[$otherUserId]',
      );
      if (ok) {
        state = state.copyWith(
          connections: state.connections.where((c) => c['user_id'] != otherUserId).toList(),
        );
        debugPrint('[Connections] ✓ Connection removed: $otherUserId');
      }
      return ok;
    } catch (e) {
      debugPrint('[Connections] ❌ Remove error: $e');
      return false;
    } finally {
      _endAction(otherUserId);
    }
  }

  Future<bool> blockUser(String otherUserId) async {
    if (_isActionPending(otherUserId)) return false;
    _startAction(otherUserId);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return false;
      final ok = await _connRetry(
        () => _svc.blockUser(uid, otherUserId),
        label: 'block[$otherUserId]',
      );
      if (ok) {
        state = state.copyWith(
          connections: state.connections.where((c) => c['user_id'] != otherUserId).toList(),
        );
        debugPrint('[Connections] ✓ User blocked: $otherUserId');
      }
      return ok;
    } catch (e) {
      debugPrint('[Connections] ❌ Block error: $e');
      return false;
    } finally {
      _endAction(otherUserId);
    }
  }

  bool isActionPending(String id) => _isActionPending(id);
}

final connectionsProvider = StateNotifierProvider<ConnectionsNotifier, ConnectionsState>((ref) {
  return ConnectionsNotifier(ConnectionService());
});

// ============================================================================
// PAGE
// ============================================================================
class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  final _scroll = ScrollController();
  DateTime? _lastLoadMore;
  bool _isStartingChat = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[Connections] 📄 Page opened');
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    debugPrint('[Connections] 👋 Page disposed');
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - _kLoadMoreThresholdPx) {
      final now = DateTime.now();
      if (_lastLoadMore != null && now.difference(_lastLoadMore!).inMilliseconds < _kLoadMoreThrottleMs) {
        return;
      }
      _lastLoadMore = now;
      ref.read(connectionsProvider.notifier).loadMoreConnections();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMMUNICATION ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _startChat(Map<String, dynamic> connection) async {
    if (_isStartingChat) {
      debugPrint('[Connections] ⚠️ Chat creation already in progress');
      return;
    }

    final l10n = AppLocalizations.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      _showError(l10n.t('connections_not_authenticated'));
      return;
    }

    final otherUserId = connection['user_id'] as String?;
    if (otherUserId == null) {
      _showError(l10n.t('connections_invalid_user'));
      return;
    }

    setState(() => _isStartingChat = true);
    _showInfo(l10n.t('connections_opening_chat'));

    try {
      final res = await _connRetry(
        () => Supabase.instance.client
            .from('conversations')
            .select('id')
            .contains('participant_ids', [currentUserId, otherUserId])
            .eq('is_group', false)
            .maybeSingle(),
        label: 'findConversation',
      );

      if (!mounted) return;

      if (res != null) {
        final convId = res['id'] as String?;
        if (convId != null) {
          debugPrint('[Connections] ✓ Found conversation: $convId');
          context.push('/chat/$convId');
          return;
        }
      }

      _showError(l10n.t('connections_cannot_start_chat'));
    } catch (e) {
      debugPrint('[Connections] ❌ Start chat error: $e');
      if (mounted) _showError(_ConnValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isStartingChat = false);
    }
  }

  void _startAudioCall(Map<String, dynamic> connection) {
    final l10n = AppLocalizations.of(context);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) {
      _showError(l10n.t('connections_not_authenticated'));
      return;
    }

    final calleeId = connection['user_id'] as String?;
    if (calleeId == null) {
      _showError(l10n.t('connections_invalid_user'));
      return;
    }

    HapticFeedback.mediumImpact();
    debugPrint('[Connections] 📞 Starting audio call to $calleeId');

    ref.read(callProvider.notifier).start(
          myUserId: myId,
          calleeId: calleeId,
          calleeName: _ConnValidators.sanitize(connection['display_name']?.toString(), maxLength: _kMaxNameLength),
          calleeAvatar: _ConnValidators.sanitizeUrl(connection['avatar_url']?.toString()),
          type: CallType.audio,
        );

    Navigator.push(context, MaterialPageRoute(builder: (_) => const CallPage()));
  }

  void _startVideoCall(Map<String, dynamic> connection) {
    final l10n = AppLocalizations.of(context);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) {
      _showError(l10n.t('connections_not_authenticated'));
      return;
    }

    final calleeId = connection['user_id'] as String?;
    if (calleeId == null) {
      _showError(l10n.t('connections_invalid_user'));
      return;
    }

    HapticFeedback.mediumImpact();
    debugPrint('[Connections] 📹 Starting video call to $calleeId');

    ref.read(callProvider.notifier).start(
          myUserId: myId,
          calleeId: calleeId,
          calleeName: _ConnValidators.sanitize(connection['display_name']?.toString(), maxLength: _kMaxNameLength),
          calleeAvatar: _ConnValidators.sanitizeUrl(connection['avatar_url']?.toString()),
          type: CallType.video,
        );

    Navigator.push(context, MaterialPageRoute(builder: (_) => const CallPage()));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONFIRMATION DIALOGS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmCancel(String id) async {
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
          l10n.t('connections_cancel_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          l10n.t('connections_cancel_message'),
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx, false);
            },
            child: Text(
              l10n.t('common_no'),
              style: TextStyle(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600),
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
            child: Text(l10n.t('connections_cancel_confirm'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final svc = ref.read(connectionsProvider.notifier);
    final res = await svc.cancel(id);

    if (mounted) {
      if (res) {
        _showSuccess(l10n.t('connections_cancelled'));
      } else {
        _showError(l10n.t('connections_cancel_error'));
      }
    }
  }

  Future<void> _confirmRemove(Map<String, dynamic> connection) async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.lightImpact();

    final name = _ConnValidators.sanitize(connection['display_name']?.toString(), maxLength: _kMaxNameLength);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.t('connections_remove_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          "${l10n.t('connections_remove_message')} ${name.isEmpty ? '—' : name}",
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.warning,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('connections_remove_confirm'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final userId = connection['user_id'] as String?;
    if (userId == null) return;

    final res = await ref.read(connectionsProvider.notifier).removeConnection(userId);
    if (mounted) {
      if (res) {
        _showSuccess(l10n.t('connections_removed'));
      } else {
        _showError(l10n.t('connections_remove_error'));
      }
    }
  }

  Future<void> _confirmBlock(Map<String, dynamic> connection) async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.lightImpact();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.block, color: ThixPolicy.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.t('connections_block_title'),
                style: ThixPolicy.h3Style.copyWith(
                  color: ThixPolicy.danger,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.t('connections_block_message'),
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('connections_block_confirm'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final userId = connection['user_id'] as String?;
    if (userId == null) return;

    final res = await ref.read(connectionsProvider.notifier).blockUser(userId);
    if (mounted) {
      if (res) {
        _showSuccess(l10n.t('connections_blocked'));
      } else {
        _showError(l10n.t('connections_block_error'));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOTTOM SHEET (ACTIONS MENU)
  // ══════════════════════════════════════════════════════════════════════════

  void _showConnectionActions(Map<String, dynamic> connection) {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ConnectionActionsSheet(
        connection: connection,
        onMessage: () {
          Navigator.pop(ctx);
          _startChat(connection);
        },
        onAudioCall: () {
          Navigator.pop(ctx);
          _startAudioCall(connection);
        },
        onVideoCall: () {
          Navigator.pop(ctx);
          _startVideoCall(connection);
        },
        onViewProfile: () {
          Navigator.pop(ctx);
          // TODO: navigation vers profil
        },
        onRemove: () {
          Navigator.pop(ctx);
          _confirmRemove(connection);
        },
        onBlock: () {
          Navigator.pop(ctx);
          _confirmBlock(connection);
        },
        l10n: l10n,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FEEDBACK HELPERS
  // ══════════════════════════════════════════════════════════════════════════

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

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(connectionsProvider);
    final notifier = ref.read(connectionsProvider.notifier);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain, size: 24),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
        title: Text(
          l10n.t('connections_page_title'),
          style: ThixPolicy.titleStyle.copyWith(
            color: ThixPolicy.textMain,
            fontSize: 20,
            fontWeight: ThixPolicy.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: l10n.t('common_refresh'),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: ThixPolicy.textMain, size: 24),
              onPressed: state.loading ? null : () => notifier.loadInitial(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.loading
          ? Center(child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3))
          : RefreshIndicator(
              color: ThixPolicy.primary,
              backgroundColor: ThixPolicy.card,
              onRefresh: () async => notifier.loadInitial(),
              child: RepaintBoundary(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    // SECTION: DEMANDES REÇUES
                    if (state.received.isNotEmpty) ...[
                      _SectionTitle(title: "${l10n.t('connections_received')} (${state.received.length})"),
                      ...state.received.map((r) => _ReceivedRequestCard(
                            request: r,
                            pendingActions: state.pendingActions,
                            onAccept: () async {
                              final ok = await notifier.accept(r.id);
                              if (mounted) {
                                if (ok) {
                                  _showSuccess(l10n.t('connections_accepted'));
                                } else {
                                  _showError(l10n.t('connections_accept_error'));
                                }
                              }
                            },
                            onReject: () async {
                              final ok = await notifier.reject(r.id);
                              if (mounted) {
                                if (ok) {
                                  _showSuccess(l10n.t('connections_ignored'));
                                } else {
                                  _showError(l10n.t('connections_reject_error'));
                                }
                              }
                            },
                          )),
                      const SizedBox(height: 16),
                    ],

                    // SECTION: DEMANDES ENVOYÉES
                    if (state.sent.isNotEmpty) ...[
                      _SectionTitle(title: "${l10n.t('connections_sent')} (${state.sent.length})"),
                      ...state.sent.map((r) => _SentRequestCard(
                            request: r,
                            onCancel: () => _confirmCancel(r.id),
                          )),
                      const SizedBox(height: 16),
                    ],

                    // SECTION: CONNEXIONS ACTIVES
                    _SectionTitle(title: "${l10n.t('connections_active')} (${state.connections.length})"),
                    if (state.connections.isEmpty)
                      _EmptyState(l10n: l10n)
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: ThixPolicy.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ThixPolicy.border),
                          boxShadow: ThixPolicy.shadowSoft(opacity: 0.02),
                        ),
                        child: Column(
                          children: state.connections.asMap().entries.map((entry) {
                            final i = entry.key;
                            final c = entry.value as Map<String, dynamic>;
                            final isLast = i == state.connections.length - 1;

                            return Column(
                              children: [
                                _ConnectionItem(
                                  connection: c,
                                  onTap: () => _showConnectionActions(c),
                                ),
                                if (!isLast)
                                  Divider(height: 1, color: ThixPolicy.border, indent: 76),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                    if (state.loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3)),
                      ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4),
      child: Text(
        title,
        style: ThixPolicy.titleStyle.copyWith(
          color: ThixPolicy.textMain,
          fontWeight: ThixPolicy.bold,
          fontSize: 16,
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

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, shape: BoxShape.circle),
            child: Icon(Icons.people_outline_rounded, size: 40, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('connections_empty_title'),
            style: ThixPolicy.titleStyle.copyWith(
              color: ThixPolicy.textMain,
              fontSize: 16,
              fontWeight: ThixPolicy.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('connections_empty_message'),
            textAlign: TextAlign.center,
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RECEIVED REQUEST CARD
// ============================================================================
class _ReceivedRequestCard extends StatelessWidget {
  final ConnectionRequest request;
  final Set<String> pendingActions;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ReceivedRequestCard({
    required this.request,
    required this.pendingActions,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sender = request.sender ?? {};
    final certInfo = _CertificationInfo.fromMap(sender);

    final name = _ConnValidators.sanitize(sender['display_name']?.toString(), maxLength: _kMaxNameLength);
    final message = _ConnValidators.sanitize(
      request.message ?? l10n.t('connections_wants_connect'),
      maxLength: _kMaxMessageLength,
    );
    final avatarUrl = _ConnValidators.sanitizeUrl(sender['avatar_url']?.toString());
    final isPending = pendingActions.contains(request.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.02),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ThixPolicy.tint,
                  borderRadius: BorderRadius.circular(14),
                  image: avatarUrl != null
                      ? DecorationImage(image: CachedNetworkImageProvider(avatarUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: avatarUrl == null
                    ? Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: ThixPolicy.labelStyle.copyWith(
                            color: ThixPolicy.primary,
                            fontWeight: ThixPolicy.bold,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name.isEmpty ? l10n.t('connections_unknown_user') : name,
                            style: ThixPolicy.labelStyle.copyWith(
                              color: ThixPolicy.textMain,
                              fontWeight: ThixPolicy.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (certInfo.isCertified)
                          CertificationNameBadge(
                            tier: certInfo.tier,
                            status: certInfo.status,
                            showLabel: false,
                            iconSize: 15,
                            padding: const EdgeInsets.only(left: 4),
                          )
                        else if (certInfo.isLegacyVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 15),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.isEmpty ? '—' : message,
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: l10n.t('connections_ignore'),
                  enabled: !isPending,
                  child: OutlinedButton(
                    onPressed: isPending ? null : () {
                      HapticFeedback.lightImpact();
                      onReject();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ThixPolicy.textMuted,
                      side: BorderSide(color: ThixPolicy.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(l10n.t('connections_ignore'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  label: l10n.t('connections_accept'),
                  enabled: !isPending,
                  child: ElevatedButton(
                    onPressed: isPending ? null : () {
                      HapticFeedback.mediumImpact();
                      onAccept();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isPending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.t('connections_accept'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SENT REQUEST CARD
// ============================================================================
class _SentRequestCard extends StatelessWidget {
  final ConnectionRequest request;
  final VoidCallback onCancel;

  const _SentRequestCard({required this.request, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final receiver = request.receiver ?? {};
    final certInfo = _CertificationInfo.fromMap(receiver);

    final name = _ConnValidators.sanitize(receiver['display_name']?.toString(), maxLength: _kMaxNameLength);
    final avatarUrl = _ConnValidators.sanitizeUrl(receiver['avatar_url']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            image: avatarUrl != null
                ? DecorationImage(image: CachedNetworkImageProvider(avatarUrl), fit: BoxFit.cover)
                : null,
          ),
          child: avatarUrl == null
              ? Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: ThixPolicy.labelStyle.copyWith(
                      color: ThixPolicy.textMuted,
                      fontWeight: ThixPolicy.bold,
                      fontSize: 16,
                    ),
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name.isEmpty ? l10n.t('connections_unknown_user') : name,
                style: ThixPolicy.labelStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (certInfo.isCertified)
              CertificationNameBadge(
                tier: certInfo.tier,
                status: certInfo.status,
                showLabel: false,
                iconSize: 15,
                padding: const EdgeInsets.only(left: 4),
              )
            else if (certInfo.isLegacyVerified)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 15),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.access_time_rounded, size: 14, color: ThixPolicy.warning),
            const SizedBox(width: 4),
            Text(
              l10n.t('connections_pending'),
              style: ThixPolicy.captionStyle.copyWith(
                color: ThixPolicy.warning,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Semantics(
          button: true,
          label: l10n.t('connections_cancel_request'),
          child: TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onCancel();
            },
            style: TextButton.styleFrom(foregroundColor: ThixPolicy.textMuted),
            child: Text(l10n.t('connections_cancel_request'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONNECTION ITEM
// ============================================================================
class _ConnectionItem extends StatelessWidget {
  final Map<String, dynamic> connection;
  final VoidCallback onTap;

  const _ConnectionItem({required this.connection, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final certInfo = _CertificationInfo.fromMap(connection);

    final name = _ConnValidators.sanitize(connection['display_name']?.toString(), maxLength: _kMaxNameLength);
    final role = _ConnValidators.sanitize(connection['role']?.toString(), maxLength: _kMaxRoleLength);
    final avatarUrl = _ConnValidators.sanitizeUrl(connection['avatar_url']?.toString());

    return Semantics(
      button: true,
      label: '$name. ${role.isEmpty ? l10n.t('connections_network') : role}',
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ThixPolicy.tint,
            borderRadius: BorderRadius.circular(12),
            image: avatarUrl != null
                ? DecorationImage(image: CachedNetworkImageProvider(avatarUrl), fit: BoxFit.cover)
                : null,
          ),
          child: avatarUrl == null
              ? Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: ThixPolicy.labelStyle.copyWith(
                      color: ThixPolicy.primary,
                      fontWeight: ThixPolicy.bold,
                      fontSize: 16,
                    ),
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name.isEmpty ? l10n.t('connections_unknown_user') : name,
                style: ThixPolicy.labelStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (certInfo.isCertified)
              CertificationNameBadge(
                tier: certInfo.tier,
                status: certInfo.status,
                showLabel: false,
                iconSize: 15,
                padding: const EdgeInsets.only(left: 4),
              )
            else if (certInfo.isLegacyVerified)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 15),
              ),
          ],
        ),
        subtitle: Text(
          role.isEmpty ? l10n.t('connections_network') : role,
          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 13),
        ),
        trailing: Semantics(
          button: true,
          label: l10n.t('connections_actions'),
          child: IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: ThixPolicy.textMuted),
            onPressed: () {
              HapticFeedback.selectionClick();
              onTap();
            },
          ),
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }
}

// ============================================================================
// CONNECTION ACTIONS SHEET
// ============================================================================
class _ConnectionActionsSheet extends StatelessWidget {
  final Map<String, dynamic> connection;
  final VoidCallback onMessage;
  final VoidCallback onAudioCall;
  final VoidCallback onVideoCall;
  final VoidCallback onViewProfile;
  final VoidCallback onRemove;
  final VoidCallback onBlock;
  final AppLocalizations l10n;

  const _ConnectionActionsSheet({
    required this.connection,
    required this.onMessage,
    required this.onAudioCall,
    required this.onVideoCall,
    required this.onViewProfile,
    required this.onRemove,
    required this.onBlock,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final certInfo = _CertificationInfo.fromMap(connection);

    final name = _ConnValidators.sanitize(connection['display_name']?.toString(), maxLength: _kMaxNameLength);
    final role = _ConnValidators.sanitize(connection['role']?.toString(), maxLength: _kMaxRoleLength);
    final avatarUrl = _ConnValidators.sanitizeUrl(connection['avatar_url']?.toString());

    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4)),
            ),

            // Header du Profil
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: ThixPolicy.tint,
                    backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Icon(Icons.person, color: ThixPolicy.primary, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name.isEmpty ? l10n.t('connections_unknown_user') : name,
                                style: ThixPolicy.titleStyle.copyWith(
                                  fontSize: 18,
                                  fontWeight: ThixPolicy.bold,
                                  color: ThixPolicy.textMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (certInfo.isCertified)
                              CertificationNameBadge(
                                tier: certInfo.tier,
                                status: certInfo.status,
                                showLabel: false,
                                iconSize: 18,
                                padding: const EdgeInsets.only(left: 6),
                              )
                            else if (certInfo.isLegacyVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          role.isEmpty ? l10n.t('connections_network_member') : role,
                          style: ThixPolicy.bodySmallStyle.copyWith(
                            fontSize: 14,
                            color: ThixPolicy.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Barre d'actions rapides (Chat / Call)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.chat_bubble_rounded,
                      label: l10n.t('connections_message'),
                      color: ThixPolicy.primary,
                      onTap: onMessage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.call_rounded,
                      label: l10n.t('connections_audio'),
                      color: ThixPolicy.success,
                      onTap: onAudioCall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.videocam_rounded,
                      label: l10n.t('connections_video'),
                      color: ThixPolicy.warning,
                      onTap: onVideoCall,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: ThixPolicy.border),
            ),

            // Actions de gestion
            _ActionListTile(
              icon: Icons.person_outline_rounded,
              title: l10n.t('connections_view_profile'),
              onTap: onViewProfile,
            ),
            _ActionListTile(
              icon: Icons.person_remove_rounded,
              title: l10n.t('connections_remove_from_network'),
              color: ThixPolicy.warning,
              onTap: onRemove,
            ),
            _ActionListTile(
              icon: Icons.block_rounded,
              title: l10n.t('connections_block_user'),
              color: ThixPolicy.danger,
              onTap: onBlock,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// QUICK ACTION BUTTON
// ============================================================================
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ACTION LIST TILE
// ============================================================================
class _ActionListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _ActionListTile({required this.icon, required this.title, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? ThixPolicy.textMain;

    return Semantics(
      button: true,
      label: title,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      ),
    );
  }
}
