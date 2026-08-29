import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// PALETTE PREMIUM (Mode Cinéma/Netflix)
// ============================================================================
class MediaColors {
  MediaColors._();
  
  static const navyDeep = Color(0xFF030712);
  static const navy = Color(0xFF0F172A);
  static const primary = Color(0xFF3B82F6);
  static const whiteAccent = Colors.white;
  static const whiteMuted = Color(0xFF94A3B8);
  static const card = Color(0xFF1E293B);
  static const cardLight = Color(0xFF334155);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const gold = Color(0xFFFFD700);
}

// ============================================================================
// MODÈLE : MediaCounts (pour le streaming live des stats)
// ============================================================================
class MediaCounts {
  final int likeCount, viewCount, commentCount;
  const MediaCounts({
    required this.likeCount,
    required this.viewCount,
    required this.commentCount,
  });

  MediaCounts copyWith({int? likeCount, int? viewCount, int? commentCount}) {
    return MediaCounts(
      likeCount: likeCount ?? this.likeCount,
      viewCount: viewCount ?? this.viewCount,
      commentCount: commentCount ?? this.commentCount,
    );
  }
}

// ============================================================================
// ANALYTICS BATCHER (anti-spam RPC)
// ============================================================================
class AnalyticsBatcher {
  AnalyticsBatcher._();
  
  static final Set<String> _pending = {};
  static Timer? _timer;
  static const int _batchThreshold = 10;
  static const Duration _flushInterval = Duration(seconds: 15);

  static void register(String id) {
    if (id.isEmpty) return;
    _pending.add(id);
    
    if (_pending.length >= _batchThreshold) {
      _flush();
    } else {
      _timer ??= Timer(_flushInterval, _flush);
    }
  }

  static Future<void> _flush() async {
    _timer?.cancel();
    _timer = null;
    
    if (_pending.isEmpty) return;
    
    final batch = _pending.toList();
    _pending.clear();
    
    try {
      await Supabase.instance.client.rpc(
        'batch_register_views', 
        params: {'p_media_ids': batch},
      );
    } catch (e) {
      // Retry unique après 30s
      Timer(const Duration(seconds: 30), () {
        _pending.addAll(batch);
      });
    }
  }
  
  static void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }
}

// ============================================================================
// MODÈLE : CommentItem (avec anti-XSS)
// ============================================================================
class CommentItem {
  final String id, userId, userName, content;
  final String? avatarUrl, parentId;
  final DateTime createdAt;
  final int likeCount, replyCount;

  CommentItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.avatarUrl,
    this.parentId,
    this.likeCount = 0,
    this.replyCount = 0,
  });

  factory CommentItem.fromMap(Map<String, dynamic> m) {
    DateTime parsedDate;
    try {
      parsedDate = m['created_at'] != null
          ? DateTime.parse(m['created_at'].toString()).toLocal()
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }
    
    return CommentItem(
      id: m['id']?.toString() ?? '',
      userId: m['user_id']?.toString() ?? '',
      userName: _sanitize(m['user_name']?.toString()) ?? 'Utilisateur',
      avatarUrl: m['avatar_url'] as String?,
      content: _sanitize(m['content']?.toString()) ?? '',
      createdAt: parsedDate,
      parentId: m['parent_id'] as String?,
      likeCount: (m['like_count'] as num?)?.toInt() ?? 0,
      replyCount: (m['reply_count'] as num?)?.toInt() ?? 0,
    );
  }
  
  static String? _sanitize(String? input) {
    if (input == null) return null;
    final clean = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');
    return clean.length > 1000 ? clean.substring(0, 1000) : clean;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
String formatMediaNumber(int num) {
  if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
  if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
  return num.toString();
}
