// lib/presentation/thix_market/pages/dispute_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxMessageLength = 2000;
const int _kMaxRetries = 1;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _DisputeValidators {
  _DisputeValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

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
    if (msg.contains('not found')) return 'Litige introuvable.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[DisputeDetail] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[DisputeDetail] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[DisputeDetail] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// MODÈLES TYPÉS
// ============================================================================
class DisputeMessage {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;
  final String userName;
  final String? userAvatarUrl;

  const DisputeMessage({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    required this.userName,
    this.userAvatarUrl,
  });

  bool isOwn(String? currentUserId) => userId == currentUserId;

  factory DisputeMessage.fromMap(Map<String, dynamic> map) {
    final user = map['user'] as Map?;
    return DisputeMessage(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      text: _DisputeValidators.sanitize(map['message']?.toString() ?? '', maxLength: _kMaxMessageLength),
      createdAt: _parseDate(map['created_at']?.toString()) ?? DateTime.now(),
      userName: _DisputeValidators.sanitize(user?['name']?.toString() ?? 'Utilisateur', maxLength: 60),
      userAvatarUrl: _DisputeValidators.sanitizeUrl(user?['avatar']?.toString()),
    );
  }
}

class DisputeDetail {
  final String id;
  final String status;
  final String reason;
  final String? lastMessage;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? orderId;
  final String userName;
  final String? userAvatarUrl;
  final String? mediatorName;
  final String? mediatorAvatarUrl;

  const DisputeDetail({
    required this.id,
    required this.status,
    required this.reason,
    this.lastMessage,
    required this.createdAt,
    this.updatedAt,
    this.orderId,
    required this.userName,
    this.userAvatarUrl,
    this.mediatorName,
    this.mediatorAvatarUrl,
  });

  factory DisputeDetail.fromMap(Map<String, dynamic> map) {
    final user = map['user'] as Map?;
    final mediator = map['mediator'] as Map?;
    final order = map['order'] as Map?;

    return DisputeDetail(
      id: map['id']?.toString() ?? '',
      status: _DisputeValidators.sanitize(map['status']?.toString() ?? 'open', maxLength: 20),
      reason: _DisputeValidators.sanitize(map['reason']?.toString() ?? '', maxLength: 500),
      lastMessage: _DisputeValidators.sanitize(map['last_message']?.toString(), maxLength: 200),
      createdAt: _parseDate(map['created_at']?.toString()) ?? DateTime.now(),
      updatedAt: _parseDate(map['updated_at']?.toString()),
      orderId: order?['id']?.toString(),
      userName: _DisputeValidators.sanitize(user?['name']?.toString() ?? 'Client', maxLength: 60),
      userAvatarUrl: _DisputeValidators.sanitizeUrl(user?['avatar']?.toString()),
      mediatorName: _DisputeValidators.sanitize(mediator?['name']?.toString(), maxLength: 60),
      mediatorAvatarUrl: _DisputeValidators.sanitizeUrl(mediator?['avatar']?.toString()),
    );
  }
}

DateTime? _parseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class DisputeDetailPage extends StatefulWidget {
  final String disputeId;

  const DisputeDetailPage({super.key, required this.disputeId});

  @override
  State<DisputeDetailPage> createState() => _DisputeDetailPageState();
}

class _DisputeDetailPageState extends State<DisputeDetailPage> {
  DisputeDetail? _dispute;
  List<DisputeMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUpdatingStatus = false;
  String? _error;
  String? _currentUserId;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final isValid = _DisputeValidators.isValidId(widget.disputeId);
    debugPrint('[DisputeDetail] 💬 Page opened for ${widget.disputeId.substring(0, widget.disputeId.length > 8 ? 8 : widget.disputeId.length)}${isValid ? "" : " (INVALID)"}');

    if (!isValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleInvalidId());
    } else {
      _loadDisputeDetails();
      _subscribeToMessages();
    }
  }

  void _handleInvalidId() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _showError('Identifiant de litige invalide');
    context.pop();
  }

  @override
  void dispose() {
    // IMPORTANT : annuler le stream pour éviter les fuites mémoire
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    debugPrint('[DisputeDetail] 👋 Page disposed');
    super.dispose();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================
  Future<void> _loadDisputeDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _withRetry(
        () => Supabase.instance.client
            .from('disputes')
            .select('''
              *,
              order:orders(id, total, currency),
              user:users(name, avatar),
              mediator:users(name, avatar)
            ''')
            .eq('id', widget.disputeId)
            .single(),
        label: 'loadDispute',
      );

      _dispute = DisputeDetail.fromMap(response);
      debugPrint('[DisputeDetail] ✓ Loaded dispute ${_dispute!.id.substring(0, 8)}');
      await _loadMessages();
    } catch (e) {
      final friendly = _DisputeValidators.friendlyError(e);
      debugPrint('[DisputeDetail] ❌ Load error: $friendly');
      if (mounted) setState(() => _error = friendly);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await _withRetry(
        () => Supabase.instance.client
            .from('dispute_messages')
            .select('*, user:users(name, avatar)')
            .eq('dispute_id', widget.disputeId)
            .order('created_at', ascending: true),
        label: 'loadMessages',
      );

      final list = (response as List).map((m) => DisputeMessage.fromMap(Map<String, dynamic>.from(m as Map))).toList();
      if (mounted) {
        setState(() => _messages = list);
        _scrollToBottom();
      }
      debugPrint('[DisputeDetail] ✓ Loaded ${list.length} messages');
    } catch (e) {
      debugPrint('[DisputeDetail] ❌ Load messages error: $e');
    }
  }

  void _subscribeToMessages() {
    _messagesSubscription = Supabase.instance.client
        .from('dispute_messages')
        .stream(primaryKey: ['id'])
        .eq('dispute_id', widget.disputeId)
        .order('created_at', ascending: true)
        .listen(
      (data) {
        if (!mounted) return;
        final newMessages = data
            .map((m) => DisputeMessage.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        setState(() => _messages = newMessages);
        _scrollToBottom();
      },
      onError: (e) {
        debugPrint('[DisputeDetail] ⚠️ Realtime stream error: $e');
      },
    );
    debugPrint('[DisputeDetail] 📡 Realtime subscription active');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ============================================================
  // ACTIONS
  // ============================================================
  Future<void> _sendMessage() async {
    if (_isSending) return;

    final text = _DisputeValidators.sanitize(_messageController.text.trim(), maxLength: _kMaxMessageLength);
    if (text.isEmpty) {
      HapticFeedback.lightImpact();
      return;
    }

    if (_currentUserId == null) {
      _showError('Vous devez être connecté');
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    try {
      await _withRetry(
        () => Supabase.instance.client.from('dispute_messages').insert({
          'dispute_id': widget.disputeId,
          'user_id': _currentUserId,
          'message': text,
          'created_at': DateTime.now().toIso8601String(),
        }),
        label: 'sendMessage',
      );

      await _withRetry(
        () => Supabase.instance.client.from('disputes').update({
          'last_message': text,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.disputeId),
        label: 'updateLastMessage',
      );

      _messageController.clear();
      debugPrint('[DisputeDetail] ✉️ Message sent');
    } catch (e) {
      debugPrint('[DisputeDetail] ❌ Send message error: $e');
      if (mounted) _showError('Erreur lors de l\'envoi du message');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _updateDisputeStatus(String newStatus) async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);
    HapticFeedback.mediumImpact();

    try {
      await _withRetry(
        () => Supabase.instance.client.from('disputes').update({
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.disputeId),
        label: 'updateStatus',
      );

      if (mounted && _dispute != null) {
        setState(() {
          _dispute = DisputeDetail(
            id: _dispute!.id,
            status: newStatus,
            reason: _dispute!.reason,
            lastMessage: _dispute!.lastMessage,
            createdAt: _dispute!.createdAt,
            updatedAt: DateTime.now(),
            orderId: _dispute!.orderId,
            userName: _dispute!.userName,
            userAvatarUrl: _dispute!.userAvatarUrl,
            mediatorName: _dispute!.mediatorName,
            mediatorAvatarUrl: _dispute!.mediatorAvatarUrl,
          );
        });
        _showSuccess('Statut mis à jour : ${_getStatusLabel(newStatus)}');
        debugPrint('[DisputeDetail] 🔄 Status updated to $newStatus');
      }
    } catch (e) {
      debugPrint('[DisputeDetail] ❌ Update status error: $e');
      if (mounted) _showError('Erreur lors de la mise à jour du statut');
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _showStatusDialog() async {
    HapticFeedback.selectionClick();

    final statuses = [
      {'value': 'open', 'label': 'Ouvert', 'color': ThixPolicy.gold, 'icon': Icons.fiber_new_rounded},
      {'value': 'mediation', 'label': 'Médiation', 'color': ThixPolicy.primary, 'icon': Icons.balance_rounded},
      {'value': 'resolved', 'label': 'Résolu', 'color': ThixPolicy.success, 'icon': Icons.check_circle_rounded},
      {'value': 'closed', 'label': 'Fermé', 'color': ThixPolicy.textMuted, 'icon': Icons.archive_rounded},
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StatusSheet(
        statuses: statuses,
        currentStatus: _dispute?.status ?? 'open',
      ),
    );

    if (selected != null && mounted && selected != _dispute?.status) {
      // Confirmation pour actions critiques
      if (selected == 'closed' || selected == 'resolved') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
            title: Text('Confirmer le changement ?', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            content: Text('Passer le litige en "${_getStatusLabel(selected)}" ?', style: ThixPolicy.bodyStyle),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
                child: const Text('Confirmer'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }
      _updateDisputeStatus(selected);
    }
  }

  // ============================================================
  // HELPERS UI
  // ============================================================
  Color _getStatusColor(String status) {
    switch (status) {
      case 'open': return ThixPolicy.gold;
      case 'mediation': return ThixPolicy.primary;
      case 'resolved': return ThixPolicy.success;
      case 'closed': return ThixPolicy.textMuted;
      default: return ThixPolicy.textMuted;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open': return 'Ouvert';
      case 'mediation': return 'Médiation';
      case 'resolved': return 'Résolu';
      case 'closed': return 'Fermé';
      default: return status;
    }
  }

  String _formatSmartDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return DateFormat('HH:mm').format(date);
    } else if (dateOnly == yesterday) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEE HH:mm', 'fr_FR').format(date);
    } else {
      return DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(date);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          'Détail du litige',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
          tooltip: 'Retour',
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        actions: [
          if (_dispute != null)
            Semantics(
              button: true,
              label: 'Changer le statut du litige',
              child: IconButton(
                icon: const Icon(Icons.edit_rounded, color: ThixPolicy.textMain),
                tooltip: 'Changer le statut',
                onPressed: _isUpdatingStatus ? null : _showStatusDialog,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const _SkeletonDispute()
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadDisputeDetails)
              : _dispute == null
                  ? const _NotFoundState()
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final dispute = _dispute!;
    return Column(
      children: [
        _DisputeHeader(
          dispute: dispute,
          statusColor: _getStatusColor(dispute.status),
          statusLabel: _getStatusLabel(dispute.status),
          formatDate: _formatSmartDate,
          onOpenOrder: dispute.orderId != null
              ? () {
                  HapticFeedback.selectionClick();
                  context.push('/market/order/${dispute.orderId}');
                }
              : null,
        ),
        const Divider(height: 1, color: ThixPolicy.border),

        // Messages
        Expanded(
          child: _messages.isEmpty
              ? const _EmptyMessages()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _MessageBubble(
                      message: msg,
                      isOwn: msg.isOwn(_currentUserId),
                      formatDate: _formatSmartDate,
                    );
                  },
                ),
        ),

        // Input bar
        _MessageInput(
          controller: _messageController,
          isSending: _isSending,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _DisputeHeader extends StatelessWidget {
  final DisputeDetail dispute;
  final Color statusColor;
  final String statusLabel;
  final String Function(DateTime) formatDate;
  final VoidCallback? onOpenOrder;

  const _DisputeHeader({
    required this.dispute,
    required this.statusColor,
    required this.statusLabel,
    required this.formatDate,
    this.onOpenOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: ThixPolicy.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Litige #${dispute.id.substring(0, dispute.id.length > 8 ? 8 : dispute.id.length)}',
                  style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain, fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: statusColor,
                    fontWeight: ThixPolicy.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (dispute.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              dispute.reason,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: ThixPolicy.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dispute.userName,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (onOpenOrder != null) ...[
                Semantics(
                  button: true,
                  label: 'Voir la commande',
                  child: GestureDetector(
                    onTap: onOpenOrder,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 14, color: ThixPolicy.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Commande #${dispute.orderId?.substring(0, dispute.orderId!.length > 8 ? 8 : dispute.orderId!.length) ?? 'N/A'}',
                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              const Icon(Icons.access_time_rounded, size: 14, color: ThixPolicy.textMuted),
              const SizedBox(width: 4),
              Text(
                'Ouvert le ${formatDate(dispute.createdAt)}',
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
              ),
            ],
          ),
          if (dispute.mediatorName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _SmallAvatar(
                  url: dispute.mediatorAvatarUrl,
                  name: dispute.mediatorName!,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Médiateur : ${dispute.mediatorName}',
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.semiBold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const _SmallAvatar({required this.url, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: ThixPolicy.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold, fontSize: size / 2),
          ),
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: ThixPolicy.surfaceSoft,
          child: const Icon(Icons.person_rounded, size: 12, color: ThixPolicy.textMuted),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DisputeMessage message;
  final bool isOwn;
  final String Function(DateTime) formatDate;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${isOwn ? "Vous" : message.userName}, ${formatDate(message.createdAt)}: ${message.text}',
      child: Row(
        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            _SmallAvatar(url: message.userAvatarUrl, name: message.userName, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOwn ? ThixPolicy.primary : ThixPolicy.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isOwn ? 12 : 4),
                  bottomRight: Radius.circular(isOwn ? 4 : 12),
                ),
                border: isOwn ? null : Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isOwn) ...[
                    Text(
                      message.userName,
                      style: ThixPolicy.captionStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 12,
                        color: ThixPolicy.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message.text,
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      color: isOwn ? Colors.white : ThixPolicy.textMain,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDate(message.createdAt),
                    style: ThixPolicy.microStyle.copyWith(
                      fontSize: 10,
                      color: isOwn ? Colors.white70 : ThixPolicy.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwn) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !widget.isSending;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              label: 'Champ de message',
              child: Container(
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: widget.controller,
                  maxLength: _kMaxMessageLength,
                  maxLines: null,
                  style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain),
                  decoration: InputDecoration(
                    hintText: 'Écrire un message...',
                    hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    counterText: '',
                  ),
                  onSubmitted: (_) => canSend ? widget.onSend() : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: canSend ? 'Envoyer le message' : 'Champ vide',
            enabled: canSend,
            child: GestureDetector(
              onTap: canSend ? widget.onSend : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canSend ? ThixPolicy.primary : ThixPolicy.border,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: widget.isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: canSend ? Colors.white : ThixPolicy.textMuted,
                          size: 18,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSheet extends StatelessWidget {
  final List<Map<String, dynamic>> statuses;
  final String currentStatus;

  const _StatusSheet({required this.statuses, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 12, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text('Changer le statut', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
          const SizedBox(height: 16),
          ...statuses.map((status) {
            final value = status['value'] as String;
            final label = status['label'] as String;
            final color = status['color'] as Color;
            final icon = status['icon'] as IconData;
            final isSelected = currentStatus == value;

            return Semantics(
              button: true,
              selected: isSelected,
              label: 'Statut $label, ${isSelected ? "actuel" : ""}',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                title: Text(label, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: ThixPolicy.success)
                    : const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context, value);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThixPolicy.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun message',
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          const SizedBox(height: 4),
          Text(
            'Démarrez la conversation ci-dessous',
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
              decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
            const SizedBox(height: 8),
            Text(message, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Réessayer',
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Réessayer', style: TextStyle(fontWeight: ThixPolicy.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: ThixPolicy.textDisabled),
          const SizedBox(height: 16),
          Text('Litige introuvable', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
        ],
      ),
    );
  }
}

class _SkeletonDispute extends StatelessWidget {
  const _SkeletonDispute();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header skeleton
        Container(
          padding: const EdgeInsets.all(16),
          color: ThixPolicy.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 18, width: 180, color: Colors.grey.shade200),
              const SizedBox(height: 12),
              Container(height: 12, width: double.infinity, color: Colors.grey.shade200),
              const SizedBox(height: 6),
              Container(height: 12, width: 220, color: Colors.grey.shade200),
              const SizedBox(height: 12),
              Container(height: 10, width: 150, color: Colors.grey.shade200),
            ],
          ),
        ),
        const Divider(height: 1),
        // Messages skeleton
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: 4,
            itemBuilder: (_, i) => Align(
              alignment: i % 2 == 0 ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: MediaQuery.of(context).size.width * 0.65,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, color: Colors.grey.shade300),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 80, color: Colors.grey.shade300),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Input skeleton
        Container(
          padding: const EdgeInsets.all(12),
          color: ThixPolicy.card,
          child: Row(
            children: [
              Expanded(child: Container(height: 44, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(24)))),
              const SizedBox(width: 8),
              Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
            ],
          ),
        ),
      ],
    );
  }
}
