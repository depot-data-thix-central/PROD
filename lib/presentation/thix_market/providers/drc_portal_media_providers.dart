// lib/presentation/thix_market/providers/drc_portal_media_providers.dart
// ============================================================================
// DRC PRODUCTS PORTAL — providers : logo, photos partenaires, rôle éditeur
// ============================================================================
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kDrcBucket = 'drc-portal';
const String kDrcTable = 'drc_portal_media';
const String kDrcKindLogo = 'logo';
const String kDrcKindPartner = 'partner';
const int kDrcMaxPartners = 12;
const int kDrcMaxFileBytes = 8 * 1024 * 1024;

class DrcMedia {
  final String id;
  final String imageUrl;
  final String storagePath;
  final String title;
  final int sortOrder;

  const DrcMedia({
    required this.id,
    required this.imageUrl,
    required this.storagePath,
    required this.title,
    required this.sortOrder,
  });
}

String? _safeUrl(String? url) {
  if (url == null) return null;
  final t = url.trim();
  if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
  return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
}

/// true si l'utilisateur est ADMIN ou MODERATOR (même fonction SQL que les policies RLS).
final drcPortalEditorProvider = FutureProvider.autoDispose<bool>((ref) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return false;
  try {
    final res = await client.rpc('is_drc_portal_editor').timeout(const Duration(seconds: 8));
    return res == true;
  } catch (e) {
    debugPrint('[DRC Portal] ⚠️ is_drc_portal_editor error: $e');
    return false;
  }
});

/// Médias actifs d'un type : 'logo' (le plus récent) ou 'partner' (ordre d'ajout).
final drcPortalMediaProvider = FutureProvider.autoDispose.family<List<DrcMedia>, String>((ref, kind) async {
  try {
    final base = Supabase.instance.client
        .from(kDrcTable)
        .select('id, title, image_url, storage_path, sort_order')
        .eq('kind', kind)
        .eq('is_active', true);

    final res = kind == kDrcKindLogo
        ? await base.order('created_at', ascending: false).limit(1).timeout(const Duration(seconds: 10))
        : await base
            .order('sort_order', ascending: true)
            .order('created_at', ascending: true)
            .limit(kDrcMaxPartners)
            .timeout(const Duration(seconds: 10));

    final out = <DrcMedia>[];
    for (final row in List<Map<String, dynamic>>.from(res as List)) {
      final url = _safeUrl(row['image_url']?.toString());
      if (url == null) continue;
      out.add(DrcMedia(
        id: row['id']?.toString() ?? '',
        imageUrl: url,
        storagePath: row['storage_path']?.toString() ?? '',
        title: (row['title'] ?? '').toString().trim(),
        sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      ));
    }
    return out;
  } catch (e) {
    debugPrint('[DRC Portal] ⚠️ media ($kind) error: $e');
    return const <DrcMedia>[];
  }
});
