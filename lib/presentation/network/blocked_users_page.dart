// lib/presentation/network/blocked_users_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _BlockedValidators {
  _BlockedValidators._();

  static const Duration requestTimeout = Duration(seconds: 15);

  static String sanitize(String? input, {int maxLength = 100}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});
  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;

    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      debugPrint('[Blocked] Loading blocked users for $uid');

      // Requête 1 : IDs des utilisateurs bloqués
      final r = await supa
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', uid)
          .order('created_at', ascending: false)
          .timeout(_BlockedValidators.requestTimeout);

      final ids = (r as List).map((e) => e['blocked_id'] as String).toList();

      if (ids.isEmpty) {
        if (mounted) setState(() { _blocked = []; _loading = false; });
        return;
      }

      // Requête 2 : Profils des utilisateurs bloqués
      final profs = await supa
          .from('profiles')
          .select('id, display_name, photo_url, avatar_url, profession')
          .inFilter('id', ids)
          .timeout(_BlockedValidators.requestTimeout);

      if (mounted) {
        setState(() {
          _blocked = (profs as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }

      debugPrint('[Blocked] Loaded ${_blocked.length} blocked users');
    } catch (e) {
      debugPrint('[Blocked] Load error: $e');
      if (mounted) {
        setState(() {
          _blocked = [];
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur de chargement'),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _unblock(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: ThixPolicy.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Débloquer l\'utilisateur', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment débloquer ${_BlockedValidators.sanitize(name, maxLength: 50)} ?\n\nCette personne pourra de nouveau interagir avec vous et voir votre profil.',
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
            ),
            child: const Text('Débloquer'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _processing.add(id));
    HapticFeedback.mediumImpact();

    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;

      await Supabase.instance.client
          .from('blocked_users')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', id)
          .timeout(_BlockedValidators.requestTimeout);

      if (!mounted) return;

      setState(() {
        _blocked.removeWhere((u) => u['id'] == id);
        _processing.remove(id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('${_BlockedValidators.sanitize(name, maxLength: 30)} débloqué')),
            ],
          ),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
        ),
      );

      debugPrint('[Blocked] Unblocked $id');
    } catch (e) {
      debugPrint('[Blocked] Unblock error: $e');
      if (mounted) {
        setState(() => _processing.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Erreur lors du déblocage'),
              ],
            ),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Utilisateurs bloqués', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        actions: [
          if (!_loading && _blocked.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                  ),
                  child: Text(
                    '${_blocked.length}',
                    style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? _buildSkeleton()
          : _blocked.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: ThixPolicy.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _blocked.length,
                    itemBuilder: (_, i) => _buildBlockedTile(_blocked[i]),
                  ),
                ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 150, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(height: 12, width: 100, color: Colors.grey.shade200),
                ],
              ),
            ),
            Container(width: 80, height: 32, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 64, color: ThixPolicy.success),
            ),
            const SizedBox(height: 24),
            Text('Aucun utilisateur bloqué', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              'Votre liste de blocage est vide.\nVous pouvez bloquer un utilisateur depuis son profil.',
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedTile(Map<String, dynamic> u) {
    final id = u['id'] as String;
    final name = _BlockedValidators.sanitize(u['display_name']?.toString() ?? 'Utilisateur', maxLength: 100);
    final photo = _BlockedValidators.sanitizeUrl(u['photo_url']?.toString() ?? u['avatar_url']?.toString());
    final profession = _BlockedValidators.sanitize(u['profession']?.toString() ?? '', maxLength: 100);
    final isProcessing = _processing.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar avec bordure
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.border, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: ThixPolicy.surfaceSoft,
                backgroundImage: photo != null ? CachedNetworkImageProvider(photo) : null,
                child: photo == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.bold),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // Nom + profession
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profession.isNotEmpty)
                    Text(
                      profession,
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Bouton débloquer / loader
            if (isProcessing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
              )
            else
              TextButton.icon(
                onPressed: () => _unblock(id, name),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: Text(
                  'Débloquer',
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.danger,
                    fontWeight: ThixPolicy.bold,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: ThixPolicy.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                    side: BorderSide(color: ThixPolicy.danger.withOpacity(0.3)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
