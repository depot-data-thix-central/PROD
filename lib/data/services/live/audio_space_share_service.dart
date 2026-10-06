// lib/data/services/live/audio_space_share_service.dart
//
// ============================================================================
// 🔗 AUDIO SPACE SHARE SERVICE
// ============================================================================
// Gère la diffusion des salons audio :
//   ✅ Lien profond (thix://space/{id} + https://thix.id/space/{id})
//   ✅ Partage natif (feuille système) + plateformes ciblées
//   ✅ Copie du lien + QR code
//   ✅ Invitations directes aux contacts THIX (table + temps réel)
//   ✅ Tracking analytics des partages
//   ✅ Écoute des deep links entrants (rejoindre en 1 tap)
// ============================================================================

import 'dart:async';
import 'dart:ui' as ui;
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/audio_space_model.dart';

// ════════════════════════════════════════════════════════════════════════
// PLATEFORMES DE PARTAGE
// ════════════════════════════════════════════════════════════════════════
enum ShareTarget {
  native,
  whatsapp,
  telegram,
  sms,
  email,
  x,
  facebook,
  copy,
  qr,
}

// ════════════════════════════════════════════════════════════════════════
// SERVICE DE PARTAGE
// ════════════════════════════════════════════════════════════════════════
class AudioSpaceShareService {
  AudioSpaceShareService._internal();
  static final AudioSpaceShareService instance = AudioSpaceShareService._internal();
  factory AudioSpaceShareService() => instance;

  SupabaseClient get _db => Supabase.instance.client;

  static const String _webBase = 'https://thix.id/space';
  static const String _schemeBase = 'thix://space';

  // ─────────────────────────────────────────────────────────────
  // CONSTRUCTION DU LIEN + TEXTE
  // ─────────────────────────────────────────────────────────────

  /// Lien universel (fonctionne web + app)
  String buildLink(AudioSpace space) => '$_webBase/${space.id}';

  /// Lien scheme (ouvre l'app directement si installée)
  String buildDeepLink(AudioSpace space) => '$_schemeBase/${space.id}';

  /// Texte riche du partage
  String buildShareText(
    AudioSpace space, {
    int? listeners,
    String? hostName,
  }) {
    final b = StringBuffer();
    b.writeln('🎙️ ${space.title}');
    b.writeln('🔴 En direct sur THIX ID');
    if (hostName != null && hostName.isNotEmpty) {
      b.writeln('👤 Animé par $hostName');
    }
    if (listeners != null && listeners > 0) {
      b.writeln('🎧 ${_fmt(listeners)} participant${listeners > 1 ? 's' : ''}');
    }
    b.writeln('👉 Rejoins-nous : ${buildLink(space)}');
    return b.toString();
  }

