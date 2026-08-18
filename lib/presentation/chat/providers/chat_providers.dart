// lib/presentation/chat/providers/chat_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/chat/status_service.dart';

import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/presence_service.dart';
import 'package:thix_id/services/chat/audio_service.dart';
import 'package:thix_id/services/chat/group_service.dart';
import 'package:thix_id/services/chat/connection_service.dart';

/// ============================================================
/// PROVIDERS CHAT — SOURCE UNIQUE (ne pas redéfinir ailleurs)
/// ============================================================

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(Supabase.instance.client);
});

final presenceServiceProvider = Provider<PresenceService>((ref) {
  return PresenceService(Supabase.instance.client);
});

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService(Supabase.instance.client);
});

final groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService(Supabase.instance.client);
});

final connectionServiceProvider = Provider<ConnectionService>((ref) {
  return ConnectionService();
});
final statusServiceProvider = Provider<StatusService>((ref) {
  return StatusService(Supabase.instance.client);
});
