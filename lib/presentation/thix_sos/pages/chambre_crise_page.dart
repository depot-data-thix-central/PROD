/// THIX SOS — Chambre de crise (victime) — production complète
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/nav.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../services/sos_crisis_media_service.dart';
import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import 'sos_pin_page.dart';

class ChambreCrisePage extends ConsumerStatefulWidget {
  const ChambreCrisePage({
    super.key,
    required this.incidentId,
    this.conversationId,
  });

  final String incidentId;
  final String? conversationId;

  @override
  ConsumerState<ChambreCrisePage> createState() => _ChambreCrisePageState();
}

class _ChambreCrisePageState extends ConsumerState<ChambreCrisePage> {
  Timer? _uiTimer;
  Duration _elapsed = Duration.zero;
  String? _resolvedConversationId;

  final Set<String> _sentQuick = {};
  bool _camOn = false;
  bool _camBusy = false;

  @override
  void initState() {
    super.initState();
    _resolvedConversationId = widget.conversationId;

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final incident =
          ref.read(sosIncidentProvider(widget.incidentId)).valueOrNull;
      if (incident != null && mounted) {
        var d = DateTime.now().difference(incident.startedAt.toLocal());
        if (d.isNegative) d = Duration.zero;
        setState(() => _elapsed = d);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(sosHeartbeatControllerProvider.notifier)
          .start(widget.incidentId);
      _loadConversationId();
      _startCamera();
    });
  }

  Future<void> _startCamera() async {
    if (_camOn || _camBusy) return;
    setState(() => _camBusy = true);
    try {
      await SosCrisisMediaService.instance
          .startVictimBroadcast(widget.incidentId);
      if (mounted) setState(() => _camOn = true);
    } catch (e) {
      debugPrint('chambre victime caméra: $e');
    } finally {
      if (mounted) setState(() => _camBusy = false);
    }
  }

  Future<void> _toggleCamera() async {
    if (_camBusy) return;
    setState(() => _camBusy = true);
    try {
      if (_camOn) {
        await SosCrisisMediaService.instance.leave();
        if (mounted) setState(() => _camOn = false);
      } else {
        await SosCrisisMediaService.instance
            .startVictimBroadcast(widget.incidentId);
        if (mounted) setState(() => _camOn = true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Caméra: $e',
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand),
          ),
          backgroundColor: ThixPolicy.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _camBusy = false);
    }
  }

  Future<void> _loadConversationId() async {
    if (_resolvedConversationId != null) return;
    try {
      final incident =
          await ref.read(sosServiceProvider).getIncidentById(widget.incidentId);
      _resolvedConversationId = incident?.chatConversationId;
    } catch (_) {}
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _openChat(SosIncident incident) async {
    final convId = incident.chatConversationId ?? _resolvedConversationId;
    if (convId == null || convId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conversation SOS pas encore créée',
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand)),
          backgroundColor: ThixPolicy.inkDeep,
        ),
      );
      return;
    }

    final conversation = ChatConversation(
      id: convId,
      isGroup: true,
      groupName: 'THIX CHAT ${incident.publicId}',
      participantIds: const [],
      updatedAt: DateTime.now(),
    );

    context.push(
      AppRoutes.chatDetail(convId),
      extra: conversation,
    );
  }

  Future<void> _callContact(SosContact contact) async {
    final userId =
        await ref.read(sosServiceProvider).resolveContactUserId(contact);
        
    // CORRECTION : On vérifie si la page est toujours montée après l'appel asynchrone
    if (!mounted) return; 

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${contact.name} : pas de compte THIX',
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand)),
          backgroundColor: ThixPolicy.danger,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appel THIX vers ${contact.name}…',
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand)),
        backgroundColor: ThixPolicy.inkDeep,
      ),
    );
  }

  Future<void> _sendQuickMessage(SosIncident incident, String text) async {
    if (_sentQuick.contains(text)) return;
    setState(() => _sentQuick.add(text));

    final convId = incident.chatConversationId ?? _resolvedConversationId;

    await ref.read(sosServiceProvider).logEventPublic(
          incident.id,
          'QUICK_MESSAGE',
          {'text': text},
        );

    if (convId != null && convId.isNotEmpty) {
      try {
        await ChatService(Supabase.instance.client).sendMessage(
          conversationId: convId,
          content: text,
        );
      } catch (e) {
        debugPrint('Quick msg chat: $e');
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text,
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand)),
        backgroundColor: ThixPolicy.inkDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _endSos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SosPinPage(
          incidentId: widget.incidentId,
          mode: SosPinMode.resolve,
        ),
      ),
    );
  }

  void _cancelSos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SosPinPage(
          incidentId: widget.incidentId,
          mode: SosPinMode.cancel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidentAsync = ref.watch(sosIncidentProvider(widget.incidentId));
    final eventsAsync = ref.watch(sosEventsProvider(widget.incidentId));
    final contactsAsync = ref.watch(sosContactsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: incidentAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: ThixPolicy.danger),
          ),
          error: (e, _) => Center(
            child: Text('Erreur: $e',
                style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger)),
          ),
          data: (incident) {
            if (incident == null) {
              return Center(
                child: Text(
                  'Incident introuvable',
                  style: ThixPolicy.bodyStyle,
                ),
              );
            }

            final circleContacts = contactsAsync.maybeWhen(
              data: (all) =>
                  all.where((c) => c.circle == incident.activeCircle).toList(),
              orElse: () => <SosContact>[],
            );

            return Column(
              children: [
                _Header(
                  publicId: incident.publicId,
                  elapsed: _elapsedLabel,
                  status: incident.status,
                  onBack: () => Navigator.pop(context),
                  onEnd: _endSos,
                  camOn: _camOn,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: ThixPolicy.danger,
                    backgroundColor: Theme.of(context).cardColor,
                    onRefresh: () async {
                      ref.invalidate(sosIncidentProvider(widget.incidentId));
                      ref.invalidate(sosEventsProvider(widget.incidentId));
                      ref.invalidate(sosContactsProvider);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                          ThixPolicy.s16,
                          ThixPolicy.s12,
                          ThixPolicy.s16,
                          ThixPolicy.s32),
                      children: [
                        _StatusStrip(incident: incident, camOn: _camOn),
                        const SizedBox(height: ThixPolicy.s16),
                        _section('LOCALISATION EN DIRECT'),
                        const SizedBox(height: ThixPolicy.s8),
                        _LiveMapCard(incident: incident),
                        const SizedBox(height: ThixPolicy.s20),
                        _section('SECOURS — CERCLE ${incident.activeCircle}'),
                        const SizedBox(height: ThixPolicy.s8),
                        if (circleContacts.isEmpty)
                          const _EmptyBox(
                            'Aucun secours dans ce cercle.\nAjoutez des contacts THIX.',
                          )
                        else
                          ...circleContacts.map(
                            (c) => _ResponderTile(
                              contact: c,
                              onCall: () => _callContact(c),
                            ),
                          ),
                        const SizedBox(height: ThixPolicy.s20),
                        _section('COMMUNICATION'),
                        const SizedBox(height: ThixPolicy.s8),
                        Row(
                          children: [
                            Expanded(
                              child: _ComButton(
                                icon: Icons.chat_bubble_outline,
                                label: 'Chat SOS',
                                color: const Color(0xFFA78BFA),
                                onTap: () => _openChat(incident),
                              ),
                            ),
                            const SizedBox(width: ThixPolicy.s10),
                            Expanded(
                              child: _ComButton(
                                icon: Icons.phone_in_talk,
                                label: 'Rappeler',
                                color: ThixPolicy.success,
                                onTap: () {
                                  if (circleContacts.isNotEmpty) {
                                    _callContact(circleContacts.first);
                                  }
                                },
                              ),
                            ),

                          ],
                        ),
                        const SizedBox(height: ThixPolicy.s20),
                        _section('MESSAGES RAPIDES'),
                        const SizedBox(height: ThixPolicy.s8),
                        Wrap(
                          spacing: ThixPolicy.s8,
                          runSpacing: ThixPolicy.s8,
                          children: [
                            for (final msg in _quickMessages)
                              _QuickMsg(
                                label: msg,
                                sent: _sentQuick.contains(msg),
                                onTap: () => _sendQuickMessage(incident, msg),
                              ),
                          ],
                        ),
                        const SizedBox(height: ThixPolicy.s20),
                        _section('ÉTAT SYSTÈME'),
                        const SizedBox(height: ThixPolicy.s8),
                        _SystemRow(incident: incident),
                        const SizedBox(height: ThixPolicy.s20),
                        _section('ÉVÉNEMENTS'),
                        const SizedBox(height: ThixPolicy.s8),
                        eventsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(ThixPolicy.s16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: ThixPolicy.danger,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          error: (_, __) => const _EmptyBox(
                              'Impossible de charger les événements'),
                          data: (events) {
                            if (events.isEmpty) {
                              return const _EmptyBox('Aucun événement');
                            }
                            return Column(
                              children: events
                                  .take(30)
                                  .map((e) => _EventTile(event: e))
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: ThixPolicy.s24),
                        Material(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                          child: InkWell(
                            onTap: _cancelSos,
                            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                            child: Container(
                              width: double.infinity,
                              padding: ThixPolicy.cardPadding,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(ThixPolicy.rMd),
                                border: Border.all(
                                  color: ThixPolicy.danger
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lock_outline,
                                    color: ThixPolicy.danger,
                                  ),
                                  const SizedBox(width: ThixPolicy.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ANNULER LE SOS',
                                          style: ThixPolicy.bodyStyle.copyWith(
                                            fontWeight: ThixPolicy.bold,
                                            color: ThixPolicy.danger,
                                          ),
                                        ),
                                        Text(
                                          'Code de sécurité requis',
                                          style: ThixPolicy.captionStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _quickMessages = [
    '🚨 J\'AI BESOIN D\'AIDE',
    '🤫 JE NE PEUX PAS PARLER',
    '📍 JE SUIS ICI',
    '🏥 JE SUIS BLESSÉ',
    '👤 JE SUIS SUIVI',
    '🚪 JE SUIS ENFERMÉ',
    '📞 APPELEZ LES SECOURS',
    '🟢 JE VAIS BIEN',
  ];

  Widget _section(String title) {
    return Text(
      title,
      style: ThixPolicy.labelStyle.copyWith(
        fontWeight: ThixPolicy.bold,
        color: ThixPolicy.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.publicId,
    required this.elapsed,
    required this.status,
    required this.onBack,
    required this.onEnd,
    this.camOn = false,
  });

  final String publicId;
  final String elapsed;
  final SosStatus status;
  final VoidCallback onBack;
  final VoidCallback onEnd;
  final bool camOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7F1D1D), Color(0xFF450A0A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  'CHAMBRE DE CRISE',
                  textAlign: TextAlign.center,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.onBrand,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEnd,
                child: Text(
                  'Terminer',
                  style: ThixPolicy.bodyMediumStyle.copyWith(
                    color: const Color(0xFFFECACA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                publicId,
                style: ThixPolicy.bodyStyle.copyWith(
                  fontWeight: ThixPolicy.semiBold,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: ThixPolicy.s16),
              const Icon(Icons.timer_outlined, size: 16, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                elapsed,
                style: ThixPolicy.bodyStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.onBrand,
                ),
              ),
              if (camOn) ...[
                const SizedBox(width: ThixPolicy.s12),
                const Icon(Icons.videocam, size: 16, color: Color(0xFFFECACA)),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: ThixPolicy.captionStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    color: const Color(0xFFFECACA),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status.labelFr.toUpperCase(),
            style: ThixPolicy.captionStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              color: const Color(0xFFFECACA),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.incident, this.camOn = false});
  final SosIncident incident;
  final bool camOn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(
          context,
          Icons.location_on,
          'Localisation',
          incident.hasLocation ? 'ACTIVE' : 'EN ATTENTE',
          incident.hasLocation,
        ),
        const SizedBox(width: ThixPolicy.s8),
        _chip(context, Icons.favorite, 'Heartbeat', 'ACTIVE', true),
        const SizedBox(width: ThixPolicy.s8),
        _chip(
          context,
          Icons.videocam,
          'Caméra',
          camOn ? 'LIVE' : 'OFF',
          camOn,
        ),
      ],
    );
  }

  Widget _chip(
      BuildContext context, IconData icon, String label, String value, bool on) {
    final color = on ? ThixPolicy.success : ThixPolicy.textMuted;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(ThixPolicy.rXs),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(label, style: ThixPolicy.microStyle),
            Text(
              value,
              style: ThixPolicy.microStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveMapCard extends StatelessWidget {
  const _LiveMapCard({required this.incident});
  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final hasPos = incident.hasLocation &&
        incident.lastLat != null &&
        incident.lastLng != null;

    final lat = incident.lastLat ?? -6.80381;
    final lng = incident.lastLng ?? 39.26000;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? ThixPolicy.border.withValues(alpha: 0.3)
            : ThixPolicy.surfaceStrong,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, color: ThixPolicy.textMuted, size: 48),
                const SizedBox(height: ThixPolicy.s8),
                Text(
                  "Carte temporairement désactivée\n(En attente de l'API Google)",
                  textAlign: TextAlign.center,
                  style: ThixPolicy.captionStyle,
                ),
              ],
            ),
          ),
          if (hasPos)
            Positioned(
              left: 12,
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Position actuelle',
                      style: ThixPolicy.captionStyle.copyWith(
                        fontWeight: ThixPolicy.semiBold,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.onBrand,
                      ),
                    ),
                    if (incident.lastLocationAt != null)
                      Text(
                        'MAJ ${_fmt(incident.lastLocationAt!)}',
                        style: ThixPolicy.microStyle.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}:${l.second.toString().padLeft(2, '0')}';
  }
}

class _ResponderTile extends StatelessWidget {
  const _ResponderTile({required this.contact, required this.onCall});
  final SosContact contact;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: ThixPolicy.border,
            backgroundImage:
                contact.photoUrl != null ? NetworkImage(contact.photoUrl!) : null,
            child: contact.photoUrl == null
                ? Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : '?',
                    style: ThixPolicy.bodyStyle
                        .copyWith(color: Theme.of(context).colorScheme.onSurface),
                  )
                : null,
          ),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: ThixPolicy.bodyStyle
                      .copyWith(fontWeight: ThixPolicy.semiBold),
                ),
                Text(
                  contact.thixId ??
                      (contact.available ? 'Disponible' : 'Indisponible'),
                  style: ThixPolicy.captionStyle
                      .copyWith(color: ThixPolicy.success),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCall,
            icon: const Icon(Icons.phone, color: ThixPolicy.success),
          ),
        ],
      ),
    );
  }
}

