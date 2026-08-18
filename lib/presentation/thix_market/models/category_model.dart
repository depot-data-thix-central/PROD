class CategoryModel {
  final String id;
  final String name;
  final String? slug;
  final String? icon;
  final String? imageUrl;
  final String? parentId;
  final int level;
  final int sortOrder;
  final int productsCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.slug,
    this.icon,
    this.imageUrl,
    this.parentId,
    this.level = 0,
    this.sortOrder = 0,
    this.productsCount = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      icon: json['icon'] as String?,
      imageUrl: json['image_url'] as String?,
      parentId: json['parent_id'] as String?,
      level: json['level'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      productsCount: json['products_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'icon': icon,
      'image_url': imageUrl,
      'parent_id': parentId,
      'level': level,
      'sort_order': sortOrder,
      'products_count': productsCount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isParent => parentId == null;
  List<CategoryModel>? children;
}

class CategoryFilter {
  final String id;
  final String name;
  final String type;
  final List<CategoryFilterValue> values;

  CategoryFilter({
    required this.id,
    required this.name,
    required this.type,
    required this.values,
  });

  factory CategoryFilter.fromJson(Map<String, dynamic> json) {
    return CategoryFilter(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      values: (json['values'] as List?)
          ?.map((e) => CategoryFilterValue.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'values': values.map((e) => e.toJson()).toList(),
    };
  }
}

class CategoryFilterValue {
  final String id;
  final String value;
  final int count;

  CategoryFilterValue({
    required this.id,
    required this.value,
    this.count = 0,
  });

  factory CategoryFilterValue.fromJson(Map<String, dynamic> json) {
    return CategoryFilterValue(
      id: json['id'] as String,
      value: json['value'] as String,
      count: json['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'count': count,
    };
  }
}
