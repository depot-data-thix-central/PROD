// lib/services/notification_counters_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// Sections de la constellation d'accueil pouvant recevoir des badges
/// de notifications non lues.
enum ThixSection {
  media,
  info,
  events,
  money,
  market,
  reservation,
  jobs,
  formations,
  opportunities,
  network,
  health,
  monPays,
  messages,
}

/// Compteurs de notifications non lues, un champ par section — noms
/// exacts attendus par HomeServicesConstellation (c.media, c.info, ...)
/// et par home_header_delegate.dart / notifications_sheet.dart (c.messages).
class SectionBadgeCounts {
  final int media;
  final int info;
  final int events;
  final int money;
  final int market;
  final int reservation;
  final int jobs;
  final int formations;
  final int opportunities;
  final int network;
  final int health;
  final int monPays;
  final int messages;

  const SectionBadgeCounts({
    this.media = 0,
    this.info = 0,
    this.events = 0,
    this.money = 0,
    this.market = 0,
    this.reservation = 0,
    this.jobs = 0,
    this.formations = 0,
    this.opportunities = 0,
    this.network = 0,
    this.health = 0,
    this.monPays = 0,
    this.messages = 0,
  });

  static const zero = SectionBadgeCounts();

  int get total =>
      media + info + events + money + market + reservation + jobs +
      formations + opportunities + network + health + monPays + messages;

  int forSection(ThixSection section) {
    switch (section) {
      case ThixSection.media: return media;
      case ThixSection.info: return info;
      case ThixSection.events: return events;
      case ThixSection.money: return money;
      case ThixSection.market: return market;
      case ThixSection.reservation: return reservation;
      case ThixSection.jobs: return jobs;
      case ThixSection.formations: return formations;
      case ThixSection.opportunities: return opportunities;
      case ThixSection.network: return network;
      case ThixSection.health: return health;
      case ThixSection.monPays: return monPays;
      case ThixSection.messages: return messages;
    }
  }
}

/// Calcule et diffuse en temps réel les compteurs de notifications non
/// lues par section, pour alimenter les badges de HomeServicesConstellation
/// et de la cloche de notifications du header.
class NotificationCountersService {
  final SupabaseClient _client;
  NotificationCountersService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  static const String _table = 'notifications';

  /// Mapping type (colonne `notifications.type`) → section. À étendre
  /// au fur et à mesure que chaque module commence à créer des
  /// notifications avec de nouveaux types.
  static const Map<String, ThixSection> _typeToSection = {
    // Contenu & Médias
    'media': ThixSection.media,
    'tdia': ThixSection.media,
    'thix_media': ThixSection.media,
    'info': ThixSection.info,
    'thix_info': ThixSection.info,
    'news': ThixSection.info,
    'event': ThixSection.events,
    'evenement': ThixSection.events,

    // Économie & Transactions
    'money': ThixSection.money,
    'payment': ThixSection.money,
    'thix_money': ThixSection.money,
    'market': ThixSection.market,
    'order': ThixSection.market,
    'shop': ThixSection.market,
    'reservation': ThixSection.reservation,
    'booking': ThixSection.reservation,

    // Carrière, Éducation & Réseau
    'job': ThixSection.jobs,
    'emploi': ThixSection.jobs,
    'formation': ThixSection.formations,
    'course': ThixSection.formations,
    'certificate': ThixSection.formations,
    'opportunity': ThixSection.opportunities,

    // THIX PRO (réseau) — types réellement en base aujourd'hui
    'like': ThixSection.network,
    'follow': ThixSection.network,
    'connection': ThixSection.network,
    'comment': ThixSection.network,
    'post': ThixSection.network,
    'mention': ThixSection.network,

    // Vie pratique & gouvernement
    'health': ThixSection.health,
    'thix_sante': ThixSection.health,
    'country': ThixSection.monPays,
    'mon_pays': ThixSection.monPays,
    'civic': ThixSection.monPays,

    // THIX CHAT
    'chat': ThixSection.messages,
    'message': ThixSection.messages,
  };

  /// Flux réactif des compteurs par section pour l'utilisateur donné.
  Stream<SectionBadgeCounts> streamCounts(String uid) {
    return _streamUnreadTypes(uid).map(_buildCounts);
  }

