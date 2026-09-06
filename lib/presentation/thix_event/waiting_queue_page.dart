// lib/presentation/thix_event/waiting_queue_page.dart
//
// WaitingQueuePage — Production Enterprise (Sécurité + i18n + Realtime)
//
// Features :
// - Validation UUID stricte sur eventId
// - Intégration AppLocalizations (8 langues)
// - Semantics complet pour a11y
// - Throttling anti-spam (500ms)
// - Protection race condition (_yourTurn)
// - Stream error handling + retry
// - Timeout sur RPC (15s)
// - Logging structuré (_QueueLogger)
// - ThixPolicy pour couleurs
// - Mounted checks systématiques
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/thix_design_policy.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../services/event_queue_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kClaimThrottle = Duration(milliseconds: 500);
const Duration _kClaimTimeout = Duration(seconds: 15);
const Duration _kStreamRetryDelay = Duration(seconds: 3);
const int _kMaxStreamRetries = 5;

// ============================================================================
// LOGGING
// ============================================================================

class _QueueLogger {
  static const _tag = 'WaitingQueue';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// VALIDATORS
// ============================================================================

class _Validators {
  _Validators._();
  
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  
  static bool isValidUuid(String? id) =>
      id != null && id.length == 36 && _uuidRegex.hasMatch(id);
}

// ============================================================================
// PAGE
// ============================================================================

class WaitingQueuePage extends ConsumerStatefulWidget {
  final String eventId;
  final int requestedQuantity;
  
  const WaitingQueuePage({
    super.key,
    required this.eventId,
    required this.requestedQuantity,
  });

