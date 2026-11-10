// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — RUBRIQUES AVANCÉES (10 fonctionnalités)
//  Fichier  : lib/presentation/thix_portfolio/data/business_extras.dart
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//  Modèle générique piloté par schéma : chaque rubrique = une liste d'items
//  (title, subtitle, text, meta, image, video, link).
//  Stockage : table Supabase `business_extras` (une ligne par rubrique).
//  N'affecte ni BusinessBundle ni BusinessTheme.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BizLayout { standard, logo, steps }

const List<String> kBizFieldKeys = [
  'title',
  'subtitle',
  'text',
  'meta',
  'image',
  'video',
  'link',
];

/// Libellés par défaut (éditeur — côté propriétaire).
const Map<String, String> kBizFieldLabelsFr = {
  'title': 'Titre',
  'subtitle': 'Sous-titre',
  'text': 'Description',
  'meta': 'Info (prix, date, lieu…)',
  'image': 'Photo',
  'video': 'Vidéo (upload ou lien)',
  'link': 'Lien externe',
};

class BizKindSpec {
  const BizKindSpec({
    required this.key,
    required this.icon,
    required this.fr,
    required this.en,
    required this.fields,
    this.layout = BizLayout.standard,
    this.labels = const {},
  });

  final String key;
  final IconData icon;
  final String fr;
  final String en;
  final BizLayout layout;
  final List<String> fields;
  final Map<String, String> labels;

  String labelOf(String field) =>
      labels[field] ?? kBizFieldLabelsFr[field] ?? field;
}

/// Les 10 rubriques avancées.
const List<BizKindSpec> kBizKinds = [
  BizKindSpec(
    key: 'videos',
    icon: Icons.play_circle_outline_rounded,
    fr: 'Vidéos',
    en: 'Videos',
    fields: ['title', 'text', 'video', 'image'],
    labels: {'image': 'Miniature (photo)'},
  ),
  BizKindSpec(
    key: 'partners',
    icon: Icons.handshake_outlined,
    fr: 'Partenaires',
    en: 'Partners',
    layout: BizLayout.logo,
    fields: ['title', 'image', 'link'],
    labels: {
      'title': 'Nom du partenaire',
      'image': 'Logo',
      'link': 'Site web',
    },
  ),
  BizKindSpec(
    key: 'clients',
    icon: Icons.business_center_outlined,
    fr: 'Ils nous font confiance',
    en: 'Trusted by',
    layout: BizLayout.logo,
    fields: ['title', 'subtitle', 'image'],
    labels: {
      'title': 'Nom du client',
      'subtitle': 'Secteur',
      'image': 'Logo',
    },
  ),
  BizKindSpec(
    key: 'certs',
    icon: Icons.workspace_premium_outlined,
    fr: 'Certifications',
    en: 'Certifications',
    fields: ['title', 'subtitle', 'meta', 'image'],
    labels: {
      'subtitle': 'Organisme',
      'meta': 'Année',
      'image': 'Photo du certificat',
    },
  ),
  BizKindSpec(
    key: 'projects',
    icon: Icons.rocket_launch_outlined,
    fr: 'Projets & études de cas',
    en: 'Projects & case studies',
    fields: ['title', 'subtitle', 'text', 'image', 'video', 'link'],
    labels: {'subtitle': 'Client'},
  ),
  BizKindSpec(
    key: 'process',
    icon: Icons.timeline_rounded,
    fr: 'Notre méthode',
    en: 'Our process',
    layout: BizLayout.steps,
    fields: ['title', 'text', 'image'],
    labels: {'title': "Titre de l'étape"},
  ),
  BizKindSpec(
    key: 'events',
    icon: Icons.event_available_outlined,
    fr: 'Événements',
    en: 'Events',
    fields: ['title', 'meta', 'subtitle', 'text', 'image', 'video', 'link'],
    labels: {'meta': 'Date', 'subtitle': 'Lieu'},
  ),
  BizKindSpec(
    key: 'careers',
    icon: Icons.work_outline_rounded,
    fr: 'Carrières',
    en: 'Careers',
    fields: ['title', 'subtitle', 'meta', 'text', 'image', 'link'],
    labels: {
      'title': 'Poste',
      'subtitle': 'Type de contrat',
      'meta': 'Lieu',
      'link': 'Lien de candidature',
    },
  ),
  BizKindSpec(
    key: 'pricing',
    icon: Icons.sell_outlined,
    fr: 'Tarifs & packs',
    en: 'Pricing & packs',
    fields: ['title', 'meta', 'text', 'image', 'link'],
    labels: {'title': 'Nom du pack', 'meta': 'Prix'},
  ),
  BizKindSpec(
    key: 'branches',
    icon: Icons.location_on_outlined,
    fr: 'Agences & implantations',
    en: 'Offices & locations',
    fields: ['title', 'subtitle', 'meta', 'image', 'link'],
    labels: {
      'title': "Nom de l'agence",
      'subtitle': 'Adresse',
      'meta': 'Téléphone',
      'link': 'Lien carte (Google Maps)',
    },
  ),
];

