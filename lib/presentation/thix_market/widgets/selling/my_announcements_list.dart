// lib/presentation/thix_market/widgets/my_announcements_list.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyAnnouncementsList extends StatefulWidget {
  final String shopId;
  final Function(Map<String, dynamic>)? onEdit;
  final Function(String)? onDelete;

  const MyAnnouncementsList({
    super.key,
    required this.shopId,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<MyAnnouncementsList> createState() => _MyAnnouncementsListState();
}

class _MyAnnouncementsListState extends State<MyAnnouncementsList> {
  static const Color navy = Color(0xFF1B2A4A);
  static const Color gold = Color(0xFFC9962C);
  static const Color bgApp = Color(0xFFF6F7FB);
  static const Color textMuted = Color(0xFF8A8FA3);
  static const Color danger = Color(0xFFE53935);

  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var query = Supabase.instance.client
          .from('products')
          .select()
          .eq('shop_id', widget.shopId);

      if (_filter == 'active') {
        query = query.eq('status', 'active').gt('stock', 0);
      } else if (_filter == 'pending') {
        query = query.eq('status', 'pending');
      } else if (_filter == 'sold_out') {
        query = query.eq('stock', 0);
      }

      final response = await query.order('created_at', ascending: false);

      setState(() {
        _announcements = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger vos annonces';
      });
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'annonce'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette annonce ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: danger)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.from('products').delete().eq('id', id);

      widget.onDelete?.call(id);
      await _loadAnnouncements();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annonce supprimée')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> announcement) async {
    final newStatus = announcement['status'] == 'active' ? 'inactive' : 'active';

    try {
      await Supabase.instance.client
          .from('products')
          .update({'status': newStatus})
          .eq('id', announcement['id']);

      await _loadAnnouncements();
    } catch (e) {
      debugPrint('Error toggling status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tous', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('En ligne', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('En attente', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Épuisés', 'sold_out'),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: gold))
              : _error != null
                  ? _buildErrorState()
                  : _announcements.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: gold,
                          onRefresh: _loadAnnouncements,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            itemCount: _announcements.length,
                            itemBuilder: (context, index) => _buildAnnouncementCard(_announcements[index]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      selected: selected,
      onSelected: (s) {
        setState(() => _filter = value);
        _loadAnnouncements();
      },
      backgroundColor: bgApp,
      selectedColor: navy.withOpacity(0.1),
      checkmarkColor: navy,
      labelStyle: TextStyle(color: selected ? navy : textMuted),
      side: BorderSide(color: selected ? navy.withOpacity(0.3) : Colors.grey[200]!),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final isActive = announcement['status'] == 'active';
    final stock = announcement['stock'] ?? 0;
    final price = announcement['price'];
    final discountPrice = announcement['discount_price'];
    final hasDiscount = discountPrice != null && price != null && discountPrice < price;
    final currency = announcement['currency'] ?? 'FC';
    final city = announcement['city'] as String?;
    final isFlash = announcement['is_flash_sale'] == true;
    final isFeatured = announcement['is_featured'] == true;

    final images = announcement['images'] as List?;
    final imageUrl = (images != null && images.isNotEmpty)
        ? images.first as String?
        : announcement['image_url'] as String?;

    final title = (announcement['title'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: navy.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (imageUrl == null || imageUrl.trim().isEmpty)
                        ? Container(
                            width: 84,
                            height: 84,
                            color: bgApp,
                            child: Icon(Icons.image_outlined, color: textMuted, size: 26),
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 84,
                              height: 84,
                              color: bgApp,
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: gold),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 84,
                              height: 84,
                              color: bgApp,
                              child: Icon(Icons.image_not_supported_outlined, color: textMuted, size: 24),
                            ),
                          ),
                  ),
                  if (isFlash)
                    Positioned(
                      top: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(5)),
                        child: const Text('FLASH', style: TextStyle(color: Color(0xFF10192E), fontSize: 7, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (title == null || title.isEmpty) ? 'Sans titre' : title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1A1D29)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${((hasDiscount ? discountPrice : price) ?? 0).toInt()} $currency',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: navy),
                        ),
                        if (hasDiscount)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              '${price.toInt()} $currency',
                              style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey[500], fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _badge(
                          isActive ? 'En ligne' : (stock == 0 ? 'Épuisé' : 'Inactif'),
                          isActive ? Colors.green : (stock == 0 ? danger : Colors.orange),
                        ),
                        if (isFeatured) _badge('Mis en avant', gold),
                        _pill('Stock: $stock'),
                        _pill('Vues: ${announcement['views'] ?? 0}'),
                        if (city != null && city.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded, size: 11, color: textMuted),
                              const SizedBox(width: 2),
                              Text(city, style: const TextStyle(fontSize: 11, color: textMuted)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onEdit?.call(announcement),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Modifier', style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navy,
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _toggleStatus(announcement),
                  icon: Icon(isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 17),
                  label: Text(isActive ? 'Désactiver' : 'Activer', style: const TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navy,
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteAnnouncement(announcement['id']),
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: const Text('Supprimer', style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: danger,
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _pill(String label) {
    return Text(label, style: const TextStyle(fontSize: 11, color: textMuted));
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 14),
          Text(_error ?? 'Une erreur est survenue', style: const TextStyle(fontSize: 14, color: textMuted)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loadAnnouncements,
            child: const Text('Réessayer', style: TextStyle(color: gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Aucune annonce', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1D29))),
          const SizedBox(height: 6),
          Text('Publiez votre première annonce', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }
}