class _ComButton extends StatelessWidget {
  const _ComButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: ThixPolicy.captionStyle
                    .copyWith(fontWeight: ThixPolicy.semiBold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickMsg extends StatelessWidget {
  const _QuickMsg({
    required this.label,
    required this.onTap,
    this.sent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: sent
          ? ThixPolicy.success.withValues(alpha: 0.15)
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
      child: InkWell(
        onTap: sent ? null : onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(
              color: sent
                  ? ThixPolicy.success.withValues(alpha: 0.4)
                  : ThixPolicy.border,
            ),
          ),
          child: Text(
            label,
            style: ThixPolicy.captionStyle.copyWith(
              fontWeight: ThixPolicy.semiBold,
              color: sent
                  ? ThixPolicy.success
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemRow extends StatelessWidget {
  const _SystemRow({required this.incident});
  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: ThixPolicy.danger, size: 18),
          const SizedBox(width: ThixPolicy.s8),
          Text(
            'HEARTBEAT',
            style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
          ),
          const Spacer(),
          if (incident.batteryPct != null) ...[
            Icon(
              Icons.battery_std,
              size: 16,
              color: incident.batteryPct! < 20
                  ? ThixPolicy.danger
                  : ThixPolicy.success,
            ),
            const SizedBox(width: 4),
            Text(
              '${incident.batteryPct}%',
              style: ThixPolicy.bodyStyle,
            ),
          ] else
            Text(
              'Cercle ${incident.activeCircle}',
              style: ThixPolicy.bodySmallStyle,
            ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final SosEvent event;

  @override
  Widget build(BuildContext context) {
    final t = event.createdAt.toLocal();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              time,
              style: ThixPolicy.captionStyle,
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4, right: 10),
            decoration: const BoxDecoration(
              color: ThixPolicy.danger,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              event.type,
              style: ThixPolicy.labelStyle
                  .copyWith(fontWeight: ThixPolicy.semiBold),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: ThixPolicy.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Text(
        text,
        style: ThixPolicy.bodySmallStyle,
      ),
    );
  }
}
