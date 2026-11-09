// lib/presentation/thix_media/live/pages/live_viewer_page.dart
//
// LiveViewerPage v4 — fine couche au-dessus de LiveRoomView + LiveRoomManager.

import 'package:flutter/material.dart';

import 'package:thix_id/data/models/live/live_model.dart';

import 'live_room_view.dart';

class LiveViewerPage extends StatelessWidget {
  final String liveId;
  final LiveSession? session;
  final AgoraCredentials? creds;

  const LiveViewerPage({
    super.key,
    required this.liveId,
    this.session,
    this.creds,
  });

  @override
  Widget build(BuildContext context) {
    return LiveRoomView(
      isHost: false,
      liveId: liveId,
      session: session,
      creds: creds,
    );
  }
}
