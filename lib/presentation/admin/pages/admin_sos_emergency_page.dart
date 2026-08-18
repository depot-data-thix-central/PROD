import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:video_player/video_player.dart';
import 'package:thix_id/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminSosEmergencyPage extends StatefulWidget {
  const AdminSosEmergencyPage({super.key});

  @override
  State<AdminSosEmergencyPage> createState() => _AdminSosEmergencyPageState();
}

class _AdminSosEmergencyPageState extends State<AdminSosEmergencyPage> {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _alerts = const [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _load();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseConfig.client.from('thix_emergency_alerts').select().order('created_at', ascending: false).limit(250);
      if (!mounted) return;
      if (rows is List) {
        setState(() => _alerts = rows.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('AdminSosEmergencyPage: fetch failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _alerts
        : _alerts.where((a) {
            final id = (a['id'] ?? '').toString().toLowerCase();
            final uid = (a['user_id'] ?? '').toString().toLowerCase();
            final type = (a['type'] ?? '').toString().toLowerCase();
            final status = (a['status'] ?? '').toString().toLowerCase();
            final title = ((a['title'] ?? '')).toString().toLowerCase();
            final desc = ((a['description'] ?? '')).toString().toLowerCase();
            return id.contains(q) || uid.contains(q) || type.contains(q) || status.contains(q) || title.contains(q) || desc.contains(q);
          }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(search: _search, onRefresh: _load, count: filtered.length),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : (_error != null)
                  ? _ErrorState(error: _error!, onRetry: _load)
                  : _AlertList(rows: filtered, onChangeStatus: _changeStatus),
        ),
      ],
    );
  }

  Future<void> _changeStatus({required String alertId, required String status}) async {
    try {
      await SupabaseConfig.client.from('thix_emergency_alerts').update({'status': status, 'updated_at': DateTime.now().toIso8601String()}).eq('id', alertId);
      unawaited(_load());
    } catch (e) {
      debugPrint('AdminSosEmergencyPage: change status failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible de mettre à jour le statut: $e')));
    }
  }
}

class _Header extends StatelessWidget {
  final TextEditingController search;
  final VoidCallback onRefresh;
  final int count;
  const _Header({required this.search, required this.onRefresh, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SOS Emergency Center', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AdminCyberColors.text)),
              const SizedBox(height: 4),
              Text('Source: thix_emergency_alerts • $count alerte(s)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
            ],
          ),
        ),
        SizedBox(
          width: 320,
          child: TextField(
            controller: search,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
            decoration: InputDecoration(
              hintText: 'Search alert, user, type…',
              hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
              prefixIcon: const Icon(Icons.search_rounded, color: AdminCyberColors.neonCyan),
              filled: true,
              fillColor: AdminCyberColors.panel.withValues(alpha: 0.72),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            foregroundColor: AdminCyberColors.text,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan),
          label: const Text('Fetch Data'),
        ),
      ],
    );
  }
}

class _AlertList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Future<void> Function({required String alertId, required String status}) onChangeStatus;
  const _AlertList({required this.rows, required this.onChangeStatus});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(child: Text('Aucune alerte.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)));
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _AlertTile(row: rows[index], onChangeStatus: onChangeStatus),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final Future<void> Function({required String alertId, required String status}) onChangeStatus;
  const _AlertTile({required this.row, required this.onChangeStatus});

  @override
  Widget build(BuildContext context) {
    final id = (row['id'] ?? '').toString();
    final userId = (row['user_id'] ?? '').toString();
    final type = (row['type'] ?? '').toString();
    final severity = (row['severity'] ?? '').toString();
    final status = (row['status'] ?? '').toString();
    final isCritical = (row['is_critical'] ?? false) == true;
    final silent = (row['silent_mode'] ?? false) == true;
    final title = (row['title'] ?? '').toString().trim();
    final createdAt = (row['created_at'] ?? '').toString();
    final lat = row['last_lat'];
    final lng = row['last_lng'];

    return InkWell(
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      onTap: () => _showDetails(context),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: AdminCyberColors.panel.withValues(alpha: 0.78),
          border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
        ),
        child: Row(
          children: [
            _StatusPill(status: status, critical: isCritical),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.isEmpty ? type : title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _MetaChip(icon: Icons.person_rounded, label: userId.isEmpty ? 'user: —' : 'user: ${_ellipsis(userId, 14)}'),
                      if (severity.isNotEmpty) _MetaChip(icon: Icons.bolt_rounded, label: 'severity: $severity'),
                      if (silent) const _MetaChip(icon: Icons.volume_off_rounded, label: 'silent'),
                      if (createdAt.isNotEmpty) _MetaChip(icon: Icons.schedule_rounded, label: _ellipsis(createdAt, 22)),
                      if (lat != null && lng != null) const _MetaChip(icon: Icons.location_on_rounded, label: 'location'),
                      if (id.isNotEmpty) _MetaChip(icon: Icons.tag_rounded, label: _ellipsis(id, 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              color: AdminCyberColors.panel,
              onSelected: (value) async {
                if (id.isEmpty) return;
                if (value == 'active' || value == 'resolved' || value == 'archived') {
                  await onChangeStatus(alertId: id, status: value);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'active', child: Text('Marquer: Active')),
                const PopupMenuItem(value: 'resolved', child: Text('Marquer: Resolved')),
                const PopupMenuItem(value: 'archived', child: Text('Marquer: Archived')),
              ],
              child: const Icon(Icons.more_vert_rounded, color: AdminCyberColors.textDim),
            )
          ],
        ),
      ),
    );
  }

  static String _ellipsis(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';

  Future<void> _showDetails(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AlertDetailsSheet(initialRow: row),
    );
  }

  static String _staticMapUrl({required Object lat, required Object lng}) {
    final cLat = Uri.encodeComponent(lat.toString());
    final cLng = Uri.encodeComponent(lng.toString());
    return 'https://staticmap.openstreetmap.de/staticmap.php?center=$cLat,$cLng&zoom=15&size=900x450&maptype=mapnik&markers=$cLat,$cLng,red-pushpin';
  }
}