final Map<String, BizKindSpec> kBizKindByKey = {
  for (final k in kBizKinds) k.key: k,
};

// ─────────────────────────────────────────────────────────────────────────────
// Modèle
// ─────────────────────────────────────────────────────────────────────────────

class BizExtra {
  BizExtra({
    required this.kind,
    this.visible = false,
    this.position = 0,
    this.title,
    List<Map<String, String>>? items,
  }) : items = items ?? <Map<String, String>>[];

  final String kind;
  bool visible;
  int position;
  String? title;
  List<Map<String, String>> items;

  factory BizExtra.fromRow(Map<String, dynamic> r) {
    final raw = r['items'];
    final list = <Map<String, String>>[];
    if (raw is List) {
      for (final it in raw) {
        if (it is Map) {
          list.add({
            for (final e in it.entries)
              e.key.toString(): (e.value ?? '').toString(),
          });
        }
      }
    }
    return BizExtra(
      kind: r['kind'] as String,
      visible: r['visible'] as bool? ?? false,
      position: (r['position'] as num?)?.toInt() ?? 0,
      title: r['title'] as String?,
      items: list,
    );
  }

  Map<String, dynamic> toRow(String businessId) => {
        'business_id': businessId,
        'kind': kind,
        'visible': visible,
        'position': position,
        'title': (title == null || title!.trim().isEmpty) ? null : title!.trim(),
        'items': items,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  BizExtra copy() => BizExtra(
        kind: kind,
        visible: visible,
        position: position,
        title: title,
        items: [for (final i in items) Map<String, String>.from(i)],
      );

  bool get hasContent =>
      items.any((i) => (i['title'] ?? '').trim().isNotEmpty);
}

// ─────────────────────────────────────────────────────────────────────────────
// Repository + provider
// ─────────────────────────────────────────────────────────────────────────────

class BusinessExtrasRepository {
  BusinessExtrasRepository();

  SupabaseClient get _c => Supabase.instance.client;

  /// Ne lève jamais : si la table n'existe pas encore, retourne [].
  Future<List<BizExtra>> fetch(String businessId) async {
    try {
      final rows = await _c
          .from('business_extras')
          .select()
          .eq('business_id', businessId)
          .order('position');
      return [
        for (final r in rows as List)
          BizExtra.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e) {
      debugPrint('[BizExtras] fetch : $e');
      return <BizExtra>[];
    }
  }

  Future<void> save(String businessId, BizExtra extra) async {
    await _c
        .from('business_extras')
        .upsert(extra.toRow(businessId), onConflict: 'business_id,kind');
  }
}

final businessExtrasRepositoryProvider =
    Provider<BusinessExtrasRepository>((ref) => BusinessExtrasRepository());

final businessExtrasProvider = FutureProvider.autoDispose
    .family<List<BizExtra>, String>((ref, businessId) {
  return ref.read(businessExtrasRepositoryProvider).fetch(businessId);
});
