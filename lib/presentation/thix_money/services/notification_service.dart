// lib/presentation/thix_money/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final _db = Supabase.instance.client;

  // Stream notifications temps réel par thix_id
  Stream<List<Map<String, dynamic>>> streamByThixId(String thixId) {
    return _db.from('notifications')
        .stream(primaryKey: ['id'])
        .eq('thix_id', thixId)
        .order('created_at', ascending: false)
        .map((list) => list.cast<Map<String, dynamic>>());
  }

  static void showSnack(BuildContext ctx, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF0A3D62),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> markAsRead(String notifId) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', notifId);
  }
}
