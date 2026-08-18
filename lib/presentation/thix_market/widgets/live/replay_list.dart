// lib/presentation/thix_market/widgets/live/replay_list.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReplayList extends StatefulWidget {
  final String? shopId;
  final Function(Map<String, dynamic>)? onReplayTap;

  const ReplayList({super.key, this.shopId, this.onReplayTap});

  @override
  State<ReplayList> createState() => _ReplayListState();
}

class _ReplayListState extends State<ReplayList> {
  List<Map<String, dynamic>> _replays = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 0;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReplays();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        _loadReplays();
      }
    }
  }

  Future<void> _loadReplays() async {
    setState(() => _isLoading = true);

    try {
      var query = Supabase.instance.client
          .from('lives')
          .select('*, shop:shops(name, logo_url)')
          .eq('status', 'ended');

      if (widget.shopId != null) {
        query = query.eq('shop_id', widget.shopId!);
      }

      final response = await query
          .order('ended_at', ascending: false)
          .range(_page * _limit, (_page + 1) * _limit - 1);

      final List<Map<String, dynamic>> newReplays = List<Map<String, dynamic>>.from(response);

      setState(() {
        if (newReplays.length < _limit) _hasMore = false;
        _replays.addAll(newReplays);
        _page++;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading replays: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '00:00';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _replays.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_replays.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Aucun replay disponible', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _replays.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _replays.length) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }
        return _buildReplayCard(_replays[index]);
      },
    );
  }

  Widget _buildReplayCard(Map<String, dynamic> replay) {
    return GestureDetector(
      onTap: () => widget.onReplayTap?.call(replay),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Web-Safe
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Image.network(
                replay['thumbnail_url'] ?? '',
                width: 120,
                height: 100,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 120,
                    height: 100,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 100,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      replay['title'] ?? 'Live replay',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundImage: replay['shop']?['logo_url'] != null
                              ? NetworkImage(replay['shop']['logo_url'])
                              : null,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            replay['shop']?['name'] ?? 'Boutique',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(
                          '${replay['viewer_count'] ?? 0} vues',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(
                          _formatDuration(replay['duration_seconds']),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(replay['ended_at'] ?? replay['created_at']),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
            // Play icon
            Container(
              margin: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFE5592F),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}
