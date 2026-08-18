import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _disputes = [];
  List<Map<String, dynamic>> _messages = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isLoadingDisputes = false;
  bool _isLoadingMessages = false;
  Stream<List<Map<String, dynamic>>>? _messagesStream;

  List<Map<String, dynamic>> get conversations => _conversations;
  List<Map<String, dynamic>> get disputes => _disputes;
  List<Map<String, dynamic>> get messages => _messages;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isLoadingDisputes => _isLoadingDisputes;
  bool get isLoadingMessages => _isLoadingMessages;

  Future<void> loadConversations() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    _setLoading(true);
    try {
      final response = await _supabase
          .from('conversations')
          .select()
          .eq('participant_ids', userId)
          .order('last_message_time', ascending: false);
      _conversations = List<Map<String, dynamic>>.from(response);
      _unreadCount = _conversations.fold<int>(0, (sum, c) => sum + ((c['unread_count'] as int?) ?? 0));
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadDisputes() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    _setLoadingDisputes(true);
    try {
      final response = await _supabase
          .from('disputes')
          .select('*, order:orders(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      _disputes = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading disputes: $e');
    } finally {
      _setLoadingDisputes(false);
    }
  }

  void subscribeToMessages(String conversationId) {
    _messagesStream = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((data) => List<Map<String, dynamic>>.from(data));
    
    _messagesStream?.listen((newMessages) {
      _messages = newMessages;
      notifyListeners();
    });
  }

  Future<void> loadMessages(String conversationId) async {
    _setLoadingMessages(true);
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      _messages = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      _setLoadingMessages(false);
    }
  }

  Future<void> sendMessage(String conversationId, String message, {String? imageUrl, String? audioUrl}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    try {
      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': userId,
        'message': message,
        'image_url': imageUrl,
        'audio_url': audioUrl,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      await _supabase
          .from('conversations')
          .update({
            'last_message': message,
            'last_message_time': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    try {
      await _supabase
          .from('conversation_participants')
          .update({'unread_count': 0, 'last_read_at': DateTime.now().toIso8601String()})
          .match({'conversation_id': conversationId, 'user_id': userId});
      await loadConversations();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> createDispute(Map<String, dynamic> disputeData) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    try {
      await _supabase.from('disputes').insert({
        ...disputeData,
        'user_id': userId,
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
      });
      await loadDisputes();
    } catch (e) {
      debugPrint('Error creating dispute: $e');
      rethrow;
    }
  }

  Future<void> updateDisputeStatus(String disputeId, String status) async {
    try {
      await _supabase
          .from('disputes')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', disputeId);
      await loadDisputes();
    } catch (e) {
      debugPrint('Error updating dispute: $e');
      rethrow;
    }
  }

  void setTyping(String conversationId, bool isTyping) {
    // ✅ sendBroadcastMessage évite de dépendre de RealtimeListenTypes
    _supabase.channel(conversationId).sendBroadcastMessage(
      event: 'typing',
      payload: {
        'user_id': _supabase.auth.currentUser?.id,
        'is_typing': isTyping,
      },
    );
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setLoadingDisputes(bool loading) {
    _isLoadingDisputes = loading;
    notifyListeners();
  }

  void _setLoadingMessages(bool loading) {
    _isLoadingMessages = loading;
    notifyListeners();
  }
}
