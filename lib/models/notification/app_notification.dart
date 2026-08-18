// lib/models/notification/app_notification.dart

class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final bool read;
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.data,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return AppNotification(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      type: (map['type'] ?? 'generic').toString(),
      title: (map['title'] ?? 'THIX ID').toString(),
      body: (map['body'] ?? '').toString(),
      read: (map['read'] as bool?) ?? false,
      data: (map['data'] is Map) ? (map['data'] as Map).cast<String, dynamic>() : const {},
      createdAt: parseDate(map['created_at']),
    );
  }

  /// Icône suggérée selon le type de notification (module d'origine)
  String get iconKey {
    switch (type) {
      case 'chat':
        return 'chat';
      case 'money':
      case 'payment':
        return 'money';
      case 'live':
      case 'network':
        return 'live';
      case 'opportunity':
      case 'job':
        return 'opportunity';
      case 'event':
        return 'event';
      case 'health':
        return 'health';
      case 'market':
        return 'market';
      default:
        return 'generic';
    }
  }
}