class _AlertDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> initialRow;
  const _AlertDetailsSheet({required this.initialRow});

  @override
  State<_AlertDetailsSheet> createState() => _AlertDetailsSheetState();
}

class _AlertDetailsSheetState extends State<_AlertDetailsSheet> {
  Map<String, dynamic> _row = const {};
  double? _lat;
  double? _lng;
  DateTime? _lastLocAt;

  bool _audioLoading = false;
  String? _audioPath;
  String? _attachedAudioPath;
  VideoPlayerController? _audioController;

  String get _id => (_row['id'] ?? '').toString();
  String get _userId => (_row['user_id'] ?? '').toString();
  String get _type => (_row['type'] ?? '').toString();
  String get _status => (_row['status'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _applyRow(widget.initialRow);
    unawaited(_refreshRow());
  }

  void _applyRow(Map<String, dynamic> r) {
    _row = r;
    final lat = r['last_lat'];
    final lng = r['last_lng'];
    _lat = (lat is num) ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
    _lng = (lng is num) ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
    final locAt = r['last_location_at'];
    _lastLocAt = (locAt is String) ? DateTime.tryParse(locAt) : null;
    _audioPath = (r['audio_path'] ?? r['audioPath'])?.toString();
  }

  Future<void> _refreshRow() async {
    final id = (_row['id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      final r = await SupabaseConfig.client.from('thix_emergency_alerts').select().eq('id', id).maybeSingle();
      if (r == null || !mounted) return;
      setState(() => _applyRow(r));
      await _refreshAudio();
    } catch (e) {
      debugPrint('AdminSOS: refreshRow failed: $e');
    }
  }

  Future<void> _refreshAudio() async {
    final id = (_row['id'] ?? '').toString();
    final path = _audioPath;
    if (id.isEmpty || path == null || path.trim().isEmpty) return;
    if (_attachedAudioPath == path) return;
    await _attachAudio(path);
  }

  Future<void> _attachAudio(String storagePath) async {
    if (_audioLoading) return;
    setState(() => _audioLoading = true);
    try {
      final signed = await SupabaseConfig.client.storage.from('thix-emergency').createSignedUrl(storagePath, 60);
      final uri = Uri.tryParse(signed);
      if (uri == null) return;

      final prev = _audioController;
      final c = VideoPlayerController.networkUrl(uri);
      await c.initialize();
      c.setLooping(false);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _audioController = c;
        _attachedAudioPath = storagePath;
      });
      if (prev != null) unawaited(prev.dispose());
    } catch (e) {
      debugPrint('AdminSOS: attachAudio failed: $e');
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  @override
  void dispose() {
    try {
      _audioController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  static String _ellipsis(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';

  static String _staticMapUrl({required double lat, required double lng}) {
    final cLat = Uri.encodeComponent(lat.toString());
    final cLng = Uri.encodeComponent(lng.toString());
    return 'https://staticmap.openstreetmap.de/staticmap.php?center=$cLat,$cLng&zoom=16&size=900x450&maptype=mapnik&markers=$cLat,$cLng,red-pushpin';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desc = (_row['description'] ?? '').toString().trim();
    final hasLoc = _lat != null && _lng != null;
    final last = _lastLocAt;
    final lastLabel = last == null
        ? null
        : '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}:${last.second.toString().padLeft(2, '0')}';

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
          color: AdminCyberColors.panel.withValues(alpha: 0.92),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Alerte SOS — Live', style: theme.textTheme.titleLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, color: AdminCyberColors.textDim))
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _MetaChip(icon: Icons.tag_rounded, label: 'id: ${_ellipsis(_id, 14)}'),
                _MetaChip(icon: Icons.person_rounded, label: 'user: ${_ellipsis(_userId, 18)}'),
                _MetaChip(icon: Icons.warning_rounded, label: 'type: $_type'),
                _MetaChip(icon: Icons.flag_rounded, label: 'status: ${_status.isEmpty ? 'active' : _status}'),
                if (lastLabel != null) _MetaChip(icon: Icons.schedule_rounded, label: 'GPS: $lastLabel'),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(desc, style: theme.textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text, height: 1.5)),
            ],
            const SizedBox(height: 12),

            if (hasLoc) ...[
              Text('Position live: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}', style: theme.textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    _staticMapUrl(lat: _lat!, lng: _lng!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AdminCyberColors.black.withValues(alpha: 0.18),
                      alignment: Alignment.center,
                      child: Text('Carte indisponible', style: theme.textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                  foregroundColor: AdminCyberColors.text,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_lat!},${_lng!}');
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.map_rounded, color: AdminCyberColors.neonCyan),
                label: const Text('Ouvrir dans Maps'),
              ),
            ] else ...[
              Text('Position live: en attente…', style: theme.textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
            ],

            const SizedBox(height: 12),
            Text('Écoute micro (preuves audio)', style: theme.textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
            const SizedBox(height: 8),
            _AudioPanel(controller: _audioController, loading: _audioLoading, onRefresh: _refreshRow),

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                      foregroundColor: AdminCyberColors.text,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final body = 'ALERTE SOS\nType: $_type\nUser: $_userId\nLatLng: ${hasLoc ? '${_lat!}, ${_lng!}' : '-'}\nId: $_id';
                      Clipboard.setData(ClipboardData(text: body));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texte copié (pour SMS/WhatsApp).')));
                    },
                    icon: const Icon(Icons.copy_rounded, color: AdminCyberColors.neonCyan),
                    label: const Text('Copier texte'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminCyberColors.electricBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: const Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _AudioPanel extends StatefulWidget {
  final VideoPlayerController? controller;
  final bool loading;
  final Future<void> Function() onRefresh;
  const _AudioPanel({required this.controller, required this.loading, required this.onRefresh});

  @override
  State<_AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<_AudioPanel> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (widget.loading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.8)),
          color: AdminCyberColors.black.withValues(alpha: 0.22),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AdminCyberColors.neonCyan)),
            const SizedBox(width: 10),
            Expanded(child: Text('Chargement audio…', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim))),
          ],
        ),
      );
    }

    if (c == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.8)),
          color: AdminCyberColors.black.withValues(alpha: 0.22),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic_off_rounded, color: AdminCyberColors.textDim),
            const SizedBox(width: 10),
            Expanded(child: Text('Aucun audio reçu pour le moment.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim))),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                foregroundColor: AdminCyberColors.text,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => widget.onRefresh(),
              icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan, size: 18),
              label: const Text('Refresh'),
            )
          ],
        ),
      );
    }

    final playing = c.value.isPlaying;
    final dur = c.value.duration;
    final pos = c.value.position;
    final durS = dur.inSeconds <= 0 ? 1 : dur.inSeconds;
    final p = (pos.inSeconds / durS).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.8)),
        color: AdminCyberColors.black.withValues(alpha: 0.22),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              try {
                if (playing) {
                  await c.pause();
                } else {
                  await c.play();
                }
                if (mounted) setState(() {});
              } catch (e) {
                debugPrint('AdminSOS: audio play/pause failed: $e');
              }
            },
            icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: AdminCyberColors.neonCyan, size: 34),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Dernier extrait audio', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: p,
                  minHeight: 6,
                  backgroundColor: AdminCyberColors.stroke.withValues(alpha: 0.35),
                  valueColor: const AlwaysStoppedAnimation(AdminCyberColors.neonCyan),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
              foregroundColor: AdminCyberColors.text,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => widget.onRefresh(),
            icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan, size: 18),
            label: const Text('Refresh'),
          )
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final bool critical;
  const _StatusPill({required this.status, required this.critical});

  @override
  Widget build(BuildContext context) {
    final s = status.trim().isEmpty ? 'active' : status.trim();
    final bg = critical ? AdminCyberColors.danger.withValues(alpha: 0.22) : AdminCyberColors.black.withValues(alpha: 0.22);
    final border = critical ? AdminCyberColors.danger.withValues(alpha: 0.7) : AdminCyberColors.stroke.withValues(alpha: 0.7);
    final icon = critical ? Icons.crisis_alert_rounded : Icons.sos_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: critical ? AdminCyberColors.danger : AdminCyberColors.textDim),
          const SizedBox(width: 6),
          Text(s, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminCyberColors.textDim)),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AdminCyberColors.black.withValues(alpha: 0.22),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AdminCyberColors.textDim),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminCyberColors.textDim)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            color: AdminCyberColors.panel.withValues(alpha: 0.78),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supabase error', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
              const SizedBox(height: 8),
              Text(error, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim, height: 1.4)),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                      foregroundColor: AdminCyberColors.text,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vérifie les RLS policies (thix_emergency_alerts) pour ADMIN/SUPER_ADMIN.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
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
}
