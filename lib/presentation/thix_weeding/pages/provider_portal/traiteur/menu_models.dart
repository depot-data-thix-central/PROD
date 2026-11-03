// lib/presentation/thix_weeding/pages/provider_portal/traiteur/menu_models.dart

import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — MODÈLES MENU TRAITEUR (Menu + Validation + Votes)
/// ═══════════════════════════════════════════════════════════════════════

enum MenuStatus {
  draft,              // Menu en cours de création
  submitted,          // Soumis au staff pour validation
  validated,          // Validé par le staff
  public,             // Rendu public pour les invités
  finalized,          // Finalisé après votes
}

enum MenuItemCategory {
  aperitif,
  entree,
  plat,
  dessert,
  boisson,
}

enum DietaryRestriction {
  vegetarian,
  vegan,
  halal,
  kosher,
  glutenFree,
  lactoseFree,
  nutFree,
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final MenuItemCategory category;
  final String? imageUrl;
  final List<DietaryRestriction> dietaryOptions;
  final double? pricePerPerson;
  final bool isAvailable;
  final int preparationTime; // en minutes
  final String? chefNote;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.imageUrl,
    this.dietaryOptions = const [],
    this.pricePerPerson,
    this.isAvailable = true,
    this.preparationTime = 30,
    this.chefNote,
  });

  String get categoryDisplayName {
    switch (category) {
      case MenuItemCategory.aperitif:
        return 'Apéritif';
      case MenuItemCategory.entree:
        return 'Entrée';
      case MenuItemCategory.plat:
        return 'Plat principal';
      case MenuItemCategory.dessert:
        return 'Dessert';
      case MenuItemCategory.boisson:
        return 'Boisson';
    }
  }

  Color getCategoryColor() {
    switch (category) {
      case MenuItemCategory.aperitif:
        return const Color(0xFF8B5CF6);
      case MenuItemCategory.entree:
        return const Color(0xFF10B981);
      case MenuItemCategory.plat:
        return const Color(0xFFF59E0B);
      case MenuItemCategory.dessert:
        return const Color(0xFFEC4899);
      case MenuItemCategory.boisson:
        return const Color(0xFF3B82F6);
    }
  }

  IconData getCategoryIcon() {
    switch (category) {
      case MenuItemCategory.aperitif:
        return Icons.local_bar;
      case MenuItemCategory.entree:
        return Icons.restaurant;
      case MenuItemCategory.plat:
        return Icons.dinner_dining;
      case MenuItemCategory.dessert:
        return Icons.icecream;
      case MenuItemCategory.boisson:
        return Icons.local_drink;
    }
  }

  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    MenuItemCategory? category,
    String? imageUrl,
    List<DietaryRestriction>? dietaryOptions,
    double? pricePerPerson,
    bool? isAvailable,
    int? preparationTime,
    String? chefNote,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      dietaryOptions: dietaryOptions ?? this.dietaryOptions,
      pricePerPerson: pricePerPerson ?? this.pricePerPerson,
      isAvailable: isAvailable ?? this.isAvailable,
      preparationTime: preparationTime ?? this.preparationTime,
      chefNote: chefNote ?? this.chefNote,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'image_url': imageUrl,
      'dietary_options': dietaryOptions.map((d) => d.name).toList(),
      'price_per_person': pricePerPerson,
      'is_available': isAvailable,
      'preparation_time': preparationTime,
      'chef_note': chefNote,
    };
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: MenuItemCategory.values.firstWhere((c) => c.name == json['category']),
      imageUrl: json['image_url'] as String?,
      dietaryOptions: (json['dietary_options'] as List?)
              ?.map((d) => DietaryRestriction.values.firstWhere((e) => e.name == d))
              .toList() ??
          [],
      pricePerPerson: (json['price_per_person'] as num?)?.toDouble(),
      isAvailable: json['is_available'] as bool? ?? true,
      preparationTime: json['preparation_time'] as int? ?? 30,
      chefNote: json['chef_note'] as String?,
    );
  }
}

