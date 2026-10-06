// lib/presentation/chat/call/call_history_page.dart
//
// ============================================================================
// CALL HISTORY PAGE — Production Enterprise v2.0
// ============================================================================
//
// Historique des appels avec design moderne, états de chargement granulaires
// et expérience utilisateur fluide (inspirée des standards iOS/Android).
//
// Améliorations clés :
//   - État de chargement scoped (un seul bouton affiche un spinner à la fois)
//   - UI modernisée avec hiérarchie visuelle claire et icônes de statut colorées
//   - Optimisation des rebuilds via des widgets Stateless dédiés
//   - Gestion élégante des états vides et des erreurs
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/chat/providers/chat_providers.dart'
    show supabaseClientProvider, supabaseUserIdProvider;
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/call/call_page.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxHistoryItems = 100;
const int _kMaxSearchLength = 100;
const Duration _kSearchDebounce = Duration(milliseconds: 300);
const Duration _kCallStartTimeout = Duration(seconds: 10);

// ============================================================================
// VALIDATORS
// ============================================================================
class _CallHistoryValidators {
  _CallHistoryValidators._();

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  static String sanitizeName(String? input, {int maxLength = 100}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String safeInitial(String? name) {
    final sanitized = sanitizeName(name);
    if (sanitized.isEmpty) return '?';
    return sanitized[0].toUpperCase();
  }
}

// ============================================================================
// DATA MODEL
// ============================================================================

class _CallRow {
  final CallInvite invite;
  final String peerId;
  final String peerName;
  final String? peerAvatar;

  _CallRow({
    required this.invite,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });
}

// ============================================================================
// CALL HISTORY PAGE
// ============================================================================

class CallHistoryPage extends ConsumerStatefulWidget {
  const CallHistoryPage({super.key});

