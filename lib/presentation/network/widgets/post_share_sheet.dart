// lib/presentation/network/widgets/post_share_sheet.dart
// Sheet de partage style X : recherche + contacts THIX + apps externes
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/models/network_connection.dart';
import 'package:thix_id/services/deep_link_service.dart';

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
  final Set<String> _sentTo = {};

  String get _shareUrl => PostShareLinks.post(widget.postId);
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
    try {
      final list = await ref.read(networkServiceProvider).getMyConnections();
      if (mounted) setState(() { _contacts = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<NetworkConnection> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  // ── Envoi IN-APP (message + notification) ──
  Future<void> _sendInApp(NetworkConnection c) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || _sentTo.contains(c.id)) return;

    setState(() => _sentTo.add(c.id));
    HapticFeedback.mediumImpact();

    try {
      final supa = Supabase.instance.client;
      await supa.from('messages').insert({
        'sender_id': uid,
        'receiver_id': c.id,
        'content': '📌 $_shareText',
        'is_read': false,
      });
      await supa.from('notifications').insert({
        'user_id': c.id,
        'sender_id': uid,
        'type': 'post_share',
        'category': 'network',
        'title': 'Post partagé avec vous',
        'body': widget.postExcerpt,
        'post_id': widget.postId,
        'route': '/network/comments/${widget.postId}',
        'is_read': false,
      });
      // compteur de partages
      unawaited(ref.read(networkServiceProvider).sharePost(widget.postId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Envoyé à ${c.name}'),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sentTo.remove(c.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Envoi impossible : ${e.toString().split('\n').first}'),
          backgroundColor: ThixPolicy.danger,
        ));
      }
    }
  }

  // ── Actions externes ──
  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      unawaited(ref.read(networkServiceProvider).sharePost(widget.postId));
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Lien copié'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
          ),
          // Recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher',
                prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.textMuted),
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const Divider(height: 1),
          // Liste contacts
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _contacts.isEmpty ? 'Aucun contact' : 'Aucun résultat',
                          style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                        itemBuilder: (context, i) {
                          final c = filtered[i];
                          final sent = _sentTo.contains(c.id);
                          return ListTile(
                            onTap: () => _sendInApp(c),
                            leading: CircleAvatar(
                              radius: 26,
                              backgroundColor: ThixPolicy.surfaceSoft,
                              backgroundImage: (c.avatar ?? '').isNotEmpty ? CachedNetworkImageProvider(c.avatar!) : null,
                              child: (c.avatar ?? '').isEmpty ? const Icon(Icons.person, color: ThixPolicy.textMuted) : null,
                            ),
                            title: Text(c.name, style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 15)),
                            subtitle: Text('@${c.name.replaceAll(' ', '').toLowerCase()}', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
                            trailing: sent
                                ? const Icon(Icons.check_circle_rounded, color: ThixPolicy.success, size: 22)
                                : Icon(Icons.radio_button_unchecked_rounded, color: ThixPolicy.border, size: 22),
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          // Rangée apps externes (style X)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ExternalAction(
                    label: 'Share via...',
                    icon: Icons.share_rounded,
                    bg: Colors.black,
                    fg: Colors.white,
                    onTap: () => Share.share(_shareText, subject: 'THIX Hub'),
                  ),
                  _ExternalAction(
                    label: 'Copy link',
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
                    onTap: () => _launch('https://wa.me/?text=${Uri.encodeComponent(_shareText)}'),
                  ),
                  _ExternalAction(
                    label: 'Discord',
                    icon: Icons.groups_rounded,
                    bg: const Color(0xFF5865F2),
                    fg: Colors.white,
                    onTap: () async {
                      await _copyLink();
                      await _launch('https://discord.com/app');
                    },
                  ),
                  _ExternalAction(
                    label: 'Messaging',
                    icon: Icons.sms_rounded,
                    bg: const Color(0xFFFFC107),
                    fg: Colors.black,
                    onTap: () => _launch('sms:?body=${Uri.encodeComponent(_shareText)}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    return GestureDetector(
      onTap: onTap,
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
            style: ThixPolicy.microStyle.copyWith(fontSize: 10, color: ThixPolicy.textMain, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
