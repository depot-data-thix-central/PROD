// lib/presentation/thix_market/widgets/live/live_auction_widget.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class LiveAuctionWidget extends StatefulWidget {
  final String auctionId;
  final Function(double)? onBidPlaced;

  const LiveAuctionWidget({super.key, required this.auctionId, this.onBidPlaced});

  @override
  State<LiveAuctionWidget> createState() => _LiveAuctionWidgetState();
}

class _LiveAuctionWidgetState extends State<LiveAuctionWidget> {
  Map<String, dynamic> _auction = {};
  List<Map<String, dynamic>> _bidHistory = [];
  bool _isLoading = true;
  bool _isBidding = false;
  final TextEditingController _bidController = TextEditingController();
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadAuction();
    _subscribeToBids();
  }

  @override
  void dispose() {
    _bidController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAuction() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await Supabase.instance.client
          .from('auctions')
          .select('*, product:products(*, shop:shops(name))')
          .eq('id', widget.auctionId)
          .single();
      
      setState(() {
        _auction = response;
        _isLoading = false;
      });
      
      await _loadBidHistory();
    } catch (e) {
      debugPrint('Error loading auction: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBidHistory() async {
    try {
      final response = await Supabase.instance.client
          .from('auction_bids')
          .select('*, user:users(name, avatar)')
          .eq('auction_id', widget.auctionId)
          .order('amount', ascending: false)
          .limit(20);
      
      setState(() {
        _bidHistory = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading bids: $e');
    }
  }

  void _subscribeToBids() {
    _channel = Supabase.instance.client
        .channel('auction_bids')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'auction_bids',
          callback: (payload) {
            final newBid = payload.newRecord;
            if (newBid['auction_id'] == widget.auctionId) {
              setState(() {
                _auction['current_bid'] = newBid['amount'];
                _auction['bid_count'] = (_auction['bid_count'] ?? 0) + 1;
                _bidHistory.insert(0, newBid);
                if (_bidHistory.length > 20) _bidHistory.removeLast();
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _placeBid() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showLoginRequired();
      return;
    }
    
    final bidAmount = double.tryParse(_bidController.text);
    if (bidAmount == null || bidAmount <= (_auction['current_bid'] ?? _auction['starting_price'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant invalide')),
      );
      return;
    }
    
    setState(() => _isBidding = true);
    
    try {
      await Supabase.instance.client
          .from('auction_bids')
          .insert({
            'auction_id': widget.auctionId,
            'user_id': userId,
            'amount': bidAmount,
            'created_at': DateTime.now().toIso8601String(),
          });
      
      _bidController.clear();
      widget.onBidPlaced?.call(bidAmount);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enchère placée !')),
      );
    } catch (e) {
      debugPrint('Error placing bid: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      setState(() => _isBidding = false);
    }
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connexion requise'),
        content: const Text('Veuillez vous connecter pour participer aux enchères'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5592F)),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  Duration _getTimeLeft() {
    final endTime = DateTime.parse(_auction['end_time']);
    return endTime.difference(DateTime.now());
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return 'Terminé';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final timeLeft = _getTimeLeft();
    final isEnded = timeLeft.isNegative;
    final product = _auction['product'] ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product info Web-Safe
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  product['image_url'] ?? '',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(product['shop']?['name'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Timer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isEnded ? Colors.grey[100] : const Color(0xFFE5592F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEnded ? 'Enchère terminée' : 'Temps restant',
                  style: TextStyle(color: isEnded ? Colors.grey : const Color(0xFFE5592F)),
                ),
                Text(
                  _formatDuration(timeLeft),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isEnded ? Colors.grey : const Color(0xFFE5592F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Current bid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Enchère actuelle', style: TextStyle(color: Colors.grey)),
              Text(
                '${_auction['current_bid']?.toInt() ?? _auction['starting_price']?.toInt() ?? 0} FCFA',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE5592F)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_auction['bid_count'] ?? 0} enchères',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          
          // Bid input
          if (!isEnded)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bidController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Votre enchère',
                      suffixText: 'FCFA',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isBidding ? null : _placeBid,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5592F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isBidding
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enchérir'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          
          // Bid history
          const Text('Historique des enchères', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.builder(
              itemCount: _bidHistory.length,
              itemBuilder: (context, index) {
                final bid = _bidHistory[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundImage: bid['user']?['avatar'] != null
                        ? NetworkImage(bid['user']['avatar'])
                        : null,
                    child: bid['user']?['avatar'] == null ? const Icon(Icons.person, size: 14) : null,
                  ),
                  title: Text(bid['user']?['name'] ?? 'Anonyme', style: const TextStyle(fontSize: 13)),
                  trailing: Text('${bid['amount'].toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
