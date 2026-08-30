// lib/presentation/thix_market/pages/help_support_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../providers/support_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const Duration _kSearchDebounce = Duration(milliseconds: 300);
const int _kMaxSubjectLength = 100;
const int _kMaxMessageLength = 2000;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _SupportValidators {
  _SupportValidators._();

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

  static bool isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https' || 
           uri.scheme == 'mailto' || uri.scheme == 'tel';
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 1,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Support] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Support] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Support] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TabController _tabController = TabController(length: 3, vsync: null);
  
  Timer? _searchDebounceTimer;
  String _selectedCategory = 'general';
  bool _submittingTicket = false;

  static const List<Map<String, dynamic>> _faqCategories = [
    {'id': 'general', 'name': 'Général', 'icon': Icons.help_outline_rounded},
    {'id': 'account', 'name': 'Compte', 'icon': Icons.person_outline_rounded},
    {'id': 'payment', 'name': 'Paiements', 'icon': Icons.payment_rounded},
    {'id': 'shipping', 'name': 'Livraison', 'icon': Icons.local_shipping_rounded},
    {'id': 'selling', 'name': 'Vendre', 'icon': Icons.store_rounded},
    {'id': 'disputes', 'name': 'Litiges', 'icon': Icons.gavel_rounded},
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('[Support] 🎧 Page opened');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final provider = context.read<SupportProvider>();

    try {
      await Future.wait([
        _withRetry(() => provider.loadFAQs(), label: 'loadFAQs'),
        _withRetry(() => provider.loadSupportTickets(), label: 'loadTickets'),
      ]);
      debugPrint('[Support] ✓ Initial data loaded');
    } catch (e) {
      debugPrint('[Support] ❌ Load error: $e');
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _messageController.dispose();
    _subjectController.dispose();
    _searchController.dispose();
    debugPrint('[Support] 👋 Page disposed');
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_kSearchDebounce, () {
      if (!mounted) return;
      final sanitized = _SupportValidators.sanitize(query, maxLength: 100);
      context.read<SupportProvider>().searchFAQs(sanitized);
      debugPrint('[Support] 🔍 Search: "$sanitized"');
    });
  }

  void _switchToContactTab() {
    HapticFeedback.selectionClick();
    // TabController non accessible depuis Stateful, utiliser DefaultTabController
    DefaultTabController.of(context).animateTo(2);
    debugPrint('[Support] 📞 Switched to contact tab');
  }

  @override
  Widget build(BuildContext context) {
    final supportProvider = context.watch<SupportProvider>();

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          'Aide & Support',
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
            Navigator.pop(context);
          },
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                label: 'Rechercher dans l\'aide',
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                    boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain),
                    decoration: InputDecoration(
                      hintText: 'Rechercher dans l\'aide...',
                      hintStyle: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ),

            // Tabs
            TabBar(
              tabs: const [
                Tab(text: 'FAQ'),
                Tab(text: 'Mes tickets'),
                Tab(text: 'Contacter'),
              ],
              indicatorColor: ThixPolicy.primary,
              labelColor: ThixPolicy.primary,
              unselectedLabelColor: ThixPolicy.textSecondary,
              labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
            ),

            Expanded(
              child: TabBarView(
                children: [
                  _buildFAQTab(supportProvider),
                  _buildTicketsTab(supportProvider),
                  _buildContactTab(supportProvider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB 1 : FAQ
  // ============================================================
  Widget _buildFAQTab(SupportProvider provider) {
    if (provider.isLoading) {
      return const _SkeletonFAQ();
    }

    return Column(
      children: [
        // Categories
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _faqCategories.length,
            itemBuilder: (context, index) {
              final category = _faqCategories[index];
              final isSelected = _selectedCategory == category['id'];
              return Semantics(
                button: true,
                label: 'Catégorie ${category['name']}',
                selected: isSelected,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = category['id']);
                    provider.loadFAQs(category: category['id']);
                    debugPrint('[Support] 📂 Category: ${category['id']}');
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? ThixPolicy.primary : ThixPolicy.card,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected ? null : Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                      boxShadow: isSelected ? ThixPolicy.shadowSoft(opacity: 0.1) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          category['icon'] as IconData,
                          color: isSelected ? Colors.white : ThixPolicy.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category['name'],
                          style: ThixPolicy.labelStyle.copyWith(
                            color: isSelected ? Colors.white : ThixPolicy.textMuted,
                            fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.regular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // FAQs list
        Expanded(
          child: provider.filteredFAQs.isEmpty
              ? _EmptyFAQ()
              : RefreshIndicator(
                  color: ThixPolicy.primary,
                  onRefresh: () async {
                    HapticFeedback.selectionClick();
                    await _withRetry(
                      () => provider.loadFAQs(category: _selectedCategory),
                      label: 'refreshFAQs',
                    );
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.filteredFAQs.length,
                    itemBuilder: (context, index) {
                      final faq = provider.filteredFAQs[index];
                      return _FAQItem(faq: faq);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ============================================================
  // TAB 2 : TICKETS
  // ============================================================
  Widget _buildTicketsTab(SupportProvider provider) {
    if (provider.isLoadingTickets) {
      return const _SkeletonList();
    }

    if (provider.supportTickets.isEmpty) {
      return _EmptyTickets(onContact: _switchToContactTab);
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: () async {
        HapticFeedback.selectionClick();
        await _withRetry(() => provider.loadSupportTickets(), label: 'refreshTickets');
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.supportTickets.length,
        itemBuilder: (context, index) {
          final ticket = provider.supportTickets[index];
          return _TicketCard(
            ticket: ticket,
            onTap: () => _viewTicket(ticket['id']?.toString() ?? ''),
          );
        },
      ),
    );
  }

  // ============================================================
  // TAB 3 : CONTACT
  // ============================================================
  Widget _buildContactTab(SupportProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact options
          Row(
            children: [
              Expanded(
                child: _ContactOption(
                  icon: Icons.chat_rounded,
                  title: 'Chat en direct',
                  subtitle: 'Réponse immédiate',
                  color: ThixPolicy.primary,
                  onTap: _startLiveChat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactOption(
                  icon: Icons.email_rounded,
                  title: 'Email',
                  subtitle: 'support@thix.com',
                  color: ThixPolicy.primary,
                  onTap: _sendEmail,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ContactOption(
                  icon: Icons.phone_rounded,
                  title: 'Téléphone',
                  subtitle: '+243 97 07 07 07 07',
                  color: ThixPolicy.success,
                  onTap: _makePhoneCall,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactOption(
                  icon: Icons.message_rounded,
                  title: 'WhatsApp',
                  subtitle: 'Support 24/7',
                  color: ThixPolicy.success,
                  onTap: _openWhatsApp,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Divider(color: ThixPolicy.border),
          const SizedBox(height: 24),

          // Create ticket form
          Text(
            'Ouvrir un ticket',
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          const SizedBox(height: 16),

          _CategoryDropdown(
            value: _selectedCategory,
            onChanged: (v) => setState(() => _selectedCategory = v ?? 'general'),
          ),
          const SizedBox(height: 16),

          _InputField(
            controller: _subjectController,
            label: 'Sujet',
            maxLength: _kMaxSubjectLength,
          ),
          const SizedBox(height: 16),

          _InputField(
            controller: _messageController,
            label: 'Message',
            hint: 'Décrivez votre problème en détail...',
            maxLines: 5,
            maxLength: _kMaxMessageLength,
          ),
          const SizedBox(height: 16),

          // File attachment (placeholder)
          Semantics(
            button: true,
            label: 'Joindre un fichier',
            child: OutlinedButton.icon(
              onPressed: _attachFile,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Joindre un fichier'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: ThixPolicy.border),
                foregroundColor: ThixPolicy.textMain,
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submittingTicket ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submittingTicket
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Envoyer',
                      style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16, color: Colors.white),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Rules section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: ThixPolicy.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Règlement intérieur',
                      style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Soyez respectueux envers les autres utilisateurs\n'
                  '• Les transactions doivent respecter les lois en vigueur\n'
                  '• Les produits contrefaits sont interdits\n'
                  '• Les données personnelles sont protégées\n'
                  '• En cas de litige, la médiation THIX est disponible',
                  style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: 'Lire le règlement complet',
                  child: TextButton(
                    onPressed: _viewFullRules,
                    child: const Text('Lire le règlement complet →'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Report problem
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _reportProblem,
              icon: const Icon(Icons.flag_rounded, color: ThixPolicy.danger),
              label: Text(
                'Signaler un problème',
                style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ThixPolicy.danger),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================
  void _viewTicket(String ticketId) {
    if (!_SupportValidators.isValidUrl(ticketId)) {
      debugPrint('[Support] ⚠️ Invalid ticket ID: $ticketId');
      return;
    }
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, '/ticket/$ticketId');
    debugPrint('[Support] 🎫 View ticket $ticketId');
  }

  void _startLiveChat() {
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, '/live-chat');
    debugPrint('[Support] 💬 Start live chat');
  }

  Future<void> _sendEmail() async {
    HapticFeedback.mediumImpact();
    final emailUri = Uri(scheme: 'mailto', path: 'support@thix.com');
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        debugPrint('[Support] 📧 Email launched');
      } else {
        _showError('Aucune application email trouvée');
      }
    } catch (e) {
      debugPrint('[Support] ❌ Email error: $e');
      _showError('Erreur lors de l\'ouverture de l\'email');
    }
  }

  Future<void> _makePhoneCall() async {
    HapticFeedback.mediumImpact();
    final phoneUri = Uri(scheme: 'tel', path: '+243970707070');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        debugPrint('[Support] 📞 Phone launched');
      } else {
        _showError('Aucune application téléphone trouvée');
      }
    } catch (e) {
      debugPrint('[Support] ❌ Phone error: $e');
      _showError('Erreur lors de l\'appel');
    }
  }

  Future<void> _openWhatsApp() async {
    HapticFeedback.mediumImpact();
    final whatsappUri = Uri.parse('https://wa.me/243970707070');
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        debugPrint('[Support] 💬 WhatsApp launched');
      } else {
        _showError('WhatsApp non installé');
      }
    } catch (e) {
      debugPrint('[Support] ❌ WhatsApp error: $e');
      _showError('Erreur lors de l\'ouverture de WhatsApp');
    }
  }

  void _attachFile() {
    HapticFeedback.selectionClick();
    _showInfo('Fonctionnalité en développement');
    debugPrint('[Support] 📎 Attach file (TODO)');
  }

  Future<void> _submitTicket() async {
    if (_submittingTicket) return;

    final subject = _SupportValidators.sanitize(_subjectController.text, maxLength: _kMaxSubjectLength);
    final message = _SupportValidators.sanitize(_messageController.text, maxLength: _kMaxMessageLength);

    if (subject.isEmpty) {
      _showError('Veuillez entrer un sujet');
      return;
    }
    if (message.isEmpty) {
      _showError('Veuillez entrer un message');
      return;
    }

    setState(() => _submittingTicket = true);
    HapticFeedback.mediumImpact();

    try {
      await _withRetry(
        () => context.read<SupportProvider>().createTicket(_selectedCategory, subject, message),
        label: 'createTicket',
      );

      _subjectController.clear();
      _messageController.clear();
      debugPrint('[Support] ✅ Ticket created');

      if (mounted) {
        _showSuccess('Ticket envoyé avec succès');
        // Switch to tickets tab
        DefaultTabController.of(context).animateTo(1);
      }
    } catch (e) {
      debugPrint('[Support] ❌ Create ticket error: $e');
      if (mounted) _showError('Erreur lors de l\'envoi du ticket');
    } finally {
      if (mounted) setState(() => _submittingTicket = false);
    }
  }

  void _viewFullRules() {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, '/rules');
    debugPrint('[Support] 📖 View full rules');
  }

  Future<void> _reportProblem() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flag_rounded, color: ThixPolicy.danger, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Signaler un problème', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: Text(
          'Décrivez le problème que vous rencontrez.\nUn agent vous contactera dans les plus brefs délais.',
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Signaler'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _showSuccess('Problème signalé, merci !');
      debugPrint('[Support] 🚩 Problem reported');
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

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _FAQItem extends StatelessWidget {
  final Map<String, dynamic> faq;
  const _FAQItem({required this.faq});

  @override
  Widget build(BuildContext context) {
    final question = _SupportValidators.sanitize(faq['question']?.toString() ?? '', maxLength: 200);
    final answer = _SupportValidators.sanitize(faq['answer']?.toString() ?? '', maxLength: 1000);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                answer,
                style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  static const Map<String, Color> _statusColors = {
    'open': ThixPolicy.gold,
    'in_progress': ThixPolicy.primary,
    'resolved': ThixPolicy.success,
    'closed': ThixPolicy.textMuted,
  };

  static const Map<String, String> _statusLabels = {
    'open': 'Ouvert',
    'in_progress': 'En cours',
    'resolved': 'Résolu',
    'closed': 'Fermé',
  };

  @override
  Widget build(BuildContext context) {
    final id = ticket['id']?.toString() ?? '';
    final status = ticket['status']?.toString() ?? 'open';
    final statusColor = _statusColors[status] ?? ThixPolicy.textMuted;
    final statusText = _statusLabels[status] ?? 'Inconnu';
    final subject = _SupportValidators.sanitize(ticket['subject']?.toString() ?? '', maxLength: 100);
    final message = _SupportValidators.sanitize(ticket['message']?.toString() ?? '', maxLength: 200);
    final updatedAt = _SupportValidators.sanitize(ticket['updated_at']?.toString() ?? '', maxLength: 30);

    return Semantics(
      button: true,
      label: 'Ticket $id, statut $statusText, sujet $subject',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
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
                      'Ticket #$id',
                      style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16, color: ThixPolicy.textMain),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: ThixPolicy.captionStyle.copyWith(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: ThixPolicy.semiBold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subject,
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: ThixPolicy.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Dernière mise à jour: $updatedAt',
                      style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: 'Catégorie',
        labelStyle: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted),
        filled: true,
        fillColor: ThixPolicy.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: BorderSide(color: ThixPolicy.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: BorderSide(color: ThixPolicy.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
        ),
      ),
      dropdownColor: ThixPolicy.card,
      items: const [
        DropdownMenuItem(value: 'general', child: Text('Général')),
        DropdownMenuItem(value: 'account', child: Text('Problème de compte')),
        DropdownMenuItem(value: 'payment', child: Text('Problème de paiement')),
        DropdownMenuItem(value: 'order', child: Text('Problème de commande')),
        DropdownMenuItem(value: 'seller', child: Text('Problème vendeur')),
      ],
      onChanged: onChanged,
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final int? maxLength;

  const _InputField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted),
        hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
        filled: true,
        fillColor: ThixPolicy.card,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: BorderSide(color: ThixPolicy.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: BorderSide(color: ThixPolicy.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _EmptyFAQ extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.help_outline_rounded, size: 64, color: ThixPolicy.textDisabled),
          const SizedBox(height: 16),
          Text(
            'Aucune FAQ trouvée',
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez une autre catégorie ou recherche',
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyTickets extends StatelessWidget {
  final VoidCallback onContact;
  const _EmptyTickets({required this.onContact});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, size: 64, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun ticket de support',
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous n\'avez pas encore contacté le support',
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Contacter le support',
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onContact();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Contacter le support', style: TextStyle(fontWeight: ThixPolicy.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonFAQ extends StatelessWidget {
  const _SkeletonFAQ();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Categories skeleton
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 6,
            itemBuilder: (_, __) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        // FAQs skeleton
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (_, __) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 200, color: Colors.grey.shade200),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 16, width: 100, color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Container(height: 10, width: 200, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }
}
