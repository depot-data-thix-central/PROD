// lib/presentation/chat/status/status_viewer_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:thix_id/models/chat/user_status_story.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/presentation/chat/status/create_status_page.dart';

class StatusViewerPage extends ConsumerStatefulWidget {
  final List<UserStatusStory> stories;

  const StatusViewerPage({super.key, required this.stories});

  @override
  ConsumerState<StatusViewerPage> createState() => _StatusViewerPageState();
}

class _StatusViewerPageState extends ConsumerState<StatusViewerPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  late AnimationController _progress;
  int _index = 0;
  bool _paused = false;

  static const _textDuration = Duration(seconds: 5);
  static const _imageDuration = Duration(seconds: 7);

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _progress = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markCurrent();
      _startProgress();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Duration get _currentDuration {
    if (widget.stories.isEmpty) return _textDuration;
    final s = widget.stories[_index];
    return s.isImage ? _imageDuration : _textDuration;
  }

  void _startProgress() {
    if (_paused || widget.stories.isEmpty) return;
    _progress.duration = _currentDuration;
    _progress.forward(from: 0);
  }

  void _pause() {
    _paused = true;
    _progress.stop();
  }

  void _resume() {
    _paused = false;
    _progress.forward();
  }

  void _next() {
    if (_index < widget.stories.length - 1) {
      setState(() => _index++);
      _pageCtrl.jumpToPage(_index);
      _markCurrent();
      _startProgress();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _pageCtrl.jumpToPage(_index);
      _markCurrent();
      _startProgress();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _markCurrent() {
    if (widget.stories.isEmpty) return;
    final s = widget.stories[_index];
    if (!s.isMine && !s.hasViewed) {
      ref.read(statusProvider.notifier).markViewed(s.statusId);
    }
  }

  Color _parseBg(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF1D4ED8);
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'À l’instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24 && local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    if (diff.inHours < 48) {
      return 'Hier ${DateFormat('HH:mm').format(local)}';
    }
    return DateFormat('dd/MM HH:mm').format(local);
  }

  Future<void> _delete() async {
    final s = widget.stories[_index];
    if (!s.isMine) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce statut ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(statusServiceProvider).deleteStatus(s.statusId);
    await ref.read(statusProvider.notifier).refresh();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _react(String emoji) async {
    final s = widget.stories[_index];
    await ref.read(statusServiceProvider).react(s.statusId, emoji);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Réaction $emoji envoyée'),
        duration: const Duration(milliseconds: 800),
        backgroundColor: Colors.black87,
      ),
    );
  }

  Future<void> _repost() async {
    final s = widget.stories[_index];
    final id = await ref.read(statusServiceProvider).repost(s);
    await ref.read(statusProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(id != null ? 'Statut republié' : 'Erreur repost'),
        backgroundColor: id != null ? Colors.green : Colors.red,
      ),
    );
  }

  void _edit() {
    final s = widget.stories[_index];
    if (!s.isMine) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateStatusPage()),
    );
  }

  Future<void> _showViewers(String statusId) async {
    _pause();
    final viewers = await ref.read(statusServiceProvider).getViewers(statusId);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Vu par ${viewers.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: viewers.isEmpty
                      ? const Center(
                          child: Text(
                            'Personne n’a encore vu ce statut',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: viewers.length,
                          itemBuilder: (_, i) {
                            final v = viewers[i];
                            final name =
                                v['display_name']?.toString() ?? 'Utilisateur';
                            final avatar = v['avatar_url']?.toString();
                            final viewedAt =
                                DateTime.tryParse('${v['viewed_at']}')
                                    ?.toLocal();
                            final time = viewedAt != null
                                ? DateFormat('HH:mm').format(viewedAt)
                                : '';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatar != null &&
                                        avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar == null || avatar.isEmpty
                                    ? Text(name.isNotEmpty ? name[0] : '?')
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Text(
                                time,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) _resume();
  }

  @override
  Widget build(BuildContext context) {
    final stories = widget.stories;
    if (stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Aucun statut', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final current = stories[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.localPosition.dx < w / 3) {
            _prev();
          } else if (d.localPosition.dx > 2 * w / 3) {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Contenu
            PageView.builder(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stories.length,
              itemBuilder: (_, i) {
                final s = stories[i];
                if (s.isImage && s.mediaUrl != null) {
                  return Image.network(s.mediaUrl!, fit: BoxFit.contain);
                }
                return Container(
                  color: _parseBg(s.background),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    s.content ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                );
              },
            ),

            // Top
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: [
                    Row(
                      children: List.generate(stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (_, __) {
                                double value = 0;
                                if (i < _index) value = 1;
                                if (i == _index) value = _progress.value;
                                return LinearProgressIndicator(
                                  value: value,
                                  minHeight: 3,
                                  backgroundColor: Colors.white30,
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: current.avatarUrl != null
                              ? NetworkImage(current.avatarUrl!)
                              : null,
                          child: current.avatarUrl == null
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.isMine
                                    ? 'Mon statut'
                                    : current.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _formatTime(current.createdAt),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (current.isMine)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
                            color: Colors.white,
                            onSelected: (v) {
                              if (v == 'edit') _edit();
                              if (v == 'delete') _delete();
                              if (v == 'views') {
                                _showViewers(current.statusId);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'views',
                                child: Text('Voir les vues'),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Modifier'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Supprimer',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom actions
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      if (current.isMine)
                        TextButton.icon(
                          onPressed: () => _showViewers(current.statusId),
                          icon: const Icon(Icons.visibility,
                              color: Colors.white70, size: 18),
                          label: const Text(
                            'Vus',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      _ReactBtn('❤️', () => _react('❤️')),
                      _ReactBtn('👍', () => _react('👍')),
                      _ReactBtn('😂', () => _react('😂')),
                      _ReactBtn('🔥', () => _react('🔥')),
                      _ReactBtn('😮', () => _react('😮')),
                      const Spacer(),
                      if (!current.isMine)
                        TextButton.icon(
                          onPressed: _repost,
                          icon: const Icon(Icons.repeat,
                              color: Colors.white, size: 18),
                          label: const Text(
                            'Repost',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactBtn extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;
  const _ReactBtn(this.emoji, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}
