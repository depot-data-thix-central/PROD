// Route: lib/models/chat/call_status.dart
// PRODUCTION - Enums complets appel

enum CallType {
  audio,
  video;

  String get name => toString().split('.').last;

  static CallType fromString(String v) {
    switch (v.toLowerCase()) {
      case 'video':
        return CallType.video;
      case 'audio':
      default:
        return CallType.audio;
    }
  }

  bool get isVideo => this == CallType.video;
  bool get isAudio => this == CallType.audio;
}

enum CallStatus {
  idle,
  ringing,
  accepted,
  ongoing,
  ended,
  rejected,
  missed,
  busy,
  canceled,
  failed;

  String get name => toString().split('.').last;

  static CallStatus fromString(String v) {
    switch (v.toLowerCase()) {
      case 'ringing':
        return CallStatus.ringing;
      case 'accepted':
        return CallStatus.accepted;
      case 'ongoing':
        return CallStatus.ongoing;
      case 'ended':
        return CallStatus.ended;
      case 'rejected':
        return CallStatus.rejected;
      case 'missed':
        return CallStatus.missed;
      case 'busy':
        return CallStatus.busy;
      case 'canceled':
      case 'cancelled':
        return CallStatus.canceled;
      case 'failed':
        return CallStatus.failed;
      case 'idle':
      default:
        return CallStatus.idle;
    }
  }

  bool get isActive => this == CallStatus.ringing || this == CallStatus.accepted || this == CallStatus.ongoing;
  bool get isFinished => this == CallStatus.ended || this == CallStatus.rejected || this == CallStatus.missed || this == CallStatus.busy || this == CallStatus.canceled || this == CallStatus.failed;
}

extension CallStatusX on CallStatus {
  String get label {
    switch (this) {
      case CallStatus.ringing: return 'Appel...';
      case CallStatus.accepted: return 'Accepté';
      case CallStatus.ongoing: return 'En cours';
      case CallStatus.ended: return 'Terminé';
      case CallStatus.rejected: return 'Refusé';
      case CallStatus.missed: return 'Manqué';
      case CallStatus.busy: return 'Occupé';
      case CallStatus.canceled: return 'Annulé';
      case CallStatus.failed: return 'Échoué';
      case CallStatus.idle: return 'Inactif';
    }
  }

  String get emoji {
    switch (this) {
      case CallStatus.ringing: return '📞';
      case CallStatus.ongoing: return '🟢';
      case CallStatus.ended: return '✅';
      case CallStatus.rejected: return '❌';
      case CallStatus.missed: return '📵';
      case CallStatus.busy: return '⛔';
      default: return '📞';
    }
  }
}
