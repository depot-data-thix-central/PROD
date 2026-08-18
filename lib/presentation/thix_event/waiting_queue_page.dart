// lib/presentation/thix_event/waiting_queue_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../services/event_queue_service.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const cardBorderStrong = Color(0x26FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class WaitingQueuePage extends ConsumerStatefulWidget {
  final String eventId;
  final int requestedQuantity;
  const WaitingQueuePage({super.key, required this.eventId, required this.requestedQuantity});
  @override
  ConsumerState<WaitingQueuePage> createState() => _WaitingQueuePageState();
}

class _WaitingQueuePageState extends ConsumerState<WaitingQueuePage> with WidgetsBindingObserver {
  late EventQueueService _queue;
  int _pos = -1;
  int _size = 0;
  bool _loading = true;
  bool _processing = false;
  String? _error;
  Event? _event;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _queue = EventQueueService(Supabase.instance.client);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && !_processing) _fetchInfo();
  }

  Future<void> _init() async {
    await _loadEvent();
    await _join();
  }

  Future<void> _loadEvent() async {
    final ev = await ref.read(eventServiceProvider).getEventById(widget.eventId);
    if (mounted && ev != null) setState(() => _event = ev);
  }

  Future<void> _join() async {
    setState(() { _loading = true; _error = null; });
    try {
      final q = await _queue.joinWaitingQueue(widget.eventId, widget.requestedQuantity);
      if (q == null) throw Exception('Impossible de rejoindre la file');
      await _fetchInfo();
      _listen();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is PostgrestException ? e.message : e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchInfo() async {
    try {
      final size = await _queue.getQueueSize(widget.eventId);
      final pos = await _queue.getQueuePosition(widget.eventId);
      if (mounted) {
        setState(() {
          _size = size;
          if (pos > 0) _pos = pos;
          _loading = false;
        });
        if (_pos == 1 && !_processing) _yourTurn();
      }
    } catch (_) {}
  }

  void _listen() {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    _sub = Supabase.instance.client.from('waiting_queue').stream(primaryKey: ['id']).eq('event_id', widget.eventId).listen((data) {
      if (!mounted || data.isEmpty) return;
      final row = data.cast<Map<String, dynamic>?>().firstWhere((r) => r?['user_id'] == uid, orElse: () => null);
      if (row == null) return;
      final np = row['position'] as int?;
      if (np != null && np != _pos) {
        setState(() => _pos = np);
        if (_pos == 1 && !_processing) _yourTurn();
      }
    });
  }

  void _yourTurn() {
    setState(() => _processing = true);
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _ThixColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: _ThixColors.cardBorder)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.confirmation_number_rounded, size: 40, color: _ThixColors.primary),
              const SizedBox(height: 12),
              const Text('C\'est votre tour !', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              Text('${widget.requestedQuantity} place(s) réservée(s). 10 min pour finaliser.', textAlign: TextAlign.center, style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _leave();
                        context.go('/thix-event');
                      },
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: _ThixColors.cardBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      child: const Text('Annuler', style: TextStyle(color: _ThixColors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _claim();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      child: const Text('RÉSERVER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claim() async {
    setState(() => _loading = true);
    try {
      final ok = await Supabase.instance.client.rpc('try_claim_spot', params: {'p_user_id': Supabase.instance.client.auth.currentUser!.id, 'p_event_id': widget.eventId}) as bool;
      if (ok && mounted) {
        _sub?.cancel();
        context.push('/thix-event/reservation/${widget.eventId}');
      } else {
        throw Exception('Délai expiré');
      }
    } catch (e) {
      if (mounted) {
        final msg = e is PostgrestException ? e.message : e.toString();
        final booked = msg.contains('déjà une réservation');
        setState(() {
          _loading = false;
          _processing = false;
          _error = msg;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(booked ? 'Vous avez déjà un billet' : msg), backgroundColor: booked ? _ThixColors.primary : Colors.red));
      }
    }
  }

  Future<void> _leave() async {
    _sub?.cancel();
    await _queue.leaveQueue(widget.eventId);
  }

  String _eta() {
    if (_pos <= 0) return 'Calcul...';
    final m = ((_pos - 1) * 0.5).round();
    if (m < 1) return 'Moins d\'1 min';
    return 'Environ $m min';
  }

  double _progress() {
    if (_size <= 0 || _pos <= 0) return 0;
    return ((_size - _pos + 1) / _size).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85),
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: _ThixColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _ThixColors.cardBorder)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Quitter la file ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            const Text('Vous perdrez votre position', style: TextStyle(color: _ThixColors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Rester'))),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _leave();
                                      Navigator.pop(context);
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Quitter'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              title: const Text('File d\'attente', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: _ThixColors.primary)) : _error != null ? _errorState() : _content(),
    );
  }

  Widget _content() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _ThixColors.cardBorder)),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(width: 110, height: 110, child: CircularProgressIndicator(value: _progress(), strokeWidth: 6, backgroundColor: Colors.white.withOpacity(0.06), valueColor: const AlwaysStoppedAnimation(_ThixColors.primary))),
                      Column(
                        children: [
                          Text('$_pos', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                          const Text('position', style: TextStyle(fontSize: 10, color: _ThixColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Vous êtes en file d\'attente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('${(_size - _pos).clamp(0, 9999)} personne(s) devant vous', style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _ThixColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _ThixColors.primary.withOpacity(0.25))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_rounded, size: 14, color: _ThixColors.primary),
                        const SizedBox(width: 6),
                        Text(_eta(), style: const TextStyle(color: _ThixColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _ThixColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: _ThixColors.primary.withOpacity(0.15))),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: _ThixColors.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Ne quittez pas. Redirection auto à votre tour.', style: TextStyle(color: _ThixColors.textSecondary, fontSize: 12, height: 1.3))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _ThixColors.cardBorder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Récapitulatif', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 12),
                  _row('Événement', _event?.title ?? '...'),
                  const Divider(height: 20, color: _ThixColors.cardBorder),
                  _row('Quantité', '${widget.requestedQuantity} place(s)'),
                  const Divider(height: 20, color: _ThixColors.cardBorder),
                  _row('Position', '$_pos / $_size'),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _row(String l, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 12)),
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _errorState() {
    final booked = _error != null && _error!.contains('déjà une réservation');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(booked ? Icons.info_outline_rounded : Icons.error_outline_rounded, size: 48, color: booked ? _ThixColors.primary : Colors.red),
            const SizedBox(height: 12),
            Text(_error ?? 'Erreur', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 18),
            ElevatedButton.icon(
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
              icon: Icon(booked ? Icons.home_rounded : Icons.refresh_rounded, size: 16),
              label: Text(booked ? 'Accueil' : 'Réessayer'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            ),
          ],
        ),
      ),
    );
  }
}
