import 'dart:io';
import 'package:flutter/material.dart';

// === SERVICES ===
import 'package:thix_id/services/chat/chat_service.dart';

// === MODÈLES (UNIFIÉS) ===
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/models/chat/user_status.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService;

  List<ChatConversation> _conversations = [];
  List<ChatConversation> _archivedConversations = [];
  List<ChatMessage> _messages = [];
  
  List<dynamic> _stories = []; 
  List<dynamic> _spaces = [];  
  dynamic _stats;              

  bool _isLoading = false;
  String? _error;

  bool _isLoadingMore = false;
  bool _hasMoreConversations = true;
  final int _pageSize = 20;

  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;

  List<ChatConversation> get conversations => _conversations;
  List<ChatConversation> get archivedConversations => _archivedConversations;
  List<ChatMessage> get messages => _messages;
  List<dynamic> get stories => _stories;
  List<dynamic> get spaces => _spaces;
  dynamic get stats => _stats;
  
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingMoreMessages => _isLoadingMoreMessages;
  bool get hasMoreConversations => _hasMoreConversations;
  bool get hasMoreMessages => _hasMoreMessages;
  String? get error => _error;

  ChatProvider(this._chatService);

  Future<void> loadConversations() async {
    _setLoading(true);
    _hasMoreConversations = true;
    try {
      final serviceConvs = await _chatService.getConversations(limit: _pageSize, offset: 0);
      _conversations = serviceConvs;
      
      if (serviceConvs.length < _pageSize) {
        _hasMoreConversations = false;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMoreConversations() async {
    if (_isLoadingMore || !_hasMoreConversations) return;
    
    _isLoadingMore = true;
    notifyListeners();

    try {
      final offset = _conversations.length;
      final serviceConvs = await _chatService.getConversations(limit: _pageSize, offset: offset);
      
      if (serviceConvs.isEmpty) {
        _hasMoreConversations = false;
      } else {
        _conversations.addAll(serviceConvs);
        if (serviceConvs.length < _pageSize) {
          _hasMoreConversations = false;
        }
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String conversationId) async {
    _setLoading(true);
    _hasMoreMessages = true;
    try {
      _messages = await _chatService.getMessages(conversationId, limit: 50, offset: 0);
      if (_messages.length < 50) _hasMoreMessages = false;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMoreMessages(String conversationId) async {
    if (_isLoadingMoreMessages || !_hasMoreMessages) return;

    _isLoadingMoreMessages = true;
    notifyListeners();

    try {
      final offset = _messages.length;
      final olderMessages = await _chatService.getMessages(conversationId, limit: 50, offset: offset);
      
      if (olderMessages.isEmpty) {
        _hasMoreMessages = false;
      } else {
        _messages.addAll(olderMessages); 
        if (olderMessages.length < 50) _hasMoreMessages = false;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMoreMessages = false;
      notifyListeners();
    }
  }

  Future<ChatMessage> sendMessage(String conversationId, String content) async {
    try {
      final msg = await _chatService.sendMessage(
        conversationId: conversationId, 
        content: content
      );
      _messages.insert(0, msg);
      _error = null;
      notifyListeners();
      return msg;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await _chatService.markAsRead(conversationId);
      
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        final conv = _conversations[index];
        _conversations[index] = ChatConversation(
          id: conv.id,
          isGroup: conv.isGroup,
          groupName: conv.groupName,
          groupAvatar: conv.groupAvatar,
          participantIds: conv.participantIds,
          otherParticipantName: conv.otherParticipantName,
          otherParticipantAvatar: conv.otherParticipantAvatar,
          lastMessage: conv.lastMessage,
          unreadCount: 0, // Force la remise à zéro instantanée pour la liste
          updatedAt: conv.updatedAt,
          isPinned: conv.isPinned,
        );
        notifyListeners(); // Rafraîchit l'UI immédiatement
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _chatService.deleteMessage(messageId);
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addReaction(String messageId, String emoji) async {
    try {
      await _chatService.toggleReaction(messageId, emoji);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _conversations = [];
    _archivedConversations = [];
    _messages = [];
    _stories = [];
    _spaces = [];
    _stats = null;
    _isLoading = false;
    _isLoadingMore = false;
    _hasMoreConversations = true;
    _hasMoreMessages = true;
    _error = null;
    notifyListeners();
  }
}
