import 'package:flutter/material.dart';

class NotifMeta {
  final IconData icon;
  final Color color;
  final String category;
  const NotifMeta(this.icon, this.color, this.category);
}

/// Catalogue central : type → icône/couleur/catégorie.
const Map<String, NotifMeta> kNotifCatalog = {
  'like': NotifMeta(Icons.favorite_rounded, Color(0xFFE11D48), 'network'),
  'comment': NotifMeta(Icons.mode_comment_rounded, Color(0xFF2563EB), 'network'),
  'comment_like': NotifMeta(Icons.thumb_up_rounded, Color(0xFF7C3AED), 'network'),
  'repost': NotifMeta(Icons.repeat_rounded, Color(0xFF059669), 'network'),
  'follow': NotifMeta(Icons.person_add_rounded, Color(0xFF0891B2), 'network'),
  'friend_request': NotifMeta(Icons.group_add_rounded, Color(0xFFD97706), 'network'),
  'friend_accepted': NotifMeta(Icons.handshake_rounded, Color(0xFF059669), 'network'),
  'mention': NotifMeta(Icons.alternate_email_rounded, Color(0xFF7C3AED), 'network'),
  'message': NotifMeta(Icons.chat_bubble_rounded, Color(0xFF2563EB), 'messages'),
  'call': NotifMeta(Icons.call_rounded, Color(0xFF059669), 'messages'),
  'call_missed': NotifMeta(Icons.phone_missed_rounded, Color(0xFFDC2626), 'messages'),
  'live_invite': NotifMeta(Icons.live_tv_rounded, Color(0xFFDC2626), 'media'),
  'order_new': NotifMeta(Icons.shopping_bag_rounded, Color(0xFFD97706), 'market'),
  'order_status': NotifMeta(Icons.local_shipping_rounded, Color(0xFF2563EB), 'market'),
  'payment_received': NotifMeta(Icons.payments_rounded, Color(0xFF059669), 'money'),
  'refund_requested': NotifMeta(Icons.money_off_rounded, Color(0xFFDC2626), 'money'),
  'sos': NotifMeta(Icons.sos_rounded, Color(0xFFDC2626), 'health'),
  'news': NotifMeta(Icons.newspaper_rounded, Color(0xFF2563EB), 'info'),
  'system': NotifMeta(Icons.notifications_rounded, Color(0xFF64748B), 'system'),
};

NotifMeta notifMeta(String? type) =>
    kNotifCatalog[type] ?? const NotifMeta(Icons.notifications_rounded, Color(0xFF64748B), 'system');

const Map<String, String> kCategoryLabels = {
  'all': 'Toutes',
  'network': 'Réseau',
  'messages': 'Messages',
  'market': 'Market',
  'money': 'Money',
  'health': 'Santé',
  'system': 'Système',
};
