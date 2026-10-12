// lib/presentation/network/widgets/post_share_sheet.dart
//
// Sheet de partage style X : recherche + contacts THIX + apps externes — v2
//
// ✅ Lien = https://thix.id/network/post/ID (ouvre l'application)
// ✅ Envoi dans l'app : message + notification, avec ouverture directe du post
// ✅ Recherche par nom ET identifiant, état de chargement / erreur avec « Réessayer »
// ✅ Rangée d'apps externes défilante : Partager, Copier, WhatsApp, Telegram, SMS, E-mail
//    (si une app n'est pas installée → repli sur le partage système)
// ✅ Textes avec repli français (clés l10n optionnelles)
// ✅ Plus de dépendance à deep_link_service.dart

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/network_connection.dart';

/// Lien public d'un post (ouvre l'application grâce aux App Links)
const String _kPostLinkBase = 'https://thix.id/network/post/';

String _linkFor(String postId) => '$_kPostLinkBase$postId';

String _t(AppLocalizations l10n, String key, String fallback) {
  final v = l10n.t(key);
  return (v.isEmpty || v == key) ? fallback : v;
}

class PostShareSheet extends ConsumerStatefulWidget {
  final String postId;
  final String postExcerpt;
  final String? imageUrl;

  const PostShareSheet({
    super.key,
    required this.postId,
    required this.postExcerpt,
    this.imageUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String postId,
    required String postExcerpt,
    String? imageUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostShareSheet(
        postId: postId,
        postExcerpt: postExcerpt,
        imageUrl: imageUrl,
      ),
    );
  }

  @override
  ConsumerState<PostShareSheet> createState() => _PostShareSheetState();
}

class _PostShareSheetState extends ConsumerState<PostShareSheet> {
  final _searchCtrl = TextEditingController();
  List<NetworkConnection> _contacts = [];
  bool _loading = true;
  bool _loadFailed = false;
  final Set<String> _sentTo = {};
  final Set<String> _sending = {};

