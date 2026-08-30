// lib/presentation/network/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/services/network_service.dart';
import 'package:thix_id/models/network_notification.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 12);

class _NotifValidators {
  _NotifValidators._();

  static String sanitize(String? input, {int maxLength = 300}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }
}

// ============================================================================
// MÉTADONÉES PAR TYPE DE NOTIFICATION
// ============================================================================
class _NotifMeta {
  final IconData icon;
  final Color color;
  final String label;

  const _NotifMeta(this.icon, this.color, this.label);

  static _NotifMeta fromType(String? type) {
    switch (type?.toLowerCase()) {
      case 'like':
        return const _NotifMeta(Icons.favorite_rounded, ThixPolicy.danger, 'J\'aime');
      case 'comment':
        return const _NotifMeta(Icons.chat_bubble_rounded, ThixPolicy.primary, 'Commentaires');
      case 'follow':
        return const _NotifMeta(Icons.person_add_rounded, ThixPolicy.success, 'Abonnés');
      case 'mention':
        return const _NotifMeta(Icons.alternate_email_rounded, ThixPolicy.domainMedia, 'Mentions');
      case 'repost':
      case 'share':
        return const _NotifMeta(Icons.repeat_rounded, ThixPolicy.gold, 'Reposts');
      case 'system':
      case 'info':
        return const _NotifMeta(Icons.info_rounded, ThixPolicy.info, 'Système');
      default:
        return const _NotifMeta(Icons.notifications_rounded, ThixPolicy.textSecondary, 'Autres');
    }
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late NetworkService _networkService;
  List<NetworkNotification> _all = [];
  List<NetworkNotification> _filtered = [];
  bool _loading = true;
  bool _markingAll = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _networkService = NetworkService(Supabase.instance.client);
    _load();
  }

  // ─── ACCÈS DÉFENSIFS AUX CHAMPS OPTIONNELS DU MODÈLE ───
  bool _isRead(NetworkNotification n) {
    try {
      return (n as dynamic).isRead == true;
    } catch (_) {
      return true;
    }
  }

  String? _actorAvatar(NetworkNotification n) {
    try {
      return _NotifValidators.sanitizeUrl((n as dynamic).actorAvatar?.toString());
    } catch (_) {
      return null;
    }
  }

  String? _actorName(NetworkNotification n) {
    try {
      return _NotifValidators.sanitize((n as dynamic).actorName?.toString(), maxLength: 60);
    } catch (_) {
      return null;
    }
  }

  int get _unreadCount => _all.where((n) => !_isRead(n)).length;

