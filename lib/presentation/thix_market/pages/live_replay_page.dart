import 'package:flutter/material.dart';

import '../widgets/live/replay_list.dart';

class LiveReplayPage extends StatelessWidget {
  final String liveId;

  const LiveReplayPage({super.key, required this.liveId});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Replays')),
        body: ReplayList(
          onReplayTap: (_) {},
        ),
      );
}