  /// Récupération ponctuelle (non réactive) — utile pour un
  /// pull-to-refresh ou un affichage one-shot.
  Future<SectionBadgeCounts> fetchCounts(String uid) async {
    try {
      final rows = await _client
          .from(_table)
          .select('type')
          .eq('user_id', uid)
          .eq('is_read', false);
      return _buildCounts(rows.map((r) => (r['type'] ?? '').toString()).toList());
    } catch (e) {
      debugPrint('NotificationCountersService: fetchCounts failed err=$e');
      return SectionBadgeCounts.zero;
    }
  }

  SectionBadgeCounts _buildCounts(List<String> types) {
    final tally = <ThixSection, int>{};
    for (final type in types) {
      final section = _typeToSection[type];
      if (section == null) continue;
      tally[section] = (tally[section] ?? 0) + 1;
    }

    return SectionBadgeCounts(
      media: tally[ThixSection.media] ?? 0,
      info: tally[ThixSection.info] ?? 0,
      events: tally[ThixSection.events] ?? 0,
      money: tally[ThixSection.money] ?? 0,
      market: tally[ThixSection.market] ?? 0,
      reservation: tally[ThixSection.reservation] ?? 0,
      jobs: tally[ThixSection.jobs] ?? 0,
      formations: tally[ThixSection.formations] ?? 0,
      opportunities: tally[ThixSection.opportunities] ?? 0,
      network: tally[ThixSection.network] ?? 0,
      health: tally[ThixSection.health] ?? 0,
      monPays: tally[ThixSection.monPays] ?? 0,
      messages: tally[ThixSection.messages] ?? 0,
    );
  }

  /// Marque comme lues toutes les notifications non lues d'une section
  /// donnée — appelé par home_page.dart / notifications_sheet.dart
  /// quand l'utilisateur tape sur un nœud de la constellation ou ouvre
  /// le panneau de notifications.
  Future<void> markSectionSeen({required String uid, required ThixSection section}) async {
    final types = _typeToSection.entries
        .where((e) => e.value == section)
        .map((e) => e.key)
        .toList();
    if (types.isEmpty) return;

    try {
      await _client
          .from(_table)
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false)
          .inFilter('type', types);
    } catch (e) {
      debugPrint('NotificationCountersService: markSectionSeen failed section=$section err=$e');
    }
  }

  // ─── Flux bas niveau : types non lus, avec fallback polling ──────────

  Stream<List<String>> _streamUnreadTypes(String uid) {
    late final StreamController<List<String>> controller;
    RealtimeChannel? channel;
    var closedRetries = 0;
    Timer? retryTimer;
    var isCancelled = false;
    Timer? pollTimer;
    var polling = false;

    Future<void> emitLatest() async {
      try {
        final rows = await _client
            .from(_table)
            .select('type')
            .eq('user_id', uid)
            .eq('is_read', false);
        controller.add(rows.map((r) => (r['type'] ?? '').toString()).toList());
      } catch (e) {
        debugPrint('NotificationCountersService: emitLatest failed uid=$uid err=$e');
        controller.add(const <String>[]);
      }
    }

    void startPolling() {
      if (polling) return;
      polling = true;
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(emitLatest()));
    }

    controller = StreamController<List<String>>.broadcast(
      onListen: () => unawaited(emitLatest()),
    );

    Future<void> subscribeOrRetry() async {
      if (isCancelled || polling) return;
      retryTimer?.cancel();

      try {
        if (channel != null) await _client.removeChannel(channel!);
      } catch (_) {}

      channel = _client.channel('notification_counters:$uid');
      try {
        channel!
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: _table,
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
              callback: (payload) => unawaited(emitLatest()),
            )
            .subscribe((status, [err]) {
              if (isCancelled) return;

              if (status == RealtimeSubscribeStatus.channelError) {
                startPolling();
                return;
              }

              final shouldRetry = err != null || status == RealtimeSubscribeStatus.closed;
              if (!shouldRetry) {
                closedRetries = 0;
                return;
              }

              closedRetries = (closedRetries + 1).clamp(1, 10);
              final delayMs = (500 * (1 << (closedRetries - 1))).clamp(500, 8000);
              retryTimer?.cancel();
              retryTimer = Timer(Duration(milliseconds: delayMs), () {
                unawaited(subscribeOrRetry());
              });
            });
      } catch (e) {
        debugPrint('NotificationCountersService: realtime wiring failed, fallback polling. err=$e');
        startPolling();
      }
    }

    unawaited(subscribeOrRetry());

    controller.onCancel = () async {
      isCancelled = true;
      retryTimer?.cancel();
      pollTimer?.cancel();
      final ch = channel;
      if (ch != null) await _client.removeChannel(ch);
    };

    return controller.stream;
  }
}
