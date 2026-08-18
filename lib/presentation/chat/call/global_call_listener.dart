// lib/presentation/chat/call/global_call_listener.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat/call_invite.dart';
import '../../../services/chat/call_signaling_service.dart';
import 'incoming_call_page.dart';

class GlobalCallListener extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const GlobalCallListener({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  ConsumerState<GlobalCallListener> createState() =>
      _GlobalCallListenerState();
}

class _GlobalCallListenerState extends ConsumerState<GlobalCallListener>
    with WidgetsBindingObserver {
  final _signal = CallSignalingService();
  StreamSubscription<CallInvite>? _sub;
  String? _shownInviteId;
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('📞 auth → ${data.event}');
      _syncListen(force: true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncListen(force: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncListen(force: true);
    }
  }

  void _syncListen({bool force = false}) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    debugPrint('📞 syncListen uid=$uid force=$force');

    if (uid == null) {
      _sub?.cancel();
      _sub = null;
      _lastUid = null;
      return;
    }

    if (!force && uid == _lastUid && _sub != null) return;

    _lastUid = uid;
    _sub?.cancel();

    // ⚠️ POLL + Realtime (obligatoire)
    _sub = _signal.watchIncomingWithPoll().listen(
      (invite) {
        debugPrint('📞 INCOMING ${invite.id} from ${invite.callerId}');
        if (!mounted) return;
        if (_shownInviteId == invite.id) return;
        _shownInviteId = invite.id;
        _openIncoming(invite);
      },
      onError: (e, st) {
        debugPrint('📞 incoming error: $e\n$st');
      },
    );
  }

  void _openIncoming(CallInvite invite) {
    debugPrint('📞 open IncomingCallPage ${invite.id}');

    final route = MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallPage(invite: invite),
    );

    // 1) rootNavigatorKey
    final nav = widget.navigatorKey?.currentState;
    if (nav != null) {
      nav.push(route);
      return;
    }

    // 2) context
    if (mounted) {
      try {
        Navigator.of(context, rootNavigator: true).push(route);
        return;
      } catch (e) {
        debugPrint('📞 navigator push failed: $e');
      }
    }

    // 3) retry court (router pas prêt)
    Future.delayed(const Duration(milliseconds: 300), () {
      final n = widget.navigatorKey?.currentState;
      if (n != null) {
        n.push(route);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _signal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