  @override
  ConsumerState<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends ConsumerState<CallHistoryPage> {
  final _searchCtrl = TextEditingController();
  late Future<List<_CallRow>> _future;
  String _query = '';
  
  // 🚀 AMÉLIORATION : Chargement granulaire par peerId au lieu d'un flag global
  String? _callingPeerId;

  @override
  void initState() {
    super.initState();
    debugPrint('[CallHistory] 🚀 Page opened');
    _future = _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    debugPrint('[CallHistory] 👋 Page disposed');
    super.dispose();
  }

  SupabaseClient get _db => ref.read(supabaseClientProvider);
  String get _myId => ref.read(supabaseUserIdProvider) ?? '';

  bool _isCalling(String peerId) => _callingPeerId == peerId;

  // ── FEEDBACK HELPERS ─────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── LOAD DATA ────────────────────────────────────────────────────────

  Future<List<_CallRow>> _load() async {
    final uid = _myId;
    if (uid.isEmpty || !_CallHistoryValidators.isValidUuid(uid)) {
      debugPrint('[CallHistory] ⚠️ No valid user ID');
      return [];
    }

    try {
      final rows = await _db
          .from('call_invites')
          .select()
          .or('caller_id.eq.$uid,callee_id.eq.$uid')
          .order('created_at', ascending: false)
          .limit(_kMaxHistoryItems);

      final invites = (rows as List)
          .map((r) => CallInvite.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();

      final peerIds = <String>{};
      for (final inv in invites) {
        final peer = inv.callerId == uid ? inv.calleeId : inv.callerId;
        if (_CallHistoryValidators.isValidUuid(peer)) {
          peerIds.add(peer);
        }
      }

      final nameById = <String, String>{};
      final avatarById = <String, String?>{};

      if (peerIds.isNotEmpty) {
        final profiles = await _db
            .from('profiles')
            .select('id, display_name, full_name, avatar_url')
            .inFilter('id', peerIds.toList());

        for (final p in (profiles as List)) {
          final m = Map<String, dynamic>.from(p as Map);
          final id = '${m['id'] ?? ''}';
          final name = _CallHistoryValidators.sanitizeName(
            '${m['display_name'] ?? m['full_name'] ?? ''}',
          );
          nameById[id] = name.isNotEmpty ? name : 'Contact';
          avatarById[id] = m['avatar_url']?.toString();
        }
      }

      final result = invites.map((inv) {
        final peerId = inv.callerId == uid ? inv.calleeId : inv.callerId;
        final nameFromInvite = inv.callerId == uid
            ? (inv.calleeName ?? '')
            : (inv.callerName ?? '');
        final sanitizedName = _CallHistoryValidators.sanitizeName(nameFromInvite);
        final name = sanitizedName.isNotEmpty
            ? sanitizedName
            : (nameById[peerId] ?? 'Contact');
        final avatar = inv.callerId == uid ? inv.calleeAvatar : inv.callerAvatar;

        return _CallRow(
          invite: inv,
          peerId: peerId,
          peerName: name,
          peerAvatar: avatar ?? avatarById[peerId],
        );
      }).toList();

      return result;
    } catch (e) {
      debugPrint('[CallHistory] ❌ Load failed: $e');
      rethrow; // Laisser le FutureBuilder gérer l'erreur
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  // ── CALL BACK ────────────────────────────────────────────────────────

  Future<void> _callBack(_CallRow row, {required bool video}) async {
    if (_isCalling(row.peerId)) return;

    final l10n = AppLocalizations.of(context);
    if (!_CallHistoryValidators.isValidUuid(row.peerId)) {
      _showError(l10n.t('call_error_invalid_peer'));
      return;
    }

    setState(() => _callingPeerId = row.peerId);
    HapticFeedback.mediumImpact();
    debugPrint('[CallHistory] 📞 Calling back: ${row.peerName} (video=$video)');

    try {
      await ref.read(callProvider.notifier).start(
            myUserId: _myId,
            calleeId: row.peerId,
            calleeName: row.peerName,
            calleeAvatar: row.peerAvatar,
            type: video ? CallType.video : CallType.audio,
          ).timeout(_kCallStartTimeout);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CallPage()),
      );
    } catch (e) {
      debugPrint('[CallHistory] ❌ Call start failed: $e');
      if (mounted) {
        _showError(l10n.t('call_error_start_failed'));
      }
    } finally {
      if (mounted) {
        setState(() => _callingPeerId = null);
      }
    }
  }

  void _openSearchToCall() {
    if (_callingPeerId != null) return;
    HapticFeedback.selectionClick();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchCallSheet(
        onPick: (id, name, avatar, {required bool video}) async {
          Navigator.pop(ctx);
          await _callBack(
            _CallRow(
              invite: CallInvite(
                id: '',
                channelName: 'call_${_myId}_$id',
                callerId: _myId,
                calleeId: id,
                callerName: '',
                calleeName: name,
                callerAvatar: null,
                calleeAvatar: avatar,
                callType: video ? CallType.video : CallType.audio,
                createdAt: DateTime.now(),
                status: CallStatus.accepted,
              ),
              peerId: id,
              peerName: name,
              peerAvatar: avatar,
            ),
            video: video,
          );
        },
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────

  String _subtitle(_CallRow row, AppLocalizations l10n) {
    final inv = row.invite;
    final isVideoCall = inv.callType == CallType.video;
    final type = isVideoCall ? l10n.t('call_type_video') : l10n.t('call_type_audio');
    
    if (inv.durationSec > 0) {
      final m = (inv.durationSec / 60).floor();
      final s = inv.durationSec % 60;
      final mm = m.toString().padLeft(2, '0');
      final ss = s.toString().padLeft(2, '0');
      return '$type · ${inv.status.label} · $mm:$ss';
    }
    return '$type · ${inv.status.label}';
  }

  IconData _dirIcon(CallInvite inv) {
    final missed = inv.status == CallStatus.missed ||
        inv.status == CallStatus.rejected ||
        inv.status == CallStatus.canceled;
    if (missed) return Icons.call_missed_rounded;
    if (inv.callerId == _myId) return Icons.call_made_rounded;
    return Icons.call_received_rounded;
  }

  Color _iconColor(CallInvite inv) {
    final missed = inv.status == CallStatus.missed ||
        inv.status == CallStatus.rejected ||
        inv.status == CallStatus.canceled;
    if (missed) return ThixPolicy.danger;
    if (inv.callerId == _myId) return ThixPolicy.success; // Sortant réussi
    return ThixPolicy.primary; // Entrant réussi
  }

  String _fmtDate(DateTime d, AppLocalizations l10n) {
    final local = d.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    
    if (day == today) return DateFormat('HH:mm').format(local);
    if (day == today.subtract(const Duration(days: 1))) {
      return l10n.t('call_yesterday');
    }
    return DateFormat('dd/MM/yy').format(local);
  }

  // ── BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          l10n.t('call_history_title'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: ThixPolicy.surface,
        foregroundColor: ThixPolicy.textMain,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: _callingPeerId != null ? null : _openSearchToCall,
            tooltip: l10n.t('call_search_button'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        onPressed: _callingPeerId != null ? null : _openSearchToCall,
        icon: const Icon(Icons.add_call_rounded),
        label: Text(l10n.t('call_new_call')),
      ),
      body: Column(
        children: [
          // ── Champ de recherche ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              maxLength: _kMaxSearchLength,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                counterText: '',
                hintText: l10n.t('call_search_hint'),
                prefixIcon: Icon(Icons.search_rounded, color: ThixPolicy.textMuted),
                filled: true,
                fillColor: ThixPolicy.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // ── Liste des appels ──
          Expanded(
            child: RefreshIndicator(
              color: ThixPolicy.primary,
              backgroundColor: ThixPolicy.surface,
              onRefresh: _refresh,
              child: FutureBuilder<List<_CallRow>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snap.hasError) {
                    return _buildErrorState(l10n);
                  }

                  var list = snap.data ?? [];
                  if (_query.isNotEmpty) {
                    list = list
                        .where((r) => r.peerName.toLowerCase().contains(_query))
                        .toList();
                  }

                  if (list.isEmpty) {
                    return _buildEmptyState(l10n, _query.isNotEmpty);
                  }

                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      return _CallHistoryTile(
                        row: list[i],
                        l10n: l10n,
                        myId: _myId,
                        isCalling: _isCalling(list[i].peerId),
                        onCall: (video) => _callBack(list[i], video: video),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 64, color: ThixPolicy.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            l10n.t('call_history_error'),
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.t('call_retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isSearch) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.call_end_rounded, 
            size: 64, 
            color: ThixPolicy.textMuted.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? l10n.t('call_search_no_results') : l10n.t('call_history_empty'),
            style: ThixPolicy.titleStyle.copyWith(
              color: ThixPolicy.textMuted,
              fontSize: 18,
            ),
          ),
          if (!isSearch) ...[
            const SizedBox(height: 8),
            Text(
              l10n.t('call_history_empty_subtitle'),
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// CALL HISTORY TILE (Extrait pour performance et lisibilité)
// ============================================================================

class _CallHistoryTile extends StatelessWidget {
  final _CallRow row;
  final AppLocalizations l10n;
  final String myId;
  final bool isCalling;
  final Function(bool video) onCall;

  const _CallHistoryTile({
    required this.row,
    required this.l10n,
    required this.myId,
    required this.isCalling,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final inv = row.invite;
    final isMissed = inv.status == CallStatus.missed ||
        inv.status == CallStatus.rejected ||
        inv.status == CallStatus.canceled;

    return InkWell(
      onTap: () => onCall(false), // Tap par défaut = appel audio
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar avec badge de statut
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: ThixPolicy.surfaceSoft,
                  backgroundImage: row.peerAvatar != null && row.peerAvatar!.isNotEmpty
                      ? NetworkImage(row.peerAvatar!)
                      : null,
                  child: row.peerAvatar == null || row.peerAvatar!.isEmpty
                      ? Text(
                          _CallHistoryValidators.safeInitial(row.peerName),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                // Badge d'icône de direction (entrante/sortante/manquée)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ThixPolicy.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.surfaceSoft, width: 2),
                    ),
                    child: Icon(
                      _dirIcon(inv),
                      size: 16,
                      color: _iconColor(inv),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            
            // Informations texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.peerName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isMissed ? ThixPolicy.danger : ThixPolicy.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        inv.callType == CallType.video ? Icons.videocam_rounded : Icons.phone_rounded,
                        size: 14,
                        color: ThixPolicy.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _subtitle(row, l10n),
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.textMuted,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions (Date + Boutons)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmtDate(inv.createdAt, l10n),
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ActionIconButton(
                      icon: Icons.videocam_rounded,
                      isCalling: isCalling,
                      color: ThixPolicy.primary,
                      onPressed: () => onCall(true),
                    ),
                    const SizedBox(width: 8),
                    _ActionIconButton(
                      icon: Icons.call_rounded,
                      isCalling: isCalling,
                      color: ThixPolicy.success,
                      onPressed: () => onCall(false),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _dirIcon(CallInvite inv) {
    final missed = inv.status == CallStatus.missed || inv.status == CallStatus.rejected || inv.status == CallStatus.canceled;
    if (missed) return Icons.call_missed_rounded;
    if (inv.callerId == myId) return Icons.call_made_rounded;
    return Icons.call_received_rounded;
  }

  Color _iconColor(CallInvite inv) {
    final missed = inv.status == CallStatus.missed || inv.status == CallStatus.rejected || inv.status == CallStatus.canceled;
    if (missed) return ThixPolicy.danger;
    if (inv.callerId == myId) return ThixPolicy.success;
    return ThixPolicy.primary;
  }
}

// ============================================================================
// ACTION ICON BUTTON (Optimisé)
// ============================================================================

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final bool isCalling;
  final Color color;
  final VoidCallback onPressed;

  const _ActionIconButton({
    required this.icon,
    required this.isCalling,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: isCalling ? null : onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCalling ? color.withOpacity(0.1) : color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: isCalling
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ============================================================================
// SEARCH CALL SHEET
// ============================================================================

class _SearchCallSheet extends ConsumerStatefulWidget {
  final void Function(String id, String name, String? avatar, {required bool video}) onPick;

  const _SearchCallSheet({required this.onPick});

  @override
  ConsumerState<_SearchCallSheet> createState() => _SearchCallSheetState();
}

class _SearchCallSheetState extends ConsumerState<_SearchCallSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  SupabaseClient get _db => ref.read(supabaseClientProvider);

  Future<void> _search(String q) async {
    final query = _CallHistoryValidators.sanitizeName(q, maxLength: _kMaxSearchLength).toLowerCase();
    final myId = ref.read(supabaseUserIdProvider);
    
    if (myId == null || !_CallHistoryValidators.isValidUuid(myId)) return;

    setState(() => _loading = true);

    try {
      final rows = await _db
          .from('connections')
          .select('user1_id, user2_id')
          .or('user1_id.eq.$myId,user2_id.eq.$myId');

      final peerIds = <String>{};
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final u1 = '${m['user1_id']}';
        final u2 = '${m['user2_id']}';
        if (u1 == myId && _CallHistoryValidators.isValidUuid(u2)) peerIds.add(u2);
        if (u2 == myId && _CallHistoryValidators.isValidUuid(u1)) peerIds.add(u1);
      }

      if (peerIds.isEmpty) {
        if (mounted) setState(() { _results = []; _loading = false; });
        return;
      }

      final profiles = await _db
          .from('profiles')
          .select('id, display_name, full_name, avatar_url')
          .inFilter('id', peerIds.toList());

      var list = (profiles as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (query.isNotEmpty) {
        list = list.where((p) {
          final name = _CallHistoryValidators.sanitizeName(
            '${p['display_name'] ?? p['full_name'] ?? ''}',
          ).toLowerCase();
          return name.contains(query);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _results = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[SearchCallSheet] ❌ Search failed: $e');
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  void _debouncedSearch(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounce, () => _search(q));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: ThixPolicy.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Text(
                l10n.t('call_new_call'),
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _ctrl,
                maxLength: _kMaxSearchLength,
                autofocus: true,
                onChanged: _debouncedSearch,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: l10n.t('call_search_contact_hint'),
                  prefixIcon: Icon(Icons.search_rounded, color: ThixPolicy.textMuted),
                  filled: true,
                  fillColor: ThixPolicy.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _results.isEmpty && !_loading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 64, color: ThixPolicy.textMuted.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            l10n.t('call_no_connections'),
                            style: ThixPolicy.bodyStyle.copyWith(
                              color: ThixPolicy.textMuted,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) {
                        final p = _results[i];
                        final id = '${p['id'] ?? ''}';
                        final name = _CallHistoryValidators.sanitizeName(
                          '${p['display_name'] ?? p['full_name'] ?? l10n.t('call_unknown_contact')}',
                        );
                        final avatar = p['avatar_url']?.toString();

                        return InkWell(
                          onTap: () => widget.onPick(id, name, avatar, video: false),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: ThixPolicy.surfaceSoft,
                                  backgroundImage: avatar != null && avatar.isNotEmpty
                                      ? NetworkImage(avatar)
                                      : null,
                                  child: avatar == null || avatar.isEmpty
                                      ? Text(
                                          _CallHistoryValidators.safeInitial(name),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ActionIconButton(
                                      icon: Icons.videocam_rounded,
                                      isCalling: false,
                                      color: ThixPolicy.primary,
                                      onPressed: () => widget.onPick(id, name, avatar, video: true),
                                    ),
                                    const SizedBox(width: 8),
                                    _ActionIconButton(
                                      icon: Icons.call_rounded,
                                      isCalling: false,
                                      color: ThixPolicy.success,
                                      onPressed: () => widget.onPick(id, name, avatar, video: false),
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
        ),
      ),
    );
  }
}