class WeddingMenu {
  final String id;
  final String orderId;
  final String providerId;
  final String title;
  final String? description;
  final List<MenuItem> items;
  final MenuStatus status;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final DateTime? validatedAt;
  final DateTime? publishedAt;
  final String? validationNote;
  final bool isPublic;
  final int maxGuests;
  final double? pricePerPerson;
  final Map<String, dynamic>? additionalInfo;

  const WeddingMenu({
    required this.id,
    required this.orderId,
    required this.providerId,
    required this.title,
    this.description,
    required this.items,
    this.status = MenuStatus.draft,
    required this.createdAt,
    this.submittedAt,
    this.validatedAt,
    this.publishedAt,
    this.validationNote,
    this.isPublic = false,
    required this.maxGuests,
    this.pricePerPerson,
    this.additionalInfo,
  });

  String get statusDisplayName {
    switch (status) {
      case MenuStatus.draft:
        return 'Brouillon';
      case MenuStatus.submitted:
        return 'En validation';
      case MenuStatus.validated:
        return 'Validé';
      case MenuStatus.public:
        return 'Public';
      case MenuStatus.finalized:
        return 'Finalisé';
    }
  }

  Color getStatusColor() {
    switch (status) {
      case MenuStatus.draft:
        return Colors.grey;
      case MenuStatus.submitted:
        return Colors.orange;
      case MenuStatus.validated:
        return Colors.blue;
      case MenuStatus.public:
        return Colors.green;
      case MenuStatus.finalized:
        return Colors.purple;
    }
  }

  List<MenuItem> getItemsByCategory(MenuItemCategory category) {
    return items.where((item) => item.category == category).toList();
  }

  int getItemCountByCategory(MenuItemCategory category) {
    return items.where((item) => item.category == category).length;
  }

  bool get hasAllCategories {
    for (var category in MenuItemCategory.values) {
      if (getItemsByCategory(category).isEmpty) return false;
    }
    return true;
  }

  double get estimatedTotalPrice {
    return (pricePerPerson ?? 0) * maxGuests;
  }

  WeddingMenu copyWith({
    String? id,
    String? orderId,
    String? providerId,
    String? title,
    String? description,
    List<MenuItem>? items,
    MenuStatus? status,
    DateTime? createdAt,
    DateTime? submittedAt,
    DateTime? validatedAt,
    DateTime? publishedAt,
    String? validationNote,
    bool? isPublic,
    int? maxGuests,
    double? pricePerPerson,
    Map<String, dynamic>? additionalInfo,
  }) {
    return WeddingMenu(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      providerId: providerId ?? this.providerId,
      title: title ?? this.title,
      description: description ?? this.description,
      items: items ?? this.items,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
      validatedAt: validatedAt ?? this.validatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      validationNote: validationNote ?? this.validationNote,
      isPublic: isPublic ?? this.isPublic,
      maxGuests: maxGuests ?? this.maxGuests,
      pricePerPerson: pricePerPerson ?? this.pricePerPerson,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'provider_id': providerId,
      'title': title,
      'description': description,
      'items': items.map((i) => i.toJson()).toList(),
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'validated_at': validatedAt?.toIso8601String(),
      'published_at': publishedAt?.toIso8601String(),
      'validation_note': validationNote,
      'is_public': isPublic,
      'max_guests': maxGuests,
      'price_per_person': pricePerPerson,
      'additional_info': additionalInfo,
    };
  }

