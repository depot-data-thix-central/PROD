
/// Modèle représentant un message vocal (audio) dans une conversation.
class AudioMessage {
  /// Identifiant unique du fichier audio.
  final String id;

  /// Identifiant du message parent (référence à [ChatMessage]).
  final String messageId;

  /// URL publique du fichier audio hébergé sur Supabase Storage.
  final String url;

  /// Durée du fichier audio en secondes.
  final int duration;

  /// Taille du fichier en octets.
  final int size;

  /// Données de l'onde sonore (optionnel), encodées en base64 ou liste de niveaux.
  final String? waveform;

  /// Indique si le message est en cours de lecture.
  final bool isPlaying;

  /// Progression de la lecture (entre 0.0 et 1.0).
  final double progress;

  /// Indique si le message a été écouté jusqu'au bout.
  final bool isFullyHeard;

  /// Indique si le message est en cours de téléchargement.
  final bool isLoading;

  /// Date de création du fichier audio.
  final DateTime createdAt;

  const AudioMessage({
    required this.id,
    required this.messageId,
    required this.url,
    required this.duration,
    required this.size,
    this.waveform,
    this.isPlaying = false,
    this.progress = 0.0,
    this.isFullyHeard = false,
    this.isLoading = false,
    required this.createdAt,
  });

  /// Crée une instance depuis un JSON (typiquement depuis Supabase).
  factory AudioMessage.fromJson(Map<String, dynamic> json) {
    return AudioMessage(
      id: json['id'] ?? '',
      messageId: json['message_id'] ?? '',
      url: json['url'] ?? '',
      duration: json['duration'] ?? 0,
      size: json['size'] ?? 0,
      waveform: json['waveform'],
      isPlaying: json['is_playing'] ?? false,
      progress: (json['progress'] ?? 0.0).toDouble(),
      isFullyHeard: json['is_fully_heard'] ?? false,
      isLoading: json['is_loading'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// Convertit l'objet en JSON pour l'insertion/update en base.
  Map<String, dynamic> toJson() => {
    'id': id,
    'message_id': messageId,
    'url': url,
    'duration': duration,
    'size': size,
    'waveform': waveform,
    'is_playing': isPlaying,
    'progress': progress,
    'is_fully_heard': isFullyHeard,
    'is_loading': isLoading,
    'created_at': createdAt.toIso8601String(),
  };

  /// Copie de l'objet avec des champs modifiés.
  AudioMessage copyWith({
    String? id,
    String? messageId,
    String? url,
    int? duration,
    int? size,
    String? waveform,
    bool? isPlaying,
    double? progress,
    bool? isFullyHeard,
    bool? isLoading,
    DateTime? createdAt,
  }) {
    return AudioMessage(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      url: url ?? this.url,
      duration: duration ?? this.duration,
      size: size ?? this.size,
      waveform: waveform ?? this.waveform,
      isPlaying: isPlaying ?? this.isPlaying,
      progress: progress ?? this.progress,
      isFullyHeard: isFullyHeard ?? this.isFullyHeard,
      isLoading: isLoading ?? this.isLoading,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Formate la durée en chaîne lisible (ex: "02:35").
  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Taille formatée en Ko ou Mo.
  String get formattedSize {
    if (size < 1024) return '$size o';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} Ko';
    return '${(size / 1048576).toStringAsFixed(1)} Mo';
  }
}
