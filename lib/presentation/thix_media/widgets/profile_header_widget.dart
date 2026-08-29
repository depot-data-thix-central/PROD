import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/services/media_service.dart';

class ProfileHeaderWidget extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Map<String, int> stats;
  final bool isFollowing;
  final bool isMe;
  final VoidCallback? onEditProfile;

  const ProfileHeaderWidget({
    super.key,
    required this.profile,
    required this.stats,
    required this.isFollowing,
    required this.isMe,
    this.onEditProfile,
  });

  @override
  State<ProfileHeaderWidget> createState() => _ProfileHeaderWidgetState();
}

class _ProfileHeaderWidgetState extends State<ProfileHeaderWidget> {
  late bool _isFollowing;
  late Map<String, int> _stats;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
    _stats = Map.from(widget.stats);
  }

  @override
  void didUpdateWidget(ProfileHeaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) {
      _isFollowing = widget.isFollowing;
    }
    if (oldWidget.stats != widget.stats) {
      _stats = Map.from(widget.stats);
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();

    final wasFollowing = _isFollowing;
    final previousCount = _stats['followers'] ?? 0;

    // ✅ Optimistic UI
    setState(() {
      _isFollowing = !_isFollowing;
      _stats['followers'] = _isFollowing ? previousCount + 1 : previousCount - 1;
      _busy = true;
    });

    try {
      await MediaService().toggleFollow(widget.profile['id'] as String);
    } catch (e) {
      // ✅ Rollback en cas d'échec
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _stats['followers'] = previousCount;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur réseau. Impossible de modifier l\'abonnement.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    if (mounted) setState(() => _busy = false);
  }

  String _getDisplayName() {
    final uname = widget.profile['username'] as String?;
    final fname = widget.profile['full_name'] as String?;
    if (fname != null && fname.trim().isNotEmpty) return fname.trim();
    if (uname != null && uname.trim().isNotEmpty) return uname.trim();
    return 'Utilisateur';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.profile['avatar_url'] as String?;
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    final bio = widget.profile['bio'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  image: hasAvatar
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasAvatar
                    ? const Icon(Icons.person_rounded, size: 40, color: Colors.white54)
                    : null,
              ),

              const SizedBox(width: 24),

              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TopStat(label: 'Publications', count: _stats['posts'] ?? 0),
                    Container(width: 1, height: 30, color: Colors.white.withOpacity(0.1)),
                    _TopStat(label: 'Abonnés', count: _stats['followers'] ?? 0),
                    Container(width: 1, height: 30, color: Colors.white.withOpacity(0.1)),
                    _TopStat(label: 'Suivis', count: _stats['following'] ?? 0),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Nom et bio
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayName(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${(widget.profile['username'] as String?)?.isNotEmpty == true ? widget.profile['username'] : 'utilisateur'}',
                  style: const TextStyle(
                    color: Color(0xFFAEB9D4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (bio != null && bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    bio,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bouton d'action
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _busy ? null : (widget.isMe ? widget.onEditProfile : _handleFollowToggle),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isMe
                    ? Colors.white.withOpacity(0.1)
                    : (_isFollowing ? Colors.white.withOpacity(0.1) : Colors.white),
                foregroundColor: widget.isMe
                    ? Colors.white
                    : (_isFollowing ? Colors.white : const Color(0xFF0A1F44)),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: widget.isMe || _isFollowing
                    ? BorderSide(color: Colors.white.withOpacity(0.15))
                    : BorderSide.none,
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.isMe ? 'Modifier le profil' : (_isFollowing ? 'Abonné' : 'Suivre'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  final String label;
  final int count;

  const _TopStat({required this.label, required this.count});

  String _format(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _format(count),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFAEB9D4),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
