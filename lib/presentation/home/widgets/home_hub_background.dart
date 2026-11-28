// lib/presentation/home/widgets/home_hub_background.dart
//
// Fond THIX HUB : photos (diversité africaine) en défilement automatique,
// fondu enchaîné + léger zoom lent, voile blanc dégradé pour la lisibilité.
// Sans photo : dégradé ciel teinté de la couleur principale.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'home_hub_settings.dart';

class HomeHubBackground extends StatefulWidget {
  final HomeHubController controller;
  const HomeHubBackground({super.key, required this.controller});

  @override
  State<HomeHubBackground> createState() => _HomeHubBackgroundState();
}

class _HomeHubBackgroundState extends State<HomeHubBackground>
    with WidgetsBindingObserver {
  int _index = 0;
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onChanged);
    _restartTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onChanged);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    _restartTimer();
  }

  void _onChanged() {
    if (!mounted) return;
    _restartTimer();
    setState(() {});
  }

  void _prefetch(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final imgs = widget.controller.settings.images;
      if (imgs.isEmpty) return;
      precacheImage(
        CachedNetworkImageProvider(imgs[index % imgs.length]),
        context,
      ).catchError((_) {});
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    final s = widget.controller.settings;
    if (s.images.length > 1) _prefetch(_index + 1);
    if (!_visible || !s.autoScroll || s.images.length < 2) return;

    _timer = Timer.periodic(Duration(seconds: s.intervalSeconds), (_) {
      if (!mounted) return;
      final imgs = widget.controller.settings.images;
      if (imgs.length < 2) return;
      final next = (_index + 1) % imgs.length;
      setState(() => _index = next);
      _prefetch(next + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.controller.settings;
    final imgs = s.images;
    final i = imgs.isEmpty ? 0 : _index % imgs.length;
    const white = Colors.white;

    final a0 = (0.35 + s.veil * 0.60).clamp(0.0, 0.97);
    final a1 = (s.veil * 0.35).clamp(0.0, 1.0);
    final a2 = (s.veil * 0.12).clamp(0.0, 1.0);
    final a3 = (s.veil * 0.45).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(white, s.primary, 0.20)!,
                  Color.lerp(white, s.primary, 0.07)!,
                  white,
                ],
              ),
            ),
          ),
          if (imgs.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 1100),
              switchInCurve: Curves.easeOut,
              child: _Slide(
                key: ValueKey<String>('${i}_${imgs[i]}'),
                url: imgs[i],
                hold: Duration(seconds: s.intervalSeconds + 2),
              ),
            ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.30, 0.52, 0.82, 1.0],
                  colors: [
                    white.withOpacity(a0),
                    white.withOpacity(a1),
                    white.withOpacity(a2),
                    white.withOpacity(a3),
                    white.withOpacity(0.96),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final String url;
  final Duration hold;
  const _Slide({super.key, required this.url, required this.hold});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: 1.08),
        duration: hold,
        curve: Curves.linear,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 350),
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
