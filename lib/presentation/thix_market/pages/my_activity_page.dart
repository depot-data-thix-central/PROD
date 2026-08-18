import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/activity_provider.dart';

// ✅ CORRECTION ICI : Déclaration globale du provider Riverpod
// Il va encapsuler ton ancienne classe ActivityProvider pour la rendre compatible
final activityProvider = ChangeNotifierProvider<ActivityProvider>((ref) => ActivityProvider());

class MyActivityPage extends ConsumerStatefulWidget {
  const MyActivityPage({super.key});

  @override
  ConsumerState<MyActivityPage> createState() => _MyActivityPageState();
}

class _MyActivityPageState extends ConsumerState<MyActivityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Chargement initial via Riverpod
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(activityProvider);
      provider.loadPurchases();
      provider.loadSales();
      provider.loadRatings();
      provider.loadGlobalStats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Écoute réactive de l'état via Riverpod
    final provider = ref.watch(activityProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mon activité',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Achats'),
            Tab(text: 'Ventes'),
            Tab(text: 'Évaluations'),
          ],
          indicatorColor: const Color(0xFFE5592F),
          labelColor: const Color(0xFFE5592F),
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPurchasesTab(provider, theme),
          _buildSalesTab(provider, theme),
          _buildRatingsTab(provider, theme),
        ],
      ),
    );
  }

  Widget _buildPurchasesTab(ActivityProvider provider, ThemeData theme) {
    if (provider.isLoadingPurchases) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE5592F)));
    }

    if (provider.purchases.isEmpty) {
      return _buildEmptyState(
        'Aucun achat',
        'Vos commandes apparaîtront ici',
        Icons.shopping_bag_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.purchases.length,
      itemBuilder: (context, index) {
        final order = provider.purchases[index];
        return _buildOrderCard(order, isPurchase: true);
      },
    );
  }

  Widget _buildSalesTab(ActivityProvider provider, ThemeData theme) {
    if (provider.isLoadingSales) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE5592F)));
    }

    if (provider.sales.isEmpty) {
      return _buildEmptyState(
        'Aucune vente',
        'Vos ventes apparaîtront ici',
        Icons.sell_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.sales.length,
      itemBuilder: (context, index) {
        final order = provider.sales[index];
        return _buildOrderCard(order, isPurchase: false);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {required bool isPurchase}) {
    final statusColors = {
      'pending': Colors.orange,
      'processing': Colors.blue,
      'shipped': Colors.purple,
      'delivered': Colors.green,
      'cancelled': Colors.red,
      'refunded': Colors.grey,
    };
    final statusColor = statusColors[order['status']] ?? Colors.grey;
    final statusText = {
      'pending': 'En attente',
      'processing': 'En préparation',
      'shipped': 'Expédiée',
      'delivered': 'Livrée',
      'cancelled': 'Annulée',
      'refunded': 'Remboursée',
    }[order['status']] ?? 'Inconnu';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => context.push('/market/order/${order['id']}'),
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
                    'Commande #${order['id']}',
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
              const SizedBox(height: 12),
              ...(order['items'] as List).take(2).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item['image_url'] ?? '',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'Article inconnu',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item['quantity']} x ${item['price']} FCFA',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
              if ((order['items'] as List).length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'et ${(order['items'] as List).length - 2} autre(s) article(s)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        '${order['total']} FCFA',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFFE5592F),
                        ),
                      ),
                    ],
                  ),
                  if (order['status'] == 'delivered' && isPurchase)
                    OutlinedButton(
                      onPressed: () => _leaveReview(order['id']),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5592F)),
                      ),
                      child: const Text('Laisser un avis', style: TextStyle(color: Color(0xFFE5592F))),
                    ),
                  if (order['status'] == 'pending')
                    OutlinedButton(
                      onPressed: () => _cancelOrder(order['id']),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Annuler', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsTab(ActivityProvider provider, ThemeData theme) {
    final stats = provider.ratingStats;
    
    return Column(
      children: [
        // Rating summary
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Average rating
              Expanded(
                child: Column(
                  children: [
                    Text(
                      stats['average'].toString(),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE5592F),
                      ),
                    ),
                    RatingBar.builder(
                      initialRating: (stats['average'] ?? 0).toDouble(),
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 20,
                      ignoreGestures: true,
                      itemBuilder: (_, __) => const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      onRatingUpdate: (_) {},
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${stats['total']} évaluations',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Rating distribution
              Expanded(
                child: Column(
                  children: List.generate(5, (index) {
                    final star = 5 - index;
                    final percentage = stats['distribution'][star] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            '$star',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.grey[200],
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${percentage.toInt()}%',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        
        // Badges
        if (provider.badges.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mes badges',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: provider.badges.map<Widget>((badge) => _buildBadge(badge)).toList(),
                ),
              ],
            ),
          ),
        
        // Ratings list
        Expanded(
          child: provider.isLoadingRatings
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE5592F)))
              : provider.ratings.isEmpty
                  ? _buildEmptyState(
                      'Aucune évaluation',
                      'Les évaluations reçues apparaîtront ici',
                      Icons.star_border,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.ratings.length,
                      itemBuilder: (context, index) {
                        final rating = provider.ratings[index];
                        return _buildRatingCard(rating);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildRatingCard(Map<String, dynamic> rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: rating['user_avatar'] != null 
                      ? NetworkImage(rating['user_avatar']) 
                      : null,
                  child: rating['user_avatar'] == null
                      ? Icon(Icons.person, color: Colors.grey[400])
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating['user_name'] ?? 'Utilisateur',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      RatingBar.builder(
                        initialRating: (rating['rating'] ?? 0).toDouble(),
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 14,
                        ignoreGestures: true,
                        itemBuilder: (_, __) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        onRatingUpdate: (_) {},
                      ),
                    ],
                  ),
                ),
                Text(
                  rating['created_at'] != null 
                    ? DateFormat('dd/MM/yyyy').format(DateTime.parse(rating['created_at']))
                    : '',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(rating['comment'] ?? ''),
            if (rating['reply'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réponse du vendeur',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(rating['reply']),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(Map<String, dynamic> badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(badge['color_start']), Color(badge['color_end'])],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            badge['name'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

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
        ],
      ),
    );
  }

  void _leaveReview(String orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LeaveReviewSheet(orderId: orderId),
    );
  }

  void _cancelOrder(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la commande'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette commande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(activityProvider).cancelOrder(orderId);
            },
            child: const Text('Oui, annuler', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SHEET AVIS CLIENT MIGRÉ VERS CONSUMERSTATEFULWIDGET
// -----------------------------------------------------------------------------
class LeaveReviewSheet extends ConsumerStatefulWidget {
  final String orderId;
  const LeaveReviewSheet({super.key, required this.orderId});

  @override
  ConsumerState<LeaveReviewSheet> createState() => _LeaveReviewSheetState();
}

class _LeaveReviewSheetState extends ConsumerState<LeaveReviewSheet> {
  double _rating = 5;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Laisser un avis',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Note', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: _rating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemSize: 32,
            itemBuilder: (_, __) => const Icon(
              Icons.star,
              color: Colors.amber,
            ),
            onRatingUpdate: (rating) {
              setState(() => _rating = rating);
            },
          ),
          const SizedBox(height: 16),
          const Text('Commentaire', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Partagez votre expérience...',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5592F)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Utilisation de Riverpod pour envoyer la review
                    ref.read(activityProvider).submitReview(
                      widget.orderId,
                      _rating,
                      _commentController.text,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5592F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text('Envoyer', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
