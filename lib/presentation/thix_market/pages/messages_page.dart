import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/message_provider.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color bgLight = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<MessageProvider>();
    await Future.wait([
      provider.loadConversations(),
      provider.loadDisputes(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = context.watch<MessageProvider>();

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat, size: 18),
                  const SizedBox(width: 8),
                  Text('Conversations'),
                  if (messageProvider.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${messageProvider.unreadCount}',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gavel, size: 18),
                  SizedBox(width: 8),
                  Text('Litiges'),
                ],
              ),
            ),
          ],
          indicatorColor: primaryBlue,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.phone_in_talk, color: Colors.black87),
            onPressed: () => _startVoiceCall(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConversationsTab(messageProvider),
          _buildDisputesTab(messageProvider),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1 : CONVERSATIONS
  // ============================================================
  Widget _buildConversationsTab(MessageProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.conversations.isEmpty) {
      return _buildEmptyState(
        'Aucune conversation',
        'Commencez à discuter avec des vendeurs',
        Icons.chat_bubble_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: provider.conversations.length,
        itemBuilder: (context, index) {
          final conv = provider.conversations[index];
          return _buildConversationTile(conv);
        },
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final lastMessage = conversation['last_message'];
    final isUnread = (conversation['unread_count'] ?? 0) > 0;
    final lastMessageTime = conversation['last_message_time'];
    final otherUser = conversation['other_user'] as Map? ?? {};
    final userName = otherUser['name'] ?? 'Utilisateur';
    final userAvatar = otherUser['avatar'] as String?;
    final isOnline = otherUser['is_online'] ?? false;

    String formattedTime = '';
    if (lastMessageTime != null) {
      try {
        final date = DateTime.parse(lastMessageTime);
        final now = DateTime.now();
        if (date.day == now.day && date.month == now.month && date.year == now.year) {
          formattedTime = DateFormat('HH:mm').format(date);
        } else {
          formattedTime = DateFormat('dd/MM').format(date);
        }
      } catch (_) {}
    }

    return InkWell(
      // ✅ Correction : on caste otherUser en Map<String, dynamic>
      onTap: () => _openChat(conversation['id'], Map<String, dynamic>.from(otherUser)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isUnread ? primaryBlue.withOpacity(0.05) : Colors.white,
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: userAvatar != null
                      ? CachedNetworkImageProvider(userAvatar)
                      : null,
                  child: userAvatar == null
                      ? Icon(Icons.person, size: 26, color: Colors.grey[400])
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
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
                          userName,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (formattedTime.isNotEmpty)
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (conversation['is_typing'] == true)
                        const SizedBox(
                          width: 60,
                          child: Text(
                            'Écrit...',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryBlue,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            lastMessage ?? 'Dernier message',
                            style: TextStyle(
                              fontSize: 13,
                              color: isUnread ? Colors.black87 : Colors.grey[600],
                              fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (conversation['unread_count'] > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conversation['unread_count']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB 2 : LITIGES
  // ============================================================
  Widget _buildDisputesTab(MessageProvider provider) {
    if (provider.isLoadingDisputes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.disputes.isEmpty) {
      return _buildEmptyState(
        'Aucun litige',
        'Tous vos litiges seront affichés ici',
        Icons.gavel,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: provider.disputes.length,
        itemBuilder: (context, index) {
          final dispute = provider.disputes[index];
          return _buildDisputeCard(dispute);
        },
      ),
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> dispute) {
    final status = dispute['status'] ?? 'open';
    final statusColors = {
      'open': Colors.orange,
      'mediation': Colors.blue,
      'resolved': Colors.green,
      'closed': Colors.grey,
    };
    final statusTexts = {
      'open': 'En cours',
      'mediation': 'Médiation',
      'resolved': 'Résolu',
      'closed': 'Fermé',
    };
    final statusColor = statusColors[status] ?? Colors.grey;
    final statusText = statusTexts[status] ?? 'Inconnu';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => _openDispute(dispute['id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (dispute['reason'] != null)
                Text(
                  dispute['reason'],
                  style: TextStyle(color: Colors.grey[700]),
                ),
              const SizedBox(height: 8),
              Text(
                'Commande #${dispute['order_id']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Ouvert le ${DateFormat('dd/MM/yyyy').format(DateTime.parse(dispute['created_at']))}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              if (dispute['last_message'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.message, size: 14, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dispute['last_message'],
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================
  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/market/search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Découvrir des boutiques'),
          ),
        ],
      ),
    );
  }

  // ✅ Modification de la signature pour accepter Map<dynamic, dynamic> ou Map<String, dynamic>
  // On peut laisser Map<String, dynamic> et faire le cast à l'appel (déjà fait)
  void _openChat(String conversationId, Map<String, dynamic> otherUser) {
    context.push(
      '/market/chat/$conversationId',
      extra: {
        'title': otherUser['name'] ?? 'Discussion',
        'userName': otherUser['name'] ?? '',
        'userAvatar': otherUser['avatar'],
      },
    );
  }

  void _openDispute(String disputeId) {
    context.push('/market/dispute/$disputeId');
  }

  void _startVoiceCall() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const VoiceCallSheet(),
    );
  }
}

// ============================================================
// VOICE CALL SHEET
// ============================================================
class VoiceCallSheet extends StatelessWidget {
  const VoiceCallSheet({super.key});

  // ✅ Définition d'une constante locale pour primaryBlue
  static const Color _primaryBlue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Appel vocal temporaire',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Appel sécurisé - Non enregistré',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildContactTile(
                  'Vendeur',
                  'Jean Dupont',
                  'Électronique Pro',
                  Icons.store,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildContactTile(
                  'Acheteur',
                  'Marie Claire',
                  'Achat #12345',
                  Icons.shopping_bag,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Démarrer l'appel
            },
            icon: const Icon(Icons.call),
            label: const Text('Démarrer l\'appel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue, // ✅ Utilisation de la constante locale
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(String role, String name, String info, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: _primaryBlue), // ✅ Utilisation de la constante locale
          const SizedBox(height: 8),
          Text(
            role,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            info,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
