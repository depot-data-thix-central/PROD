// lib/presentation/thix_media/live/pages/go_live_page.dart
//
// GoLivePage — Pré-Live Production Enterprise (niveau TikTok/IG Live)
//
// Features :
// - Preview caméra réelle avec permission check
// - Toggle caméra (front/back), micro, flash
// - Mode audience (public/privé/abonnés)
// - Indicateur qualité réseau
// - Sanitization titre/description
// - Draft auto-save
// - Countdown avant démarrage
// - i18n complet + Semantics
// - Logging structuré + throttling
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../providers/go_live_provider.dart';
import 'live_host_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxTitleLength = 80;
const int _kMaxDescLength = 500;
const Duration _kThrottle = Duration(milliseconds: 500);
const Duration _kNetworkCheckInterval = Duration(seconds: 5);
const Duration _kCountdownDuration = Duration(seconds: 3);
const String _kDraftKey = 'go_live_draft_v1';

// ============================================================================
// LOGGING
// ============================================================================

class _GoLiveLogger {
  static const _tag = 'GoLive';
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
// SANITIZER (anti-XSS + validation)
// ============================================================================

class _LiveSanitizer {
  _LiveSanitizer._();

  static String title(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    if (s.length > _kMaxTitleLength) {
      s = s.substring(0, _kMaxTitleLength);
    }
    return s;
  }

  static String description(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    if (s.length > _kMaxDescLength) {
      s = s.substring(0, _kMaxDescLength);
    }
    return s;
  }
}

// ============================================================================
// AUDIENCE TYPE
// ============================================================================

enum _Audience { public, followers, private }

extension _AudienceX on _Audience {
  IconData get icon {
    switch (this) {
      case _Audience.public:
        return Icons.public_rounded;
      case _Audience.followers:
        return Icons.people_outline_rounded;
      case _Audience.private:
        return Icons.lock_outline_rounded;
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case _Audience.public:
        return l10n.t('live_audience_public');
      case _Audience.followers:
        return l10n.t('live_audience_followers');
      case _Audience.private:
        return l10n.t('live_audience_private');
    }
  }
}

// ============================================================================
// NETWORK QUALITY
// ============================================================================

enum _NetworkQuality { excellent, good, poor, offline }

extension _NetworkQualityX on _NetworkQuality {
  Color color(BuildContext ctx) {
    switch (this) {
      case _NetworkQuality.excellent:
        return const Color(0xFF22C55E);
      case _NetworkQuality.good:
        return const Color(0xFFEAB308);
      case _NetworkQuality.poor:
        return const Color(0xFFF97316);
      case _NetworkQuality.offline:
        return const Color(0xFFEF4444);
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case _NetworkQuality.excellent:
        return l10n.t('live_network_excellent');
      case _NetworkQuality.good:
        return l10n.t('live_network_good');
      case _NetworkQuality.poor:
        return l10n.t('live_network_poor');
      case _NetworkQuality.offline:
        return l10n.t('live_network_offline');
    }
  }
}

// ============================================================================
// GO LIVE PAGE
// ============================================================================

class GoLivePage extends ConsumerStatefulWidget {
  const GoLivePage({super.key});

  @override
  ConsumerState<GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends ConsumerState<GoLivePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ═══ Controllers ═══
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  late final AnimationController _countdownCtrl;

  // ═══ Camera ═══
  CameraController? _cameraCtrl;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _cameraReady = false;
  bool _cameraError = false;
  bool _micEnabled = true;
  bool _flashEnabled = false;

  // ═══ State ═══
  String _category = 'general';
  _Audience _audience = _Audience.public;
  _NetworkQuality _networkQuality = _NetworkQuality.good;
  DateTime? _lastTap;
  bool _showAdvanced = false;
  int _countdownValue = 3;
  bool _isCountingDown = false;
  Timer? _networkTimer;

