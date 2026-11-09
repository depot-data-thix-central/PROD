// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — MODÈLES MÉTIER (BUNDLE)
//  Fichier  : lib/presentation/thix_portfolio/models/business_bundle.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.1.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  ✅ v1.1 : champs `imageUrl` ajoutés à :
//    • AboutContent  (image_url)  → section « À propos » avec photo
//    • ServiceItem   (image_url)  → cartes services avec photo OU icône
//
//  Regroupe tout ce qui compose le site public d'une entreprise :
//    • Business        : identité, vérification, statut
//    • BusinessTheme   : couleurs, police, style d'animation
//    • BusinessSection : bloc éditorial typé (8 types, contenu jsonb)
//    • BusinessStats   : KPI agrégés
//    • BusinessBundle  : objet racine servi à la page publique + au studio
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

import 'business_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Statut de publication
// ─────────────────────────────────────────────────────────────────────────────

enum BusinessStatus {
  draft,
  published,
  suspended,
  deleted;

  String get slug => name;

  static BusinessStatus fromSlug(String? slug) => values.firstWhere(
        (e) => e.name == slug,
        orElse: () => BusinessStatus.draft,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Business (identité)
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class Business {
  const Business({
    required this.id,
    required this.thixId,
    required this.ownerUid,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.legacySeq,
    this.claim,
    this.description,
    this.sector,
    this.city,
    this.country = 'CD',
    this.sinceYear,
    this.employees,
    this.website,
    this.phone,
    this.email,
    this.logoUrl,
    this.coverUrl,
    this.verified = false,
    this.publishedAt,
  });

  final String id; // UUID Postgres (pk)
  final String thixId; // THIX-BIZ-YYMM-SSSSS-LLL-K
  final String? legacySeq;
  final String ownerUid;
  final String name;
  final String? claim;
  final String? description;
  final String? sector;
  final String? city;
  final String country;
  final int? sinceYear;
  final int? employees;
  final String? website;
  final String? phone;
  final String? email;
  final String? logoUrl;
  final String? coverUrl;
  final bool verified;
  final BusinessStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;

  bool get isPublished => status == BusinessStatus.published;
  bool get isVisible =>
      status == BusinessStatus.published || status == BusinessStatus.draft;

  /// Âge de l'entreprise en années (null si non renseigné).
  int? get ageYears =>
      sinceYear == null ? null : DateTime.now().year - sinceYear!;

  /// Première ligne de description pour aperçu (tronquée à 140 caractères).
  String get shortDescription {
    final body = description ?? '';
    if (body.length <= 140) return body;
    return '${body.substring(0, 137).trimRight()}…';
  }

  factory Business.fromJson(Map<String, dynamic> j) => Business(
        id: j['id'] as String,
        thixId: j['thix_id'] as String,
        legacySeq: j['legacy_seq'] as String?,
        ownerUid: j['owner_uid'] as String,
        name: (j['name'] as String? ?? '').trim(),
        claim: j['claim'] as String?,
        description: j['description'] as String?,
        sector: j['sector'] as String?,
        city: j['city'] as String?,
        country: (j['country'] as String?) ?? 'CD',
        sinceYear: j['since_year'] as int?,
        employees: j['employees'] as int?,
        website: j['website'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        logoUrl: j['logo_url'] as String?,
        coverUrl: j['cover_url'] as String?,
        verified: (j['verified'] as bool?) ?? false,
        status: BusinessStatus.fromSlug(j['status'] as String?),
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        publishedAt: j['published_at'] == null
            ? null
            : DateTime.parse(j['published_at'] as String),
      );

  Map<String, Object?> toJson({bool includeId = false}) => {
        if (includeId) 'id': id,
        'thix_id': thixId,
        'legacy_seq': legacySeq,
        'owner_uid': ownerUid,
        'name': name,
        'claim': claim,
        'description': description,
        'sector': sector,
        'city': city,
        'country': country,
        'since_year': sinceYear,
        'employees': employees,
        'website': website,
        'phone': phone,
        'email': email,
        'logo_url': logoUrl,
        'cover_url': coverUrl,
        'verified': verified,
        'status': status.slug,
      };

  Business copyWith({
    String? name,
    String? claim,
    String? description,
    String? sector,
    String? city,
    String? country,
    int? sinceYear,
    int? employees,
    String? website,
    String? phone,
    String? email,
    String? logoUrl,
    String? coverUrl,
    bool? verified,
    BusinessStatus? status,
  }) =>
      Business(
        id: id,
        thixId: thixId,
        legacySeq: legacySeq,
        ownerUid: ownerUid,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        publishedAt: publishedAt,
        name: name ?? this.name,
        claim: claim ?? this.claim,
        description: description ?? this.description,
        sector: sector ?? this.sector,
        city: city ?? this.city,
        country: country ?? this.country,
        sinceYear: sinceYear ?? this.sinceYear,
        employees: employees ?? this.employees,
        website: website ?? this.website,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        logoUrl: logoUrl ?? this.logoUrl,
        coverUrl: coverUrl ?? this.coverUrl,
        verified: verified ?? this.verified,
        status: status ?? this.status,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sections — types & contenu typé (sealed class)
// ─────────────────────────────────────────────────────────────────────────────

enum BusinessSectionType {
  about,
  services,
  products,
  gallery,
  team,
  news,
  testimonials,
  contact;

  String get slug => name;

  static BusinessSectionType fromSlug(String? slug) => values.firstWhere(
        (e) => e.name == slug,
        orElse: () => BusinessSectionType.about,
      );

  String get defaultTitle {
    switch (this) {
      case BusinessSectionType.about:
        return 'À propos';
      case BusinessSectionType.services:
        return 'Nos services';
      case BusinessSectionType.products:
        return 'Produits';
      case BusinessSectionType.gallery:
        return 'Galerie';
      case BusinessSectionType.team:
        return 'Équipe';
      case BusinessSectionType.news:
        return 'Actualités';
      case BusinessSectionType.testimonials:
        return 'Témoignages';
      case BusinessSectionType.contact:
        return 'Contact';
    }
  }

  String get iconName {
    switch (this) {
      case BusinessSectionType.about:
        return 'info_outline';
      case BusinessSectionType.services:
        return 'miscellaneous_services';
      case BusinessSectionType.products:
        return 'inventory_2_outlined';
      case BusinessSectionType.gallery:
        return 'photo_library_outlined';
      case BusinessSectionType.team:
        return 'groups_outlined';
      case BusinessSectionType.news:
        return 'article_outlined';
      case BusinessSectionType.testimonials:
        return 'rate_review_outlined';
      case BusinessSectionType.contact:
        return 'mail_outline';
    }
  }
}

/// Scellée : force l'exhaustivité dans les éditeurs / switch côté UI.
@immutable
sealed class BusinessSectionContent {
  const BusinessSectionContent();

  Map<String, Object?> toJson();

  factory BusinessSectionContent.fromJson(
    BusinessSectionType type,
    Map<String, dynamic>? raw,
  ) {
    final j = raw ?? <String, dynamic>{};
    switch (type) {
      case BusinessSectionType.about:
        return AboutContent.fromJson(j);
      case BusinessSectionType.services:
        return ServicesContent.fromJson(j);
      case BusinessSectionType.products:
        return ProductsContent.fromJson(j);
      case BusinessSectionType.gallery:
        return GalleryContent.fromJson(j);
      case BusinessSectionType.team:
        return TeamContent.fromJson(j);
      case BusinessSectionType.news:
        return NewsContent.fromJson(j);
      case BusinessSectionType.testimonials:
        return TestimonialsContent.fromJson(j);
      case BusinessSectionType.contact:
        return ContactContent.fromJson(j);
    }
  }
}

// ── About (✅ v1.1 : imageUrl) ───────────────────────────────────────────────

class AboutContent extends BusinessSectionContent {
  const AboutContent({
    required this.title,
    required this.body,
    this.tagline,
    this.imageUrl,
  });

  final String title;
  final String body;
  final String? tagline;
  final String? imageUrl;

  factory AboutContent.fromJson(Map<String, dynamic> j) => AboutContent(
        title: (j['title'] as String?) ?? 'À propos',
        body: (j['body'] as String?) ?? '',
        tagline: j['tagline'] as String?,
        imageUrl: j['image_url'] as String?,
      );

  @override
  Map<String, Object?> toJson() => {
        'title': title,
        'body': body,
        'tagline': tagline,
        'image_url': imageUrl,
      };

  AboutContent copyWith({
    String? title,
    String? body,
    String? tagline,
    String? imageUrl,
  }) =>
      AboutContent(
        title: title ?? this.title,
        body: body ?? this.body,
        tagline: tagline ?? this.tagline,
        imageUrl: imageUrl ?? this.imageUrl,
      );
}

// ── Services (✅ v1.1 : ServiceItem.imageUrl) ────────────────────────────────

@immutable
class ServiceItem {
  const ServiceItem({
    required this.title,
    this.description,
    this.iconName,
    this.price,
    this.imageUrl,
  });

  final String title;
  final String? description;
  final String? iconName;
  final String? price;
  final String? imageUrl;

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
        title: (j['title'] as String?) ?? '',
        description: j['description'] as String?,
        iconName: j['icon_name'] as String?,
        price: j['price'] as String?,
        imageUrl: j['image_url'] as String?,
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'description': description,
        'icon_name': iconName,
        'price': price,
        'image_url': imageUrl,
      };
}

class ServicesContent extends BusinessSectionContent {
  const ServicesContent({required this.title, required this.items});

  final String title;
  final List<ServiceItem> items;

  factory ServicesContent.fromJson(Map<String, dynamic> j) => ServicesContent(
        title: (j['title'] as String?) ?? 'Nos services',
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ServiceItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );

  @override
  Map<String, Object?> toJson() => {
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

// ── Products ───────────────────────────────────────────────────────────────

@immutable
class ProductItem {
  const ProductItem({
    required this.title,
    this.description,
    this.imageUrl,
    this.price,
    this.currency = 'USD',
    this.url,
  });

  final String title;
  final String? description;
  final String? imageUrl;
  final String? price;
  final String currency;
  final String? url;

  factory ProductItem.fromJson(Map<String, dynamic> j) => ProductItem(
        title: (j['title'] as String?) ?? '',
        description: j['description'] as String?,
        imageUrl: j['image_url'] as String?,
        price: j['price'] as String?,
        currency: (j['currency'] as String?) ?? 'USD',
        url: j['url'] as String?,
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'price': price,
        'currency': currency,
        'url': url,
      };
}

class ProductsContent extends BusinessSectionContent {
  const ProductsContent({required this.title, required this.items});

  final String title;
  final List<ProductItem> items;

  factory ProductsContent.fromJson(Map<String, dynamic> j) => ProductsContent(
        title: (j['title'] as String?) ?? 'Produits',
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ProductItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );

  @override
  Map<String, Object?> toJson() => {
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

// ── Gallery ─────────────────────────────────────────────────────────────────

@immutable
class GalleryImage {
  const GalleryImage({required this.url, this.caption});

  final String url;
  final String? caption;

  factory GalleryImage.fromJson(Map<String, dynamic> j) => GalleryImage(
        url: (j['url'] as String?) ?? '',
        caption: j['caption'] as String?,
      );

  Map<String, Object?> toJson() => {'url': url, 'caption': caption};
}

class GalleryContent extends BusinessSectionContent {
  const GalleryContent({required this.title, required this.images});

  final String title;
  final List<GalleryImage> images;

  factory GalleryContent.fromJson(Map<String, dynamic> j) => GalleryContent(
        title: (j['title'] as String?) ?? 'Galerie',
        images: ((j['images'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => GalleryImage.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );

  @override
  Map<String, Object?> toJson() => {
        'title': title,
        'images': images.map((e) => e.toJson()).toList(),
      };
}

// ── Team ────────────────────────────────────────────────────────────────────

@immutable
class TeamMember {
  const TeamMember({
    required this.name,
    this.role,
    this.photoUrl,
    this.bio,
    this.linkedinUrl,
  });

  final String name;
  final String? role;
  final String? photoUrl;
  final String? bio;
  final String? linkedinUrl;

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        name: (j['name'] as String?) ?? '',
        role: j['role'] as String?,
        photoUrl: j['photo_url'] as String?,
        bio: j['bio'] as String?,
        linkedinUrl: j['linkedin_url'] as String?,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'role': role,
        'photo_url': photoUrl,
        'bio': bio,
        'linkedin_url': linkedinUrl,
      };
}

class TeamContent extends BusinessSectionContent {
  const TeamContent({required this.title, required this.members});

  final String title;
  final List<TeamMember> members;

  factory TeamContent.fromJson(Map<String, dynamic> j) => TeamContent(
        title: (j['title'] as String?) ?? 'Équipe',
        members: ((j['members'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => TeamMember.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );

  @override
  Map<String, Object?> toJson() => {
        'title': title,
        'members': members.map((e) => e.toJson()).toList(),
      };
}

// ── News ────────────────────────────────────────────────────────────────────

@immutable
class NewsPost {
  const NewsPost({
    required this.title,
    this.excerpt,
    this.imageUrl,
    this.publishedAt,
    this.url,
  });

  final String title;
  final String? excerpt;
  final String? imageUrl;
  final DateTime? publishedAt;
  final String? url;

  factory NewsPost.fromJson(Map<String, dynamic> j) => NewsPost(
        title: (j['title'] as String?) ?? '',
        excerpt: j['excerpt'] as String?,
        imageUrl: j['image_url'] as String?,
        publishedAt: j['published_at'] == null
            ? null
            : DateTime.tryParse(j['published_at'] as String),
        url: j['url'] as String?,
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'excerpt': excerpt,
        'image_url': imageUrl,
        if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
        'url': url,
      };
}

class NewsContent extends BusinessSectionContent {
  const NewsContent({required this.title, required this.posts});

  final String title;
  final List<NewsPost> posts;

  factory NewsContent.fromJson(Map<String, dynamic> j) => NewsContent(
        title: (j['title'] as String?) ?? 'Actualités',
        posts: ((j['posts'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => NewsPost.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );

  @override
  Map<String, Object?> toJson() => {
        'title': title,
        'posts': posts.map((e) => e.toJson()).toList(),
      };
}

// ── Testimonials ────────────────────────────────────────────────────────────

@immutable
class TestimonialItem {
  const TestimonialItem({
    required this.quote,
    this.author,
    this.role,
    this.rating,
  });

  final String quote;
  final String? author;
  final String? role;
  final int? rating; // 0..5

  factory TestimonialItem.fromJson(Map<String, dynamic> j) => TestimonialItem(
        quote: (j['quote'] as String?) ?? '',
        author: j['author'] as String?,
        role: j['role'] as String?,
        rating: (j['rating'] as num?)?.toInt(),
      );

  Map<String, Object?> toJson() => {
        'quote': quote,
        'author': author,
        'role': role,
        'rating': rating,
      };
}

class TestimonialsContent extends BusinessSectionContent {
  const TestimonialsContent({required this.title, required this.items});

  final String title;
  final List<TestimonialItem> items;

  factory TestimonialsContent.fromJson(Map<String, dynamic> j) =>
      TestimonialsContent(
        title: (j['title'] as String?) ?? 'Témoignages',
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => TestimonialItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );

  @override
  Map<String, Object?> toJson() => {
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

// ── Contact ────────────────────────────────────────────────────────────────

enum ContactChannelType { phone, email, whatsapp, website, address, map }

@immutable
class ContactChannel {
  const ContactChannel({
    required this.type,
    required this.value,
    this.label,
  });

  final ContactChannelType type;
  final String value;
  final String? label;

  factory ContactChannel.fromJson(Map<String, dynamic> j) => ContactChannel(
        type: ContactChannelType.values.firstWhere(
          (e) => e.name == (j['type'] as String?),
          orElse: () => ContactChannelType.phone,
        ),
        value: (j['value'] as String?) ?? '',
        label: j['label'] as String?,
      );

  Map<String, Object?> toJson() =>
      {'type': type.name, 'value': value, 'label': label};

  /// URI prête à ouvrir (tel: / mailto: / https://wa.me / etc.).
  Uri? get launchUri {
    switch (type) {
      case ContactChannelType.phone:
        return Uri.parse('tel:${value.replaceAll(RegExp(r'\s+'), '')}');
      case ContactChannelType.email:
        return Uri.parse('mailto:$value');
      case ContactChannelType.whatsapp:
        final cleaned = value.replaceAll(RegExp(r'\D'), '');
        return Uri.parse('https://wa.me/$cleaned');
      case ContactChannelType.website:
        return Uri.tryParse(value.startsWith('http') ? value : 'https://$value');
      case ContactChannelType.address:
        return Uri.parse('geo:0,0?q=${Uri.encodeComponent(value)}');
      case ContactChannelType.map:
        return Uri.tryParse(value);
    }
  }
}

class ContactContent extends BusinessSectionContent {
  const ContactContent({required this.title, required this.channels});

  final String title;
  final List<ContactChannel> channels;

  factory ContactContent.fromJson(Map<String, dynamic> j) => ContactContent(
        title: (j['title'] as String?) ?? 'Contact',
        channels: ((j['channels'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ContactChannel.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );

  @override
  Map<String, Object?> toJson() => {
        'title': title,
        'channels': channels.map((e) => e.toJson()).toList(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// BusinessSection (wrapper autour d'un type + contenu typé)
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class BusinessSection {
  const BusinessSection({
    required this.id,
    required this.businessId,
    required this.type,
    required this.position,
    required this.visible,
    required this.content,
  });

  final String id;
  final String businessId;
  final BusinessSectionType type;
  final int position;
  final bool visible;
  final BusinessSectionContent content;

  factory BusinessSection.fromJson(Map<String, dynamic> j) {
    final type = BusinessSectionType.fromSlug(j['type'] as String?);
    final rawContent = (j['content'] is Map)
        ? Map<String, dynamic>.from(j['content'] as Map)
        : null;
    return BusinessSection(
      id: j['id'] as String,
      businessId: j['business_id'] as String,
      type: type,
      position: (j['position'] as int?) ?? 0,
      visible: (j['visible'] as bool?) ?? true,
      content: BusinessSectionContent.fromJson(type, rawContent),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'business_id': businessId,
        'type': type.slug,
        'position': position,
        'visible': visible,
        'content': content.toJson(),
      };

  BusinessSection copyWith({
    int? position,
    bool? visible,
    BusinessSectionContent? content,
  }) =>
      BusinessSection(
        id: id,
        businessId: businessId,
        type: type,
        position: position ?? this.position,
        visible: visible ?? this.visible,
        content: content ?? this.content,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BusinessStats (agrégats quotidiens)
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class BusinessStats {
  const BusinessStats({
    this.views = 0,
    this.shares = 0,
    this.contacts = 0,
  });

  final int views;
  final int shares;
  final int contacts;

  factory BusinessStats.fromJson(Map<String, dynamic> j) => BusinessStats(
        views: (j['views'] as int?) ?? 0,
        shares: (j['shares'] as int?) ?? 0,
        contacts: (j['contacts'] as int?) ?? 0,
      );

  Map<String, Object?> toJson() =>
      {'views': views, 'shares': shares, 'contacts': contacts};

  BusinessStats copyWith({int? views, int? shares, int? contacts}) =>
      BusinessStats(
        views: views ?? this.views,
        shares: shares ?? this.shares,
        contacts: contacts ?? this.contacts,
      );

  BusinessStats operator +(BusinessStats o) => BusinessStats(
        views: views + o.views,
        shares: shares + o.shares,
        contacts: contacts + o.contacts,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BusinessBundle (objet racine servi à la page publique et au studio)
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class BusinessBundle {
  const BusinessBundle({
    required this.business,
    required this.theme,
    required this.sections,
    this.stats,
  });

  final Business business;
  final BusinessTheme theme;

  /// Sections **déjà triées** par `position`.
  final List<BusinessSection> sections;

  final BusinessStats? stats;

  factory BusinessBundle.fromJson(Map<String, dynamic> j) {
    final rawSections = (j['business_sections'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => BusinessSection.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    rawSections.sort((a, b) => a.position.compareTo(b.position));

    BusinessStats? stats;
    if (j['stats'] is Map) {
      stats =
          BusinessStats.fromJson(Map<String, dynamic>.from(j['stats'] as Map));
    }

    return BusinessBundle(
      business:
          Business.fromJson(Map<String, dynamic>.from(j['business'] ?? j)),
      theme: BusinessTheme.fromJson(
          Map<String, dynamic>.from(j['business_themes'] ?? const {})),
      sections: rawSections,
      stats: stats,
    );
  }

  /// Sections visibles uniquement, triées (utilisées par la page publique).
  List<BusinessSection> get visibleSections =>
      sections.where((s) => s.visible).toList(growable: false);

  /// Retourne la section d'un type donné (null si absente).
  BusinessSection? sectionOfType(BusinessSectionType type) {
    for (final s in sections) {
      if (s.type == type) return s;
    }
    return null;
  }

  /// URL de partage canonique.
  Uri shareUri({String baseUrl = 'https://thixid.com'}) =>
      Uri.parse('$baseUrl/b/${business.thixId}');

  BusinessBundle copyWith({
    Business? business,
    BusinessTheme? theme,
    List<BusinessSection>? sections,
    BusinessStats? stats,
  }) =>
      BusinessBundle(
        business: business ?? this.business,
        theme: theme ?? this.theme,
        sections: sections ?? this.sections,
        stats: stats ?? this.stats,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Résultat d'une création (retour de la RPC `create_business`)
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class BusinessCreationResult {
  const BusinessCreationResult({
    required this.businessId,
    required this.thixId,
    required this.status,
  });

  final String businessId;
  final String thixId;
  final BusinessStatus status;

  factory BusinessCreationResult.fromJson(Map<String, dynamic> j) =>
      BusinessCreationResult(
        businessId: j['business_id'] as String,
        thixId: j['thix_id'] as String,
        status: BusinessStatus.fromSlug(j['status'] as String?),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers polices Google Fonts
// ─────────────────────────────────────────────────────────────────────────────

/// Liste filtrée des polices Google Fonts recommandées.
const List<String> kRecommendedFontFamilies = [
  'Plus Jakarta Sans',
  'Poppins',
  'Manrope',
  'Outfit',
  'Space Grotesk',
  'Nunito',
  'Sora',
  'DM Sans',
  'Inter',
];

/// Vérifie qu'une police demandée existe bien dans Google Fonts.
bool isSupportedFont(String family) =>
    GoogleFonts.asMap().containsKey(family) ||
    kRecommendedFontFamilies.contains(family);
