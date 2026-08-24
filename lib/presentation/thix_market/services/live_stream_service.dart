import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveStreamService {
  final SupabaseClient _supabase = Supabase.instance.client;

  late RtcEngine _engine;

  bool _isHost = false;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;

  int _remoteUid = 0;
  String? _currentChannel;

  // =========================
  // INIT ENGINE
  // =========================
  Future<void> initEngine({required bool isHost}) async {
    await [
      Permission.microphone,
      Permission.camera,
    ].request();

    _isHost = isHost;

    _engine = createAgoraRtcEngine();

    await _engine.initialize(
      RtcEngineContext(
        appId: 'YOUR_AGORA_APP_ID', // préférer la Edge Function côté player
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    await _engine.enableVideo();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          _isJoined = true;
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          _remoteUid = uid;
        },
        onUserOffline: (
          RtcConnection connection,
          int uid,
          UserOfflineReasonType reason,
        ) {
          _remoteUid = 0;
        },
        onError: (ErrorCodeType err, String msg) {
          print('Agora error: $err - $msg');
        },
      ),
    );

    if (_isHost) {
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    } else {
      await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    }
  }

  // =========================
  // JOIN CHANNEL
  // =========================
  Future<void> joinChannel({
    required String channelName,
    required String token,
  }) async {
    _currentChannel = channelName;

    await _engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  // =========================
  // LEAVE CHANNEL
  // =========================
  Future<void> leaveChannel() async {
    await _engine.leaveChannel();

    _isJoined = false;
    _remoteUid = 0;
    _currentChannel = null;
  }

  // =========================
  // MUTING
  // =========================
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _engine.muteLocalAudioStream(_isMuted);
  }

  // =========================
  // VIDEO CONTROL
  // =========================
  Future<void> toggleVideo() async {
    _isVideoEnabled = !_isVideoEnabled;

    if (_isVideoEnabled) {
      await _engine.enableVideo();
    } else {
      await _engine.disableVideo();
    }
  }

  Future<void> switchCamera() async {
    await _engine.switchCamera();
  }

  // =========================
  // GET AGORA TOKEN (Edge Function)
  // =========================
  Future<String?> getAgoraToken(String channelName) async {
    try {
      final response = await _supabase.functions.invoke('generate-rtc-token', body: {
        'channelName': channelName,
        'role': _isHost ? 'publisher' : 'subscriber',
      });
      return response.data['token'] as String?;
    } catch (e) {
      return null;
    }
  }

  // =========================
  // SUPABASE LIVE SESSION (TABLE UNIFIÉE)
  // =========================
  Future<Map<String, dynamic>> createLiveSession({
    required String shopId,
    required String title,
    String? description,
    required List<String> productIds,
    bool hasAuction = false,
    double? startingPrice,
    DateTime? auctionEndTime,
    DateTime? scheduledStart,
  }) async {
    final channelName = 'live_${DateTime.now().millisecondsSinceEpoch}';
    final token = await getAgoraToken(channelName);
    final userId = _supabase.auth.currentUser?.id;

    final liveData = {
      'shop_id': shopId,
      'host_id': userId,
      'title': title,
      'description': description,
      'channel_name': channelName,
      'token': token,
      'products': productIds,
      'has_auction': hasAuction,
      'starting_price': startingPrice,
      'auction_end_time': auctionEndTime?.toIso8601String(),
      'scheduled_start': (scheduledStart ?? DateTime.now().add(const Duration(minutes: 5))).toIso8601String(),
      'status': 'scheduled',
      'source': 'market', // ✅ UNIFIÉ
      'created_at': DateTime.now().toIso8601String(),
    };

    final res = await _supabase
        .from('live_sessions') // ✅ UNIFIÉ
        .insert(liveData)
        .select()
        .single();

    return res;
  }

  // =========================
  // START LIVE
  // =========================
  Future<void> startLive(String liveId) async {
    await _supabase.from('live_sessions').update({ // ✅ UNIFIÉ
      'status': 'live',
      'started_at': DateTime.now().toIso8601String(),
    }).eq('id', liveId);
  }

  // =========================
  // END LIVE
  // =========================
  Future<void> endLive(String liveId) async {
    await _supabase.from('live_sessions').update({ // ✅ UNIFIÉ
      'status': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', liveId);

    await leaveChannel();
  }

  // =========================
  // VIEWERS
  // =========================
  Future<void> incrementViewers(String liveId) async {
    await _supabase.rpc('increment_live_viewers', params: {
      'live_id': liveId,
    });
  }

  // =========================
  // LIVE COMMENTS
  // =========================
  Future<void> sendComment(String liveId, String comment) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('live_comments').insert({
      'live_id': liveId,
      'user_id': userId,
      'comment': comment,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<Map<String, dynamic>>> getLiveComments(String liveId) {
    return _supabase
        .from('live_comments')
        .stream(primaryKey: ['id'])
        .eq('live_id', liveId)
        .order('created_at', ascending: true)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // =========================
  // AUCTIONS
  // =========================
  Future<void> placeBid(String auctionId, double amount) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Login required');

    await _supabase.rpc('place_bid', params: {
      'auction_id': auctionId,
      'bid_amount': amount,
    });
  }

  Stream<List<Map<String, dynamic>>> getAuctionBids(String auctionId) {
    return _supabase
        .from('auction_bids')
        .stream(primaryKey: ['id'])
        .eq('auction_id', auctionId)
        .order('amount', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  Future<double> getCurrentBid(String auctionId) async {
    try {
      final response = await _supabase
          .from('auctions')
          .select('current_bid')
          .eq('id', auctionId)
          .single();
      return (response['current_bid'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // =========================
  // DISPOSE
  // =========================
  Future<void> dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
  }
}