  // ─── CHARGEMENT ───
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      debugPrint('[Notifications] 📥 Loading...');
      final n = await _networkService.getNotifications().timeout(_kRequestTimeout);
      if (!mounted) return;
      setState(() {
        _all = n;
        _applyFilter();
        _loading = false;
      });
      debugPrint('[Notifications] ✓ Loaded ${n.length} (${_unreadCount} unread)');
    } catch (e) {
      debugPrint('[Notifications] ❌ Load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _filter == 'all'
          ? _all
          : _all.where((n) => (n.type ?? '').toLowerCase() == _filter).toList();
    });
  }

  // ─── MARQUER COMME LUE (tap individuel) ───
  Future<void> _markAsRead(NetworkNotification n) async {
    if (_isRead(n)) return;
    try {
      await (n as dynamic).markAsRead?.call() ??
          _networkService.markNotificationAsRead(n.id).timeout(_kRequestTimeout);
      if (mounted) {
        setState(() {
          // Rafraîchit l'état local
          _all = List.from(_all);
          _applyFilter();
        });
      }
    } catch (e) {
      debugPrint('[Notifications] ⚠️ markAsRead error: $e');
    }
  }

  // ─── TOUT MARQUER COMME LU ───
  Future<void> _markAllAsRead() async {
    if (_markingAll || _unreadCount == 0) return;
    setState(() => _markingAll = true);
    HapticFeedback.mediumImpact();

    try {
      await _networkService.markAllNotificationsAsRead().timeout(_kRequestTimeout);
      if (!mounted) return;
      setState(() {
        _all = List.from(_all);
        _applyFilter();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.done_all_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Toutes les notifications sont lues'),
            ],
          ),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      debugPrint('[Notifications] ✓ All marked as read');
    } catch (e) {
      debugPrint('[Notifications] ❌ markAll error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du marquage'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  // ─── TAP NOTIFICATION ───
  void _onTap(NetworkNotification n) {
    HapticFeedback.selectionClick();
    _markAsRead(n);
    if (n.postId != null && n.postId!.isNotEmpty) {
      context.push('/network/post/${n.postId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Text('Notifications', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger,
                  borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                ),
                child: Text(
                  '$_unreadCount',
                  style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              tooltip: 'Tout marquer comme lu',
              icon: _markingAll
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))
                  : const Icon(Icons.done_all_rounded, color: ThixPolicy.primary, size: 22),
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: _loading
          ? _buildSkeleton()
          : _all.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildFilterChips(),
                    Expanded(
                      child: _filtered.isEmpty
                          ? _buildNoResults()
                          : RefreshIndicator(
                              color: ThixPolicy.primary,
                              onRefresh: _load,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 0, indent: 76),
                                itemBuilder: (_, i) => _buildTile(_filtered[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  // ─── CHIPS DE FILTRE ───
  Widget _buildFilterChips() {
    final counts = <String, int>{'all': _all.length};
    for (final n in _all) {
      final t = (n.type ?? '').toLowerCase();
      counts[t] = (counts[t] ?? 0) + 1;
    }

    const filters = ['all', 'like', 'comment', 'follow', 'mention', 'system'];

    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: filters.map((f) {
            final count = counts[f] ?? 0;
            if (f != 'all' && count == 0) return const SizedBox.shrink();

            final selected = _filter == f;
            final meta = f == 'all' ? const _NotifMeta(Icons.apps_rounded, ThixPolicy.primary, 'Toutes') : _NotifMeta.fromType(f);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  _filter = f;
                  _applyFilter();
                },
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(meta.icon, size: 14, color: selected ? Colors.white : meta.color),
                    const SizedBox(width: 6),
                    Text(
                      f == 'all' ? 'Toutes' : meta.label,
                      style: ThixPolicy.captionStyle.copyWith(
                        color: selected ? Colors.white : ThixPolicy.textMain,
                        fontWeight: ThixPolicy.semiBold,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: ThixPolicy.microStyle.copyWith(
                          color: selected ? Colors.white70 : ThixPolicy.textSecondary,
                          fontWeight: ThixPolicy.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                selectedColor: ThixPolicy.primary,
                backgroundColor: ThixPolicy.surfaceSoft,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── TUILE NOTIFICATION ───
  Widget _buildTile(NetworkNotification n) {
    final meta = _NotifMeta.fromType(n.type);
    final isRead = _isRead(n);
    final avatar = _actorAvatar(n);
    final actor = _actorName(n);
    final title = _NotifValidators.sanitize(n.title, maxLength: 120);
    final body = _NotifValidators.sanitize(n.body, maxLength: 200);

    return Material(
      color: isRead ? Colors.transparent : ThixPolicy.tint,
      child: InkWell(
        onTap: () => _onTap(n),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar acteur + icône type superposée
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.border, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: ThixPolicy.surfaceSoft,
                      backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                      child: avatar == null
                          ? Icon(meta.icon, size: 20, color: meta.color)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: meta.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.card, width: 2),
                      ),
                      child: Icon(meta.icon, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            actor != null && actor.isNotEmpty ? actor : title,
                            style: ThixPolicy.labelStyle.copyWith(
                              fontWeight: isRead ? ThixPolicy.semiBold : ThixPolicy.bold,
                              color: ThixPolicy.textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: ThixPolicy.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: ThixPolicy.bodySmallStyle.copyWith(
                          color: isRead ? ThixPolicy.textSecondary : ThixPolicy.textMain,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(n.createdAt, locale: 'fr'),
                      style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SKELETON ───
  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 140, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 12, width: double.infinity, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(height: 10, width: 60, color: Colors.grey.shade200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ÉTATS VIDES ───
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.notifications_none_rounded, size: 64, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 24),
            Text('Aucune notification', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              'Les interactions avec vos publications\napparaîtront ici.',
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_alt_off_rounded, size: 48, color: ThixPolicy.textMuted),
          const SizedBox(height: 12),
          Text('Rien dans cette catégorie', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }
}