  factory WeddingMenu.fromJson(Map<String, dynamic> json) {
    return WeddingMenu(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      providerId: json['provider_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      items: (json['items'] as List)
          .map((i) => MenuItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      status: MenuStatus.values.firstWhere((s) => s.name == json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      validatedAt: json['validated_at'] != null
          ? DateTime.parse(json['validated_at'] as String)
          : null,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      validationNote: json['validation_note'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      maxGuests: json['max_guests'] as int,
      pricePerPerson: (json['price_per_person'] as num?)?.toDouble(),
      additionalInfo: json['additional_info'] as Map<String, dynamic>?,
    );
  }
}

class GuestVote {
  final String id;
  final String guestId;
  final String guestName;
  final String guestEmail;
  final String menuId;
  final Map<String, List<String>> choices; // category -> list of item ids
  final String? comment;
  final DateTime votedAt;
  final List<String>? dietaryRestrictions;

  const GuestVote({
    required this.id,
    required this.guestId,
    required this.guestName,
    required this.guestEmail,
    required this.menuId,
    required this.choices,
    this.comment,
    required this.votedAt,
    this.dietaryRestrictions,
  });

  List<String> getChoicesForCategory(String category) {
    return choices[category] ?? [];
  }

  bool hasVotedForCategory(String category) {
    return choices.containsKey(category) && choices[category]!.isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guest_id': guestId,
      'guest_name': guestName,
      'guest_email': guestEmail,
      'menu_id': menuId,
      'choices': choices,
      'comment': comment,
      'voted_at': votedAt.toIso8601String(),
      'dietary_restrictions': dietaryRestrictions,
    };
  }

  factory GuestVote.fromJson(Map<String, dynamic> json) {
    return GuestVote(
      id: json['id'] as String,
      guestId: json['guest_id'] as String,
      guestName: json['guest_name'] as String,
      guestEmail: json['guest_email'] as String,
      menuId: json['menu_id'] as String,
      choices: (json['choices'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      ),
      comment: json['comment'] as String?,
      votedAt: DateTime.parse(json['voted_at'] as String),
      dietaryRestrictions: json['dietary_restrictions'] as List<String>?,
    );
  }
}

class MenuValidation {
  final String id;
  final String menuId;
  final String staffId;
  final String staffName;
  final bool approved;
  final String? comment;
  final DateTime validatedAt;
  final List<String>? requestedChanges;

  const MenuValidation({
    required this.id,
    required this.menuId,
    required this.staffId,
    required this.staffName,
    required this.approved,
    this.comment,
    required this.validatedAt,
    this.requestedChanges,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_id': menuId,
      'staff_id': staffId,
      'staff_name': staffName,
      'approved': approved,
      'comment': comment,
      'validated_at': validatedAt.toIso8601String(),
      'requested_changes': requestedChanges,
    };
  }

  factory MenuValidation.fromJson(Map<String, dynamic> json) {
    return MenuValidation(
      id: json['id'] as String,
      menuId: json['menu_id'] as String,
      staffId: json['staff_id'] as String,
      staffName: json['staff_name'] as String,
      approved: json['approved'] as bool,
      comment: json['comment'] as String?,
      validatedAt: DateTime.parse(json['validated_at'] as String),
      requestedChanges: json['requested_changes'] as List<String>?,
    );
  }
}

class MenuStatistics {
  final String menuId;
  final int totalVotes;
  final int totalGuests;
  final Map<String, int> votesByCategory;
  final Map<String, Map<String, int>> itemVotes;
  final DateTime lastUpdated;

  const MenuStatistics({
    required this.menuId,
    required this.totalVotes,
    required this.totalGuests,
    required this.votesByCategory,
    required this.itemVotes,
    required this.lastUpdated,
  });

  double get participationRate {
    if (totalGuests == 0) return 0;
    return totalVotes / totalGuests;
  }

  String get mostVotedItem {
    int maxVotes = 0;
    String mostVoted = '';
    
    for (var category in itemVotes.keys) {
      for (var item in itemVotes[category]!.keys) {
        if (itemVotes[category]![item]! > maxVotes) {
          maxVotes = itemVotes[category]![item]!;
          mostVoted = item;
        }
      }
    }
    
    return mostVoted;
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_id': menuId,
      'total_votes': totalVotes,
      'total_guests': totalGuests,
      'votes_by_category': votesByCategory,
      'item_votes': itemVotes,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  factory MenuStatistics.fromJson(Map<String, dynamic> json) {
    return MenuStatistics(
      menuId: json['menu_id'] as String,
      totalVotes: json['total_votes'] as int,
      totalGuests: json['total_guests'] as int,
      votesByCategory: Map<String, int>.from(json['votes_by_category']),
      itemVotes: (json['item_votes'] as Map<String, dynamic>).map(
        (category, items) => MapEntry(
          category,
          Map<String, int>.from(items as Map<String, dynamic>),
        ),
      ),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }
}
