import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/support_provider.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedCategory = 'general';

  final List<Map<String, dynamic>> faqCategories = [
    {'id': 'general', 'name': 'Général', 'icon': Icons.help_outline},
    {'id': 'account', 'name': 'Compte', 'icon': Icons.person_outline},
    {'id': 'payment', 'name': 'Paiements', 'icon': Icons.payment},
    {'id': 'shipping', 'name': 'Livraison', 'icon': Icons.local_shipping},
    {'id': 'selling', 'name': 'Vendre', 'icon': Icons.store},
    {'id': 'disputes', 'name': 'Litiges', 'icon': Icons.gavel},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().loadFAQs();
      context.read<SupportProvider>().loadSupportTickets();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportProvider = context.watch<SupportProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Aide & Support',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher dans l\'aide...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) => supportProvider.searchFAQs(value),
                ),
              ),
            ),
            
            // Tabs
            const TabBar(
              tabs: [
                Tab(text: 'FAQ'),
                Tab(text: 'Mes tickets'),
                Tab(text: 'Contacter'),
              ],
              indicatorColor: Color(0xFFE5592F),
              labelColor: Color(0xFFE5592F),
              unselectedLabelColor: Colors.grey,
            ),
            
            Expanded(
              child: TabBarView(
                children: [
                  _buildFAQTab(supportProvider, theme),
                  _buildTicketsTab(supportProvider, theme),
                  _buildContactTab(supportProvider, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQTab(SupportProvider provider, ThemeData theme) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Categories
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: faqCategories.length,
            itemBuilder: (context, index) {
              final category = faqCategories[index];
              final isSelected = _selectedCategory == category['id'];
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCategory = category['id']);
                  provider.loadFAQs(category: category['id']);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE5592F) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        category['icon'] as IconData,
                        color: isSelected ? Colors.white : Colors.grey[600],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category['name'],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[600],
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // FAQs list
        Expanded(
          child: provider.filteredFAQs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.help_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune FAQ trouvée',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.filteredFAQs.length,
                  itemBuilder: (context, index) {
                    final faq = provider.filteredFAQs[index];
                    return _buildFAQItem(faq);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFAQItem(Map<String, dynamic> faq) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            faq['question'],
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                faq['answer'],
                style: TextStyle(color: Colors.grey[700], height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsTab(SupportProvider provider, ThemeData theme) {
    if (provider.isLoadingTickets) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.supportTickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Aucun ticket de support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous n\'avez pas encore contacté le support',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _openContactTab(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5592F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Contacter le support'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.supportTickets.length,
      itemBuilder: (context, index) {
        final ticket = provider.supportTickets[index];
        return _buildTicketCard(ticket);
      },
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final statusColors = {
      'open': Colors.orange,
      'in_progress': Colors.blue,
      'resolved': Colors.green,
      'closed': Colors.grey,
    };
    final statusColor = statusColors[ticket['status']] ?? Colors.grey;
    final statusText = {
      'open': 'Ouvert',
      'in_progress': 'En cours',
      'resolved': 'Résolu',
      'closed': 'Fermé',
    }[ticket['status']] ?? 'Inconnu';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => _viewTicket(ticket['id']),
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
                    'Ticket #${ticket['id']}',
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
              Text(
                ticket['subject'],
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                ticket['message'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Dernière mise à jour: ${ticket['updated_at']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactTab(SupportProvider provider, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact options
          Row(
            children: [
              Expanded(
                child: _buildContactOption(
                  icon: Icons.chat,
                  title: 'Chat en direct',
                  subtitle: 'Réponse immédiate',
                  color: const Color(0xFFE5592F),
                  onTap: () => _startLiveChat(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactOption(
                  icon: Icons.email,
                  title: 'Email',
                  subtitle: 'support@thix.com',
                  color: Colors.blue,
                  onTap: () => _sendEmail(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildContactOption(
                  icon: Icons.phone,
                  title: 'Téléphone',
                  subtitle: '+243 97 07 07 07 07',
                  color: Colors.green,
                  onTap: () => _makePhoneCall(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactOption(
    icon: Icons.message, // ✅ ou Icons.chat
    title: 'WhatsApp',
    subtitle: 'Support 24/7',
    color: Colors.green,
    onTap: () => _openWhatsApp(),
  ),
),
            ],
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          
          // Create ticket form
          const Text(
            'Ouvrir un ticket',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Catégorie',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: 'general', child: Text('Général')),
              const DropdownMenuItem(value: 'account', child: Text('Problème de compte')),
              const DropdownMenuItem(value: 'payment', child: Text('Problème de paiement')),
              const DropdownMenuItem(value: 'order', child: Text('Problème de commande')),
              const DropdownMenuItem(value: 'seller', child: Text('Problème vendeur')),
            ],
            onChanged: (value) {
              setState(() => _selectedCategory = value!);
            },
          ),
          const SizedBox(height: 16),
          
          TextField(
            decoration: const InputDecoration(
              labelText: 'Sujet',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Décrivez votre problème en détail...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          // File attachment
          OutlinedButton.icon(
            onPressed: () => _attachFile(),
            icon: const Icon(Icons.attach_file),
            label: const Text('Joindre un fichier'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _submitTicket(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5592F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Envoyer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Rules section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📖 Règlement intérieur',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Soyez respectueux envers les autres utilisateurs\n'
                  '• Les transactions doivent respecter les lois en vigueur\n'
                  '• Les produits contrefaits sont interdits\n'
                  '• Les données personnelles sont protégées\n'
                  '• En cas de litige, la médiation THIX est disponible',
                  style: TextStyle(color: Colors.grey[700], height: 1.5),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _viewFullRules(),
                  child: const Text('Lire le règlement complet →'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Report problem
          OutlinedButton.icon(
            onPressed: () => _reportProblem(),
            icon: const Icon(Icons.flag, color: Colors.red),
            label: const Text('Signaler un problème', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openContactTab() {
    // Switch to contact tab
  }

  void _viewTicket(String ticketId) {
    Navigator.pushNamed(context, '/ticket/$ticketId');
  }

  void _startLiveChat() {
    Navigator.pushNamed(context, '/live-chat');
  }

  void _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@thix.com',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _makePhoneCall() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+2250707070707');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _openWhatsApp() async {
    final Uri whatsappUri = Uri(
      scheme: 'https',
      path: 'wa.me/2250707070707',
    );
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    }
  }

  void _attachFile() {
    // Implement file picker
  }

  void _submitTicket() {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un message')),
      );
      return;
    }
    
    context.read<SupportProvider>().createTicket(
      _selectedCategory,
      _messageController.text,
    );
    
    _messageController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ticket envoyé avec succès')),
    );
  }

  void _viewFullRules() {
    Navigator.pushNamed(context, '/rules');
  }

  void _reportProblem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler un problème'),
        content: const Text(
          'Décrivez le problème que vous rencontrez.\n'
          'Un agent vous contactera dans les plus brefs délais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Problème signalé, merci !')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5592F),
            ),
            child: const Text('Signaler'),
          ),
        ],
      ),
    );
  }
}
