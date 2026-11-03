// lib/presentation/thix_weeding/providers/wedding_badges.dart
// ============================================================================
// THIX WEDDING — COMPTEURS « NOUVEAU / À TRAITER » PAR RUBRIQUE
// ✅ Un seul appel RPC (thix_weeding_badges) → tous les compteurs d'un rôle
// ✅ Temps réel (tables du mariage + notifications) + rattrapage toutes les 45 s
// ✅ markWeddingSeen() : remet la rubrique à zéro (synchronisé entre appareils)
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// role : 'staff' ou 'guest'
typedef BadgeKey = ({String weddingId, String role});

class WeddingBadges {
  final Map<String, int> counts;
  const WeddingBadges(this.counts);

  static const WeddingBadges empty = WeddingBadges({});

  int of(String feature) => counts[feature] ?? 0;
  int get total => counts.values.fold(0, (s, v) => s + v);
}

const List<String> _kWeddingTables = [
  'thix_weeding_guests',
  'thix_weeding_messages',
  'thix_weeding_playlist',
  'thix_weeding_menu_items',
  'thix_weeding_menu_settings',
  'thix_weeding_menu_votes',
  'thix_weeding_info_blocks',
  'thix_weeding_vendor_requests',
  'thix_weeding_vendors',
];

final weddingBadgesProvider =
    StreamProvider.autoDispose.family<WeddingBadges, BadgeKey>((ref, key) {
  final supa = Supabase.instance.client;
  final ctrl = StreamController<WeddingBadges>();
  Timer? debounce;
  Timer? poll;
  RealtimeChannel? channel;
  var closed = false;

  Future<void> fetch() async {
    if (closed) return;
    try {
      final r = await supa.rpc('thix_weeding_badges', params: {
        'p_wedding': key.weddingId,
        'p_role': key.role,
      });
      final out = <String, int>{};
      if (r is Map) {
        r.forEach((k, v) => out['$k'] = (v as num?)?.toInt() ?? 0);
      }
      if (!closed) ctrl.add(WeddingBadges(out));
    } catch (e) {
      debugPrint('[WeddingBadges] ❌ $e');
      if (!closed && !ctrl.isClosed) ctrl.add(WeddingBadges.empty);
    }
  }

  void schedule() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 450), fetch);
  }

  PostgresChangeFilter eq(String col, String v) =>
      PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: col, value: v);

  try {
    var c = supa.channel('wedding-badges-${key.role}-${key.weddingId}');
    for (final t in _kWeddingTables) {
      c = c.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: t,
        filter: eq('wedding_id', key.weddingId),
        callback: (_) => schedule(),
      );
    }
    final uid = supa.auth.currentUser?.id;
    if (uid != null) {
      c = c.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: eq('user_id', uid),
        callback: (_) => schedule(),
      );
    }
    channel = c.subscribe();
  } catch (e) {
    debugPrint('[WeddingBadges] ⚠️ realtime indisponible: $e');
  }

  // Rattrapage (galerie, livre d'or, paiements, tâches…)
  poll = Timer.periodic(const Duration(seconds: 45), (_) => fetch());
  fetch();

  ref.onDispose(() {
    closed = true;
    debounce?.cancel();
    poll?.cancel();
    if (channel != null) {
      try {
        supa.removeChannel(channel!);
      } catch (_) {}
    }
    ctrl.close();
  });

  return ctrl.stream;
});

/// À appeler à l'ouverture d'une rubrique : remet son compteur à zéro
/// et marque ses notifications push comme lues.
Future<void> markWeddingSeen(
  WidgetRef ref, {
  required String weddingId,
  required String role,
  required String feature,
}) async {
  try {
    await Supabase.instance.client.rpc('thix_weeding_mark_seen', params: {
      'p_wedding': weddingId,
      'p_role': role,
      'p_feature': feature,
    });
  } catch (e) {
    debugPrint('[WeddingBadges] ⚠️ markSeen($feature): $e');
  }
  try {
    ref.invalidate(weddingBadgesProvider((weddingId: weddingId, role: role)));
  } catch (_) {}
}