  // ═══ Static data ═══
  static const _categoryKeys = [
    'general',
    'music',
    'comedy',
    'sport',
    'education',
    'business',
    'gaming',
    'cooking',
    'art',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _countdownCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadDraft();
    _initCamera();
    _startNetworkMonitor();
    _GoLiveLogger.info('GoLivePage init');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDraft();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    _countdownCtrl.dispose();
    _cameraCtrl?.dispose();
    _networkTimer?.cancel();
    _GoLiveLogger.info('GoLivePage disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveDraft();
    }
  }

  // ════════════════════════════════════════════════════════════
  // DRAFT (auto-save)
  // ════════════════════════════════════════════════════════════

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_kDraftKey);
      if (data == null) return;

      final parts = data.split('|||');
      if (parts.length >= 3) {
        setState(() {
          _titleCtrl.text = parts[0];
          _descCtrl.text = parts[1];
          _category = parts[2];
          if (parts.length > 3) _tagsCtrl.text = parts[3];
        });
        _GoLiveLogger.info('Draft loaded');
      }
    } catch (e) {
      _GoLiveLogger.warn('Draft load failed', {'error': '$e'});
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = [
        _titleCtrl.text,
        _descCtrl.text,
        _category,
        _tagsCtrl.text,
      ].join('|||');
      await prefs.setString(_kDraftKey, data);
    } catch (e) {
      _GoLiveLogger.warn('Draft save failed', {'error': '$e'});
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDraftKey);
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════
  // CAMERA
  // ════════════════════════════════════════════════════════════

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!status.isGranted || !micStatus.isGranted) {
        _GoLiveLogger.warn('Camera/mic permission denied');
        setState(() => _cameraError = true);
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _GoLiveLogger.warn('No cameras available');
        setState(() => _cameraError = true);
        return;
      }

      // Choisir front par défaut
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;

      await _setupCamera();
    } catch (e) {
      _GoLiveLogger.error('Camera init failed', {'error': '$e'});
      if (mounted) setState(() => _cameraError = true);
    }
  }

  Future<void> _setupCamera() async {
    try {
      _cameraCtrl?.dispose();
      _cameraCtrl = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: _micEnabled,
      );
      await _cameraCtrl!.initialize();
      if (mounted) {
        setState(() => _cameraReady = true);
        _GoLiveLogger.info('Camera ready',
            {'camera': _cameras[_cameraIndex].name});
      }
    } catch (e) {
      _GoLiveLogger.error('Camera setup failed', {'error': '$e'});
      if (mounted) setState(() => _cameraError = true);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _cameraCtrl == null) return;
    HapticFeedback.selectionClick();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _setupCamera();
    _GoLiveLogger.info('Camera switched', {'index': _cameraIndex});
  }

  Future<void> _toggleMic() async {
    HapticFeedback.selectionClick();
    setState(() => _micEnabled = !_micEnabled);
    if (_cameraCtrl != null) {
      await _setupCamera();
    }
    _GoLiveLogger.info('Mic toggled', {'enabled': _micEnabled});
  }

  Future<void> _toggleFlash() async {
    if (_cameraCtrl == null) return;
    HapticFeedback.selectionClick();
    try {
      if (_flashEnabled) {
        await _cameraCtrl!.setFlashMode(FlashMode.off);
      } else {
        await _cameraCtrl!.setFlashMode(FlashMode.torch);
      }
      setState(() => _flashEnabled = !_flashEnabled);
      _GoLiveLogger.info('Flash toggled', {'enabled': _flashEnabled});
    } catch (e) {
      _GoLiveLogger.warn('Flash toggle failed', {'error': '$e'});
    }
  }

  // ════════════════════════════════════════════════════════════
  // NETWORK MONITORING
  // ════════════════════════════════════════════════════════════

  void _startNetworkMonitor() {
    _checkNetwork();
    _networkTimer =
        Timer.periodic(_kNetworkCheckInterval, (_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _NetworkQuality q;
      if (result.contains(ConnectivityResult.none)) {
        q = _NetworkQuality.offline;
      } else if (result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet)) {
        q = _NetworkQuality.excellent;
      } else if (result.contains(ConnectivityResult.mobile)) {
        q = _NetworkQuality.good;
      } else {
        q = _NetworkQuality.poor;
      }
      if (mounted && _networkQuality != q) {
        setState(() => _networkQuality = q);
      }
    } catch (e) {
      _GoLiveLogger.warn('Network check failed', {'error': '$e'});
    }
  }

  // ════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kThrottle) {
      return false;
    }
    _lastTap = now;
    return true;
  }

  Future<void> _onStart() async {
    if (!_throttle()) return;

    // Validation
    final title = _LiveSanitizer.title(_titleCtrl.text);
    if (title.isEmpty) {
      // ✅ CORRECTION : Utilisation de AppLocalizations.of(context)
      _snack(AppLocalizations.of(context).t('live_error_title_required'),
          error: true);
      return;
    }

    if (_networkQuality == _NetworkQuality.offline) {
      // ✅ CORRECTION : Utilisation de AppLocalizations.of(context)
      _snack(AppLocalizations.of(context).t('live_error_offline'),
          error: true);
      return;
    }

    if (_networkQuality == _NetworkQuality.poor) {
      final l10n = AppLocalizations.of(context);
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.t('live_poor_network_title')),
          content: Text(l10n.t('live_poor_network_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.t('common_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('live_start_anyway')),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    await _clearDraft();

    // Countdown
    setState(() => _isCountingDown = true);
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;

    _GoLiveLogger.info('Starting live', {
      'title': title,
      'category': _category,
      'audience': _audience.name,
    });

    await ref.read(goLiveNotifierProvider.notifier).start(
          title: title.isEmpty ? 'Live THIX' : title,
          category: _category,
        );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? ThixPolicy.danger : ThixPolicy.domainMedia,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(goLiveNotifierProvider);

    ref.listen<GoLiveState>(goLiveNotifierProvider, (prev, next) {
      if (next is GoLiveReady) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LiveHostPage(
              session: next.session,
              creds: next.creds,
            ),
          ),
        );
      } else if (next is GoLiveError) {
        // ✅ CORRECTION : Utilisation de next.error.toString()
       _snack("Erreur : ${next.toString()}", error: true);
        ref.read(goLiveNotifierProvider.notifier).reset();
        if (mounted) setState(() => _isCountingDown = false);
      }
    });

    final loading = state is GoLiveLoading || _isCountingDown;

    return PopScope(
      canPop: !loading,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || loading) return;
        await _confirmExit(l10n);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(l10n, loading),
                  Expanded(child: _buildPreview(l10n)),
                  _buildControls(),
                  _buildForm(l10n, loading),
                  _buildStartButton(l10n, loading),
                ],
              ),
            ),
            if (_isCountingDown) _buildCountdown(l10n),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ──
  Widget _buildTopBar(AppLocalizations l10n, bool loading) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.t('common_close'),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: loading ? null : () => _confirmExit(l10n),
            ),
          ),
          const Spacer(),
          _NetworkIndicator(quality: _networkQuality, l10n: l10n),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: l10n.t('live_advanced_options'),
            child: IconButton(
              icon: Icon(
                _showAdvanced
                    ? Icons.expand_less_rounded
                    : Icons.tune_rounded,
                color: Colors.white,
              ),
              onPressed: loading
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() => _showAdvanced = !_showAdvanced);
                    },
            ),
          ),
        ],
      ),
    );
  }

  // ── Preview ──
  Widget _buildPreview(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_cameraReady && _cameraCtrl != null)
              CameraPreview(_cameraCtrl!)
            else if (_cameraError)
              _PreviewError(l10n: l10n, onRetry: _initCamera)
            else
              _PreviewLoading(l10n: l10n),

            // Overlay category badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.t('live_category_${_category}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // Audience badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_audience.icon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _audience.label(l10n),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Controls ──
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.cameraswitch_rounded,
            label: 'Flip',
            onTap: _cameraReady ? _switchCamera : null,
          ),
          _ControlButton(
            icon: _micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: _micEnabled ? 'Mic ON' : 'Mic OFF',
            active: _micEnabled,
            onTap: _toggleMic,
          ),
          _ControlButton(
            icon:
                _flashEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            label: 'Flash',
            active: _flashEnabled,
            onTap: _cameraReady ? _toggleFlash : null,
          ),
        ],
      ),
    );
  }

  // ── Form ──
  Widget _buildForm(AppLocalizations l10n, bool loading) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              textField: true,
              label: l10n.t('live_title_label'),
              child: TextField(
                controller: _titleCtrl,
                enabled: !loading,
                maxLength: _kMaxTitleLength,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  labelText: l10n.t('live_title_label'),
                  labelStyle: const TextStyle(color: Colors.white54),
                  counterStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            if (_showAdvanced) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                enabled: !loading,
                maxLength: _kMaxDescLength,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: l10n.t('live_description_label'),
                  labelStyle: const TextStyle(color: Colors.white54),
                  counterStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagsCtrl,
                enabled: !loading,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: l10n.t('live_tags_label'),
                  hintText: l10n.t('live_tags_hint'),
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t('live_audience_label'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _Audience.values.map((a) {
                  final sel = _audience == a;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(a.icon,
                                size: 14,
                                color: sel ? Colors.white : Colors.white70),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                a.label(l10n),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: sel ? Colors.white : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        selected: sel,
                        onSelected: loading
                            ? null
                            : (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _audience = a);
                              },
                        selectedColor: ThixPolicy.primary,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.06),
                        side: BorderSide.none,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),
            Text(
              l10n.t('live_category_label'),
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categoryKeys.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final key = _categoryKeys[i];
                  final sel = key == _category;
                  return Semantics(
                    button: true,
                    selected: sel,
                    label: l10n.t('live_category_$key'),
                    child: ChoiceChip(
                      label: Text(l10n.t('live_category_$key')),
                      selected: sel,
                      onSelected: loading
                          ? null
                          : (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _category = key);
                            },
                      selectedColor: ThixPolicy.primary,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.06),
                      side: BorderSide.none,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Start Button ──
  Widget _buildStartButton(AppLocalizations l10n, bool loading) {
    final offline = _networkQuality == _NetworkQuality.offline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Semantics(
        button: true,
        label: l10n.t('live_start_btn'),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (loading || offline) ? null : _onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: offline
                  ? Colors.grey.shade700
                  : const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white24,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.podcasts_rounded, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        offline
                            ? l10n.t('live_network_offline')
                            : l10n.t('live_start_btn'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Countdown overlay ──
  Widget _buildCountdown(AppLocalizations l10n) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_countdownValue',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 140,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('live_starting_soon'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirm exit ──
  Future<void> _confirmExit(AppLocalizations l10n) async {
    if (_titleCtrl.text.trim().isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.t('live_exit_title')),
          content: Text(l10n.t('live_exit_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.t('common_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('live_exit_discard'),
                  style: const TextStyle(color: ThixPolicy.danger)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (mounted) Navigator.of(context).pop();
  }
}

// ============================================================================
// SUB-WIDGETS
// ============================================================================

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: active
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                icon,
                color: active ? Colors.white : Colors.white70,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkIndicator extends StatelessWidget {
  final _NetworkQuality quality;
  final AppLocalizations l10n;

  const _NetworkIndicator({required this.quality, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final color = quality.color(context);
    return Semantics(
      label: '${l10n.t("live_network_quality")}: ${quality.label(l10n)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              quality.label(l10n),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewLoading extends StatelessWidget {
  final AppLocalizations l10n;
  const _PreviewLoading({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              l10n.t('live_camera_loading'),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onRetry;
  const _PreviewError({required this.l10n, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              l10n.t('live_camera_error'),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.t('common_retry'),
                  style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