  String get _shareUrl => _linkFor(widget.postId);
  String get _shareText => '${widget.postExcerpt}\n\n$_shareUrl';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final list = await ref
          .read(networkServiceProvider)
          .getMyConnections()
          .timeout(const Duration(seconds: 12));
      if (mounted) {
        setState(() {
          _contacts = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[PostShareSheet] contacts: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  String _handle(NetworkConnection c) => '@${c.name.replaceAll(' ', '').toLowerCase()}';

  List<NetworkConnection> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    final qq = q.startsWith('@') ? q.substring(1) : q;
    return _contacts
        .where((c) => c.name.toLowerCase().contains(qq) || _handle(c).contains(qq))
        .toList();
  }

  void _toast(String message, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  // ── Envoi IN-APP (message + notification) ──
  Future<void> _sendInApp(NetworkConnection c) async {
    final l10n = AppLocalizations.of(context);
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null || _sentTo.contains(c.id) || _sending.contains(c.id)) return;

    setState(() => _sending.add(c.id));
    HapticFeedback.mediumImpact();

    try {
      await supa.from('messages').insert({
        'sender_id': uid,
        'receiver_id': c.id,
        'content': '📌 $_shareText',
        'is_read': false,
      });

      // La notification ne doit pas faire échouer l'envoi du message
      try {
        await supa.from('notifications').insert({
          'user_id': c.id,
          'sender_id': uid,
          'type': 'post_share',
          'category': 'network',
          'title': _t(l10n, 'post_share_notif_title', 'Post partagé avec vous'),
          'body': widget.postExcerpt,
          'post_id': widget.postId,
          'route': '/network/post/${widget.postId}',
          'is_read': false,
        });
      } catch (e) {
        debugPrint('[PostShareSheet] notification: $e');
      }

      unawaited(ref.read(networkServiceProvider).sharePost(widget.postId));

      if (mounted) {
        setState(() {
          _sending.remove(c.id);
          _sentTo.add(c.id);
        });
        _toast('${_t(l10n, 'post_share_sent_to', 'Envoyé à')} ${c.name}', bg: ThixPolicy.success);
      }
    } catch (e) {
      debugPrint('[PostShareSheet] send: $e');
      if (mounted) {
        setState(() => _sending.remove(c.id));
        _toast(_t(l10n, 'post_share_send_error', 'Envoi impossible. Réessayez.'), bg: ThixPolicy.danger);
      }
    }
  }

  // ── Actions externes ──
  Future<void> _shareSystem() async {
    try {
      await Share.share(_shareText, subject: 'THIX Hub');
      unawaited(ref.read(networkServiceProvider).sharePost(widget.postId));
    } catch (e) {
      debugPrint('[PostShareSheet] share: $e');
    }
  }

  /// Ouvre une app externe ; si elle n'est pas disponible → partage système
  Future<void> _launchOrFallback(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) {
          unawaited(ref.read(networkServiceProvider).sharePost(widget.postId));
          return;
        }
      }
    } catch (e) {
      debugPrint('[PostShareSheet] launch: $e');
    }
    await _shareSystem();
  }

  Future<void> _copyLink() async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    _toast(_t(l10n, 'post_link_copied', 'Lien copié'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _filtered;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Poignée
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _t(l10n, 'post_share_search', 'Rechercher'),
                prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textMuted),
                        onPressed: () => setState(_searchCtrl.clear),
                      )
                    : null,
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const Divider(height: 1),
          // Liste contacts
          Expanded(child: _buildContactList(filtered, l10n)),
          const Divider(height: 1),
          // Rangée apps externes (style X), défilante
          SafeArea(
            top: false,
            child: SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                physics: const BouncingScrollPhysics(),
                children: [
                  _ExternalAction(
                    label: _t(l10n, 'post_share_via', 'Partager'),
                    icon: Icons.share_rounded,
                    bg: Colors.black,
                    fg: Colors.white,
                    onTap: _shareSystem,
                  ),
                  _ExternalAction(
                    label: _t(l10n, 'post_copy_link', 'Copier le lien'),
                    icon: Icons.link_rounded,
                    bg: Colors.black,
                    fg: Colors.white,
                    onTap: _copyLink,
                  ),
                  _ExternalAction(
                    label: 'WhatsApp',
                    icon: Icons.chat_rounded,
                    bg: const Color(0xFF25D366),
                    fg: Colors.white,
                    onTap: () => _launchOrFallback('https://wa.me/?text=${Uri.encodeComponent(_shareText)}'),
                  ),
                  _ExternalAction(
                    label: 'Telegram',
                    icon: Icons.send_rounded,
                    bg: const Color(0xFF229ED9),
                    fg: Colors.white,
                    onTap: () => _launchOrFallback(
                        'https://t.me/share/url?url=${Uri.encodeComponent(_shareUrl)}&text=${Uri.encodeComponent(widget.postExcerpt)}'),
                  ),
                  _ExternalAction(
                    label: 'SMS',
                    icon: Icons.sms_rounded,
                    bg: const Color(0xFFFFC107),
                    fg: Colors.black,
                    onTap: () => _launchOrFallback('sms:?body=${Uri.encodeComponent(_shareText)}'),
                  ),
                  _ExternalAction(
                    label: _t(l10n, 'post_share_email', 'E-mail'),
                    icon: Icons.email_rounded,
                    bg: const Color(0xFF5865F2),
                    fg: Colors.white,
                    onTap: () => _launchOrFallback(
                        'mailto:?subject=${Uri.encodeComponent('THIX Hub')}&body=${Uri.encodeComponent(_shareText)}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactList(List<NetworkConnection> filtered, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
    }

    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _t(l10n, 'post_share_load_error', 'Impossible de charger vos contacts'),
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadContacts,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_t(l10n, 'common_retry', 'Réessayer')),
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _contacts.isEmpty
              ? _t(l10n, 'post_share_no_contacts', 'Aucun contact')
              : _t(l10n, 'post_share_no_results', 'Aucun résultat'),
          style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
      itemBuilder: (context, i) {
        final c = filtered[i];
        final sent = _sentTo.contains(c.id);
        final busy = _sending.contains(c.id);
        final hasAvatar = (c.avatar ?? '').isNotEmpty;

        return ListTile(
          onTap: () => _sendInApp(c),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: ThixPolicy.surfaceSoft,
            backgroundImage: hasAvatar ? CachedNetworkImageProvider(c.avatar!) : null,
            child: hasAvatar ? null : const Icon(Icons.person, color: ThixPolicy.textMuted),
          ),
          title: Text(
            c.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          subtitle: Text(
            _handle(c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
          ),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                )
              : (sent
                  ? const Icon(Icons.check_circle_rounded, color: ThixPolicy.success, size: 22)
                  : Icon(Icons.radio_button_unchecked_rounded, color: ThixPolicy.border, size: 22)),
        );
      },
    );
  }
}

class _ExternalAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _ExternalAction({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: fg, size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.microStyle.copyWith(
                    fontSize: 10,
                    color: ThixPolicy.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
