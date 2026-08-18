import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

const Color kViolet = Color(0xFF7C5CFC);
const Color kBgBlack = Color(0xFF080610);

// Riverpod state pour analytics / scalability
final videoPlaybackProvider = StateProvider.autoDispose<bool>((ref) => false);

class VideoPlayerPage extends ConsumerStatefulWidget {
  final String title;
  final String videoUrl;
  const VideoPlayerPage({super.key, required this.title, required this.videoUrl});
  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isError = false;
  String _errorMsg = '';
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isMuted = false;
  bool _isBuffering = false;
  Timer? _hideTimer;
  Timer? _seekTextTimer;
  String _seekText = '';
  bool _seekIsForward = true;
  int _retryCount = 0;
  static const int _maxRetry = 3;

  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(Duration.zero);
  Duration get _duration => _durationNotifier.value;
  Duration get _position => _positionNotifier.value;

  // Animation pour le bouton play/pause central (feedback plus fluide)
  late final AnimationController _playPauseAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      setState(() {
        _isError = false;
        _isInitialized = false;
        _isBuffering = true;
      });
      _controller?.removeListener(_listener);
      await _controller?.dispose();
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false),
      );
      _controller!.addListener(_listener);
      await _controller!.initialize().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      _durationNotifier.value = _controller!.value.duration;
      setState(() {
        _isInitialized = true;
        _isBuffering = false;
      });
      await _controller!.play();
      _playPauseAnim.forward();
      ref.read(videoPlaybackProvider.notifier).state = true;
      _startHideTimer();
      _retryCount = 0;
    } catch (e) {
      if (!mounted) return;
      if (_retryCount < _maxRetry) {
        _retryCount++;
        await Future.delayed(Duration(seconds: _retryCount * 2));
        _initVideo();
      } else {
        setState(() {
          _isError = true;
          _isBuffering = false;
          _errorMsg = e.toString();
        });
      }
    }
  }

  void _listener() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (!mounted) return;
    final val = _controller!.value;
    _positionNotifier.value = val.position;
    _durationNotifier.value = val.duration;
    final buffering = val.isBuffering;
    if (buffering != _isBuffering) setState(() => _isBuffering = buffering);
    if (val.hasError && !_isError) setState(() => _isError = true);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _togglePlay() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _playPauseAnim.reverse();
      ref.read(videoPlaybackProvider.notifier).state = false;
    } else {
      _controller!.play();
      _playPauseAnim.forward();
      ref.read(videoPlaybackProvider.notifier).state = true;
    }
    _startHideTimer();
  }

  void _seekRelative(int seconds) {
    if (_controller == null) return;
    final newPos = _position + Duration(seconds: seconds);
    Duration target = newPos;
    if (target < Duration.zero) target = Duration.zero;
    if (target > _duration) target = _duration;
    _controller!.seekTo(target);
    setState(() {
      _seekIsForward = seconds > 0;
      _seekText = '${seconds > 0 ? '+' : ''}$seconds s';
    });
    _seekTextTimer?.cancel();
    _seekTextTimer = Timer(const Duration(milliseconds: 600), () => mounted ? setState(() => _seekText = '') : null);
    _startHideTimer();
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      setState(() => _isFullscreen = false);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    } else {
      setState(() => _isFullscreen = true);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    _startHideTimer();
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() => _isMuted = !_isMuted);
    _controller!.setVolume(_isMuted ? 0 : 1);
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    if (state == AppLifecycleState.paused) _controller!.pause();
    if (state == AppLifecycleState.resumed && _isInitialized && !_isError) _controller!.play();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _seekTextTimer?.cancel();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _playPauseAnim.dispose();
    _controller?.removeListener(_listener);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) async {
        if (_isFullscreen && !didPop) {
          await _toggleFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: kBgBlack,
        body: SafeArea(
          top: !_isFullscreen,
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isError
                ? _errorView()
                : !_isInitialized
                    ? _loading()
                    : _player(),
          ),
        ),
      ),
    );
  }

  Widget _loading() => Center(
        key: const ValueKey('loading'),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: kViolet, strokeWidth: 2.5)),
          const SizedBox(height: 12),
          Text(widget.title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          const Text('Chargement...', style: TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      );

  Widget _errorView() => Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
              child: const Icon(Icons.play_disabled_rounded, size: 32, color: Colors.white54),
            ),
            const SizedBox(height: 14),
            const Text('Impossible de lire la vidéo', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              _errorMsg.isEmpty ? 'Vérifie ta connexion' : _errorMsg,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 10.5),
            ),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(
                onPressed: _initVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kViolet,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text('Réessayer', style: TextStyle(fontSize: 11, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Retour', style: TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ]),
          ]),
        ),
      );

  Widget _player() {
    return GestureDetector(
      key: const ValueKey('player'),
      onTap: _toggleControls,
      onDoubleTapDown: (d) {
        final w = MediaQuery.of(context).size.width;
        if (d.globalPosition.dx < w / 2) {
          _seekRelative(-10);
        } else {
          _seekRelative(10);
        }
      },
      child: Stack(children: [
        Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),

        // Indicateur de buffering fluide (fondu au lieu d'apparition brute)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isBuffering ? 1 : 0,
          child: const Center(
            child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: kViolet, strokeWidth: 2.5)),
          ),
        ),

        // Voile de dégradé derrière les contrôles (fondu)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _showControls ? 1 : 0,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.75)],
                ),
              ),
            ),
          ),
        ),

        // Ripple visuel de double-tap (avance/recul 10s)
        if (_seekText.isNotEmpty)
          Align(
            alignment: _seekIsForward ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _seekText.isEmpty ? 0 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(50)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_seekIsForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded, color: Colors.white, size: 20),
                    const SizedBox(height: 2),
                    Text(_seekText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),

        // Barre du haut
        AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          offset: _showControls ? Offset.zero : const Offset(0, -0.5),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _showControls ? 1 : 0,
            child: Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: Row(children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                    InkWell(
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _toggleFullscreen,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),

        // Contrôles centraux (lecture / avance / recul)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _showControls ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_showControls,
            child: Center(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _circleBtn(Icons.replay_10_rounded, () => _seekRelative(-10)),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: kViolet,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: kViolet.withOpacity(0.4), blurRadius: 18)],
                    ),
                    child: AnimatedIcon(
                      icon: AnimatedIcons.play_pause,
                      progress: _playPauseAnim,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                _circleBtn(Icons.forward_10_rounded, () => _seekRelative(10)),
              ]),
            ),
          ),
        ),

        // Barre du bas (progression + temps)
        AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          offset: _showControls ? Offset.zero : const Offset(0, 0.5),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _showControls ? 1 : 0,
            child: Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, _isFullscreen ? 10 : 18),
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ValueListenableBuilder<Duration>(
                          valueListenable: _positionNotifier,
                          builder: (_, pos, __) => ValueListenableBuilder<Duration>(
                            valueListenable: _durationNotifier,
                            builder: (_, dur, ___) => Text(
                              '${_fmt(pos)} / ${_fmt(dur)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<Duration>(
                      valueListenable: _positionNotifier,
                      builder: (_, pos, __) => ValueListenableBuilder<Duration>(
                        valueListenable: _durationNotifier,
                        builder: (_, dur, ___) {
                          final progress = dur.inMilliseconds == 0 ? 0.0 : pos.inMilliseconds / dur.inMilliseconds;
                          return SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: kViolet,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: kViolet,
                            ),
                            child: Slider(
                              value: progress.clamp(0.0, 1.0),
                              onChanged: (v) {
                                final newPos = Duration(milliseconds: (v * dur.inMilliseconds).round());
                                _positionNotifier.value = newPos; // feedback instantané pendant le drag
                                _controller!.seekTo(newPos);
                              },
                              onChangeStart: (_) => _hideTimer?.cancel(),
                              onChangeEnd: (_) => _startHideTimer(),
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      );
}
