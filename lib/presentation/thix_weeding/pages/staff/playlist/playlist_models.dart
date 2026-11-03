// lib/presentation/thix_weeding/pages/staff/playlist/playlist_models.dart
import 'package:flutter/material.dart';

class PlaylistSong {
  final String id;
  final String weddingId;
  String title;
  String? artist;
  String? linkUrl;
  
  /// ✅ NOUVEAU : URL directe du fichier audio (MP3/WAV uploadé par le staff)
  /// Permet la lecture intégrée côté invité
  String? audioUrl;
  
  String status; // pending | approved | rejected | played
  String priority; // normal | must_play | do_not_play
  int position;
  int votes;
  String? requestedByName;
  String? requestedBy;
  String source; // guest | staff | staff_local
  DateTime? createdAt;

  PlaylistSong({
    required this.id,
    required this.weddingId,
    required this.title,
    this.artist,
    this.linkUrl,
    this.audioUrl,
    this.status = 'pending',
    this.priority = 'normal',
    this.position = 0,
    this.votes = 0,
    this.requestedByName,
    this.requestedBy,
    this.source = 'guest',
    this.createdAt,
  });

  factory PlaylistSong.fromJson(Map<String, dynamic> j) => PlaylistSong(
        id: '${j['id']}',
        weddingId: '${j['wedding_id']}',
        title: '${j['title'] ?? ''}',
        artist: (j['artist'] as String?)?.trim().isEmpty == true ? null : j['artist'] as String?,
        linkUrl: (j['link_url'] as String?)?.trim().isEmpty == true ? null : j['link_url'] as String?,
        audioUrl: (j['audio_url'] as String?)?.trim().isEmpty == true ? null : j['audio_url'] as String?,
        status: '${j['status'] ?? 'pending'}',
        priority: '${j['priority'] ?? 'normal'}',
        position: (j['position'] as num?)?.toInt() ?? 0,
        votes: (j['votes_count'] as num?)?.toInt() ?? 0,
        requestedByName: j['requested_by_name'] as String?,
        requestedBy: j['requested_by'] as String?,
        source: '${j['source'] ?? 'guest'}',
        createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'wedding_id': weddingId,
        'title': title,
        'artist': artist,
        'link_url': linkUrl,
        'audio_url': audioUrl,
        'status': status,
        'priority': priority,
        'position': position,
        'votes_count': votes,
        'requested_by_name': requestedByName,
        'requested_by': requestedBy,
        'source': source,
        'created_at': createdAt?.toIso8601String(),
      };

  bool get isMust => priority == 'must_play';
  bool get isAvoid => priority == 'do_not_play';
  String get line => artist == null ? title : '$title — $artist';
  
  /// ✅ Vérifie si ce titre a un fichier audio uploadé
  bool get hasAudioFile => audioUrl != null && audioUrl!.isNotEmpty;
}

const Map<String, String> kPlaylistStatusLabel = {
  'pending': 'En attente',
  'approved': 'Validée',
  'played': 'Jouée',
  'rejected': 'Refusée',
};

const Map<String, Color> kPlaylistStatusColor = {
  'pending': Color(0xFFD97706),
  'approved': Color(0xFF059669),
  'played': Color(0xFF6B46C1),
  'rejected': Color(0xFFE31C4E),
};
