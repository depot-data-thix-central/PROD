// lib/presentation/thix_media/widgets/profile_header_widget.dart
/// ProfileHeaderWidget (Production Enterprise)
///
/// - Design : Modern Sleek Light (Clair, épuré, ombres douces)
/// - Sécurité : Sanitization des URLs et textes via MediaSanitizer
/// - i18n : Textes de secours en cas d'absence de traduction
/// - UX : Optimistic UI pour le Follow/Unfollow, HapticFeedback

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/media_service.dart';

import '../thix_media_page.dart' show MediaLightPalette, MediaSanitizer, formatMediaNumber;

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

  String _safeTr(AppLocalizations l10n, String key, String fallback) {
    final val = l10n.t(key);
    if (val.isEmpty || val == key || val.contains(key)) return fallback;
    return val;
  }

  Future<void> _handleFollowToggle(AppLocalizations l10n) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();

    final wasFollowing = _isFollowing;
    final previousCount = _stats['followers'] ?? 0;

    // ✅ Optimistic UI
    setState(() {
      _isFollowing = !_isFollowing;
      _stats['followers'] = _isFollowing ? previousCount + 1 : (previousCount > 0 ? previousCount - 1 : 0);
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
            content: Text(_safeTr(l10n, 'profile_follow_error', 'Erreur réseau. Impossible de modifier l\'abonnement.')),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) setState(() => _busy = false);
  }

  String _getDisplayName(AppLocalizations l10n) {
    final uname = widget.profile['username'] as String?;
    final fname = widget.profile['full_name'] as String?;
    if (fname != null && fname.trim().isNotEmpty) return MediaSanitizer.text(fname, maxLength: 40);
    if (uname != null && uname.trim().isNotEmpty) return MediaSanitizer.text(uname, maxLength: 40);
    return _safeTr(l10n, 'detail_creator_default', 'Utilisateur');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatarUrl = MediaSanitizer.imageUrl(widget.profile['avatar_url'] as String?);
    final hasAvatar = avatarUrl != null;
    final bio = MediaSanitizer.text(widget.profile['bio'] as String?, maxLength: 250);
    
    final safeUsername = MediaSanitizer.text(widget.profile['username'] as String?, maxLength: 30);
    final displayUsername = safeUsername.isNotEmpty ? safeUsername : 'utilisateur';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 24), // 100 de padding-top pour compenser l'AppBar transparente
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
                  border: Border.all(color: MediaLightPalette.border, width: 2),
                  color: MediaLightPalette.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  image: hasAvatar
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasAvatar
                    ? const Icon(Icons.person_rounded, size: 40, color: MediaLightPalette.textMuted)
                    : null,
              ),

              const SizedBox(width: 24),

              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TopStat(label: _safeTr(l10n, 'profile_stats_posts', 'Publications'), count: _stats['posts'] ?? 0),
                    Container(width: 1, height: 30, color: MediaLightPalette.border),
                    _TopStat(label: _safeTr(l10n, 'profile_stats_followers', 'Abonnés'), count: _stats['followers'] ?? 0),
                    Container(width: 1, height: 30, color: MediaLightPalette.border),
                    _TopStat(label: _safeTr(l10n, 'profile_stats_following', 'Suivis'), count: _stats['following'] ?? 0),
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
                  _getDisplayName(l10n),
                  style: const TextStyle(
                    color: MediaLightPalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$displayUsername',
                  style: const TextStyle(
                    color: MediaLightPalette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    bio,
                    style: const TextStyle(
                      color: MediaLightPalette.textPrimary,
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
              onPressed: _busy ? null : (widget.isMe ? widget.onEditProfile : () => _handleFollowToggle(l10n)),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isMe || _isFollowing
                    ? MediaLightPalette.surface
                    : MediaLightPalette.textPrimary,
                foregroundColor: widget.isMe || _isFollowing
                    ? MediaLightPalette.textPrimary
                    : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: widget.isMe || _isFollowing
                    ? const BorderSide(color: MediaLightPalette.border, width: 1.5)
                    : BorderSide.none,
              ),
              child: _busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, 
                        color: widget.isMe || _isFollowing ? MediaLightPalette.textPrimary : Colors.white
                      ),
                    )
                  : Text(
                      widget.isMe 
                          ? _safeTr(l10n, 'profile_edit_btn', 'Modifier le profil') 
                          : (_isFollowing ? _safeTr(l10n, 'profile_following_btn', 'Abonné') : _safeTr(l10n, 'profile_follow_btn', 'Suivre')),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          formatMediaNumber(count), // ✅ Utilisation du formatteur global
          style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: MediaLightPalette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
