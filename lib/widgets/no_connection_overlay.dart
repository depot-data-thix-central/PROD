import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

/// Overlay plein écran quand il n'y a pas de réseau.
/// À placer en haut d'un Stack.
class NoConnectionOverlay extends StatefulWidget {
  const NoConnectionOverlay({super.key});

  @override
  State<NoConnectionOverlay> createState() => _NoConnectionOverlayState();
}

class _NoConnectionOverlayState extends State<NoConnectionOverlay> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _check();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
      if (offline != _offline && mounted) {
        setState(() => _offline = offline);
      }
    });
  }

  Future<void> _check() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    if (mounted) setState(() => _offline = offline);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        color: ThixPolicy.surfaceSoft,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      size: 44,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Pas de connexion',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: ThixPolicy.textMain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Vérifiez votre réseau et réessayez.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: ThixPolicy.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _check,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      'Réessayer',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
