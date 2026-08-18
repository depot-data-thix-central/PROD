// lib/presentation/thix_market/pages/dispute_detail_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DisputeDetailPage extends StatefulWidget {
  final String disputeId;

  const DisputeDetailPage({super.key, required this.disputeId});

  @override
  State<DisputeDetailPage> createState() => _DisputeDetailPageState();
}

class _DisputeDetailPageState extends State<DisputeDetailPage> {
  Map<String, dynamic>? _dispute;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  String? _currentUserId;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color bgLight = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadDisputeDetails();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDisputeDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('disputes')
          .select('''
            *,
            order:orders(*),
            user:users(name, avatar),
            mediator:users(name, avatar)
          ''')
          .eq('id', widget.disputeId)
          .single();

      setState(() {
        _dispute = response;
        _isLoading = false;
      });

      await _loadMessages();
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger le litige';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await Supabase.instance.client
          .from('dispute_messages')
          .select('*, user:users(name, avatar)')
          .eq('dispute_id', widget.disputeId)
          .order('created_at', ascending: true);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading dispute messages: $e');
    }
  }

  void _subscribeToMessages() {
    Supabase.instance.client
        .from('dispute_messages')
        .stream(primaryKey: ['id'])
        .eq('dispute_id', widget.disputeId)
        .order('created_at', ascending: true)
        .listen((data) {
      if (mounted) {
        final newMessages = List<Map<String, dynamic>>.from(data);
        setState(() {
          _messages = newMessages;
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await Supabase.instance.client.from('dispute_messages').insert({
        'dispute_id': widget.disputeId,
        'user_id': _currentUserId,
        'message': text,
        'created_at': DateTime.now().toIso8601String(),
      });

      await Supabase.instance.client
          .from('disputes')
          .update({
            'last_message': text,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.disputeId);

      _messageController.clear();
    } catch (e) {
      debugPrint('Error sending dispute message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _updateDisputeStatus(String newStatus) async {
    try {
      await Supabase.instance.client
          .from('disputes')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.disputeId);

      setState(() {
        _dispute!['status'] = newStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour : $newStatus')),
        );
      }
    } catch (e) {
      debugPrint('Error updating dispute status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour')),
        );
      }
    }
  }

  void _showStatusDialog() {
    final statuses = [
      {'value': 'open', 'label': 'Ouvert', 'color': Colors.orange},
      {'value': 'mediation', 'label': 'Médiation', 'color': Colors.blue},
      {'value': 'resolved', 'label': 'Résolu', 'color': Colors.green},
      {'value': 'closed', 'label': 'Fermé', 'color': Colors.grey},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Changer le statut',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...statuses.map((status) => ListTile(
              leading: Icon(
                Icons.circle,
                color: status['color'] as Color,
                size: 16,
              ),
              title: Text(status['label'] as String),
              trailing: _dispute?['status'] == status['value']
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _updateDisputeStatus(status['value'] as String);
              },
            )),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'mediation':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Ouvert';
      case 'mediation':
        return 'Médiation';
      case 'resolved':
        return 'Résolu';
      case 'closed':
        return 'Fermé';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          'Détail du litige',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_dispute != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black87),
              onPressed: _showStatusDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _dispute == null
                  ? const Center(child: Text('Litige introuvable'))
                  : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDisputeDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final dispute = _dispute!;
    final status = dispute['status'] ?? 'open';
    final statusColor = _getStatusColor(status);
    final createdAt = _formatDate(dispute['created_at']);
    final user = dispute['user'] as Map?;
    final mediator = dispute['mediator'] as Map?;
    final order = dispute['order'] as Map?;
    final mediatorAvatar = mediator?['avatar'] as String?;

    return Column(
      children: [
        // Informations du litige
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Litige #${dispute['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (dispute['reason'] != null)
                Text(
                  dispute['reason'],
                  style: const TextStyle(fontSize: 14),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    user?['name'] ?? 'Client',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.shopping_bag, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Commande #${order?['id'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Ouvert le $createdAt',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              if (mediator != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: mediatorAvatar != null && mediatorAvatar.trim().isNotEmpty
                          ? NetworkImage(mediatorAvatar)
                          : null,
                      child: mediatorAvatar == null || mediatorAvatar.trim().isEmpty
                          ? const Icon(Icons.person, size: 12)
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Médiateur: ${mediator['name'] ?? ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // Messages
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun message',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isOwn = msg['user_id'] == _currentUserId;
                    final msgUser = msg['user'] as Map?;
                    final userName = msgUser?['name'] ?? 'Utilisateur';
                    final userAvatar = msgUser?['avatar'] as String?;

                    return Row(
                      mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isOwn)
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: userAvatar != null && userAvatar.trim().isNotEmpty
                                ? NetworkImage(userAvatar)
                                : null,
                            child: userAvatar == null || userAvatar.trim().isEmpty
                                ? const Icon(Icons.person, size: 14)
                                : null,
                          ),
                        if (!isOwn) const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isOwn ? primaryBlue : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: Radius.circular(isOwn ? 12 : 4),
                                bottomRight: Radius.circular(isOwn ? 4 : 12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isOwn)
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  msg['message'] ?? '',
                                  style: TextStyle(
                                    color: isOwn ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(msg['created_at']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isOwn ? Colors.white70 : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),

        // Barre d'envoi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _messageController.text.trim().isEmpty
                    ? Colors.grey[300]
                    : primaryBlue,
                child: IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: _messageController.text.trim().isEmpty || _isSending
                      ? null
                      : _sendMessage,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
