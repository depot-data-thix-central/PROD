// lib/services/event_queue_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/event_waiting_queue.dart';

class EventQueueService {
  final SupabaseClient _supabase;

  EventQueueService(this._supabase);

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  // Entrer dans la file d'attente
  Future<WaitingQueue?> joinWaitingQueue(String eventId, int quantity) async {
    final userId = currentUserId;
    if (userId.isEmpty) return null;

    try {
      // Vérifier si déjà dans la file
      final existing = await _supabase
          .from('event_waiting_queue')
          .select('*')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .eq('status', 'waiting')
          .maybeSingle();

      if (existing != null) {
        return WaitingQueue.fromJson(existing);
      }

      // ✅ CORRECTION : Récupérer toutes les entrées et compter en Dart
      final allEntries = await _supabase
          .from('event_waiting_queue')
          .select('id')
          .eq('event_id', eventId)
          .eq('status', 'waiting');
      
      final position = (allEntries as List).length + 1;

      final response = await _supabase.from('event_waiting_queue').insert({
        'event_id': eventId,
        'user_id': userId,
        'quantity': quantity,
        'position': position,
        'status': 'waiting',
        'joined_at': DateTime.now().toIso8601String(),
      }).select().single();

      // Lancer le traitement de la file
      _processQueue(eventId);

      return WaitingQueue.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error joinWaitingQueue: $e');
      return null;
    }
  }

  // Traitement de la file d'attente
  Future<void> _processQueue(String eventId) async {
    try {
      // Récupérer le prochain en attente
      final next = await _supabase
          .from('event_waiting_queue')
          .select('*')
          .eq('event_id', eventId)
          .eq('status', 'waiting')
          .order('position', ascending: true)
          .limit(1)
          .maybeSingle();

      if (next != null) {
        // Vérifier si des places sont disponibles
        final availableSeats = await _getAvailableSeats(eventId);
        
        if (availableSeats >= (next['quantity'] as int)) {
          // Mettre à jour le statut
          await _supabase
              .from('event_waiting_queue')
              .update({
                'status': 'processing',
                'processed_at': DateTime.now().toIso8601String(),
              })
              .eq('id', next['id']);
          
          // Notifier l'utilisateur
          await _notifyUser(next['user_id'], eventId);
        }
      }
    } catch (e) {
      debugPrint('❌ Error processQueue: $e');
    }
  }

  // Obtenir la position dans la file
  Future<int> getQueuePosition(String eventId) async {
    final userId = currentUserId;
    if (userId.isEmpty) return -1;

    try {
      final response = await _supabase
          .from('event_waiting_queue')
          .select('position')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .eq('status', 'waiting')
          .maybeSingle();

      return response != null ? response['position'] as int : -1;
    } catch (e) {
      debugPrint('❌ Error getQueuePosition: $e');
      return -1;
    }
  }

  // ✅ CORRECTION : Compter en Dart au lieu d'utiliser count
  Future<int> getQueueSize(String eventId) async {
    try {
      final response = await _supabase
          .from('event_waiting_queue')
          .select('id')
          .eq('event_id', eventId)
          .eq('status', 'waiting');
      
      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Error getQueueSize: $e');
      return 0;
    }
  }

  // Quitter la file d'attente
  Future<void> leaveQueue(String eventId) async {
    final userId = currentUserId;
    if (userId.isEmpty) return;

    try {
      await _supabase
          .from('event_waiting_queue')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('❌ Error leaveQueue: $e');
    }
  }

  // ✅ CORRECTION : Compter en Dart
  Future<int> _getAvailableSeats(String eventId) async {
    try {
      final response = await _supabase
          .from('event_seats')
          .select('id')
          .eq('event_id', eventId)
          .eq('status', 'available');
      
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _notifyUser(String userId, String eventId) async {
    // Notification push à l'utilisateur
    debugPrint('📢 Notify user $userId: your turn for event $eventId');
    // TODO: Implémenter la notification push réelle
  }
}