  String _fmt(num n) => n
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  // ─────────────────────────────────────────────────────────────
  // PARTAGE MULTI-PLATEFORMES
  // ─────────────────────────────────────────────────────────────
  Future<void> share({
    required AudioSpace space,
    required ShareTarget target,
    int? listeners,
    String? hostName,
  }) async {
    final text = buildShareText(space, listeners: listeners, hostName: hostName);
    final link = buildLink(space);
    final encodedText = Uri.encodeComponent(text);
    final encodedLink = Uri.encodeComponent(link);

    try {
      switch (target) {
        case ShareTarget.native:
          await Share.share(text, subject: '🎙️ ${space.title} — THIX ID');
          break;

        case ShareTarget.whatsapp:
          await _launch('https://wa.me/?text=$encodedText');
          break;

        case ShareTarget.telegram:
          await _launch('https://t.me/share/url?url=$encodedLink&text=$encodedText');
          break;

        case ShareTarget.sms:
          await _launch('sms:?body=$encodedText');
          break;

        case ShareTarget.email:
          await _launch(
            'mailto:?subject=${Uri.encodeComponent('🎙️ ${space.title} — THIX ID')}&body=$encodedText',
          );
          break;

        case ShareTarget.x:
          await _launch('https://twitter.com/intent/tweet?text=$encodedText');
          break;

        case ShareTarget.facebook:
          await _launch('https://www.facebook.com/sharer/sharer.php?u=$encodedLink');
          break;

        case ShareTarget.copy:
          await Clipboard.setData(ClipboardData(text: link));
          break;

        case ShareTarget.qr:
          // Géré par l'UI (showQrDialog)
          break;
      }

      // 📊 Tracking (sauf copie/QR)
      if (target != ShareTarget.copy && target != ShareTarget.qr) {
        await trackShare(space.id, target.name);
      }
    } catch (e) {
      debugPrint('[ShareService] share error ($target): $e');
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // INVITATIONS DIRECTES (contacts THIX)
  // ─────────────────────────────────────────────────────────────
  /// Liste des contacts invitable (connexions de l'utilisateur)
  Future<List<Map<String, dynamic>>> getInvitableContacts(String userId) async {
    try {
      final rows = await _db
          .from('connections')
          .select('user1_id, user2_id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId');

      final peerIds = <String>{};
      for (final r in rows.whereType<Map>()) {
        final u1 = r['user1_id']?.toString() ?? '';
        final u2 = r['user2_id']?.toString() ?? '';
        if (u1 == userId && u2.isNotEmpty) peerIds.add(u2);
        if (u2 == userId && u1.isNotEmpty) peerIds.add(u1);
      }
      if (peerIds.isEmpty) return [];

      final profiles = await _db
          .from('profiles')
          .select('id, display_name, full_name, avatar_url')
          .inFilter('id', peerIds.toList());

      return profiles
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[ShareService] getInvitableContacts error: $e');
      return [];
    }
  }

  /// Envoie des invitations (table + temps réel via postgres_changes)
  Future<void> inviteUsers({
    required AudioSpace space,
    required List<String> userIds,
    required String inviterName,
  }) async {
    if (userIds.isEmpty) return;

    final rows = userIds.map((id) => {
          'space_id': space.id,
          'invitee_id': id,
          'invited_by_name': inviterName,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        }).toList();

    try {
      await _db.from('audio_space_invites').upsert(
            rows,
            onConflict: 'space_id,invitee_id',
          );
      await trackShare(space.id, 'invite');
      debugPrint('[ShareService] ✓ ${userIds.length} invitation(s) envoyée(s)');
    } catch (e) {
      debugPrint('[ShareService] inviteUsers error: $e');
      rethrow;
    }
  }

  /// Écoute les invitations entrantes en temps réel
  Stream<Map<String, dynamic>> watchInvites(String userId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    final channel = _db
        .channel('audio_space_invites_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'audio_space_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'invitee_id',
            value: userId,
          ),
          callback: (payload) {
            controller.add(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe();

    controller.onCancel = () async {
      try {
        await _db.removeChannel(channel);
      } catch (_) {}
    };

    return controller.stream;
  }

  /// Accepter / refuser une invitation
  Future<void> respondInvite(String inviteId, bool accept) async {
    try {
      await _db
          .from('audio_space_invites')
          .update({
            'status': accept ? 'accepted' : 'declined',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', inviteId);
    } catch (e) {
      debugPrint('[ShareService] respondInvite error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TRACKING ANALYTICS
  // ─────────────────────────────────────────────────────────────
  Future<void> trackShare(String spaceId, String platform) async {
    try {
      await _db.from('audio_space_share_events').insert({
        'space_id': spaceId,
        'platform': platform,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Non bloquant
      debugPrint('[ShareService] trackShare error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PARSING DEEP LINK
  // ─────────────────────────────────────────────────────────────
  /// Extrait l'ID du space depuis un lien (thix:// ou https://)
  String? parseSpaceId(String link) {
    try {
      final uri = Uri.parse(link);

      // thix://space/{id}
      if (uri.scheme == 'thix' && uri.host == 'space' && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }

      // https://thix.id/space/{id}
      if (uri.host == 'thix.id' &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments[0] == 'space') {
        return uri.pathSegments[1];
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════
// ÉCOUTEUR DE DEEP LINKS ENTRANTS
// ════════════════════════════════════════════════════════════════════════
class AudioSpaceDeepLinkHandler {
  AudioSpaceDeepLinkHandler._internal();
  static final AudioSpaceDeepLinkHandler instance = AudioSpaceDeepLinkHandler._internal();
  factory AudioSpaceDeepLinkHandler() => instance;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  final StreamController<String> _controller = StreamController<String>.broadcast();

  /// Stream des IDs de space reçus via deep link
  Stream<String> get spaceLinks => _controller.stream;

  /// À appeler au démarrage de l'app (main.dart)
  Future<void> start() async {
    // Lien initial (app lancée via un lien)
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (e) {
      debugPrint('[DeepLink] initial error: $e');
    }

    // Liens pendant que l'app tourne
    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (e) => debugPrint('[DeepLink] stream error: $e'),
    );
  }

  void _handle(Uri uri) {
    final id = AudioSpaceShareService.instance.parseSpaceId(uri.toString());
    if (id != null && !_controller.isClosed) {
      debugPrint('[DeepLink] ✓ Space link reçu → $id');
      _controller.add(id);
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

// ════════════════════════════════════════════════════════════════════════
// UI — FEUILLE DE PARTAGE (bottom sheet)
// ════════════════════════════════════════════════════════════════════════
class AudioSpaceShareSheet extends StatelessWidget {
  final AudioSpace space;
  final int? listeners;
  final String? hostName;
  final String currentUserId;
  final String currentUserName;

  const AudioSpaceShareSheet({
    super.key,
    required this.space,
    required this.currentUserId,
    required this.currentUserName,
    this.listeners,
    this.hostName,
  });

  /// Ouvre la feuille de partage
  static Future<void> show(
    BuildContext context, {
    required AudioSpace space,
    required String currentUserId,
    required String currentUserName,
    int? listeners,
    String? hostName,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AudioSpaceShareSheet(
        space: space,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        listeners: listeners,
        hostName: hostName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = AudioSpaceShareService.instance;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42, height: 4,
                  decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Partager le salon',
                  style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(space.title,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
              const SizedBox(height: 20),

              // ─── Grille des plateformes ───
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
                children: [
                  _ShareTile(
                    icon: Icons.share_rounded, color: ThixPolicy.primary, label: 'Plus',
                    onTap: () => _shareAndClose(context, service, ShareTarget.native),
                  ),
                  _ShareTile(
                    icon: Icons.chat_rounded, color: const Color(0xFF25D366), label: 'WhatsApp',
                    onTap: () => _shareAndClose(context, service, ShareTarget.whatsapp),
                  ),
                  _ShareTile(
                    icon: Icons.send_rounded, color: const Color(0xFF229ED9), label: 'Telegram',
                    onTap: () => _shareAndClose(context, service, ShareTarget.telegram),
                  ),
                  _ShareTile(
                    icon: Icons.sms_rounded, color: const Color(0xFF43A047), label: 'SMS',
                    onTap: () => _shareAndClose(context, service, ShareTarget.sms),
                  ),
                  _ShareTile(
                    icon: Icons.email_rounded, color: const Color(0xFFE53935), label: 'Email',
                    onTap: () => _shareAndClose(context, service, ShareTarget.email),
                  ),
                  _ShareTile(
                    icon: Icons.copy_rounded, color: const Color(0xFF5E35B1), label: 'Copier',
                    onTap: () async {
                      await service.share(space: space, target: ShareTarget.copy);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🔗 Lien copié')),
                        );
                      }
                    },
                  ),
                  _ShareTile(
                    icon: Icons.qr_code_rounded, color: ThixPolicy.gold, label: 'QR Code',
                    onTap: () {
                      Navigator.pop(context);
                      _showQrDialog(context, service);
                    },
                  ),
                  _ShareTile(
                    icon: Icons.person_add_alt_rounded, color: const Color(0xFF8E24AA), label: 'Inviter',
                    onTap: () {
                      Navigator.pop(context);
                      _showInviteSheet(context, service);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareAndClose(BuildContext context, AudioSpaceShareService service, ShareTarget target) async {
    await service.share(space: space, target: target, listeners: listeners, hostName: hostName);
    if (context.mounted) Navigator.pop(context);
  }

  void _showQrDialog(BuildContext context, AudioSpaceShareService service) {
    final link = service.buildLink(space);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Scanner pour rejoindre',
                  style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: QrImageView(
                  data: link,
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ThixPolicy.primary),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ThixPolicy.inkDeep),
                ),
              ),
              const SizedBox(height: 12),
              Text(space.title, textAlign: TextAlign.center,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context, AudioSpaceShareService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InviteContactsSheet(
        space: space,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tuile de partage
// ─────────────────────────────────────────────────────────────
class _ShareTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ShareTile({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Feuille d'invitation des contacts
// ─────────────────────────────────────────────────────────────
class _InviteContactsSheet extends StatefulWidget {
  final AudioSpace space;
  final String currentUserId;
  final String currentUserName;
  const _InviteContactsSheet({
    required this.space,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<_InviteContactsSheet> createState() => _InviteContactsSheetState();
}

class _InviteContactsSheetState extends State<_InviteContactsSheet> {
  final Set<String> _selected = {};
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final service = AudioSpaceShareService.instance;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inviter des contacts',
                style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: service.getInvitableContacts(widget.currentUserId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
                  }
                  final contacts = snap.data ?? [];
                  if (contacts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text('Aucun contact à inviter',
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = contacts[i];
                      final id = c['id']?.toString() ?? '';
                      final name = (c['display_name'] ?? c['full_name'] ?? 'Contact').toString();
                      final avatar = c['avatar_url']?.toString() ?? '';
                      final isSelected = _selected.contains(id);

                      return InkWell(
                        onTap: () => setState(() {
                          isSelected ? _selected.remove(id) : _selected.add(id);
                        }),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? ThixPolicy.primary.withOpacity(0.08) : ThixPolicy.surfaceSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? ThixPolicy.primary : ThixPolicy.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: ThixPolicy.card,
                                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                child: avatar.isEmpty
                                    ? const Icon(Icons.person, size: 20, color: ThixPolicy.textMuted)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(name,
                                    style: ThixPolicy.labelStyle.copyWith(
                                        color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700)),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: ThixPolicy.primary),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selected.isEmpty || _sending
                    ? null
                    : () async {
                        setState(() => _sending = true);
                        try {
                          await service.inviteUsers(
                            space: widget.space,
                            userIds: _selected.toList(),
                            inviterName: widget.currentUserName,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('📨 ${_selected.length} invitation(s) envoyée(s)')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _sending = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('⚠️ Erreur d\'envoi')),
                            );
                          }
                        }
                      },
                icon: _sending
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_selected.isEmpty ? 'Sélectionner des contacts' : 'Inviter (${_selected.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E24AA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helper blur (compatibilité)
// ─────────────────────────────────────────────────────────────
class ImageFilterBlurHelper {
  static ImageFilterBlur blur() => ImageFilterBlur._();
}

class ImageFilterBlur {
  ImageFilterBlur._();
}
