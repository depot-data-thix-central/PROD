import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/presentation/network/widgets/create_post_dialog.dart';
import 'package:thix_id/services/network_service.dart';

class FeedPage extends StatefulWidget {
  final String profileId;

  const FeedPage({
    super.key,
    required this.profileId,
  });

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final List<NetworkPost> _posts = [];

  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;

  static const int _pageSize = 20;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Rafraîchissement automatique toutes les 90 secondes
  /// (au lieu de 10 secondes → forte réduction de la consommation data)
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) {
        if (mounted && !_loading) {
          _loadInitial();
        }
      },
    );
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _page = 0;
      _hasMore = true;
    });

    try {
      final svc = context.read<NetworkService>();

      final items = await svc.getFeedPosts(
        limit: _pageSize,
        start: 0,
      );

      if (!mounted) return;

      setState(() {
        _posts
          ..clear()
          ..addAll(items);
        _page = 1;
        _hasMore = items.length >= _pageSize;
      });
    } catch (e) {
      debugPrint('FeedPage _loadInitial error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;

    setState(() {
      _loading = true;
    });

    try {
      final svc = context.read<NetworkService>();

      final items = await svc.getFeedPosts(
        limit: _pageSize,
        start: _page * _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _posts.addAll(items);
        _page++;
        _hasMore = items.length >= _pageSize;
      });
    } catch (e) {
      debugPrint('FeedPage _loadMore error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (_loading || !_hasMore) return false;

    final metrics = notification.metrics;

    if (metrics.pixels >= metrics.maxScrollExtent - 200) {
      _loadMore();
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fil d\'actualité'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const CreatePostDialog(),
          ).then((_) {
            if (mounted) {
              _loadInitial();
            }
          });
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _posts.length + 1,
            itemBuilder: (context, index) {
              if (index >= _posts.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : !_hasMore
                            ? const Text('Fin du fil')
                            : const SizedBox.shrink(),
                  ),
                );
              }

              final post = _posts[index];

              return PostCard(
                post: post,
                currentProfileId: widget.profileId,
              );
            },
          ),
        ),
      ),
    );
  }
}
