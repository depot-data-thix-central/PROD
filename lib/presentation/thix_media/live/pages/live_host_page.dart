// lib/presentation/thix_media/live/pages/live_host_page.dart
//
// LiveHostPage v4 — fine couche au-dessus de LiveRoomView + LiveRoomManager.

import 'package:flutter/material.dart';

import 'package:thix_id/data/models/live/live_model.dart';

import 'live_room_view.dart';

class LiveHostPage extends StatelessWidget {
  final LiveSession session;
  final AgoraCredentials creds;

  const LiveHostPage({
    super.key,
    required this.session,
    required this.creds,
  });

  @override
  Widget build(BuildContext context) {
    return LiveRoomView(isHost: true, session: session, creds: creds);
  }
}