  @override
  ConsumerState<WaitingQueuePage> createState() => _WaitingQueuePageState();
}

class _WaitingQueuePageState extends ConsumerState<WaitingQueuePage>
    with WidgetsBindingObserver {
  late EventQueueService _queue;
  int _pos = -1;
  int _size = 0;
  bool _loading = true;
  bool _processing = false;
  String? _error;
  Event? _event;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  DateTime? _lastClaim;
  int _streamRetryCount = 0;

  @override
  void initState() {
    super.initState();
    
    // Validation UUID
    if (!_Validators.isValidUuid(widget.eventId)) {
      _QueueLogger.error('Invalid eventId', {'id': widget.eventId});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showError('Invalid event ID');
          context.pop();
        }
      });
      return;
    }
    
    WidgetsBinding.instance.addObserver(this);
    _queue = EventQueueService(Supabase.instance.client);
    _init();
    _QueueLogger.info('WaitingQueuePage init', {
      'eventId': widget.eventId,
      'quantity': widget.requestedQuantity,
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _QueueLogger.info('WaitingQueuePage disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && !_processing) {
      _QueueLogger.info('App resumed, fetching info');
      _fetchInfo();
    }
  }

  bool _canClaim() {
    final now = DateTime.now();
    if (_lastClaim != null && 
        now.difference(_lastClaim!) < _kClaimThrottle) {
      return false;
    }
    _lastClaim = now;
    return true;
  }

  Future<void> _init() async {
    await _loadEvent();
    await _join();
  }

  Future<void> _loadEvent() async {
    try {
      final ev = await ref
          .read(eventServiceProvider)
          .getEventById(widget.eventId)
          .timeout(const Duration(seconds: 10));
      
      if (mounted && ev != null) {
        setState(() => _event = ev);
        _QueueLogger.info('Event loaded', {'title': ev.title});
      }
    } catch (e, stack) {
      _QueueLogger.error('Load event failed', {
        'error': '$e',
        'stack': stack.toString(),
      });
    }
  }

  Future<void> _join() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final q = await _queue
          .joinWaitingQueue(widget.eventId, widget.requestedQuantity)
          .timeout(const Duration(seconds: 10));
      
      if (q == null) {
        throw Exception('Failed to join queue');
      }
      
      await _fetchInfo();
      _listen();
      _QueueLogger.info('Joined queue', {'position': _pos, 'size': _size});
    } on TimeoutException {
      _QueueLogger.error('Join timeout');
      if (mounted) {
        setState(() {
          _error = 'Timeout';
          _loading = false;
        });
      }
    } catch (e, stack) {
      _QueueLogger.error('Join failed', {
        'error': '$e',
        'stack': stack.toString(),
      });
      if (mounted) {
        setState(() {
          _error = e is PostgrestException
              ? e.message
              : e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchInfo() async {
    try {
      final size = await _queue
          .getQueueSize(widget.eventId)
          .timeout(const Duration(seconds: 10));
      
      final pos = await _queue
          .getQueuePosition(widget.eventId)
          .timeout(const Duration(seconds: 10));
      
      if (mounted) {
        setState(() {
          _size = size;
          if (pos > 0) _pos = pos;
          _loading = false;
        });
        
        if (_pos == 1 && !_processing) {
          _yourTurn();
        }
      }
    } on TimeoutException {
      _QueueLogger.warn('Fetch info timeout');
    } catch (e) {
      _QueueLogger.warn('Fetch info failed', {'error': '$e'});
    }
  }

  void _listen() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _QueueLogger.error('No user ID for stream');
      return;
    }

    _sub = Supabase.instance.client
        .from('waiting_queue')
        .stream(primaryKey: ['id'])
        .eq('event_id', widget.eventId)
        .listen(
      (data) {
        if (!mounted || data.isEmpty) return;
        
        final row = data.cast<Map<String, dynamic>?>().firstWhere(
          (r) => r?['user_id'] == uid,
          orElse: () => null,
        );
        
        if (row == null) {
          _QueueLogger.warn('User not found in stream data');
          return;
        }
        
        final np = row['position'] as int?;
        if (np != null && np != _pos) {
          setState(() => _pos = np);
          _QueueLogger.info('Position updated', {'position': np});
          
          if (_pos == 1 && !_processing) {
            _yourTurn();
          }
        }
      },
      onError: (error) {
        _QueueLogger.error('Stream error', {'error': '$error'});
        _handleStreamError();
      },
    );
    
    _streamRetryCount = 0;
  }

  void _handleStreamError() {
    if (_streamRetryCount >= _kMaxStreamRetries) {
      _QueueLogger.error('Max stream retries reached');
      return;
    }
    
    _streamRetryCount++;
    _QueueLogger.info('Retrying stream', {'attempt': _streamRetryCount});
    
    Future.delayed(_kStreamRetryDelay, () {
      if (mounted) {
        _sub?.cancel();
        _listen();
      }
    });
  }

  void _yourTurn() {
    // Guard against race condition
    if (_processing) {
      _QueueLogger.warn('Your turn called but already processing');
      return;
    }
    
    if (!mounted) return;
    
    _QueueLogger.info('Your turn!', {'position': _pos});
    setState(() => _processing = true);
    
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => Semantics(
        namesRoute: true,
        scopesRoute: true,
        child: Dialog(
          backgroundColor: ThixPolicy.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: ThixPolicy.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.confirmation_number_rounded,
                  size: 40,
                  color: ThixPolicy.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.t('queue_your_turn'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('queue_your_turn_msg', args: [
                    widget.requestedQuantity.toString(),
                  ]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ThixPolicy.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: l10n.t('common_cancel'),
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _leave();
                            context.go('/thix-event');
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ThixPolicy.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            l10n.t('common_cancel'),
                            style: const TextStyle(color: ThixPolicy.textMuted),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: l10n.t('queue_book_now'),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _claim();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            l10n.t('queue_book_now'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _claim() async {
    if (!_canClaim()) {
      _QueueLogger.warn('Claim throttled');
      return;
    }
    
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _QueueLogger.error('No user ID for claim');
      return;
    }
    
    setState(() => _loading = true);
    _QueueLogger.info('Claiming spot');
    
    try {
      final ok = await Supabase.instance.client
          .rpc(
            'try_claim_spot',
            params: {
              'p_user_id': uid,
              'p_event_id': widget.eventId,
            },
          )
          .timeout(_kClaimTimeout) as bool;
      
      if (ok && mounted) {
        _sub?.cancel();
        _QueueLogger.info('Spot claimed successfully');
        context.push('/thix-event/reservation/${widget.eventId}');
      } else {
        throw Exception('Claim failed or timeout');
      }
    } on TimeoutException {
      _QueueLogger.error('Claim timeout');
      if (mounted) {
        setState(() {
          _loading = false;
          _processing = false;
          _error = 'Timeout';
        });
      }
    } catch (e, stack) {
      _QueueLogger.error('Claim failed', {
        'error': '$e',
        'stack': stack.toString(),
      });
      
      if (mounted) {
        final msg = e is PostgrestException ? e.message : e.toString();
        final booked = msg.contains('déjà une réservation') || 
                       msg.contains('already has a reservation');
        
        setState(() {
          _loading = false;
          _processing = false;
          _error = msg;
        });
        
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              booked 
                  ? l10n.t('queue_already_booked') 
                  : msg,
            ),
            backgroundColor: booked ? ThixPolicy.primary : ThixPolicy.danger,
          ),
        );
      }
    }
  }

  Future<void> _leave() async {
    _QueueLogger.info('Leaving queue');
    _sub?.cancel();
    
    try {
      await _queue
          .leaveQueue(widget.eventId)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      _QueueLogger.warn('Leave queue failed', {'error': '$e'});
    }
  }

  String _eta(AppLocalizations l10n) {
    if (_pos <= 0) return l10n.t('queue_calculating');
    final m = ((_pos - 1) * 0.5).round();
    if (m < 1) return l10n.t('queue_less_than_minute');
    return l10n.t('queue_eta_minutes', args: [m.toString()]);
  }

  double _progress() {
    if (_size <= 0 || _pos <= 0) return 0;
    return ((_size - _pos + 1) / _size).clamp(0.0, 1.0);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThixPolicy.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: ThixPolicy.inkDeep.withOpacity(0.85),
              elevation: 0,
              leading: Semantics(
                button: true,
                label: l10n.t('common_back'),
                child: IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: const BorderSide(color: ThixPolicy.border),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _showLeaveDialog(l10n);
                  },
                ),
              ),
              title: Text(
                l10n.t('queue_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: ThixPolicy.primary),
            )
          : _error != null
              ? _errorState(l10n)
              : _content(l10n),
    );
  }

  void _showLeaveDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (_) => Semantics(
        namesRoute: true,
        scopesRoute: true,
        child: Dialog(
          backgroundColor: ThixPolicy.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: ThixPolicy.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.t('queue_leave_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('queue_leave_msg'),
                  style: const TextStyle(
                    color: ThixPolicy.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: l10n.t('queue_stay'),
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.t('queue_stay')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: l10n.t('queue_leave'),
                        child: ElevatedButton(
                          onPressed: () {
                            _leave();
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThixPolicy.danger,
                          ),
                          child: Text(l10n.t('queue_leave')),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(AppLocalizations l10n) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ThixPolicy.surface,
            borderRadius: BorderRadius.circular(20),
            border: const BorderSide(color: ThixPolicy.border),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                      value: _progress(),
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: const AlwaysStoppedAnimation(ThixPolicy.primary),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '$_pos',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const Text(
                        l10n.t('queue_position'),
                        style: TextStyle(
                          fontSize: 10,
                          color: ThixPolicy.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('queue_waiting'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.t('queue_people_ahead', args: [
                  (_size - _pos).clamp(0, 9999).toString(),
                ]),
                style: const TextStyle(
                  color: ThixPolicy.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ThixPolicy.primary.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_rounded,
                      size: 14,
                      color: ThixPolicy.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _eta(l10n),
                      style: const TextStyle(
                        color: ThixPolicy.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ThixPolicy.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ThixPolicy.primary.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: ThixPolicy.primary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.t('queue_dont_leave'),
                  style: const TextStyle(
                    color: ThixPolicy.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThixPolicy.surface,
            borderRadius: BorderRadius.circular(16),
            border: const BorderSide(color: ThixPolicy.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('queue_summary'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _row(l10n.t('queue_event'), _event?.title ?? '...'),
              const Divider(height: 20, color: ThixPolicy.border),
              _row(
                l10n.t('queue_quantity'),
                l10n.t('queue_places', args: [
                  widget.requestedQuantity.toString(),
                ]),
              ),
              const Divider(height: 20, color: ThixPolicy.border),
              _row(l10n.t('queue_position_label'), '$_pos / $_size'),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(color: ThixPolicy.textMuted, fontSize: 12),
      ),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _errorState(AppLocalizations l10n) {
    final booked = _error != null && 
        (_error!.contains('déjà une réservation') || 
         _error!.contains('already has a reservation'));
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              booked
                  ? Icons.info_outline_rounded
                  : Icons.error_outline_rounded,
              size: 48,
              color: booked ? ThixPolicy.primary : ThixPolicy.danger,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? l10n.t('error_generic'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Semantics(
              button: true,
              label: booked ? l10n.t('common_home') : l10n.t('common_retry'),
              child: ElevatedButton.icon(
                onPressed: () {
                  if (booked) {
                    context.go('/thix-event');
                  } else {
                    setState(() {
                      _error = null;
                      _loading = true;
                    });
                    _join();
                  }
                },
                icon: Icon(
                  booked ? Icons.home_rounded : Icons.refresh_rounded,
                  size: 16,
                ),
                label: Text(
                  booked ? l10n.t('common_home') : l10n.t('common_retry'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
