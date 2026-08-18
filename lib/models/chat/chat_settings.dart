// ============================================================
// 📁 lib/models/chat/chat_settings.dart
// ============================================================

class ChatSettings {
  // Apparence
  final String theme; // 'light', 'dark', 'system'
  final String wallpaper; // 'default', 'solid_color', 'image_url'
  final double fontSize;
  final String bubbleStyle; // 'rounded', 'square'
  final String accentColor; // 'blue', 'gold', 'green', 'purple'

  // Confidentialité
  final String lastSeenVisibility; // 'everyone', 'contacts', 'nobody'
  final String profilePhotoVisibility; // 'everyone', 'contacts', 'nobody'
  final String statusVisibility; // 'everyone', 'contacts', 'nobody'
  final bool readReceipts;
  final bool typingIndicator;

  // Messages
  final int? ephemeralDuration; // null = désactivé
  final bool ephemeralDefault;

  // Notifications
  final bool notifMessages;
  final bool notifCalls;
  final bool notifSound;
  final bool notifVibration;
  final bool notifPreview;

  // Stockage
  final String autoDownload; // 'wifi', 'mobile', 'never'

  ChatSettings({
    this.theme = 'system',
    this.wallpaper = 'default',
    this.fontSize = 14.0,
    this.bubbleStyle = 'rounded',
    this.accentColor = 'blue',
    this.lastSeenVisibility = 'everyone',
    this.profilePhotoVisibility = 'everyone',
    this.statusVisibility = 'everyone',
    this.readReceipts = true,
    this.typingIndicator = true,
    this.ephemeralDuration,
    this.ephemeralDefault = false,
    this.notifMessages = true,
    this.notifCalls = true,
    this.notifSound = true,
    this.notifVibration = true,
    this.notifPreview = true,
    this.autoDownload = 'wifi',
  });

  factory ChatSettings.fromJson(Map<String, dynamic> json) {
    return ChatSettings(
      theme: json['theme'] ?? 'system',
      wallpaper: json['wallpaper'] ?? 'default',
      fontSize: (json['fontSize'] ?? 14.0).toDouble(),
      bubbleStyle: json['bubbleStyle'] ?? 'rounded',
      accentColor: json['accentColor'] ?? 'blue',
      lastSeenVisibility: json['lastSeenVisibility'] ?? 'everyone',
      profilePhotoVisibility: json['profilePhotoVisibility'] ?? 'everyone',
      statusVisibility: json['statusVisibility'] ?? 'everyone',
      readReceipts: json['readReceipts'] ?? true,
      typingIndicator: json['typingIndicator'] ?? true,
      ephemeralDuration: json['ephemeralDuration'],
      ephemeralDefault: json['ephemeralDefault'] ?? false,
      notifMessages: json['notifMessages'] ?? true,
      notifCalls: json['notifCalls'] ?? true,
      notifSound: json['notifSound'] ?? true,
      notifVibration: json['notifVibration'] ?? true,
      notifPreview: json['notifPreview'] ?? true,
      autoDownload: json['autoDownload'] ?? 'wifi',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'wallpaper': wallpaper,
      'fontSize': fontSize,
      'bubbleStyle': bubbleStyle,
      'accentColor': accentColor,
      'lastSeenVisibility': lastSeenVisibility,
      'profilePhotoVisibility': profilePhotoVisibility,
      'statusVisibility': statusVisibility,
      'readReceipts': readReceipts,
      'typingIndicator': typingIndicator,
      'ephemeralDuration': ephemeralDuration,
      'ephemeralDefault': ephemeralDefault,
      'notifMessages': notifMessages,
      'notifCalls': notifCalls,
      'notifSound': notifSound,
      'notifVibration': notifVibration,
      'notifPreview': notifPreview,
      'autoDownload': autoDownload,
    };
  }

  ChatSettings copyWith({
    String? theme,
    String? wallpaper,
    double? fontSize,
    String? bubbleStyle,
    String? accentColor,
    String? lastSeenVisibility,
    String? profilePhotoVisibility,
    String? statusVisibility,
    bool? readReceipts,
    bool? typingIndicator,
    int? ephemeralDuration,
    bool? ephemeralDefault,
    bool? notifMessages,
    bool? notifCalls,
    bool? notifSound,
    bool? notifVibration,
    bool? notifPreview,
    String? autoDownload,
  }) {
    return ChatSettings(
      theme: theme ?? this.theme,
      wallpaper: wallpaper ?? this.wallpaper,
      fontSize: fontSize ?? this.fontSize,
      bubbleStyle: bubbleStyle ?? this.bubbleStyle,
      accentColor: accentColor ?? this.accentColor,
      lastSeenVisibility: lastSeenVisibility ?? this.lastSeenVisibility,
      profilePhotoVisibility: profilePhotoVisibility ?? this.profilePhotoVisibility,
      statusVisibility: statusVisibility ?? this.statusVisibility,
      readReceipts: readReceipts ?? this.readReceipts,
      typingIndicator: typingIndicator ?? this.typingIndicator,
      ephemeralDuration: ephemeralDuration ?? this.ephemeralDuration,
      ephemeralDefault: ephemeralDefault ?? this.ephemeralDefault,
      notifMessages: notifMessages ?? this.notifMessages,
      notifCalls: notifCalls ?? this.notifCalls,
      notifSound: notifSound ?? this.notifSound,
      notifVibration: notifVibration ?? this.notifVibration,
      notifPreview: notifPreview ?? this.notifPreview,
      autoDownload: autoDownload ?? this.autoDownload,
    );
  }
}
