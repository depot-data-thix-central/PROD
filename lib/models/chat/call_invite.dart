import 'call_status.dart';

class CallInvite {
  final String id;
  final String channelName;
  final String callerId;
  final String? calleeId; // Nullable pour les groupes
  final CallType callType;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSec;

  // ✅ NOUVEAU : Support des appels de groupe
  final bool isGroup;
  final List<String> participantIds;
  final List<String> acceptedIds;

  // optionnel (join profiles)
  final String? callerName;
  final String? callerAvatar;
  final String? calleeName;
  final String? calleeAvatar;

  const CallInvite({
    required this.id,
    required this.channelName,
    required this.callerId,
    this.calleeId,
    required this.callType,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.durationSec = 0,
    this.isGroup = false,
    this.participantIds = const [],
    this.acceptedIds = const [],
    this.callerName,
    this.callerAvatar,
    this.calleeName,
    this.calleeAvatar,
  });

  factory CallInvite.fromJson(Map<String, dynamic> j) {
    return CallInvite(
      id: '${j['id'] ?? j['invite_id'] ?? ''}',
      channelName: '${j['channel_name'] ?? ''}',
      callerId: '${j['caller_id'] ?? ''}',
      calleeId: j['callee_id']?.toString(),
      callType: CallType.fromString('${j['call_type'] ?? 'audio'}'),
      status: CallStatus.fromString('${j['status'] ?? 'ringing'}'),
      createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      answeredAt: j['answered_at'] != null ? DateTime.tryParse('${j['answered_at']}') : null,
      endedAt: j['ended_at'] != null ? DateTime.tryParse('${j['ended_at']}') : null,
      durationSec: (j['duration_sec'] as num?)?.toInt() ?? 0,
      // ✅ Parsing des nouveaux champs
      isGroup: j['is_group'] == true,
      participantIds: (j['participant_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      acceptedIds: (j['accepted_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      callerName: j['caller_name']?.toString(),
      callerAvatar: j['caller_avatar']?.toString(),
      calleeName: j['callee_name']?.toString(),
      calleeAvatar: j['callee_avatar']?.toString(),
    );
  }

  bool get isVideo => callType == CallType.video;
  bool get isRinging => status == CallStatus.ringing;
}
