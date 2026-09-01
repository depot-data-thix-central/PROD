// lib/presentation/chat/new_conversation_page.dart
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
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/connection_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kSearchLimit = 25;
const int _kSearchDebounceMs = 300;
const int _kLoadMoreThresholdPx = 300;
const int _kMaxNameLength = 80;
const int _kMaxProfessionLength = 100;
const int _kMaxHandleLength = 50;
const int _kMaxGroupNameLength = 60;
const int _kMaxMessageLength = 500;

// ============================================================================
// VALIDATORS
// ============================================================================
class _ConvValidators {
  _ConvValidators._();

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
Future<T> _convRetry<T>(
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
        debugPrint('[NewConv] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[NewConv] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[NewConv] ❌ $label error: $e');
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

  factory _CertificationInfo.fromUser(Map<String, dynamic> user) {
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
class NewConvState {
  final List<Map<String, dynamic>> results;
  final List<Map<String, dynamic>> selected;
  final Map<String, String> connStatus;
  final bool isLoading;
  final bool isCreating;
  final bool hasMore;
  final String query;
  final String groupName;

  const NewConvState({
    this.results = const [],
    this.selected = const [],
    this.connStatus = const {},
    this.isLoading = false,
    this.isCreating = false,
    this.hasMore = true,
    this.query = '',
    this.groupName = '',
  });

  NewConvState copyWith({
    List<Map<String, dynamic>>? results,
    List<Map<String, dynamic>>? selected,
    Map<String, String>? connStatus,
    bool? isLoading,
    bool? isCreating,
    bool? hasMore,
    String? query,
    String? groupName,
  }) {
    return NewConvState(
      results: results ?? this.results,
      selected: selected ?? this.selected,
      connStatus: connStatus ?? this.connStatus,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      hasMore: hasMore ?? this.hasMore,
      query: query ?? this.query,
      groupName: groupName ?? this.groupName,
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================
class NewConvNotifier extends StateNotifier<NewConvState> {
  final SupabaseClient supabase;
  final ConnectionService connSvc;
  int _offset = 0;
  Timer? _debounce;

  NewConvNotifier(this.supabase, this.connSvc) : super(const NewConvState());

  void setGroupName(String v) {
    final sanitized = _ConvValidators.sanitize(v, maxLength: _kMaxGroupNameLength);
    state = state.copyWith(groupName: sanitized);
  }

  void search(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _kSearchDebounceMs), () {
      _doSearch(raw.trim(), reset: true);
    });
  }

  Future<void> _doSearch(String q, {bool reset = false}) async {
    if (q.isEmpty) {
      state = state.copyWith(results: [], query: '', hasMore: true, isLoading: false);
      return;
    }

    if (reset) {
      _offset = 0;
      state = state.copyWith(query: q, isLoading: true, hasMore: true);
    }

    try {
      // Champs sanitisés via select
      const selectFields =
          'id, display_name, avatar_url, profession, thix_chat, certification_tier, certification_status, is_verified';

      final exact = await _convRetry(
        () => supabase
            .from('profiles')
            .select(selectFields)
            .ilike('thix_chat', '%$q%')
            .range(_offset, _offset + 4),
        label: 'searchExact',
      );

      final names = await _convRetry(
        () => supabase
            .from('profiles')
            .select(selectFields)
            .ilike('display_name', '%$q%')
            .range(_offset, _offset + _kSearchLimit - 1),
        label: 'searchNames',
      );

      final seen = <String>{...state.selected.map((e) => e['id'] as String)};
      final merged = <Map<String, dynamic>>[];

      for (var r in [...exact, ...names]) {
        final id = r['id'] as String?;
        if (id != null && !seen.contains(id)) {
          seen.add(id);
          merged.add(Map<String, dynamic>.from(r));
        }
      }

      await _loadStatus(merged);

      final finalList = reset ? merged : [...state.results, ...merged];
      final deduped = <String, Map<String, dynamic>>{};
      for (var e in finalList) {
        final id = e['id'] as String?;
        if (id != null) deduped[id] = e;
      }

      state = state.copyWith(
        results: deduped.values.where((e) => !state.selected.any((s) => s['id'] == e['id'])).toList(),
        isLoading: false,
        hasMore: merged.length == _kSearchLimit,
      );
      _offset += _kSearchLimit;
      debugPrint('[NewConv] ✓ Search returned ${merged.length} results');
    } catch (e) {
      debugPrint('[NewConv] ❌ Search error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.query.isEmpty) return;
    state = state.copyWith(isLoading: true);
    await _doSearch(state.query, reset: false);
  }

  Future<void> _loadStatus(List<Map<String, dynamic>> users) async {
    final cur = supabase.auth.currentUser?.id;
    if (cur == null) return;
    final map = Map<String, String>.from(state.connStatus);
    for (var u in users) {
      final id = u['id'] as String?;
      if (id == null || id == cur || map.containsKey(id)) continue;
      try {
        map[id] = await _convRetry(
          () async => (await connSvc.getStatusBetween(cur, id)).name,

          label: 'getStatus[$id]',
        );
      } catch (e) {
        debugPrint('[NewConv] ⚠️ Status load failed for $id: $e');
      }
    }
    state = state.copyWith(connStatus: map);
  }

  void toggleSelect(Map<String, dynamic> user) {
    final exists = state.selected.any((s) => s['id'] == user['id']);
    List<Map<String, dynamic>> sel;
    List<Map<String, dynamic>> res = List.from(state.results);
    if (exists) {
      sel = state.selected.where((s) => s['id'] != user['id']).toList();
      res = [...res, user];
    } else {
      sel = [...state.selected, user];
      res = res.where((r) => r['id'] != user['id']).toList();
    }
    state = state.copyWith(selected: sel, results: res);
  }

  void addSelectedForSingle(Map<String, dynamic> user) {
    if (state.selected.isEmpty) {
      state = state.copyWith(
        selected: [user],
        results: state.results.where((r) => r['id'] != user['id']).toList(),
      );
    }
  }

  void setCreating(bool v) => state = state.copyWith(isCreating: v);

  void updateStatus(String userId, String status) {
    final m = Map<String, String>.from(state.connStatus)..[userId] = status;
    state = state.copyWith(connStatus: m);
  }

  void clearQuery() {
    state = state.copyWith(query: '', results: [], hasMore: true, isLoading: false);
    _offset = 0;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final newConvProvider = StateNotifierProvider<NewConvNotifier, NewConvState>((ref) {
  return NewConvNotifier(Supabase.instance.client, ConnectionService());
});

// ============================================================================
// PAGE
// ============================================================================
class NewConversationPage extends ConsumerStatefulWidget {
  const NewConversationPage({super.key});

  @override
  ConsumerState<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends ConsumerState<NewConversationPage> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  late ChatService _chatService;
  DateTime? _lastLoadMore;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(Supabase.instance.client);
    debugPrint('[NewConv] 🚀 Page opened');
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    debugPrint('[NewConv] 👋 Page disposed');
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - _kLoadMoreThresholdPx) {
      // Throttle loadMore à max 1x/500ms
      final now = DateTime.now();
      if (_lastLoadMore != null && now.difference(_lastLoadMore!).inMilliseconds < 500) return;
      _lastLoadMore = now;
      ref.read(newConvProvider.notifier).loadMore();
    }
  }

  (String, Color) _statusDisplay(String? s, AppLocalizations l10n) {
    switch (s) {
      case 'connected':
        return (l10n.t('conv_status_connected'), ThixPolicy.success);
      case 'pending':
        return (l10n.t('conv_status_pending'), ThixPolicy.warning);
      case 'rejected':
        return (l10n.t('conv_status_rejected'), ThixPolicy.danger);
      default:
        return ('', Colors.transparent);
    }
  }

  void _onUserTap(Map<String, dynamic> user) {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();

    final state = ref.read(newConvProvider);
    final curId = Supabase.instance.client.auth.currentUser?.id;
    if (user['id'] == curId) {
      _showInfo(l10n.t('conv_cannot_self'));
      return;
    }

    final status = state.connStatus[user['id'] as String] ?? 'none';

    if (status == 'connected') {
      if (state.selected.isEmpty) {
        ref.read(newConvProvider.notifier).addSelectedForSingle(user);
        _startChat();
      } else {
        ref.read(newConvProvider.notifier).toggleSelect(user);
      }
    } else if (status == 'pending') {
      _showInfo(l10n.t('conv_request_pending'), color: ThixPolicy.warning);
    } else if (status == 'rejected') {
      _showInfo(l10n.t('conv_request_rejected'), color: ThixPolicy.danger);
    } else {
      _showRequestDialog(user);
    }
  }

  void _showRequestDialog(Map<String, dynamic> user) {
    final l10n = AppLocalizations.of(context);
    final msgCtrl = TextEditingController();
    final safeName = _ConvValidators.sanitize(user['display_name']?.toString(), maxLength: _kMaxNameLength);
    final safeAvatar = _ConvValidators.sanitizeUrl(user['avatar_url']?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ThixPolicy.border),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: ThixPolicy.surfaceSoft,
              backgroundImage: safeAvatar != null ? CachedNetworkImageProvider(safeAvatar) : null,
              child: safeAvatar == null ? const Icon(Icons.person, color: ThixPolicy.textMuted) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${l10n.t('conv_request_to')} ${safeName.isEmpty ? '—' : safeName}',
                style: ThixPolicy.h3Style.copyWith(
                  color: ThixPolicy.textMain,
                  fontSize: 16,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('conv_request_hint'),
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: msgCtrl,
              maxLength: _kMaxMessageLength,
              maxLines: 3,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontSize: 14),
              decoration: InputDecoration(
                counterText: '',
                hintText: l10n.t('conv_message_optional'),
                hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 14),
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ThixPolicy.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ThixPolicy.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
            },
            child: Text(
              l10n.t('common_cancel'),
              style: TextStyle(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.t('conv_send_request'),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                Navigator.pop(ctx);
                if (!mounted) return;
                await _sendRequest(user, msgCtrl.text.trim());
              },
              child: Text(
                l10n.t('conv_send_request'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRequest(Map<String, dynamic> user, String msg) async {
    final l10n = AppLocalizations.of(context);
    final cur = Supabase.instance.client.auth.currentUser?.id;
    if (cur == null) return;

    final userId = user['id'] as String;
    final sanitizedMsg = _ConvValidators.sanitize(msg, maxLength: _kMaxMessageLength);

    debugPrint('[NewConv] 📨 Sending request to $userId');

    final svc = ConnectionService();
    try {
      final ok = await _convRetry(
        () => svc.sendRequest(
          senderId: cur,
          receiverId: userId,
          message: sanitizedMsg.isNotEmpty ? sanitizedMsg : null,
        ),
        label: 'sendConnectionRequest',
      );

      if (!mounted) return;

      if (ok) {
        ref.read(newConvProvider.notifier).updateStatus(userId, 'pending');
        _showSuccess(l10n.t('conv_request_sent'));
        debugPrint('[NewConv] ✓ Request sent');
      } else {
        _showError(svc.error ?? l10n.t('conv_request_exists'));
      }
    } catch (e) {
      debugPrint('[NewConv] ❌ Send request error: $e');
      if (mounted) _showError(_ConvValidators.friendlyError(e));
    }
  }

  Future<void> _startChat() async {
    final l10n = AppLocalizations.of(context);
    final state = ref.read(newConvProvider);

    if (state.isCreating) {
      debugPrint('[NewConv] ⚠️ Chat creation already in progress');
      return;
    }

    if (state.selected.isEmpty) {
      _showInfo(l10n.t('conv_select_contact'));
      return;
    }

    final cur = Supabase.instance.client.auth.currentUser?.id;
    if (cur == null) return;

    final notConnected = state.selected.where((u) {
      final s = state.connStatus[u['id'] as String] ?? 'none';
      return s != 'connected';
    }).toList();

    if (notConnected.isNotEmpty) {
      final names = notConnected
          .map((u) => _ConvValidators.sanitize(u['display_name']?.toString(), maxLength: _kMaxNameLength))
          .join(', ');
      _showInfo('${l10n.t('conv_waiting_connection')}: $names', color: ThixPolicy.warning);
      return;
    }

    ref.read(newConvProvider.notifier).setCreating(true);
    HapticFeedback.mediumImpact();
    debugPrint('[NewConv] 💬 Creating conversation with ${state.selected.length} users');

    try {
      if (state.selected.length == 1) {
        final otherId = state.selected.first['id'] as String;
        final conv = await _convRetry(
          () => _chatService.createDirectConversation(otherId),
          label: 'createDM',
        );
        if (!mounted) return;
        context.pushReplacement(AppRoutes.chatDetail(conv.id), extra: conv);
        debugPrint('[NewConv] ✓ DM created: ${conv.id}');
        return;
      }

      throw Exception(l10n.t('conv_group_rpc_required'));
    } catch (e) {
      debugPrint('[NewConv] ❌ Create chat error: $e');
      if (mounted) {
        _showError(_ConvValidators.friendlyError(e));
      }
    } finally {
      if (mounted) ref.read(newConvProvider.notifier).setCreating(false);
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

  void _showInfo(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: color ?? ThixPolicy.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(newConvProvider);
    final notifier = ref.read(newConvProvider.notifier);

    return Scaffold(
      backgroundColor: ThixPolicy.card,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain, size: 24),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            splashRadius: 24,
          ),
        ),
        title: Text(
          l10n.t('conv_page_title'),
          style: ThixPolicy.titleStyle.copyWith(
            color: ThixPolicy.textMain,
            fontSize: 18,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        actions: [
          if (state.selected.isNotEmpty)
            state.isCreating
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: '${l10n.t('conv_start')} (${state.selected.length})',
                        child: InkWell(
                          onTap: _startChat,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: ThixPolicy.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  '${l10n.t('conv_start')} (${state.selected.length})',
                                  style: ThixPolicy.captionStyle.copyWith(
                                    color: Colors.white,
                                    fontWeight: ThixPolicy.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
        ],
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Semantics(
                label: l10n.t('conv_search_label'),
                textField: true,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => notifier.search(v),
                  textInputAction: TextInputAction.search,
                  style: ThixPolicy.bodyStyle.copyWith(
                    color: ThixPolicy.textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.t('conv_search_hint'),
                    hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 15),
                    prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.textMuted, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? Semantics(
                            button: true,
                            label: l10n.t('common_clear'),
                            child: IconButton(
                              icon: const Icon(Icons.clear_rounded, color: ThixPolicy.textMuted, size: 18),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _searchCtrl.clear();
                                notifier.clearQuery();
                              },
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // Group name field (si plusieurs sélectionnés)
          if (state.selected.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: Semantics(
                  label: l10n.t('conv_group_name_label'),
                  textField: true,
                  child: TextField(
                    maxLength: _kMaxGroupNameLength,
                    onChanged: (v) => notifier.setGroupName(v),
                    style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontSize: 15),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: l10n.t('conv_group_name_hint'),
                      hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 15),
                      prefixIcon: const Icon(Icons.groups_rounded, color: ThixPolicy.textMuted, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),

          // Selected users (horizontal)
          if (state.selected.isNotEmpty)
            SizedBox(
              height: 60,
              child: RepaintBoundary(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: state.selected.length,
                  itemBuilder: (ctx, i) {
                    final u = state.selected[i];
                    final certInfo = _CertificationInfo.fromUser(u);
                    final safeName = _ConvValidators.sanitize(
                      u['display_name']?.toString(),
                      maxLength: _kMaxNameLength,
                    );
                    final safeAvatar = _ConvValidators.sanitizeUrl(u['avatar_url']?.toString());

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.only(left: 6, right: 10),
                        decoration: BoxDecoration(
                          color: ThixPolicy.tint,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: safeAvatar != null
                                  ? CachedNetworkImageProvider(safeAvatar)
                                  : null,
                              backgroundColor: ThixPolicy.primary,
                              child: safeAvatar == null
                                  ? const Icon(Icons.person, size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              safeName.isEmpty ? '—' : safeName,
                              style: ThixPolicy.captionStyle.copyWith(
                                color: ThixPolicy.primary,
                                fontSize: 13,
                                fontWeight: ThixPolicy.bold,
                              ),
                            ),
                            if (certInfo.isCertified)
                              CertificationNameBadge(
                                tier: certInfo.tier,
                                status: certInfo.status,
                                showLabel: false,
                                iconSize: 12,
                                padding: const EdgeInsets.only(left: 4),
                              )
                            else if (certInfo.isLegacyVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 12),
                              ),
                            const SizedBox(width: 6),
                            Semantics(
                              button: true,
                              label: '${l10n.t('common_remove')} $safeName',
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  notifier.toggleSelect(u);
                                },
                                child: const Icon(Icons.close_rounded, size: 16, color: ThixPolicy.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Results
          Expanded(
            child: state.isLoading && state.results.isEmpty
                ? Center(
                    child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3),
                  )
                : state.results.isEmpty
                    ? _EmptyState(searchText: _searchCtrl.text, l10n: l10n)
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: state.results.length + (state.hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          if (i == state.results.length) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3),
                              ),
                            );
                          }

                          final user = state.results[i];
                          final id = user['id'] as String;
                          final isSel = state.selected.any((s) => s['id'] == id);
                          final (label, color) = _statusDisplay(state.connStatus[id], l10n);
                          final certInfo = _CertificationInfo.fromUser(user);

                          return _UserResultTile(
                            user: user,
                            certInfo: certInfo,
                            isSel: isSel,
                            statusLabel: label,
                            statusColor: color,
                            onTap: () => _onUserTap(user),
                            onRequestConnection: () => _showRequestDialog(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// USER RESULT TILE
// ============================================================================
class _UserResultTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final _CertificationInfo certInfo;
  final bool isSel;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback onRequestConnection;

  const _UserResultTile({
    required this.user,
    required this.certInfo,
    required this.isSel,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
    required this.onRequestConnection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeName = _ConvValidators.sanitize(user['display_name']?.toString(), maxLength: _kMaxNameLength);
    final safeProfession = _ConvValidators.sanitize(user['profession']?.toString(), maxLength: _kMaxProfessionLength);
    final safeHandle = _ConvValidators.sanitize(user['thix_chat']?.toString(), maxLength: _kMaxHandleLength);
    final safeAvatar = _ConvValidators.sanitizeUrl(user['avatar_url']?.toString());

    return Semantics(
      button: true,
      selected: isSel,
      label: '$safeName. ${statusLabel.isEmpty ? l10n.t('conv_no_connection') : statusLabel}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSel ? ThixPolicy.primary : ThixPolicy.border,
              width: isSel ? 1.5 : 1,
            ),
            boxShadow: isSel ? [BoxShadow(color: ThixPolicy.primary.withOpacity(0.1), blurRadius: 8)] : [],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: ThixPolicy.surfaceSoft,
                backgroundImage: safeAvatar != null ? CachedNetworkImageProvider(safeAvatar) : null,
                child: safeAvatar == null
                    ? const Icon(Icons.person_rounded, color: ThixPolicy.textMuted, size: 24)
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
                            safeName.isEmpty ? l10n.t('conv_user_default') : safeName,
                            style: ThixPolicy.labelStyle.copyWith(
                              color: ThixPolicy.textMain,
                              fontWeight: ThixPolicy.bold,
                              fontSize: 16,
                            ),
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
                        const SizedBox(width: 8),
                        if (statusLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: statusColor.withOpacity(0.2)),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (safeProfession.isNotEmpty)
                      Text(
                        safeProfession,
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (safeHandle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          safeHandle,
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.primary,
                            fontSize: 12,
                            fontWeight: ThixPolicy.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildTrailingIcon(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingIcon(AppLocalizations l10n) {
    if (statusLabel == l10n.t('conv_status_connected')) {
      return isSel
          ? const Icon(Icons.check_circle_rounded, color: ThixPolicy.primary, size: 28)
          : Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.border),
              ),
              child: const Icon(Icons.add_rounded, color: ThixPolicy.textMain, size: 20),
            );
    } else if (statusLabel == l10n.t('conv_status_pending')) {
      return const Icon(Icons.hourglass_top_rounded, color: ThixPolicy.warning, size: 24);
    } else if (statusLabel == l10n.t('conv_status_rejected')) {
      return const Icon(Icons.block_rounded, color: ThixPolicy.danger, size: 24);
    } else {
      return Semantics(
        button: true,
        label: l10n.t('conv_add_contact'),
        child: IconButton(
          icon: const Icon(Icons.person_add_alt_1_rounded, color: ThixPolicy.primary, size: 24),
          onPressed: onRequestConnection,
          splashRadius: 24,
        ),
      );
    }
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  final String searchText;
  final AppLocalizations l10n;

  const _EmptyState({required this.searchText, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              shape: BoxShape.circle,
              border: Border.all(color: ThixPolicy.border),
            ),
            child: const Icon(Icons.people_outline_rounded, color: ThixPolicy.textMuted, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            searchText.isEmpty ? l10n.t('conv_search_prompt') : l10n.t('conv_no_results'),
            style: ThixPolicy.titleStyle.copyWith(
              color: ThixPolicy.textMain,
              fontSize: 16,
              fontWeight: ThixPolicy.bold,
            ),
          ),
          if (searchText.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.t('conv_start_typing'),
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
